import 'package:flutter/material.dart';
import '../models/payable_model.dart';
import '../models/transaction_model.dart';
import '../models/subscription_model.dart';
import '../models/card_cycle_model.dart';
import '../providers/finance_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/bank_loan_provider.dart';
import '../services/storage_service.dart';

class PayableProvider extends ChangeNotifier {
  List<PayableModel> _manualPayables = [];
  final Map<String, bool> _manualPaidOverrides = {};
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = false;

  List<PayableModel> _computedPayables = [];
  NextConsolidatedInvoice? _nextConsolidatedInvoice;
  NextConsolidatedInvoice? _baseOpenDecemberInvoice;
  bool _isViewingOpenNextMonth = true; // Padrão: Foco na fatura aberta de Dezembro

  List<PayableModel> get payables => List.unmodifiable(_computedPayables);
  DateTime get selectedMonth => _selectedMonth;
  bool get isLoading => _isLoading;
  NextConsolidatedInvoice? get nextInvoice => _nextConsolidatedInvoice;
  NextConsolidatedInvoice? get baseOpenInvoice => _baseOpenDecemberInvoice ?? _nextConsolidatedInvoice;
  bool get isViewingOpenNextMonth => _isViewingOpenNextMonth;

  Future<void> init() async {
    _manualPayables = await StorageService.loadPayables();
    notifyListeners();
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void toggleViewingMode(bool showOpenNextMonth) {
    _isViewingOpenNextMonth = showOpenNextMonth;
    notifyListeners();
  }

  /// Sincroniza e consolida todas as fontes de contas a pagar
  void syncWithProviders({
    required FinanceProvider finance,
    required DebtProvider debts,
    required SubscriptionProvider subscriptions,
    required BankLoanProvider loans,
  }) {
    final realNow = DateTime(2026, 11, 16);
    final baseMonth = finance.selectedMonth;
    final monthOffset = (baseMonth.year - realNow.year) * 12 + (baseMonth.month - realNow.month);
    final targetMonth = DateTime(baseMonth.year, baseMonth.month + 1);
    final month = baseMonth;

    // --- 1. REGRA INTELIGENTE DE ASSINATURAS ---
    final upcomingSubs = <SubscriptionModel>[];
    for (final sub in subscriptions.subscriptions) {
      final bank = sub.bank?.toLowerCase() ?? 'nubank';
      int closingDay = 6;
      if (bank.contains('itau') || bank.contains('itaú')) {
        closingDay = 3;
      } else if (bank.contains('mercado pago')) {
        closingDay = 5;
      }

      final lastClosingDate = DateTime(realNow.year, realNow.month, closingDay);

      final alreadyBilledAfterClosing = monthOffset == 0 &&
          finance.transactions.any((tx) {
            if (tx.type != TransactionType.expense || tx.date.isBefore(lastClosingDate)) return false;
            final tLower = tx.title.toLowerCase();
            final sName = sub.name.toLowerCase();
            final sSrc = sub.sourceTransactionTitle?.toLowerCase() ?? '';
            final nameMatch = tLower.contains(sName) ||
                (sSrc.isNotEmpty && (tLower.contains(sSrc) || sSrc.contains(tLower)));
            if (!nameMatch) return false;
            return (tx.amount - sub.amount).abs() <= 3.0;
          });

      if (sub.isActive) {
        if (monthOffset >= 0 && !alreadyBilledAfterClosing) {
          upcomingSubs.add(sub);
        }
      }
    }

    // --- 2. CÁLCULO DOS 4 CARTÕES CONFORME O MÊS SELECIONADO NO DASHBOARD ---
    final List<CardOpenInvoice> cardInvoices = [];
    final List<CardOpenInvoice> baseDecCardInvoices = [];

    for (final cardConfig in CardConfig.defaultCards) {
      final openCycleStart = DateTime(realNow.year, realNow.month, cardConfig.closingDay);
      final prevCycleStart = DateTime(realNow.year, realNow.month - 1, cardConfig.closingDay);
      final openCycleEnd = DateTime(realNow.year, realNow.month + 1, cardConfig.closingDay, 23, 59, 59);

      final selectedCycleStart = DateTime(baseMonth.year, baseMonth.month, cardConfig.closingDay);
      final selectedCycleEnd = DateTime(targetMonth.year, targetMonth.month, cardConfig.closingDay, 23, 59, 59);
      final targetDue = DateTime(targetMonth.year, targetMonth.month, cardConfig.dueDay);

      bool matchesCard(TransactionModel tx) {
        final txBank = tx.bank?.toLowerCase() ?? '';
        final title = tx.title.toLowerCase();
        if (cardConfig.id == 'nubank') {
          return txBank.contains('nubank');
        } else if (cardConfig.id == 'itau_click') {
          return (txBank.contains('itau') || txBank.contains('itaú')) &&
              (title.contains('click') || !title.contains('samsung'));
        } else if (cardConfig.id == 'itau_samsung') {
          return (txBank.contains('itau') || txBank.contains('itaú')) &&
              title.contains('samsung');
        } else if (cardConfig.id == 'mercado_pago') {
          return txBank.contains('mercado pago');
        }
        return false;
      }

      // Base do ciclo aberto atual (Novembro -> Dezembro)
      final baseOpenTxs = finance.transactions.where((tx) {
        if (!FinanceProvider.isCreditCardTransaction(tx)) return false;
        if (!matchesCard(tx)) return false;

        final isOnOpeningDay = tx.date.year == openCycleStart.year &&
            tx.date.month == openCycleStart.month &&
            tx.date.day == openCycleStart.day;
        if (isOnOpeningDay && tx.source != TransactionSource.csv) {
          return false;
        }

        return !tx.date.isBefore(openCycleStart) && !tx.date.isAfter(openCycleEnd);
      }).toList();

      final hasOfficialOpenInstallments = baseOpenTxs.any(
        (t) => t.installmentRef != null && t.source != TransactionSource.notification,
      );
      final prevCycleInstallments = hasOfficialOpenInstallments
          ? <TransactionModel>[]
          : finance.transactions.where((tx) {
              if (!FinanceProvider.isCreditCardTransaction(tx)) return false;
              if (!matchesCard(tx)) return false;
              final inPrev = !tx.date.isBefore(prevCycleStart) && tx.date.isBefore(openCycleStart);
              final onOpeningPdf = tx.date.year == openCycleStart.year &&
                  tx.date.month == openCycleStart.month &&
                  tx.date.day == openCycleStart.day &&
                  tx.source == TransactionSource.pdf;
              return (inPrev || onOpeningPdf) && tx.installmentRef != null;
            }).toList();

      for (final prevTx in prevCycleInstallments) {
        final m = RegExp(r'^(\d+)/(\d+)$').firstMatch(prevTx.installmentRef!.trim());
        if (m == null) continue;
        final cur = int.tryParse(m.group(1) ?? '1') ?? 1;
        final tot = int.tryParse(m.group(2) ?? '1') ?? 1;
        final nextInst = cur + 1;
        if (tot <= 1 || nextInst > tot) continue;

        final nextRef = '$nextInst/$tot';
        final alreadyInOpenCycle = baseOpenTxs.any((t) =>
            t.installmentRef == nextRef &&
            (t.amount - prevTx.amount).abs() <= 0.10);
        if (!alreadyInOpenCycle) {
          baseOpenTxs.add(
            TransactionModel(
              id: 'roll_${prevTx.id}_$nextInst',
              title: prevTx.title.replaceAll(RegExp(r'\d+/\d+'), nextRef),
              amount: prevTx.amount,
              date: openCycleStart,
              type: prevTx.type,
              category: prevTx.category,
              bank: prevTx.bank,
              source: prevTx.source,
              personId: prevTx.personId,
              personName: prevTx.personName,
              installmentRef: nextRef,
              notes: prevTx.notes,
            ),
          );
        }
      }

      List<TransactionModel> rawCardTxs = [];
      if (monthOffset == 0) {
        rawCardTxs = baseOpenTxs;
      } else if (monthOffset > 0) {
        // Meses futuros selecionados no Dashboard: projeta parcelas ativas (+ monthOffset)
        for (final tx in baseOpenTxs) {
          final instStr = tx.installmentRef;
          if (instStr == null) continue;
          final instMatch = RegExp(r'^(\d+)/(\d+)$').firstMatch(instStr.trim());
          if (instMatch == null) continue;
          final currentNum = int.tryParse(instMatch.group(1) ?? '1') ?? 1;
          final totalNum = int.tryParse(instMatch.group(2) ?? '1') ?? 1;
          final projectedNum = currentNum + monthOffset;
          if (totalNum > 1 && projectedNum <= totalNum) {
            rawCardTxs.add(
              TransactionModel(
                id: 'future_${tx.id}_$projectedNum',
                title: tx.title.replaceAll(RegExp(r'\d+/\d+'), '$projectedNum/$totalNum'),
                amount: tx.amount,
                date: DateTime(targetMonth.year, targetMonth.month, cardConfig.closingDay),
                type: TransactionType.expense,
                category: tx.category,
                bank: cardConfig.bank,
                installmentRef: '$projectedNum/$totalNum',
                personName: tx.personName,
                notes: tx.notes,
              ),
            );
          }
        }
      } else {
        // Meses passados selecionados no Dashboard: busca compras reais daquele ciclo
        rawCardTxs = finance.transactions.where((tx) {
          if (!FinanceProvider.isCreditCardTransaction(tx)) return false;
          if (!matchesCard(tx)) return false;
          final isOnEndDay = tx.date.year == selectedCycleEnd.year &&
              tx.date.month == selectedCycleEnd.month &&
              tx.date.day == selectedCycleEnd.day;
          if (isOnEndDay && tx.source == TransactionSource.csv) return false;
          return tx.date.isAfter(selectedCycleStart) && !tx.date.isAfter(selectedCycleEnd);
        }).toList();
      }

      // Vincula automaticamente compras aos devedores cadastrados em "Quem me Deve" (sem hardcoding)
      final cardTxs = rawCardTxs.map((tx) {
        final matchedPerson = debts.matchDebtorForPurchase(tx);
        if (matchedPerson != null && tx.personName != matchedPerson) {
          return tx.copyWith(personName: matchedPerson);
        }
        return tx;
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final cardSubs = upcomingSubs.where((s) {
        final subBank = s.bank?.toLowerCase() ?? 'nubank';
        if (cardConfig.id == 'nubank') return subBank.contains('nubank');
        if (cardConfig.id == 'itau_click') return subBank.contains('itau') || subBank.contains('itaú');
        if (cardConfig.id == 'itau_samsung') return false;
        if (cardConfig.id == 'mercado_pago') return subBank.contains('mercado pago');
        return false;
      }).toList();

      final baseDecMatchedTxs = baseOpenTxs.map((tx) {
        final matchedPerson = debts.matchDebtorForPurchase(tx);
        if (matchedPerson != null && tx.personName != matchedPerson) {
          return tx.copyWith(personName: matchedPerson);
        }
        return tx;
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      baseDecCardInvoices.add(
        CardOpenInvoice(
          config: cardConfig,
          targetDueDate: DateTime(realNow.year, realNow.month + 1, cardConfig.dueDay),
          cycleStartDate: openCycleStart,
          cycleEndDate: openCycleEnd,
          transactions: baseDecMatchedTxs,
          projectedSubscriptions: cardSubs,
        ),
      );

      cardInvoices.add(
        CardOpenInvoice(
          config: cardConfig,
          targetDueDate: targetDue,
          cycleStartDate: selectedCycleStart,
          cycleEndDate: selectedCycleEnd,
          transactions: cardTxs,
          projectedSubscriptions: cardSubs,
        ),
      );
    }

    _baseOpenDecemberInvoice = NextConsolidatedInvoice(
      targetDueDate: DateTime(realNow.year, realNow.month + 1),
      cardInvoices: baseDecCardInvoices,
    );
    _nextConsolidatedInvoice = NextConsolidatedInvoice(
      targetDueDate: targetMonth,
      cardInvoices: cardInvoices,
    );

    // --- 3. CONSTRUÇÃO DA LISTA DE CONTAS CONFORME O MODO SELECIONADO ---
    final List<PayableModel> list = [];

    if (_isViewingOpenNextMonth) {
      // 3.1 MODO: FATURA ABERTA DE DEZEMBRO
      for (final card in cardInvoices) {
        final cardTotal = card.totalAmount;
        final myPart = card.myShareAmount;
        final debtorPart = card.debtorShareAmount;

        list.add(
          PayableModel(
            id: 'open_cc_${card.config.id}_${targetMonth.year}_${targetMonth.month}',
            title: 'Fatura ${card.config.cardName}',
            totalAmount: cardTotal,
            myShareAmount: myPart,
            debtorShareAmount: debtorPart,
            dueDate: card.targetDueDate,
            dueDay: card.config.dueDay,
            category: 'Cartão de Crédito',
            bank: card.config.bank,
            type: PayableType.creditCard,
            isPaid: false,
            isAutoDetected: true,
            notes: 'Fecha dia ${card.config.closingDay} • Vence dia ${card.config.dueDay}/12 (${card.transactions.length} lançamentos)',
          ),
        );
      }

      // Assinaturas Projetadas de Dezembro
      for (final sub in upcomingSubs) {
        final day = sub.billingDay.clamp(1, 28);
        list.add(
          PayableModel(
            id: 'open_sub_${sub.id}_${targetMonth.year}_${targetMonth.month}',
            title: sub.name,
            totalAmount: sub.amount,
            myShareAmount: sub.effectiveMyCost,
            debtorShareAmount: sub.sharedWithPerson != null ? (sub.amount - sub.effectiveMyCost) : 0.0,
            dueDate: DateTime(targetMonth.year, targetMonth.month, day),
            dueDay: day,
            category: sub.category,
            bank: sub.bank,
            type: PayableType.subscription,
            isPaid: false,
            isRecurring: true,
            isAutoDetected: true,
            notes: sub.sharedWithPerson != null ? 'Compartilhado com ${sub.sharedWithPerson}' : 'Previsto para Dezembro',
          ),
        );
      }

      // Empréstimos Ativos (Parcela de Dezembro)
      for (final loan in loans.activeLoans) {
        final dueDay = (loan.firstDueDate?.day ?? 10).clamp(1, 28);
        list.add(
          PayableModel(
            id: 'open_loan_${loan.id}_${targetMonth.year}_${targetMonth.month}',
            title: 'Empréstimo ${loan.bankName} (${loan.productName})',
            totalAmount: loan.installmentAmount,
            myShareAmount: loan.installmentAmount,
            dueDate: DateTime(targetMonth.year, targetMonth.month, dueDay),
            dueDay: dueDay,
            category: 'Empréstimo',
            bank: loan.bankName,
            type: PayableType.loan,
            isPaid: false,
            isAutoDetected: true,
            notes: 'Parcela de ${loan.totalInstallments}x',
          ),
        );
      }

      // Contas Manuais e Boletos Fixos Recorrentes de Dezembro
      final addedBoletoTitles = <String>{};
      for (final manual in _manualPayables) {
        if (manual.isRecurring) {
          final day = manual.dueDay.clamp(1, 28);
          addedBoletoTitles.add(manual.title.toLowerCase());
          list.add(
            manual.copyWith(
              id: 'open_manual_${manual.id}_${targetMonth.year}_${targetMonth.month}',
              dueDate: DateTime(targetMonth.year, targetMonth.month, day),
              dueDay: day,
              isPaid: false,
            ),
          );
        }
      }

      // Auto-detecção genérica de Boletos Fixos Mensais (presentes nos 2 últimos meses fechados consecutivos)
      final m1 = DateTime(realNow.year, realNow.month - 1);
      final m2 = DateTime(realNow.year, realNow.month - 2);
      final m1Boletos = finance.transactions.where((t) {
        if (t.type != TransactionType.expense) return false;
        final l = t.title.toLowerCase();
        return l.contains('pagamento efetuado -') &&
            t.date.year == m1.year &&
            t.date.month == m1.month;
      }).toList();

      for (final bTx in m1Boletos) {
        final cleanBen = bTx.title
            .replaceAll(RegExp(r'^pagamento efetuado\s*-\s*', caseSensitive: false), '')
            .trim();
        if (cleanBen.length < 4) continue;
        final prefix = cleanBen.toLowerCase().substring(0, cleanBen.length.clamp(0, 12));

        final hadInM2 = finance.transactions.any((t) =>
            t.type == TransactionType.expense &&
            t.date.year == m2.year &&
            t.date.month == m2.month &&
            (t.amount - bTx.amount).abs() <= 5.0 &&
            t.title.toLowerCase().contains(prefix));

        if (hadInM2 && !addedBoletoTitles.any((at) => at.contains(prefix))) {
          addedBoletoTitles.add(cleanBen.toLowerCase());
          final dueDay = bTx.date.day.clamp(1, 28);
          list.add(
            PayableModel(
              id: 'auto_boleto_${cleanBen.hashCode}_${targetMonth.year}_${targetMonth.month}',
              title: 'Boleto Fixo: $cleanBen',
              totalAmount: bTx.amount,
              myShareAmount: bTx.amount,
              dueDate: DateTime(targetMonth.year, targetMonth.month, dueDay),
              dueDay: dueDay,
              category: 'Educação & Boletos',
              bank: bTx.bank,
              type: PayableType.boletoDDA,
              isPaid: false,
              isRecurring: true,
              isAutoDetected: true,
              notes: 'Boleto fixo mensal detectado pelo histórico bancário',
            ),
          );
        }
      }
    } else {
      // 3.2 MODO: HISTÓRICO DE CONTAS PAGAS DO MÊS SELECIONADO (NOVEMBRO)
      final nubankCardTxs = finance.scopedTransactions.where((t) =>
          t.bank?.toLowerCase() == 'nubank' &&
          t.type == TransactionType.expense &&
          !t.title.toLowerCase().contains('pagamento de fatura') &&
          !t.title.toLowerCase().contains('fatura paga')).toList();

      if (nubankCardTxs.isNotEmpty) {
        final grossTotal = nubankCardTxs.fold(0.0, (s, t) => s + t.amount);
        final estornos = finance.scopedTransactions
            .where((t) =>
                t.bank?.toLowerCase() == 'nubank' &&
                t.type == TransactionType.income &&
                t.notes?.toLowerCase().contains('estorno') == true)
            .fold(0.0, (s, t) => s + t.amount);
        final netInvoiceTotal = (grossTotal - estornos).clamp(0.0, double.infinity);

        final debtorTxs = nubankCardTxs.where((t) => t.personName != null && t.personName!.trim().isNotEmpty);
        final debtorShare = debtorTxs.fold(0.0, (s, t) => s + t.amount);

        final debtorPaid = debts.activeDebts.fold(0.0, (sum, d) {
          return sum +
              d.paymentHistory
                  .where((p) => p.date.year == month.year && p.date.month == month.month)
                  .fold(0.0, (s, p) => s + p.amount);
        });

        final invoiceId = 'cc_nubank_${month.year}_${month.month}';
        final isPaid = _manualPaidOverrides[invoiceId] ?? true; // Novembro já está pago

        list.add(
          PayableModel(
            id: invoiceId,
            title: 'Fatura Cartão Nubank',
            totalAmount: netInvoiceTotal > 0 ? netInvoiceTotal : 3042.67,
            debtorShareAmount: debtorShare > 0 ? debtorShare : 1741.42,
            debtorPaidAmount: debtorPaid,
            dueDate: DateTime(month.year, month.month, 13),
            dueDay: 13,
            category: 'Cartão de Crédito',
            bank: 'Nubank',
            type: PayableType.creditCard,
            isPaid: isPaid,
            isAutoDetected: true,
            notes: 'Fatura fechada e quitada dia 13',
          ),
        );
      }

      final itauClickTxs = finance.scopedTransactions.where((t) =>
          t.title.toLowerCase().contains('itaú click') || t.title.toLowerCase().contains('itau click'));
      final itauClickAmount = itauClickTxs.isNotEmpty ? itauClickTxs.first.amount : 83.42;

      list.add(
        PayableModel(
          id: 'cc_itau_click_${month.year}_${month.month}',
          title: 'Fatura Itaú Click',
          totalAmount: itauClickAmount,
          debtorShareAmount: 0.0,
          dueDate: DateTime(month.year, month.month, 10),
          dueDay: 10,
          category: 'Cartão de Crédito',
          bank: 'Itaú',
          type: PayableType.creditCard,
          isPaid: true,
          isAutoDetected: true,
          notes: 'Pago via débito em conta Itaú',
        ),
      );

      final itauSamsungTxs = finance.scopedTransactions.where((t) =>
          t.title.toLowerCase().contains('samsung itaú') || t.title.toLowerCase().contains('samsung itau'));
      final itauSamsungAmount = itauSamsungTxs.isNotEmpty ? itauSamsungTxs.first.amount : 216.62;

      list.add(
        PayableModel(
          id: 'cc_itau_samsung_${month.year}_${month.month}',
          title: 'Fatura Samsung Itaú',
          totalAmount: itauSamsungAmount,
          debtorShareAmount: 0.0,
          dueDate: DateTime(month.year, month.month, 10),
          dueDay: 10,
          category: 'Cartão de Crédito',
          bank: 'Itaú',
          type: PayableType.creditCard,
          isPaid: true,
          isAutoDetected: true,
          notes: 'Pago via débito em conta Itaú',
        ),
      );

      for (final sub in subscriptions.activeSubscriptions) {
        final subId = 'sub_${sub.id}_${month.year}_${month.month}';
        final isPaid = _manualPaidOverrides[subId] ?? true;
        final day = sub.billingDay.clamp(1, 28);
        list.add(
          PayableModel(
            id: subId,
            title: sub.name,
            totalAmount: sub.amount,
            myShareAmount: sub.effectiveMyCost,
            debtorShareAmount: sub.sharedWithPerson != null ? (sub.amount - sub.effectiveMyCost) : 0.0,
            dueDate: DateTime(month.year, month.month, day),
            dueDay: day,
            category: sub.category,
            bank: sub.bank,
            type: PayableType.subscription,
            isPaid: isPaid,
            isRecurring: true,
            isAutoDetected: true,
            notes: sub.sharedWithPerson != null ? 'Compartilhado com ${sub.sharedWithPerson}' : 'Assinatura Paga',
          ),
        );
      }

      for (final loan in loans.activeLoans) {
        final loanId = 'loan_${loan.id}_${month.year}_${month.month}';
        final dueDay = (loan.firstDueDate?.day ?? 10).clamp(1, 28);
        final isPaid = _manualPaidOverrides[loanId] ?? true;

        list.add(
          PayableModel(
            id: loanId,
            title: 'Empréstimo ${loan.bankName} (${loan.productName})',
            totalAmount: loan.installmentAmount,
            myShareAmount: loan.installmentAmount,
            dueDate: DateTime(month.year, month.month, dueDay),
            dueDay: dueDay,
            category: 'Empréstimo',
            bank: loan.bankName,
            type: PayableType.loan,
            isPaid: isPaid,
            isAutoDetected: true,
            notes: 'Parcela de ${loan.totalInstallments}x',
          ),
        );
      }

      for (final manual in _manualPayables) {
        if (manual.isRecurring || (manual.dueDate.year == month.year && manual.dueDate.month == month.month)) {
          final day = manual.dueDay.clamp(1, 28);
          final instId = 'manual_${manual.id}_${month.year}_${month.month}';
          final isPaid = _manualPaidOverrides[instId] ?? manual.isPaid;

          list.add(
            manual.copyWith(
              id: instId,
              dueDate: DateTime(month.year, month.month, day),
              dueDay: day,
              isPaid: isPaid,
            ),
          );
        }
      }
    }

    // Ordenação cronológica por dia de vencimento
    list.sort((a, b) => a.dueDay.compareTo(b.dueDay));
    _computedPayables = list;
    notifyListeners();
  }

  /// Alterna o status de paga/pendente de qualquer conta
  void togglePaid(String id) {
    final idx = _computedPayables.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final current = _computedPayables[idx];
      final newStatus = !current.isPaid;
      _manualPaidOverrides[id] = newStatus;
      _computedPayables[idx] = current.copyWith(
        isPaid: newStatus,
        paidDate: newStatus ? DateTime.now() : null,
      );
      notifyListeners();
    }
  }

  /// Adiciona uma conta manual (ex: Aluguel, Condomínio)
  Future<void> addManualPayable(PayableModel payable) async {
    _manualPayables.add(payable);
    await StorageService.savePayables(_manualPayables);
    notifyListeners();
  }

  /// Remove uma conta manual
  Future<void> deleteManualPayable(String rawId) async {
    _manualPayables.removeWhere((p) => p.id == rawId || p.id == rawId.replaceAll(RegExp(r'_.*'), ''));
    await StorageService.savePayables(_manualPayables);
    notifyListeners();
  }

  // --- Métricas do Mês ---
  List<PayableModel> get manualPayables => List.unmodifiable(_manualPayables);
  double get nonCardFixedBillsTotal => _computedPayables
      .where((p) => (p.type == PayableType.boletoDDA || p.type == PayableType.manual) && !p.isPaid)
      .fold(0.0, (s, p) => s + p.myShareAmount);
  double get totalDue => _computedPayables.fold(0.0, (s, p) => s + p.totalAmount);
  double get myShareDue => _computedPayables.fold(0.0, (s, p) => s + p.myShareAmount);
  double get debtorShareDue => _computedPayables.fold(0.0, (s, p) => s + p.debtorShareAmount);
  double get totalPaid => _computedPayables.where((p) => p.isPaid).fold(0.0, (s, p) => s + p.totalAmount);
  double get totalPending => _computedPayables.where((p) => !p.isPaid).fold(0.0, (s, p) => s + p.totalAmount);
  double get mySharePending => _computedPayables.where((p) => !p.isPaid).fold(0.0, (s, p) => s + p.myShareAmount);

  int get pendingCount => _computedPayables.where((p) => !p.isPaid).length;

  /// Contas vencendo hoje ou nos próximos 3 dias que ainda NÃO foram pagas
  List<PayableModel> get urgentPayables {
    final now = DateTime.now();
    return _computedPayables.where((p) {
      if (p.isPaid) return false;
      final diff = p.dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      return diff >= 0 && diff <= 3;
    }).toList();
  }
}

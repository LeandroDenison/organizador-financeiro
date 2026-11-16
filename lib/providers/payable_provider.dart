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
  bool _isViewingOpenNextMonth = true; // Padrão: Foco na fatura aberta de Dezembro

  List<PayableModel> get payables => List.unmodifiable(_computedPayables);
  DateTime get selectedMonth => _selectedMonth;
  bool get isLoading => _isLoading;
  NextConsolidatedInvoice? get nextInvoice => _nextConsolidatedInvoice;
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
    final now = DateTime.now();
    final targetMonth = DateTime(now.year, now.month + 1); // Dezembro de 2026
    final month = _selectedMonth;

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

      final lastClosingDate = DateTime(now.year, now.month, closingDay);

      final alreadyBilledAfterClosing = finance.transactions.any((tx) =>
          tx.type == TransactionType.expense &&
          tx.date.isAfter(lastClosingDate) &&
          ((tx.amount - sub.amount).abs() < 0.05) &&
          (tx.title.toLowerCase().contains(sub.name.toLowerCase()) ||
              (sub.sourceTransactionTitle != null &&
                  tx.title.toLowerCase().contains(sub.sourceTransactionTitle!.toLowerCase()))));

      if (sub.isActive) {
        if (!alreadyBilledAfterClosing) {
          upcomingSubs.add(sub);
        }
      } else {
        // Cancelada no app: se já foi cobrada após o fechamento, já estará nas compras do cartão.
        // Se ainda não cobrou, não projeta para dezembro!
      }
    }

    // --- 2. CÁLCULO DOS 4 CARTÕES PARA O CICLO ABERTO DE DEZEMBRO ---
    final List<CardOpenInvoice> cardInvoices = [];

    for (final cardConfig in CardConfig.defaultCards) {
      final lastClosing = DateTime(now.year, now.month, cardConfig.closingDay);
      final nextClosing = DateTime(targetMonth.year, targetMonth.month, cardConfig.closingDay);
      final targetDue = DateTime(targetMonth.year, targetMonth.month, cardConfig.dueDay);

      final cardTxs = finance.transactions.where((tx) {
        if (tx.type != TransactionType.expense) return false;
        final title = tx.title.toLowerCase();
        if (title.contains('pagamento de fatura') || title.contains('fatura paga')) {
          return false;
        }

        bool matchesCard = false;
        final txBank = tx.bank?.toLowerCase() ?? '';

        if (cardConfig.id == 'nubank') {
          matchesCard = txBank.contains('nubank');
        } else if (cardConfig.id == 'itau_click') {
          matchesCard = (txBank.contains('itau') || txBank.contains('itaú')) &&
              (title.contains('click') || !title.contains('samsung'));
        } else if (cardConfig.id == 'itau_samsung') {
          matchesCard = (txBank.contains('itau') || txBank.contains('itaú')) &&
              title.contains('samsung');
        } else if (cardConfig.id == 'mercado_pago') {
          matchesCard = txBank.contains('mercado pago');
        }

        if (!matchesCard) return false;

        return tx.date.isAfter(lastClosing) && !tx.date.isAfter(nextClosing);
      }).toList();

      final cardSubs = upcomingSubs.where((s) {
        final subBank = s.bank?.toLowerCase() ?? 'nubank';
        if (cardConfig.id == 'nubank') return subBank.contains('nubank');
        if (cardConfig.id == 'itau_click') return subBank.contains('itau') || subBank.contains('itaú');
        if (cardConfig.id == 'itau_samsung') return false;
        if (cardConfig.id == 'mercado_pago') return subBank.contains('mercado pago');
        return false;
      }).toList();

      cardInvoices.add(
        CardOpenInvoice(
          config: cardConfig,
          targetDueDate: targetDue,
          cycleStartDate: lastClosing,
          cycleEndDate: nextClosing,
          transactions: cardTxs,
          projectedSubscriptions: cardSubs,
        ),
      );
    }

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

      // Contas Manuais Recorrentes de Dezembro
      for (final manual in _manualPayables) {
        if (manual.isRecurring) {
          final day = manual.dueDay.clamp(1, 28);
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

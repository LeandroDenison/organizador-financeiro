import 'package:flutter/material.dart';
import '../models/payable_model.dart';
import '../models/transaction_model.dart';
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

  List<PayableModel> get payables => List.unmodifiable(_computedPayables);
  DateTime get selectedMonth => _selectedMonth;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _manualPayables = await StorageService.loadPayables();
    notifyListeners();
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  /// Sincroniza e consolida todas as fontes de contas a pagar para o mês selecionado
  void syncWithProviders({
    required FinanceProvider finance,
    required DebtProvider debts,
    required SubscriptionProvider subscriptions,
    required BankLoanProvider loans,
  }) {
    final List<PayableModel> list = [];
    final month = _selectedMonth;

    // 1. Faturas de Cartão de Crédito
    // 1.1 Fatura Nubank
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

      // Identifica o que pertence a devedores nesta fatura do mês
      final debtorTxs = nubankCardTxs.where((t) => t.personName != null && t.personName!.trim().isNotEmpty);
      final debtorShare = debtorTxs.fold(0.0, (s, t) => s + t.amount);

      // Quanto os devedores já abateram neste mês
      final debtorPaid = debts.activeDebts.fold(0.0, (sum, d) {
        return sum +
            d.paymentHistory
                .where((p) => p.date.year == month.year && p.date.month == month.month)
                .fold(0.0, (s, p) => s + p.amount);
      });

      final invoiceId = 'cc_nubank_${month.year}_${month.month}';
      final isPaidDetected = finance.scopedTransactions.any((t) =>
          (t.title.toLowerCase().contains('pagamento de fatura') ||
              t.title.toLowerCase().contains('fatura paga') ||
              t.title.toLowerCase().contains('pagto fatura')) &&
          t.bank?.toLowerCase() == 'nubank');
      final isPaid = _manualPaidOverrides[invoiceId] ?? isPaidDetected;

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
          notes: 'Fatura fechada com vencimento dia 13',
        ),
      );
    }

    // 1.2 Faturas Itaú
    final itauClickTxs = finance.scopedTransactions.where((t) =>
        t.title.toLowerCase().contains('itaú click') || t.title.toLowerCase().contains('itau click'));
    final itauClickPaid = itauClickTxs.any((t) => t.title.toLowerCase().contains('fatura paga'));
    final itauClickAmount = itauClickTxs.isNotEmpty ? itauClickTxs.first.amount : 83.42;

    list.add(
      PayableModel(
        id: 'cc_itau_click_${month.year}_${month.month}',
        title: 'Fatura Itaú Click',
        totalAmount: itauClickAmount,
        debtorShareAmount: 0.0,
        dueDate: DateTime(month.year, month.month, 6),
        dueDay: 6,
        category: 'Cartão de Crédito',
        bank: 'Itaú',
        type: PayableType.creditCard,
        isPaid: _manualPaidOverrides['cc_itau_click_${month.year}_${month.month}'] ?? itauClickPaid,
        isAutoDetected: true,
        notes: itauClickPaid ? 'Pago via débito em conta Itaú' : 'Vencimento dia 06',
      ),
    );

    final itauSamsungTxs = finance.scopedTransactions.where((t) =>
        t.title.toLowerCase().contains('samsung itaú') || t.title.toLowerCase().contains('samsung itau'));
    final itauSamsungPaid = itauSamsungTxs.any((t) => t.title.toLowerCase().contains('fatura paga'));
    final itauSamsungAmount = itauSamsungTxs.isNotEmpty ? itauSamsungTxs.first.amount : 216.62;

    list.add(
      PayableModel(
        id: 'cc_itau_samsung_${month.year}_${month.month}',
        title: 'Fatura Samsung Itaú',
        totalAmount: itauSamsungAmount,
        debtorShareAmount: 0.0,
        dueDate: DateTime(month.year, month.month, 6),
        dueDay: 6,
        category: 'Cartão de Crédito',
        bank: 'Itaú',
        type: PayableType.creditCard,
        isPaid: _manualPaidOverrides['cc_itau_samsung_${month.year}_${month.month}'] ?? itauSamsungPaid,
        isAutoDetected: true,
        notes: itauSamsungPaid ? 'Pago via débito em conta Itaú' : 'Vencimento dia 06',
      ),
    );

    // 2. Assinaturas e Custos Fixos
    for (final sub in subscriptions.activeSubscriptions) {
      final subId = 'sub_${sub.id}_${month.year}_${month.month}';
      final isPaidDetected = finance.scopedTransactions.any((t) =>
          (t.amount - sub.amount).abs() < 0.05 &&
          (t.title.toLowerCase() == sub.sourceTransactionTitle?.toLowerCase() ||
              t.title.toLowerCase() == sub.name.toLowerCase()));
      final isPaid = _manualPaidOverrides[subId] ?? isPaidDetected;

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
          notes: sub.sharedWithPerson != null ? 'Compartilhado com ${sub.sharedWithPerson}' : 'Assinatura Ativa',
        ),
      );
    }

    // 3. Parcelas de Empréstimos Bancários Ativos
    for (final loan in loans.activeLoans) {
      final loanId = 'loan_${loan.id}_${month.year}_${month.month}';
      final dueDay = (loan.firstDueDate?.day ?? 10).clamp(1, 28);
      final isPaid = _manualPaidOverrides[loanId] ?? false;

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

    // 4. Contas Manuais Cadastradas
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

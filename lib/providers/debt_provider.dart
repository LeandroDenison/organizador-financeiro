import 'package:flutter/foundation.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import '../services/sample_data_service.dart';
import '../services/firebase_service.dart';
import 'finance_provider.dart';

class DebtProvider extends ChangeNotifier {
  List<DebtModel> _debts = [];
  bool _isLoading = true;

  List<DebtModel> get debts => _debts;
  bool get isLoading => _isLoading;

  List<DebtModel> get activeDebts => _debts.where((d) => !d.isSettled).toList();
  List<DebtModel> get settledDebts => _debts.where((d) => d.isSettled).toList();

  Map<String, List<DebtModel>> get activeDebtsByPerson {
    final Map<String, List<DebtModel>> map = {};
    for (final d in activeDebts) {
      final key = d.personName.trim();
      map.putIfAbsent(key, () => []).add(d);
    }
    return map;
  }

  List<String> get uniquePersonNames {
    final set = _debts.map((d) => d.personName.trim()).where((name) => name.isNotEmpty).toSet();
    return set.toList()..sort();
  }

  String? findMatchingPerson(String text) {
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    for (final name in uniquePersonNames) {
      if (lower.contains(name.toLowerCase()) || name.toLowerCase().contains(lower)) {
        return name;
      }
    }
    return null;
  }

  double get totalOwedToMe {
    return activeDebts.fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  double get totalAlreadyReceived {
    return _debts.fold(0.0, (sum, d) => sum + d.paidAmount);
  }

  int get totalPendingInstallments {
    return activeDebts.fold(0, (sum, d) => sum + d.remainingInstallments);
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    var stored = await StorageService.loadDebts();
    final hasFakes = stored.any((d) => d.personName == 'Carlos Silva' || d.personName == 'Mariana Costa');
    if (hasFakes) {
      stored = [];
      await StorageService.saveDebts([]);
    }

    _debts = stored;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearDebts() async {
    _debts = [];
    await StorageService.saveDebts([]);
    notifyListeners();
  }

  Future<void> addDebt(DebtModel debt) async {
    _debts.insert(0, debt);
    await _persist();
    notifyListeners();
  }

  Future<void> payInstallment({
    required String debtId,
    required FinanceProvider financeProvider,
    double? customAmount,
    String? note,
    bool addToTransactions = true,
  }) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index == -1) return;

    final current = _debts[index];
    if (current.remainingInstallments <= 0 || current.isSettled) return;

    final installmentNum = current.paidInstallments + 1;
    final amountPaid = customAmount ?? current.installmentValue;
    final newRemaining = current.remainingInstallments - 1;
    final isNowSettled = newRemaining <= 0;

    final newPayment = DebtPaymentRecord(
      date: DateTime.now(),
      amount: amountPaid,
      installmentNumber: installmentNum,
      note: note ?? 'Parcela $installmentNum/${current.totalInstallments}',
    );

    final updatedPayments = List<DebtPaymentRecord>.from(current.paymentHistory)..add(newPayment);

    _debts[index] = current.copyWith(
      remainingInstallments: newRemaining > 0 ? newRemaining : 0,
      isSettled: isNowSettled,
      paymentHistory: updatedPayments,
    );

    // Automatically add as Income in Transactions
    if (addToTransactions) {
      await financeProvider.addTransaction(
        TransactionModel(
          title: '${current.personName} - Parcela $installmentNum/${current.totalInstallments}',
          amount: amountPaid,
          date: DateTime.now(),
          type: TransactionType.income,
          category: 'Empréstimo Recebido',
          personId: current.id,
          personName: current.personName,
          installmentRef: '$installmentNum/${current.totalInstallments}',
          notes: note ?? 'Amortização de parcela recebida',
        ),
      );
    }

    await _persist();
    notifyListeners();
  }

  /// Abate a custom amount on a specific debt (e.g. Sergio paid R$ 1.000)
  Future<void> abateDebtAmount({
    required String debtId,
    required double amount,
    required FinanceProvider financeProvider,
    String? note,
    bool addToTransactions = true,
  }) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index == -1 || amount <= 0) return;

    final current = _debts[index];
    final actualAbatement = amount > current.remainingAmount ? current.remainingAmount : amount;

    final newPayment = DebtPaymentRecord(
      date: DateTime.now(),
      amount: actualAbatement,
      installmentNumber: current.paidInstallments + 1,
      note: note ?? 'Abatimento avulso / parcial',
    );

    final updatedPayments = List<DebtPaymentRecord>.from(current.paymentHistory)..add(newPayment);
    final remainingAfter = (current.remainingAmount - actualAbatement).clamp(0.0, double.infinity);
    final isNowSettled = remainingAfter <= 0.01;
    final int newRemainingInst = current.installmentValue > 0
        ? (remainingAfter / current.installmentValue).ceil()
        : (isNowSettled ? 0 : current.remainingInstallments);

    _debts[index] = current.copyWith(
      remainingInstallments: newRemainingInst,
      isSettled: isNowSettled,
      paymentHistory: updatedPayments,
    );

    if (addToTransactions) {
      await financeProvider.addTransaction(
        TransactionModel(
          title: '${current.personName} - Abatimento Recebido',
          amount: actualAbatement,
          date: DateTime.now(),
          type: TransactionType.income,
          category: 'Empréstimo Recebido',
          personId: current.id,
          personName: current.personName,
          notes: note ?? 'Abatimento de dívida (${current.description})',
        ),
      );
    }

    await _persist();
    notifyListeners();
  }

  /// Abate an amount across all active debts of a person (e.g. Sergio paid R$ 1.000)
  Future<double> abatePersonDebts({
    required String personName,
    required double amount,
    required FinanceProvider financeProvider,
    String? note,
    bool addToTransactions = true,
  }) async {
    if (amount <= 0) return 0.0;
    final personDebts = activeDebts
        .where((d) => d.personName.trim().toLowerCase() == personName.trim().toLowerCase())
        .toList();

    if (personDebts.isEmpty) return 0.0;

    double remainingToAbate = amount;
    double totalActuallyAbated = 0.0;

    for (final debt in personDebts) {
      if (remainingToAbate <= 0.001) break;

      final canAbate = debt.remainingAmount;
      final amountForThisDebt = remainingToAbate >= canAbate ? canAbate : remainingToAbate;

      await abateDebtAmount(
        debtId: debt.id,
        amount: amountForThisDebt,
        financeProvider: financeProvider,
        note: note ?? 'Abatimento de $personName',
        addToTransactions: false,
      );

      remainingToAbate -= amountForThisDebt;
      totalActuallyAbated += amountForThisDebt;
    }

    if (addToTransactions && totalActuallyAbated > 0) {
      await financeProvider.addTransaction(
        TransactionModel(
          title: '$personName - Abatimento de Contas',
          amount: totalActuallyAbated,
          date: DateTime.now(),
          type: TransactionType.income,
          category: 'Empréstimo Recebido',
          personName: personName,
          notes: note ?? 'Abatimento distribuído nas contas de $personName',
        ),
      );
    }

    await _persist();
    notifyListeners();
    return totalActuallyAbated;
  }

  Future<void> updateRemainingInstallments(String debtId, int newRemaining) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index == -1) return;

    final current = _debts[index];
    final validRemaining = newRemaining.clamp(0, current.totalInstallments);
    _debts[index] = current.copyWith(
      remainingInstallments: validRemaining,
      isSettled: validRemaining == 0,
    );

    await _persist();
    notifyListeners();
  }

  Future<void> settleEntireDebt({
    required String debtId,
    required FinanceProvider financeProvider,
    bool addToTransactions = true,
  }) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index == -1) return;

    final current = _debts[index];
    final remainingVal = current.remainingAmount;

    final newPayment = DebtPaymentRecord(
      date: DateTime.now(),
      amount: remainingVal,
      installmentNumber: current.totalInstallments,
      note: 'Quitação total antecipada',
    );

    _debts[index] = current.copyWith(
      remainingInstallments: 0,
      isSettled: true,
      paymentHistory: List<DebtPaymentRecord>.from(current.paymentHistory)..add(newPayment),
    );

    if (addToTransactions && remainingVal > 0) {
      await financeProvider.addTransaction(
        TransactionModel(
          title: '${current.personName} - Quitação Total',
          amount: remainingVal,
          date: DateTime.now(),
          type: TransactionType.income,
          category: 'Empréstimo Recebido',
          personId: current.id,
          personName: current.personName,
          installmentRef: 'Quitação',
          notes: 'Dívida quitada integralmente',
        ),
      );
    }

    await _persist();
    notifyListeners();
  }

  Future<void> deleteDebt(String id) async {
    _debts.removeWhere((d) => d.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.saveDebts(_debts);
    FirebaseService().triggerSync();
  }
}

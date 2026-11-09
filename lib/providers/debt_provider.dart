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

    final stored = await StorageService.loadDebts();
    if (stored.isNotEmpty) {
      _debts = stored;
    } else {
      _debts = SampleDataService.getInitialDebts();
      await StorageService.saveDebts(_debts);
    }

    _isLoading = false;
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

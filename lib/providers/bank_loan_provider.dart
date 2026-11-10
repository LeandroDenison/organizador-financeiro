import 'package:flutter/foundation.dart';
import '../models/bank_loan_model.dart';
import '../services/open_finance_service.dart';
import '../services/firebase_service.dart';

class BankLoanProvider extends ChangeNotifier {
  List<BankLoanModel> _loans = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<BankLoanModel> get loans => _loans;
  List<BankLoanModel> get activeLoans => _loans.where((l) => !l.isSettled).toList();
  List<BankLoanModel> get settledLoans => _loans.where((l) => l.isSettled).toList();

  double get totalDebtBalance =>
      activeLoans.fold(0.0, (s, l) => s + l.totalRemainingAmount);

  double get totalRemainingDebt => totalDebtBalance;

  double get totalMonthlyInstallments =>
      activeLoans.fold(0.0, (s, l) => s + l.installmentAmount);

  double get totalMonthlyInstallment => totalMonthlyInstallments;

  double get totalContracted =>
      _loans.fold(0.0, (s, l) => s + l.contractAmount);

  Future<void> init() async {
    _loans = await OpenFinanceService.loadStoredLoans();
    if (_loans.isEmpty) {
      await refreshFromOpenFinance();
    }
    notifyListeners();
  }

  Future<void> syncFromOpenFinance(List<BankLoanModel> fresh) async {
    if (fresh.isNotEmpty) {
      _loans = fresh;
      await OpenFinanceService.saveStoredLoans(fresh);
      notifyListeners();
      FirebaseService().triggerSync();
    }
  }

  Future<void> refreshFromOpenFinance() async {
    _isLoading = true;
    notifyListeners();
    try {
      final config = await OpenFinanceService.loadConfig();
      final fresh = await OpenFinanceService.fetchBankLoans(config);
      if (fresh.isNotEmpty) {
        _loans = fresh;
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
    FirebaseService().triggerSync();
  }
}

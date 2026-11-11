import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

class BudgetProvider extends ChangeNotifier {
  static const String _storageKey = 'financial_budgets_v1';
  List<BudgetModel> _budgets = [];

  List<BudgetModel> get budgets => _budgets;

  Future<void> init() async {
    final raw = await StorageService.getStoredData(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        _budgets = list
            .map((item) => BudgetModel.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        _loadDefaults();
      }
    } else {
      _loadDefaults();
      await _persist(syncCloud: false);
    }
    notifyListeners();
  }

  void _loadDefaults() {
    _budgets = [
      BudgetModel(category: 'Alimentação', monthlyLimit: 800.0),
      BudgetModel(category: 'Transporte', monthlyLimit: 350.0),
      BudgetModel(category: 'Lazer', monthlyLimit: 250.0),
      BudgetModel(category: 'Compras', monthlyLimit: 400.0),
      BudgetModel(category: 'Moradia', monthlyLimit: 1500.0),
    ];
  }

  double getLimitFor(String category) {
    final b = _budgets.cast<BudgetModel?>().firstWhere(
      (element) => element?.category.toLowerCase() == category.toLowerCase(),
      orElse: () => null,
    );
    return b?.monthlyLimit ?? 0.0;
  }

  bool hasBudgetFor(String category) {
    return _budgets.any((b) => b.category.toLowerCase() == category.toLowerCase());
  }

  double getSpentFor(String category, List<TransactionModel> transactions, [DateTime? targetMonth]) {
    final month = targetMonth ?? DateTime.now();
    return transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.category.toLowerCase() == category.toLowerCase() &&
            t.date.year == month.year &&
            t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getProgressFor(String category, List<TransactionModel> transactions, [DateTime? targetMonth]) {
    final limit = getLimitFor(category);
    if (limit <= 0) return 0.0;
    final spent = getSpentFor(category, transactions, targetMonth);
    return (spent / limit).clamp(0.0, 1.5);
  }

  List<BudgetModel> getAlertBudgets(List<TransactionModel> transactions, [DateTime? targetMonth]) {
    return _budgets.where((b) {
      final spent = getSpentFor(b.category, transactions, targetMonth);
      return spent >= (b.monthlyLimit * 0.8);
    }).toList();
  }

  Future<void> setBudgetLimit(String category, double newLimit) async {
    final index = _budgets.indexWhere((b) => b.category.toLowerCase() == category.toLowerCase());
    if (index != -1) {
      _budgets[index].monthlyLimit = newLimit;
    } else {
      _budgets.add(BudgetModel(category: category, monthlyLimit: newLimit));
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist({bool syncCloud = true}) async {
    final list = _budgets.map((b) => b.toMap()).toList();
    await StorageService.setStoredData(_storageKey, jsonEncode(list));
    if (syncCloud) {
      FirebaseService().triggerSync();
    }
  }
}

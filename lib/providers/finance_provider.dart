import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import '../services/sample_data_service.dart';
import '../services/firebase_service.dart';

class FinanceProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _selectedCategory = 'Todas';
  String _searchQuery = '';
  TransactionType? _typeFilter;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  TransactionType? get typeFilter => _typeFilter;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final stored = await StorageService.loadTransactions();
    if (stored.isNotEmpty) {
      _transactions = stored;
    } else {
      _transactions = SampleDataService.getInitialTransactions();
      await StorageService.saveTransactions(_transactions);
    }

    _isLoading = false;
    notifyListeners();
  }

  double get totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get balance => totalIncome - totalExpense;

  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final t in _transactions.where((t) => t.type == TransactionType.expense)) {
      map[t.category] = (map[t.category] ?? 0.0) + t.amount;
    }
    return map;
  }

  List<TransactionModel> get filteredTransactions {
    return _transactions.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_selectedCategory != 'Todas' && t.category != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = t.title.toLowerCase().contains(query);
        final matchCat = t.category.toLowerCase().contains(query);
        final matchPerson = t.personName?.toLowerCase().contains(query) ?? false;
        final matchBank = t.bank?.toLowerCase().contains(query) ?? false;
        if (!matchTitle && !matchCat && !matchPerson && !matchBank) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setTypeFilter(TransactionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    _transactions.insert(0, transaction);
    await _persist();
    notifyListeners();
  }

  Future<void> addMultipleTransactions(List<TransactionModel> newItems) async {
    // Avoid exact duplicates (same date, amount, title)
    for (final item in newItems) {
      final exists = _transactions.any((t) =>
          t.title == item.title &&
          (t.amount - item.amount).abs() < 0.01 &&
          t.date.year == item.date.year &&
          t.date.month == item.date.month &&
          t.date.day == item.date.day);
      if (!exists) {
        _transactions.insert(0, item);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.saveTransactions(_transactions);
    FirebaseService().triggerSync();
  }
}

import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
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

    // Remove legacy fake transactions if they exist
    final cleaned = await StorageService.hasCleanedFakeData();
    var stored = await StorageService.loadTransactions();

    if (!cleaned) {
      final hasFakes = stored.any((t) =>
          t.title.contains('Salário Mensal') ||
          t.title.contains('Pão de Açúcar') ||
          t.title.contains('Posto Shell') ||
          t.personName == 'Carlos Silva');
      if (hasFakes) {
        await StorageService.clearAllData();
        stored = [];
      }
      await StorageService.markFakeDataCleaned();
    }

    // Auto-repair: remove self-transfers, de-duplicate exact matches,
    // and ensure salary/yield entries are always TransactionType.income
    bool modified = false;
    final repaired = <TransactionModel>[];
    final seenTxKeys = <String>{};

    for (final t in stored) {
      if (_isSelfTransfer(t)) {
        modified = true;
        continue;
      }

      final key = '${t.date.year}-${t.date.month}-${t.date.day}_${t.amount.toStringAsFixed(2)}_${t.type.name}_${t.title.trim().toLowerCase()}';
      if (seenTxKeys.contains(key)) {
        modified = true;
        continue;
      }
      seenTxKeys.add(key);

      final lower = t.title.toLowerCase();
      if (t.type == TransactionType.expense &&
          (lower.contains('pagto sal') || lower.contains('salário') || lower.contains('salario') || lower.contains('rend pago'))) {
        repaired.add(t.copyWith(type: TransactionType.income));
        modified = true;
      } else {
        repaired.add(t);
      }
    }

    _transactions = repaired;
    if (modified) {
      await StorageService.saveTransactions(_transactions);
      FirebaseService().triggerSync();
    }
    _isLoading = false;
    notifyListeners();
  }

  static bool _isSelfTransfer(TransactionModel t) {
    final lower = t.title.toLowerCase();
    return lower.contains('pix transf d eniso') ||
        lower.contains('pix transf denison') ||
        (lower.contains('d enison') && (lower.contains('transf') || lower.contains('transferência') || lower.contains('transferencia'))) ||
        (lower.contains('denison') && (lower.contains('transf') || lower.contains('transferência') || lower.contains('transferencia')));
  }

  static bool _isCardBillPayment(TransactionModel t) {
    final lower = t.title.toLowerCase();
    return lower.contains('pagamento de fatura') ||
        lower.contains('pagamento recebido') ||
        lower.contains('fatura paga') ||
        lower.contains('pagamento fatura') ||
        lower.contains('pagamento efetuado');
  }

  static bool _isCreditRefund(TransactionModel t) {
    return t.type == TransactionType.income && t.title.toLowerCase().contains('estorno');
  }

  DateTime _selectedMonth = DateTime(2026, 11);
  bool _filterBySelectedMonth = true;

  DateTime get selectedMonth => _selectedMonth;
  bool get filterBySelectedMonth => _filterBySelectedMonth;

  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void toggleMonthFilter(bool value) {
    _filterBySelectedMonth = value;
    notifyListeners();
  }

  List<TransactionModel> get scopedTransactions {
    final base = _filterBySelectedMonth
        ? _transactions.where((t) =>
            t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month).toList()
        : _transactions;
    return base.where((t) => !_isSelfTransfer(t)).toList();
  }

  double get totalIncome {
    return scopedTransactions
        .where((t) =>
            t.type == TransactionType.income &&
            !_isCreditRefund(t) &&
            !_isCardBillPayment(t))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    final grossExpenses = scopedTransactions
        .where((t) =>
            t.type == TransactionType.expense &&
            !_isCardBillPayment(t))
        .fold(0.0, (sum, t) => sum + t.amount);
    final refunds = scopedTransactions
        .where(_isCreditRefund)
        .fold(0.0, (sum, t) => sum + t.amount);
    final net = grossExpenses - refunds;
    return net < 0 ? 0.0 : net;
  }

  double get balance => totalIncome - totalExpense;

  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final t in scopedTransactions.where((t) => t.type == TransactionType.expense && !_isCardBillPayment(t))) {
      map[t.category] = (map[t.category] ?? 0.0) + t.amount;
    }
    for (final r in scopedTransactions.where(_isCreditRefund)) {
      if (map.containsKey(r.category)) {
        final updated = map[r.category]! - r.amount;
        if (updated <= 0.01) {
          map.remove(r.category);
        } else {
          map[r.category] = updated;
        }
      }
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

  Future<void> updateTransaction(TransactionModel updated) async {
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      _transactions[index] = updated;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearTransactions() async {
    _transactions = [];
    await StorageService.saveTransactions([]);
    FirebaseService().triggerSync();
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.saveTransactions(_transactions);
    FirebaseService().triggerSync();
  }
}

import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/open_finance_service.dart';
import '../services/ofx_parser_service.dart';

class FinanceProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  List<BankAccountBalance> _bankBalances = [];
  bool _isLoading = true;
  bool _isSyncingBalances = false;
  String _selectedCategory = 'Todas';
  String _searchQuery = '';
  TransactionType? _typeFilter;

  List<TransactionModel> get transactions => _transactions;
  List<BankAccountBalance> get bankBalances => _bankBalances;
  bool get isLoading => _isLoading;
  bool get isSyncingBalances => _isSyncingBalances;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  TransactionType? get typeFilter => _typeFilter;

  /// Soma dos saldos em conta corrente/depósito à vista dos 3 bancos (Nubank, Itaú, Mercado Pago)
  double get openFinanceCashBalance {
    final cashAccounts = _bankBalances.where((b) => b.accountType == 'BANK').toList();
    if (cashAccounts.isEmpty) return balance;
    return cashAccounts.fold(0.0, (sum, b) => sum + b.balance);
  }

  /// Saldo individual de cada banco
  double getBankBalance(String bank) {
    return _bankBalances
        .where((b) => b.accountType == 'BANK' && b.bankName.toLowerCase().contains(bank.toLowerCase()))
        .fold(0.0, (sum, b) => sum + b.balance);
  }

  Future<void> refreshBankBalances() async {
    _isSyncingBalances = true;
    notifyListeners();
    try {
      _bankBalances = await OpenFinanceService.fetchBankBalances();
    } catch (_) {}
    _isSyncingBalances = false;
    notifyListeners();
  }

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
    // ensure salary/yield entries are always TransactionType.income,
    // and normalize categories to Portuguese
    bool modified = false;
    final repaired = <TransactionModel>[];
    final seenTxKeys = <String>{};

    for (var t in stored) {
      // Keep all valid transactions (manual, notification, ofx, csv, pdf)

      if (_isSelfTransfer(t) || _isPromotionalOrOffer(t)) {
        modified = true;
        continue;
      }

      final lower = t.title.toLowerCase();

      // Clear mistakenly assigned person on Jim.Com or non-debt expenses
      if (lower.contains('jim.com') && t.personName != null) {
        t = t.copyWith(personName: null, personId: null);
        modified = true;
      }

      // Normalize English categories from Open Finance to Portuguese
      final normalizedCat = OfxParserService.normalizeCategory(t.category, t.title);
      if (normalizedCat != t.category) {
        t = t.copyWith(category: normalizedCat);
        modified = true;
      }

      final key = (t.id.isNotEmpty && (t.id.startsWith('pluggy_') || t.id.startsWith('notif_')))
          ? t.id
          : '${t.date.year}-${t.date.month}-${t.date.day}_${t.amount.toStringAsFixed(2)}_${t.type.name}_${t.title.trim().toLowerCase()}';
      if (seenTxKeys.contains(key)) {
        modified = true;
        continue;
      }
      seenTxKeys.add(key);

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

    // Carrega saldos consolidados do Open Finance
    _bankBalances = await OpenFinanceService.loadStoredBalances();

    _isLoading = false;
    notifyListeners();
  }

  static bool _isSelfTransfer(TransactionModel t) {
    final lower = t.title.toLowerCase();

    // 1. Transferências entre contas do próprio Denison
    final mentionsDenison = lower.contains('denison') ||
        lower.contains('d enison') ||
        lower.contains('d eniso') ||
        lower.contains('enison leandro');
    if (mentionsDenison &&
        (lower.contains('pix') ||
            lower.contains('transf') ||
            lower.contains('transferência') ||
            lower.contains('transferencia') ||
            lower.contains('enviad') ||
            lower.contains('recebid'))) {
      return true;
    }

    // 2. Transferências entre contas conectadas do usuário (Nubank <-> Mercado Pago <-> Itaú)
    final isTransferAction = lower.contains('transferência') ||
        lower.contains('transferencia') ||
        lower.contains('pix enviado') ||
        lower.contains('pix transf');
    final mentionsOwnBank = lower.contains('mercado pago') ||
        lower.contains('nu pagamentos') ||
        lower.contains('nubank') ||
        lower.contains('itau') ||
        lower.contains('itaú');
    if (isTransferAction && mentionsOwnBank) {
      return true;
    }

    return false;
  }

  static bool _isPromotionalOrOffer(TransactionModel t) {
    final lower = t.title.toLowerCase();
    return lower.contains('oferta') ||
        lower.contains('globoplay por') ||
        lower.contains('aproveite') ||
        lower.contains('cashback no inter');
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

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _filterBySelectedMonth = true;

  DateTime get selectedMonth => _selectedMonth;
  bool get filterBySelectedMonth => _filterBySelectedMonth;

  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void resetToCurrentMonth() {
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
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

  /// Soma das despesas no mês selecionado atribuídas a terceiros (devedores)
  double get thirdPartyExpense {
    return scopedTransactions
        .where((t) =>
            t.type == TransactionType.expense &&
            !_isCardBillPayment(t) &&
            t.personName != null &&
            t.personName!.trim().isNotEmpty)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Meu gasto pessoal líquido (despesas totais subtraindo o que foi gasto por terceiros/devedores)
  double get myNetExpense {
    final val = totalExpense - thirdPartyExpense;
    return val < 0 ? 0.0 : val;
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
    final base = _filterBySelectedMonth
        ? _transactions.where((t) =>
            t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month).toList()
        : _transactions;

    return base.where((t) {
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
    final normCat = OfxParserService.normalizeCategory(transaction.category, transaction.title);
    final toAdd = normCat != transaction.category
        ? transaction.copyWith(category: normCat)
        : transaction;
    _transactions.insert(0, toAdd);
    await _persist();
    notifyListeners();
  }

  Future<void> addMultipleTransactions(List<TransactionModel> newItems) async {
    for (var item in newItems) {
      final normCat = OfxParserService.normalizeCategory(item.category, item.title);
      if (normCat != item.category) {
        item = item.copyWith(category: normCat);
      }

      final existingIndex = _transactions.indexWhere((t) =>
          (item.id.isNotEmpty && t.id == item.id) ||
          (t.title == item.title &&
              (t.amount - item.amount).abs() < 0.01 &&
              t.date.year == item.date.year &&
              t.date.month == item.date.month &&
              t.date.day == item.date.day));

      if (existingIndex != -1) {
        final existing = _transactions[existingIndex];
        final updated = existing.copyWith(
          bank: item.bank ?? existing.bank,
          installmentRef: item.installmentRef ?? existing.installmentRef,
          category: (existing.category == 'Outros' || existing.category == 'Geral')
              ? item.category
              : existing.category,
        );
        _transactions[existingIndex] = updated;
      } else {
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

  /// Permite ao usuário ajustar ou corrigir o saldo real de qualquer banco
  Future<void> updateBankBalance(String bankName, double newBalance) async {
    final index = _bankBalances.indexWhere(
      (b) => b.bankName.toLowerCase().contains(bankName.toLowerCase()) && b.accountType == 'BANK',
    );
    if (index != -1) {
      _bankBalances[index] = BankAccountBalance(
        bankName: _bankBalances[index].bankName,
        accountName: _bankBalances[index].accountName,
        accountType: 'BANK',
        balance: newBalance,
        updatedAt: DateTime.now(),
      );
    } else {
      _bankBalances.add(
        BankAccountBalance(
          bankName: bankName,
          accountName: 'Conta Corrente $bankName',
          accountType: 'BANK',
          balance: newBalance,
          updatedAt: DateTime.now(),
        ),
      );
    }
    await OpenFinanceService.saveStoredBalances(_bankBalances);
    notifyListeners();
  }

  /// Limpa todas as transações anteriores e faz uma nova importação limpa do zero via Open Finance
  Future<int> resetAndImportFromOpenFinance() async {
    _isLoading = true;
    notifyListeners();

    // 1. Limpa histórico anterior
    _transactions = [];
    await StorageService.saveTransactions([]);

    // 2. Busca saldos reais atualizados dos bancos
    try {
      _bankBalances = await OpenFinanceService.fetchBankBalances();
    } catch (_) {}

    // 3. Busca transações reais do Open Finance (Pluggy API)
    int count = 0;
    try {
      final freshTxs = await OpenFinanceService.fetchTransactions();
      _transactions = freshTxs;
      count = freshTxs.length;
      await _persist();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
    return count;
  }

  Future<void> _persist() async {
    await StorageService.saveTransactions(_transactions);
    FirebaseService().triggerSync();
  }
}

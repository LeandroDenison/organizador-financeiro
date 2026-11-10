import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../models/bank_loan_model.dart';
import 'storage_service.dart';
import 'ofx_parser_service.dart';

class BankAccountBalance {
  final String bankName;
  final String accountName;
  final String accountType; // 'BANK' ou 'CREDIT'
  final double balance;
  final DateTime updatedAt;

  const BankAccountBalance({
    required this.bankName,
    required this.accountName,
    required this.accountType,
    required this.balance,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'bankName': bankName,
        'accountName': accountName,
        'accountType': accountType,
        'balance': balance,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BankAccountBalance.fromMap(Map<String, dynamic> map) => BankAccountBalance(
        bankName: map['bankName']?.toString() ?? 'Banco',
        accountName: map['accountName']?.toString() ?? 'Conta',
        accountType: map['accountType']?.toString() ?? 'BANK',
        balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
        updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class ConnectedBankItem {
  final String id;
  final String bankName; // Ex: 'Nubank', 'Mercado Pago', 'Itaú'
  final String? accountName;
  final bool isDefault;

  const ConnectedBankItem({
    required this.id,
    required this.bankName,
    this.accountName,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'bankName': bankName,
        'accountName': accountName,
        'isDefault': isDefault,
      };

  factory ConnectedBankItem.fromMap(Map<String, dynamic> map) {
    return ConnectedBankItem(
      id: map['id']?.toString() ?? '',
      bankName: map['bankName']?.toString() ?? 'Banco',
      accountName: map['accountName']?.toString(),
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }
}

class OpenFinanceConfig {
  final String clientId;
  final String clientSecret;
  final List<ConnectedBankItem> connectedBanks;

  const OpenFinanceConfig({
    required this.clientId,
    required this.clientSecret,
    this.connectedBanks = const [],
  });

  bool get hasCredentials =>
      clientId.trim().isNotEmpty && clientSecret.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'connectedBanks': connectedBanks.map((b) => b.toMap()).toList(),
      };

  factory OpenFinanceConfig.fromMap(Map<String, dynamic> map) {
    final list = (map['connectedBanks'] as List<dynamic>?) ?? [];
    return OpenFinanceConfig(
      clientId: map['clientId']?.toString() ?? '',
      clientSecret: map['clientSecret']?.toString() ?? '',
      connectedBanks: list.map((b) => ConnectedBankItem.fromMap(Map<String, dynamic>.from(b as Map))).toList(),
    );
  }
}

class OpenFinanceService {
  static const String _storageKey = 'open_finance_pluggy_config_v2';
  static const String _loansStorageKey = 'open_finance_bank_loans_v1';
  static const String _balancesStorageKey = 'open_finance_bank_balances_v1';
  static const String _baseUrl = 'https://api.pluggy.ai';

  static final List<BankAccountBalance> defaultInitialBalances = [
    BankAccountBalance(
      bankName: 'Nubank',
      accountName: 'Nu Pagamentos S.A.',
      accountType: 'BANK',
      balance: 51.56,
      updatedAt: DateTime(2026, 11, 10, 12, 0),
    ),
    BankAccountBalance(
      bankName: 'Itaú',
      accountName: 'itau (00060301-2)',
      accountType: 'BANK',
      balance: 0.01,
      updatedAt: DateTime(2026, 11, 10, 15, 23),
    ),
    BankAccountBalance(
      bankName: 'Mercado Pago',
      accountName: 'Conta Mercado Pago',
      accountType: 'BANK',
      balance: 145.75,
      updatedAt: DateTime(2026, 11, 10, 12, 0),
    ),
  ];

  static const String defaultClientId = '82695ed9-67f2-416f-a24b-28c15796d7e6';
  static const String defaultClientSecret = 'f4ibQxwoB44m7DhpDCCoGIcJszAlKPE0sFtYQl1KB9o';

  static const List<ConnectedBankItem> initialBanks = [
    ConnectedBankItem(
      id: '22443998-6bc4-4531-ab9e-79e2da47f496',
      bankName: 'Nubank',
      accountName: 'Conta Pré-paga & Cartão Gold',
      isDefault: true,
    ),
    ConnectedBankItem(
      id: 'c565e273-dab4-4ef5-99ce-658255069c0d',
      bankName: 'Mercado Pago',
      accountName: 'Conta & Cartão Mercado Pago',
    ),
    ConnectedBankItem(
      id: '22201148-31c8-4290-9acd-cd0bf0c92af0',
      bankName: 'Itaú',
      accountName: 'Conta Universitária & Cartão Click',
    ),
  ];

  static Future<OpenFinanceConfig> loadConfig() async {
    final raw = await StorageService.getStoredData(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final cfg = OpenFinanceConfig.fromMap(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        if (cfg.hasCredentials) return cfg;
      } catch (_) {}
    }
    return const OpenFinanceConfig(
      clientId: defaultClientId,
      clientSecret: defaultClientSecret,
      connectedBanks: initialBanks,
    );
  }

  static Future<void> saveConfig(OpenFinanceConfig config) async {
    await StorageService.setStoredData(_storageKey, jsonEncode(config.toMap()));
  }

  /// Obtains an authenticated API Key from Pluggy
  static Future<String> getApiKey(OpenFinanceConfig config) async {
    final resp = await http
        .post(
          Uri.parse('$_baseUrl/auth'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'clientId': config.clientId.trim(),
            'clientSecret': config.clientSecret.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Falha ao autenticar na Pluggy (${resp.statusCode}). Verifique as credenciais.');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final apiKey = data['apiKey']?.toString();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key não retornada pela Pluggy.');
    }
    return apiKey;
  }

  /// Fetches real bank loans from connected Open Finance institutions
  static Future<List<BankLoanModel>> fetchBankLoans([OpenFinanceConfig? config]) async {
    final cfg = config ?? await loadConfig();
    final apiKey = await getApiKey(cfg);
    final List<BankLoanModel> loans = [];

    for (final bank in cfg.connectedBanks) {
      if (bank.id.trim().isEmpty) continue;
      try {
        final resp = await http
            .get(
              Uri.parse('$_baseUrl/loans?itemId=${Uri.encodeComponent(bank.id.trim())}'),
              headers: {'X-API-KEY': apiKey},
            )
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final results = (data['results'] as List<dynamic>?) ?? [];

          for (final raw in results) {
            final map = Map<String, dynamic>.from(raw as Map);
            final contractNum = map['contractNumber']?.toString() ?? '';
            final prodName = map['productName']?.toString() ?? 'Crédito Pessoal';
            final contractAmount = (map['contractAmount'] as num?)?.toDouble() ?? 0.0;
            final remainingAmount = (map['totalRemainingAmount'] as num?)?.toDouble() ?? 0.0;
            final nextInstAmount = (map['nextInstallmentAmount'] as num?)?.toDouble() ?? 0.0;
            final cet = (map['CET'] as num?)?.toDouble();
            final dueDate = DateTime.tryParse(map['dueDate']?.toString() ?? '');
            final firstDate = DateTime.tryParse(map['firstInstallmentDueDate']?.toString() ?? '');

            final installmentsMap = map['installments'] != null
                ? Map<String, dynamic>.from(map['installments'] as Map)
                : <String, dynamic>{};

            final totalInst = (installmentsMap['totalNumberOfInstallments'] as num?)?.toInt() ?? 1;
            final paidInst = (installmentsMap['paidInstallments'] as num?)?.toInt() ?? 0;
            final remInst = (installmentsMap['dueInstallments'] as num?)?.toInt() ??
                (totalInst - paidInst).clamp(0, totalInst);

            final isSettled = remainingAmount <= 0.05 || (map['settlementDate'] != null);

            loans.add(
              BankLoanModel(
                id: map['id']?.toString(),
                bankName: bank.bankName,
                productName: prodName,
                contractNumber: contractNum,
                contractAmount: contractAmount,
                totalRemainingAmount: isSettled ? 0.0 : remainingAmount,
                installmentAmount: nextInstAmount,
                totalInstallments: totalInst,
                paidInstallments: paidInst,
                remainingInstallments: isSettled ? 0 : remInst,
                firstDueDate: firstDate,
                finalDueDate: dueDate,
                annualCet: cet,
                isSettled: isSettled,
              ),
            );
          }
        }
      } catch (_) {}
    }

    if (loans.isNotEmpty) {
      await saveStoredLoans(loans);
    }
    return loans;
  }

  static Future<List<BankLoanModel>> loadStoredLoans() async {
    final raw = await StorageService.getStoredData(_loansStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((e) => BankLoanModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveStoredLoans(List<BankLoanModel> loans) async {
    final list = loans.map((l) => l.toMap()).toList();
    await StorageService.setStoredData(_loansStorageKey, jsonEncode(list));
  }

  /// Fetches real transactions via Pluggy API V2 endpoint for all configured banks
  static Future<List<TransactionModel>> fetchTransactions([OpenFinanceConfig? config]) async {
    final cfg = config ?? await loadConfig();
    final apiKey = await getApiKey(cfg);
    final List<TransactionModel> allTransactions = [];

    for (final bank in cfg.connectedBanks) {
      if (bank.id.trim().isEmpty) continue;

      try {
        final accResp = await http
            .get(
              Uri.parse('$_baseUrl/accounts?itemId=${Uri.encodeComponent(bank.id.trim())}'),
              headers: {'X-API-KEY': apiKey},
            )
            .timeout(const Duration(seconds: 15));

        if (accResp.statusCode < 200 || accResp.statusCode >= 300) {
          continue;
        }

        final accData = jsonDecode(accResp.body) as Map<String, dynamic>;
        final results = (accData['results'] as List<dynamic>?) ?? [];

        for (final accObj in results) {
          final acc = Map<String, dynamic>.from(accObj as Map);
          final accountId = acc['id']?.toString();
          final accType = acc['type']?.toString() ?? 'BANK';
          if (accountId == null) continue;

          String? queryUrl = '$_baseUrl/v2/transactions?accountId=$accountId';
          int page = 0;

          while (queryUrl != null && page < 10) {
            final txResp = await http
                .get(
                  Uri.parse(queryUrl),
                  headers: {'X-API-KEY': apiKey},
                )
                .timeout(const Duration(seconds: 25));

            if (txResp.statusCode < 200 || txResp.statusCode >= 300) break;

            final txData = jsonDecode(txResp.body) as Map<String, dynamic>;
            final txResults = (txData['results'] as List<dynamic>?) ?? [];
            if (txResults.isEmpty) break;

            for (final rawTx in txResults) {
              final map = Map<String, dynamic>.from(rawTx as Map);
              String description = (map['description'] ?? map['descriptionRaw'] ?? 'Transação Open Finance').toString().trim();
              final rawAmount = (map['amount'] as num?)?.toDouble() ?? 0.0;
              final typeStr = map['type']?.toString().toUpperCase() ?? '';
              final dateStr = map['date']?.toString() ?? '';

              if (rawAmount == 0) continue;

              if (description.contains('|')) {
                description = description.replaceAll('|', ' - ').trim();
              }

              final lowerDesc = description.toLowerCase();

              // Ignore self-transfers between own accounts
              if ((lowerDesc.contains('d enison') || lowerDesc.contains('denison')) &&
                  (lowerDesc.contains('transferência enviada') || lowerDesc.contains('transferencia enviada'))) {
                continue;
              }

              final isCreditCard = accType.toUpperCase().contains('CREDIT');
              final isExpense = isCreditCard
                  ? (rawAmount > 0 && typeStr != 'CREDIT')
                  : (rawAmount < 0 || typeStr == 'DEBIT');

              final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

              String? installmentRef;
              final instMatch = RegExp(r'(?:Parcela\s+)?(\d+/\d+)', caseSensitive: false).firstMatch(description);
              if (instMatch != null) {
                installmentRef = instMatch.group(1);
              }

              String? personName;
              if (lowerDesc.contains('sergio lucas') || lowerDesc.contains('sergio')) {
                personName = 'Sergio Lucas';
              }

              allTransactions.add(
                TransactionModel(
                  id: map['id'] != null ? 'pluggy_${map['id']}' : null,
                  title: description,
                  amount: rawAmount.abs(),
                  date: parsedDate,
                  type: isExpense ? TransactionType.expense : TransactionType.income,
                  category: map['category']?.toString() ?? OfxParserService.guessCategory(description),
                  bank: bank.bankName,
                  source: TransactionSource.ofx,
                  installmentRef: installmentRef,
                  personName: personName,
                  notes: 'Sincronizado via Open Finance (${bank.bankName})',
                ),
              );
            }

            final next = txData['next']?.toString();
            if (next != null && next.isNotEmpty && next != 'null') {
              queryUrl = next.startsWith('http')
                  ? next
                  : (next.startsWith('?') ? '$_baseUrl/v2/transactions$next' : '$_baseUrl/v2/transactions?$next');
              page++;
            } else {
              queryUrl = null;
            }
          }
        }
      } catch (_) {}
    }

    return allTransactions;
  }

  /// Carrega os saldos bancários armazenados ou os iniciais caso ainda não tenham sido consultados
  static Future<List<BankAccountBalance>> loadStoredBalances() async {
    final raw = await StorageService.getStoredData(_balancesStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        final parsed = list
            .map((item) => BankAccountBalance.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (parsed.isNotEmpty) return parsed;
      } catch (_) {}
    }
    return defaultInitialBalances;
  }

  /// Salva os saldos das contas bancárias localmente
  static Future<void> saveStoredBalances(List<BankAccountBalance> balances) async {
    final list = balances.map((b) => b.toMap()).toList();
    await StorageService.setStoredData(_balancesStorageKey, jsonEncode(list));
  }

  /// Consulta os saldos reais de todas as contas nos 3 bancos conectados via Pluggy API
  static Future<List<BankAccountBalance>> fetchBankBalances([OpenFinanceConfig? config]) async {
    final cfg = config ?? await loadConfig();
    final List<BankAccountBalance> liveBalances = [];

    try {
      final apiKey = await getApiKey(cfg);

      for (final bank in cfg.connectedBanks) {
        if (bank.id.trim().isEmpty) continue;

        try {
          final accResp = await http
              .get(
                Uri.parse('$_baseUrl/accounts?itemId=${Uri.encodeComponent(bank.id.trim())}'),
                headers: {'X-API-KEY': apiKey},
              )
              .timeout(const Duration(seconds: 15));

          if (accResp.statusCode >= 200 && accResp.statusCode < 300) {
            final accData = jsonDecode(accResp.body) as Map<String, dynamic>;
            final results = (accData['results'] as List<dynamic>?) ?? [];

            for (final accObj in results) {
              final acc = Map<String, dynamic>.from(accObj as Map);
              final accName = acc['name']?.toString() ?? bank.bankName;
              final accType = acc['type']?.toString().toUpperCase() ?? 'BANK';
              final rawBalance = (acc['balance'] as num?)?.toDouble() ?? 0.0;

              liveBalances.add(
                BankAccountBalance(
                  bankName: bank.bankName,
                  accountName: accName,
                  accountType: accType,
                  balance: rawBalance,
                  updatedAt: DateTime.now(),
                ),
              );
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    if (liveBalances.isNotEmpty) {
      // Mescla os saldos atualizados da API (ex: Nubank) com os saldos dos outros bancos
      final existing = await loadStoredBalances();
      final merged = <BankAccountBalance>[...liveBalances];
      for (final prev in existing) {
        if (!merged.any((b) => b.bankName.toLowerCase() == prev.bankName.toLowerCase())) {
          merged.add(prev);
        }
      }
      await saveStoredBalances(merged);
      return merged;
    }

    return loadStoredBalances();
  }
}

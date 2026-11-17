import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../models/bank_loan_model.dart';
import 'storage_service.dart';
import 'ofx_parser_service.dart';
import '../utils/installment_helper.dart';

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
      balance: 50.56,
      updatedAt: DateTime(2026, 11, 10, 16, 11),
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
      balance: 1.00,
      updatedAt: DateTime(2026, 11, 10, 16, 0),
    ),
  ];

  static const String defaultClientId = 'a4c94458-9f21-4e93-8afc-5680b50b3cb7';
  static const String defaultClientSecret = 'pKKGhj265x0p-Lszoo-EYYagf9pWkMEWFkJ4X3bcHkA';

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
      accountName: 'Samsung Itaú Visa & Itaú Click',
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

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
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
          final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
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
        var currentApiKey = apiKey;
        var accResp = await http
            .get(
              Uri.parse('$_baseUrl/accounts?itemId=${Uri.encodeComponent(bank.id.trim())}'),
              headers: {'X-API-KEY': currentApiKey},
            )
            .timeout(const Duration(seconds: 15));

        var accData = accResp.statusCode >= 200 && accResp.statusCode < 300
            ? (jsonDecode(utf8.decode(accResp.bodyBytes)) as Map<String, dynamic>)
            : <String, dynamic>{};
        var results = (accData['results'] as List<dynamic>?) ?? [];

        if (accResp.statusCode == 404 || results.isEmpty) {
          try {
            final fallbackKey = await getApiKey(const OpenFinanceConfig(
              clientId: '82695ed9-67f2-416f-a24b-28c15796d7e6',
              clientSecret: 'f4ibQxwoB44m7DhpDCCoGIcJszAlKPE0sFtYQl1KB9o',
            ));
            final fallbackResp = await http
                .get(
                  Uri.parse('$_baseUrl/accounts?itemId=${Uri.encodeComponent(bank.id.trim())}'),
                  headers: {'X-API-KEY': fallbackKey},
                )
                .timeout(const Duration(seconds: 15));
            if (fallbackResp.statusCode >= 200 && fallbackResp.statusCode < 300) {
              final fallbackData = jsonDecode(utf8.decode(fallbackResp.bodyBytes)) as Map<String, dynamic>;
              final fallbackResults = (fallbackData['results'] as List<dynamic>?) ?? [];
              if (fallbackResults.isNotEmpty) {
                results = fallbackResults;
                currentApiKey = fallbackKey;
              }
            }
          } catch (_) {}
        }

        if (results.isEmpty) {
          continue;
        }

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
                  headers: {'X-API-KEY': currentApiKey},
                )
                .timeout(const Duration(seconds: 25));

            if (txResp.statusCode < 200 || txResp.statusCode >= 300) break;

            final txData = jsonDecode(utf8.decode(txResp.bodyBytes)) as Map<String, dynamic>;
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

              final isCreditCard = accType.toUpperCase().contains('CREDIT');
              final isExpense = isCreditCard
                  ? (rawAmount > 0 && typeStr != 'CREDIT')
                  : (rawAmount < 0 || typeStr == 'DEBIT');

              final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

              // Parcelamento: prioridade ao metadado oficial do banco (Open Finance);
              // fallback genérico via texto, sem regras específicas de usuário.
              String? installmentRef;
              if (map['creditCardMetadata'] != null) {
                final ccMeta = Map<String, dynamic>.from(map['creditCardMetadata'] as Map);
                final instNum = ccMeta['installmentNumber'];
                final totInst = ccMeta['totalInstallments'];
                if (instNum != null && totInst != null && (totInst as num) > 1) {
                  installmentRef = '$instNum/$totInst';
                }
              }
              installmentRef ??= InstallmentHelper.extractInstallmentRef(description);

              // Devedores NÃO são atribuídos automaticamente por nome: o usuário define
              // por compra (ou por regra própria), tornando o app utilizável por qualquer pessoa.
              const String? personName = null;


              allTransactions.add(
                TransactionModel(
                  id: map['id'] != null ? 'pluggy_${map['id']}' : null,
                  title: description,
                  amount: rawAmount.abs(),
                  date: parsedDate, // Data REAL e exata da transação
                  type: isExpense ? TransactionType.expense : TransactionType.income,
                  category: isCreditCard
                      ? 'Cartão de Crédito'
                      : OfxParserService.normalizeCategory(
                          map['category']?.toString(),
                          description,
                        ),
                  bank: bank.bankName,
                  source: TransactionSource.ofx,
                  installmentRef: installmentRef,
                  personName: personName,
                  notes: isCreditCard
                      ? 'Cartão de Crédito • Open Finance (${bank.bankName})'
                      : 'Conta Corrente • Open Finance (${bank.bankName})',
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
          var accResp = await http
              .get(
                Uri.parse('$_baseUrl/accounts?itemId=${Uri.encodeComponent(bank.id.trim())}'),
                headers: {'X-API-KEY': apiKey},
              )
              .timeout(const Duration(seconds: 15));

          if (accResp.statusCode == 404) {
            try {
              final fallbackKey = await getApiKey(const OpenFinanceConfig(
                clientId: '82695ed9-67f2-416f-a24b-28c15796d7e6',
                clientSecret: 'f4ibQxwoB44m7DhpDCCoGIcJszAlKPE0sFtYQl1KB9o',
              ));
              accResp = await http
                  .get(
                    Uri.parse('$_baseUrl/accounts?itemId=${Uri.encodeComponent(bank.id.trim())}'),
                    headers: {'X-API-KEY': fallbackKey},
                  )
                  .timeout(const Duration(seconds: 15));
            } catch (_) {}
          }

          if (accResp.statusCode >= 200 && accResp.statusCode < 300) {
            final accData = jsonDecode(utf8.decode(accResp.bodyBytes)) as Map<String, dynamic>;
            final results = (accData['results'] as List<dynamic>?) ?? [];

            for (final accObj in results) {
              final acc = Map<String, dynamic>.from(accObj as Map);
              final rawName = acc['name']?.toString() ?? bank.bankName;
              final accType = acc['type']?.toString().toUpperCase() ?? 'BANK';
              final accSubtype = acc['subtype']?.toString().toUpperCase() ?? '';
              final accNumber = acc['number']?.toString() ?? '';
              final rawBalance = (acc['balance'] as num?)?.toDouble() ?? 0.0;

              String finalName = rawName;
              if (finalName.trim().toLowerCase() == bank.bankName.trim().toLowerCase() ||
                  finalName.trim().toLowerCase() == 'conta') {
                if (accType == 'CREDIT' || accSubtype.contains('CREDIT')) {
                  finalName = '${bank.bankName} Cartão de Crédito';
                } else {
                  finalName = '${bank.bankName} Conta Corrente';
                }
              }
              if (accNumber.isNotEmpty && !finalName.contains(accNumber)) {
                final lastDigits = accNumber.length > 4 ? accNumber.substring(accNumber.length - 4) : accNumber;
                finalName = '$finalName ($lastDigits)';
              }

              liveBalances.add(
                BankAccountBalance(
                  bankName: bank.bankName,
                  accountName: finalName,
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
      final uniqueBalances = <BankAccountBalance>[];
      for (final b in liveBalances) {
        final existingIdx = uniqueBalances.indexWhere((u) =>
            u.bankName.toLowerCase() == b.bankName.toLowerCase() &&
            u.accountType == b.accountType &&
            (u.accountName.toLowerCase() == b.accountName.toLowerCase() ||
                (u.balance - b.balance).abs() <= 0.01));
        if (existingIdx != -1) {
          uniqueBalances[existingIdx] = b;
        } else {
          uniqueBalances.add(b);
        }
      }

      await saveStoredBalances(uniqueBalances);
      return uniqueBalances;
    }

    return loadStoredBalances();
  }
}




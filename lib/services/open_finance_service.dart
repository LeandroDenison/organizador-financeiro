import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import 'storage_service.dart';
import 'ofx_parser_service.dart';

class OpenFinanceConfig {
  final String clientId;
  final String clientSecret;
  final String itemId;

  const OpenFinanceConfig({
    required this.clientId,
    required this.clientSecret,
    required this.itemId,
  });

  bool get isConfigured =>
      clientId.trim().isNotEmpty &&
      clientSecret.trim().isNotEmpty &&
      itemId.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'itemId': itemId,
      };

  factory OpenFinanceConfig.fromMap(Map<String, dynamic> map) {
    return OpenFinanceConfig(
      clientId: map['clientId']?.toString() ?? '',
      clientSecret: map['clientSecret']?.toString() ?? '',
      itemId: map['itemId']?.toString() ?? '',
    );
  }
}

class OpenFinanceService {
  static const String _storageKey = 'open_finance_pluggy_config_v1';
  static const String _baseUrl = 'https://api.pluggy.ai';

  static Future<OpenFinanceConfig> loadConfig() async {
    final raw = await StorageService.getStoredData(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return OpenFinanceConfig.fromMap(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {}
    }
    return const OpenFinanceConfig(clientId: '', clientSecret: '', itemId: '');
  }

  static Future<void> saveConfig(OpenFinanceConfig config) async {
    await StorageService.setStoredData(_storageKey, jsonEncode(config.toMap()));
  }

  /// Fetches real transactions from Open Finance Brasil via Pluggy API
  static Future<List<TransactionModel>> fetchTransactions(OpenFinanceConfig config) async {
    if (!config.isConfigured) {
      throw Exception('Configure o Client ID, Client Secret e Item ID da Pluggy Open Finance.');
    }

    // Step 1: Authenticate with Pluggy API to obtain API Key
    final authResp = await http
        .post(
          Uri.parse('$_baseUrl/auth'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'clientId': config.clientId.trim(),
            'clientSecret': config.clientSecret.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (authResp.statusCode < 200 || authResp.statusCode >= 300) {
      throw Exception('Falha na autenticação Pluggy (${authResp.statusCode}). Verifique Client ID e Secret.');
    }

    final authData = jsonDecode(authResp.body) as Map<String, dynamic>;
    final apiKey = authData['apiKey']?.toString();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Token apiKey não retornado pela Pluggy.');
    }

    // Step 2: List accounts for the connected bank Item ID
    final accResp = await http
        .get(
          Uri.parse('$_baseUrl/accounts?itemId=${Uri.encodeComponent(config.itemId.trim())}'),
          headers: {'X-API-KEY': apiKey},
        )
        .timeout(const Duration(seconds: 15));

    if (accResp.statusCode < 200 || accResp.statusCode >= 300) {
      throw Exception('Erro ao buscar contas do Item ID (${accResp.statusCode}).');
    }

    final accData = jsonDecode(accResp.body) as Map<String, dynamic>;
    final results = (accData['results'] as List<dynamic>?) ?? [];
    if (results.isEmpty) {
      throw Exception('Nenhuma conta ou cartão encontrado para este Item ID.');
    }

    final List<TransactionModel> allTransactions = [];

    // Step 3: Fetch transactions for each account/credit card
    for (final accObj in results) {
      final acc = Map<String, dynamic>.from(accObj as Map);
      final accountId = acc['id']?.toString();
      final accName = acc['name']?.toString() ?? 'Open Finance';
      final accType = acc['type']?.toString() ?? 'BANK';
      if (accountId == null) continue;

      final txResp = await http
          .get(
            Uri.parse('$_baseUrl/transactions?accountId=$accountId&pageSize=100'),
            headers: {'X-API-KEY': apiKey},
          )
          .timeout(const Duration(seconds: 15));

      if (txResp.statusCode >= 200 && txResp.statusCode < 300) {
        final txData = jsonDecode(txResp.body) as Map<String, dynamic>;
        final txResults = (txData['results'] as List<dynamic>?) ?? [];

        for (final rawTx in txResults) {
          final map = Map<String, dynamic>.from(rawTx as Map);
          final description = (map['description'] ?? map['descriptionRaw'] ?? 'Transação Open Finance').toString().trim();
          final rawAmount = (map['amount'] as num?)?.toDouble() ?? 0.0;
          final typeStr = map['type']?.toString().toUpperCase() ?? '';
          final dateStr = map['date']?.toString() ?? '';

          if (rawAmount == 0) continue;

          // Ignore self-transfers to Denison
          final lowerDesc = description.toLowerCase();
          if (lowerDesc.contains('pix transf d eniso') || lowerDesc.contains('pix transf denison')) {
            continue;
          }

          final isCreditCard = accType.toUpperCase().contains('CREDIT');
          final isExpense = isCreditCard
              ? (rawAmount > 0 && typeStr != 'CREDIT')
              : (rawAmount < 0 || typeStr == 'DEBIT');

          final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

          allTransactions.add(
            TransactionModel(
              id: map['id'] != null ? 'of_${map['id']}' : null,
              title: description,
              amount: rawAmount.abs(),
              date: parsedDate,
              type: isExpense ? TransactionType.expense : TransactionType.income,
              category: OfxParserService.guessCategory(description),
              bank: accName.contains('Nu')
                  ? 'Nubank'
                  : (accName.contains('Ita') ? 'Itaú' : accName),
              source: TransactionSource.ofx,
              notes: 'Sincronizado via Open Finance Brasil',
            ),
          );
        }
      }
    }

    return allTransactions;
  }
}

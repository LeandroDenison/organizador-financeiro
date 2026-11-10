import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import 'storage_service.dart';
import 'ofx_parser_service.dart';

class OpenFinanceConfig {
  final String clientId;
  final String clientSecret;
  final String? itemId;

  const OpenFinanceConfig({
    required this.clientId,
    required this.clientSecret,
    this.itemId,
  });

  bool get hasCredentials =>
      clientId.trim().isNotEmpty && clientSecret.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'itemId': itemId,
      };

  factory OpenFinanceConfig.fromMap(Map<String, dynamic> map) {
    return OpenFinanceConfig(
      clientId: map['clientId']?.toString() ?? '',
      clientSecret: map['clientSecret']?.toString() ?? '',
      itemId: map['itemId']?.toString(),
    );
  }
}

class OpenFinanceItem {
  final String id;
  final String connectorName;
  final String status;
  final DateTime? createdAt;

  const OpenFinanceItem({
    required this.id,
    required this.connectorName,
    required this.status,
    this.createdAt,
  });
}

class OpenFinanceService {
  static const String _storageKey = 'open_finance_pluggy_config_v1';
  static const String _baseUrl = 'https://api.pluggy.ai';

  static const String defaultClientId = '82695ed9-67f2-416f-a24b-28c15796d7e6';
  static const String defaultClientSecret = 'f4ibQxwoB44m7DhpDCCoGIcJszAlKPE0sFtYQl1KB9o';

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

  /// Generates a Connect Token and URL for the official Pluggy Open Finance popup widget
  static Future<String> generateConnectUrl(OpenFinanceConfig config) async {
    final apiKey = await getApiKey(config);

    final resp = await http
        .post(
          Uri.parse('$_baseUrl/connect_token'),
          headers: {
            'Content-Type': 'application/json',
            'X-API-KEY': apiKey,
          },
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Erro ao criar Connect Token na Pluggy (${resp.statusCode}).');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final connectToken = data['accessToken']?.toString();
    if (connectToken == null || connectToken.isEmpty) {
      throw Exception('Connect Token não retornado.');
    }

    return 'https://connect.pluggy.ai/?connect_token=$connectToken';
  }

  /// Lists all connected bank accounts/institutions (items)
  static Future<List<OpenFinanceItem>> listConnectedItems(OpenFinanceConfig config) async {
    final apiKey = await getApiKey(config);

    final resp = await http
        .get(
          Uri.parse('$_baseUrl/items'),
          headers: {'X-API-KEY': apiKey},
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return [];
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>?) ?? [];

    return results.map((obj) {
      final map = Map<String, dynamic>.from(obj as Map);
      final connector = map['connector'] != null
          ? Map<String, dynamic>.from(map['connector'] as Map)
          : null;
      return OpenFinanceItem(
        id: map['id']?.toString() ?? '',
        connectorName: connector?['name']?.toString() ?? 'Banco',
        status: map['status']?.toString() ?? 'UPDATED',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      );
    }).toList();
  }

  /// Fetches transactions for a specific Item ID or all items
  static Future<List<TransactionModel>> fetchTransactions(
    OpenFinanceConfig config, {
    String? specificItemId,
  }) async {
    final apiKey = await getApiKey(config);
    final targetItemId = specificItemId ?? config.itemId;

    final String accountsUrl = (targetItemId != null && targetItemId.trim().isNotEmpty)
        ? '$_baseUrl/accounts?itemId=${Uri.encodeComponent(targetItemId.trim())}'
        : '$_baseUrl/accounts';

    final accResp = await http
        .get(
          Uri.parse(accountsUrl),
          headers: {'X-API-KEY': apiKey},
        )
        .timeout(const Duration(seconds: 15));

    if (accResp.statusCode < 200 || accResp.statusCode >= 300) {
      throw Exception('Erro ao buscar contas no Open Finance (${accResp.statusCode}).');
    }

    final accData = jsonDecode(accResp.body) as Map<String, dynamic>;
    final results = (accData['results'] as List<dynamic>?) ?? [];
    if (results.isEmpty) {
      throw Exception(
        'Nenhuma conta bancária conectada encontrada. Conecte seu banco pelo botão "Conectar Banco via Open Finance".',
      );
    }

    final List<TransactionModel> allTransactions = [];

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

          // Ignore self-transfers
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

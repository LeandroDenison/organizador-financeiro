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

class OpenFinanceService {
  static const String _storageKey = 'open_finance_pluggy_config_v1';
  static const String _baseUrl = 'https://api.pluggy.ai';

  static const String defaultClientId = '82695ed9-67f2-416f-a24b-28c15796d7e6';
  static const String defaultClientSecret = 'f4ibQxwoB44m7DhpDCCoGIcJszAlKPE0sFtYQl1KB9o';
  static const String defaultNubankItemId = '22443998-6bc4-4531-ab9e-79e2da47f496';

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
      itemId: defaultNubankItemId,
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

  /// Fetches real transactions via Pluggy API V2 endpoint
  static Future<List<TransactionModel>> fetchTransactions(
    OpenFinanceConfig config, {
    String? specificItemId,
  }) async {
    final apiKey = await getApiKey(config);
    final targetItemId = specificItemId ?? config.itemId ?? defaultNubankItemId;

    final String accountsUrl = '$_baseUrl/accounts?itemId=${Uri.encodeComponent(targetItemId.trim())}';

    final accResp = await http
        .get(
          Uri.parse(accountsUrl),
          headers: {'X-API-KEY': apiKey},
        )
        .timeout(const Duration(seconds: 15));

    if (accResp.statusCode < 200 || accResp.statusCode >= 300) {
      throw Exception('Erro ao buscar contas no Open Finance (${accResp.statusCode}). Verifique o Item ID.');
    }

    final accData = jsonDecode(accResp.body) as Map<String, dynamic>;
    final results = (accData['results'] as List<dynamic>?) ?? [];
    if (results.isEmpty) {
      throw Exception('Nenhuma conta encontrada para a conexão $targetItemId.');
    }

    final List<TransactionModel> allTransactions = [];

    for (final accObj in results) {
      final acc = Map<String, dynamic>.from(accObj as Map);
      final accountId = acc['id']?.toString();
      final accName = acc['name']?.toString() ?? 'Nubank';
      final accType = acc['type']?.toString() ?? 'BANK';
      if (accountId == null) continue;

      // Pluggy API V2 transactions endpoint
      final txResp = await http
          .get(
            Uri.parse('$_baseUrl/v2/transactions?accountId=$accountId'),
            headers: {'X-API-KEY': apiKey},
          )
          .timeout(const Duration(seconds: 25));

      if (txResp.statusCode >= 200 && txResp.statusCode < 300) {
        final txData = jsonDecode(txResp.body) as Map<String, dynamic>;
        final txResults = (txData['results'] as List<dynamic>?) ?? [];

        for (final rawTx in txResults) {
          final map = Map<String, dynamic>.from(rawTx as Map);
          String description = (map['description'] ?? map['descriptionRaw'] ?? 'Transação Open Finance').toString().trim();
          final rawAmount = (map['amount'] as num?)?.toDouble() ?? 0.0;
          final typeStr = map['type']?.toString().toUpperCase() ?? '';
          final dateStr = map['date']?.toString() ?? '';

          if (rawAmount == 0) continue;

          // Format description from pipe if present: e.g. "Transferência Recebida|Nome" -> "Transferência Recebida - Nome"
          if (description.contains('|')) {
            description = description.replaceAll('|', ' - ').trim();
          }

          final lowerDesc = description.toLowerCase();

          // Ignore self-transfers between Denison's own accounts
          if ((lowerDesc.contains('d enison') || lowerDesc.contains('denison')) &&
              (lowerDesc.contains('transferência enviada') || lowerDesc.contains('transferencia enviada'))) {
            continue;
          }

          final isCreditCard = accType.toUpperCase().contains('CREDIT');
          final isExpense = isCreditCard
              ? (rawAmount > 0 && typeStr != 'CREDIT')
              : (rawAmount < 0 || typeStr == 'DEBIT');

          final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

          // Check if installment info exists (e.g. "10/10" or "Parcela 4/10")
          String? installmentRef;
          final instMatch = RegExp(r'(?:Parcela\s+)?(\d+/\d+)', caseSensitive: false).firstMatch(description);
          if (instMatch != null) {
            installmentRef = instMatch.group(1);
          }

          // Detect debtor reference (e.g. Sergio Lucas)
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
              bank: accName.toLowerCase().contains('gold') || accName.toLowerCase().contains('nu') ? 'Nubank' : accName,
              source: TransactionSource.ofx,
              installmentRef: installmentRef,
              personName: personName,
              notes: 'Sincronizado via Open Finance (Pluggy API)',
            ),
          );
        }
      }
    }

    return allTransactions;
  }
}

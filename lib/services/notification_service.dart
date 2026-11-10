import 'dart:async';
import 'package:flutter/services.dart';
import '../models/notification_event_model.dart';
import '../models/transaction_model.dart';

class NotificationParseResult {
  final double amount;
  final String merchant;
  final String? senderName;
  final String bankName;
  final TransactionType type;
  final bool isDda;
  final String? ddaBeneficiary;
  final DateTime? ddaDueDate;
  final String? ddaSignature;

  NotificationParseResult({
    required this.amount,
    required this.merchant,
    this.senderName,
    required this.bankName,
    required this.type,
    this.isDda = false,
    this.ddaBeneficiary,
    this.ddaDueDate,
    this.ddaSignature,
  });
}

class NotificationService {
  static const MethodChannel _channel = MethodChannel('com.leandrodenison.organizador_financeiro/notification_listener');

  static bool isSupportedBankPackage(String package) {
    final lower = package.toLowerCase();
    return lower.contains('nu.production') ||
        lower.contains('itau') ||
        lower.contains('mercadopago') ||
        lower.contains('bradesco') ||
        lower.contains('santander') ||
        lower.contains('inter');
  }

  static String getBankNameFromPackage(String package) {
    final lower = package.toLowerCase();
    if (lower.contains('nu.production') || lower.contains('nubank')) return 'Nubank';
    if (lower.contains('itau')) return 'Itaú';
    if (lower.contains('mercadopago')) return 'Mercado Pago';
    if (lower.contains('bradesco')) return 'Bradesco';
    if (lower.contains('santander')) return 'Santander';
    if (lower.contains('inter')) return 'Inter';
    return 'Banco';
  }

  /// Checks if notification text is related to a DDA / electronic boleto
  static bool isDdaNotification(String fullText) {
    final lower = fullText.toLowerCase();
    if (lower.contains('buscador de boleto') ||
        lower.contains('dda') ||
        lower.contains('boleto eletrônico') ||
        lower.contains('boleto eletronico')) {
      return true;
    }
    if (lower.contains('boleto') &&
        (lower.contains('identificad') ||
            lower.contains('novo boleto') ||
            lower.contains('disponív') ||
            lower.contains('disponiv') ||
            lower.contains('a pagar') ||
            lower.contains('vencimento') ||
            lower.contains('emitido'))) {
      return true;
    }
    return false;
  }

  /// Extracts the beneficiary / issuer of a DDA boleto
  static String extractDdaBeneficiary(String fullText) {
    // Pattern 1: emitido por / recebido de / boleto de / boleto da [BENEFICIARY] (no valor|com vencimento|para|de r$|\.|$)
    final p1 = RegExp(
      r'(?:emitido por|recebido de|novo boleto de|novo boleto da|boleto de|boleto da|boleto do|cedente|benefici[aá]rio)\s+([A-Za-zÀ-ÿ0-9\.\s\-\&]{3,40}?)(?:\s+(?:no\s+valor|com\s+vencimento|para\s+o\s+dia|para\s+o|para|vence|vencendo|de\s+r\$|\.|$))',
      caseSensitive: false,
    );
    final m1 = p1.firstMatch(fullText);
    if (m1 != null) {
      final raw = m1.group(1)?.trim();
      if (raw != null && raw.length >= 3 && !raw.toLowerCase().contains('banco') && !raw.toLowerCase().startsWith('r\$')) {
        return raw;
      }
    }

    // Pattern 2: "de ([A-Za-z0-9...]) com vencimento"
    final p2 = RegExp(
      r'\bde\s+([A-Za-zÀ-ÿ0-9\.\s\-\&]{3,40}?)\s+(?:com\s+vencimento|para\s+o\s+dia|vence|\.|$)',
      caseSensitive: false,
    );
    final m2 = p2.firstMatch(fullText);
    if (m2 != null) {
      final raw = m2.group(1)?.trim();
      if (raw != null && raw.length >= 3 && !raw.toLowerCase().contains('banco') && !raw.toLowerCase().startsWith('r\$')) {
        return raw;
      }
    }

    return 'Boleto DDA';
  }

  /// Extracts due date (vencimento) of a DDA boleto
  static DateTime? extractDdaDueDate(String fullText) {
    final dateRegex = RegExp(
      r'(?:vencimento|vence|para|dia)\s*(?:em|para|no\s+dia)?\s*[:\s]*(\d{1,2})[\/\-\.](\d{1,2})(?:[\/\-\.](\d{2,4}))?',
      caseSensitive: false,
    );
    final match = dateRegex.firstMatch(fullText);
    if (match != null) {
      final day = int.tryParse(match.group(1) ?? '') ?? 1;
      final month = int.tryParse(match.group(2) ?? '') ?? DateTime.now().month;
      var year = DateTime.now().year;
      if (match.group(3) != null) {
        final rawYear = int.tryParse(match.group(3)!) ?? year;
        year = rawYear < 100 ? (2000 + rawYear) : rawYear;
      } else {
        if (month < DateTime.now().month - 1) {
          year += 1;
        }
      }
      try {
        return DateTime(year, month, day);
      } catch (_) {}
    }
    return null;
  }

  /// Generates a normalized signature to detect cross-bank duplicates (e.g. Nubank vs Itaú)
  static String generateDdaSignature({
    required double amount,
    required String beneficiary,
    DateTime? dueDate,
  }) {
    String clean = beneficiary.toUpperCase();
    final accents = {
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C',
    };
    accents.forEach((k, v) => clean = clean.replaceAll(k, v));
    clean = clean.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    clean = clean
        .replaceAll('DISTRIBUICAO', '')
        .replaceAll('DISTRIBUIDORA', '')
        .replaceAll('SERVICOS', '')
        .replaceAll('SERVICO', '')
        .replaceAll('COMPANHIA', '')
        .replaceAll('PAGAMENTOS', '')
        .replaceAll('BRASIL', '')
        .replaceAll('LTDA', '')
        .replaceAll('SA', '')
        .replaceAll('ME', '')
        .replaceAll('EPP', '');

    final stem = clean.length > 8 ? clean.substring(0, 8) : clean;
    final amountCents = (amount * 100).round();
    final duePart = dueDate != null
        ? '${dueDate.month.toString().padLeft(2, '0')}${dueDate.day.toString().padLeft(2, '0')}'
        : 'ANY';

    return 'DDA_${stem}_${amountCents}_$duePart';
  }

  /// Parses text from a push notification to extract financial transaction information
  static NotificationParseResult? parseNotificationText({
    required String appPackage,
    required String title,
    required String text,
  }) {
    final bankName = getBankNameFromPackage(appPackage);
    final fullText = '$title $text';

    // Regex to extract Brazilian currency values: R$ 45,90 or 45,90 or R$ 1.250,00
    final amountRegex = RegExp(r'R\$\s*([\d\.]+(?:,\d{2})?)');
    final amountMatch = amountRegex.firstMatch(fullText);

    if (amountMatch == null) return null;

    final rawAmountStr = amountMatch.group(1) ?? '0';
    final cleanAmount = rawAmountStr.replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(cleanAmount) ?? 0.0;

    if (amount <= 0) return null;

    // Check if it's a DDA electronic boleto notification
    final bool isDda = isDdaNotification(fullText);
    String? ddaBeneficiary;
    DateTime? ddaDueDate;
    String? ddaSignature;

    if (isDda) {
      ddaBeneficiary = extractDdaBeneficiary(fullText);
      ddaDueDate = extractDdaDueDate(fullText);
      ddaSignature = generateDdaSignature(
        amount: amount,
        beneficiary: ddaBeneficiary,
        dueDate: ddaDueDate,
      );

      return NotificationParseResult(
        amount: amount,
        merchant: 'Boleto DDA: $ddaBeneficiary',
        bankName: bankName,
        type: TransactionType.expense,
        isDda: true,
        ddaBeneficiary: ddaBeneficiary,
        ddaDueDate: ddaDueDate,
        ddaSignature: ddaSignature,
      );
    }

    // Determine transaction type
    final lower = fullText.toLowerCase();
    final isIncome = lower.contains('recebido') ||
        lower.contains('recebeu') ||
        lower.contains('pix recebido') ||
        lower.contains('transferência recebida') ||
        lower.contains('ted recebida') ||
        lower.contains('te enviou um pix');

    // Extract Merchant / Destination / Sender
    String merchant = isIncome ? 'Pix Recebido' : 'Compra Cartão';
    String? senderName;

    if (isIncome) {
      // Pattern 1: "[Nome] te enviou um Pix"
      final senderSentRegex = RegExp(
        r'([A-Za-zÀ-ÿ\s]{3,35})\s+te enviou um pix',
        caseSensitive: false,
      );
      final matchSent = senderSentRegex.firstMatch(fullText);

      // Pattern 2: "de [Nome]" or "remetente [Nome]" or "enviado por [Nome]"
      final senderDeRegex = RegExp(
        r'(?:de|enviado por|remetente)\s+([A-Za-zÀ-ÿ\s]{3,35})(?:\s+no|\s+de\s+r\$|\.|$)',
        caseSensitive: false,
      );
      final matchDe = senderDeRegex.firstMatch(fullText);

      final rawSender = matchSent?.group(1)?.trim() ?? matchDe?.group(1)?.trim();
      if (rawSender != null &&
          !rawSender.toLowerCase().contains('banco') &&
          !rawSender.toLowerCase().contains('r\$') &&
          !rawSender.toLowerCase().contains('conta') &&
          rawSender.length >= 3) {
        senderName = rawSender;
        merchant = 'Pix: $rawSender';
      }
    } else {
      // Patterns for expense merchant:
      final merchantRegex = RegExp(
        r'(?:em|no|para|no estabelecimento)\s+([^.,;\n]+)',
        caseSensitive: false,
      );
      final merchantMatch = merchantRegex.firstMatch(text);
      if (merchantMatch != null) {
        merchant = merchantMatch.group(1)?.trim() ?? merchant;
      } else if (title.isNotEmpty &&
          !title.toLowerCase().contains('compra') &&
          !title.toLowerCase().contains('pix')) {
        merchant = title;
      }
    }

    return NotificationParseResult(
      amount: amount,
      merchant: merchant,
      senderName: senderName,
      bankName: bankName,
      type: isIncome ? TransactionType.income : TransactionType.expense,
    );
  }

  /// Request Android notification listener permission
  static Future<bool> requestPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestPermission') ?? false;
      return granted;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // In web or non-android platforms
      return false;
    }
  }

  /// Check if notification listener permission is granted
  static Future<bool> isPermissionGranted() async {
    try {
      final bool granted = await _channel.invokeMethod('isPermissionGranted') ?? false;
      return granted;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Listen to native Android notification events coming through MethodChannel
  static void registerNativeListener(Function(String package, String title, String text) onReceived) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationReceived') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          final pkg = args['package']?.toString() ?? '';
          final title = args['title']?.toString() ?? '';
          final text = args['text']?.toString() ?? '';
          onReceived(pkg, title, text);
        }
      }
    });
  }

  /// Factory helper to build NotificationEventModel from raw inputs
  static NotificationEventModel processIncoming({
    required String appPackage,
    required String title,
    required String text,
    bool autoAdd = false,
  }) {
    final parsed = parseNotificationText(
      appPackage: appPackage,
      title: title,
      text: text,
    );

    return NotificationEventModel(
      appPackage: appPackage,
      bankName: parsed?.bankName ?? getBankNameFromPackage(appPackage),
      rawTitle: title,
      rawText: text,
      parsedAmount: parsed?.amount,
      parsedMerchant: parsed?.merchant,
      status: autoAdd && parsed != null ? NotificationStatus.approved : NotificationStatus.pending,
      autoAdded: autoAdd && parsed != null,
      isDdaBoleto: parsed?.isDda ?? false,
      ddaBeneficiary: parsed?.ddaBeneficiary,
      ddaDueDate: parsed?.ddaDueDate,
      ddaSignature: parsed?.ddaSignature,
    );
  }
}

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

  NotificationParseResult({
    required this.amount,
    required this.merchant,
    this.senderName,
    required this.bankName,
    required this.type,
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
    );
  }
}

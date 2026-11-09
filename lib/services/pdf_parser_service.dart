import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/transaction_model.dart';

class PdfParseResult {
  final String bankName;
  final List<TransactionModel> transactions;
  final String? accountOwner;
  final double? invoiceTotal;

  PdfParseResult({
    required this.bankName,
    required this.transactions,
    this.accountOwner,
    this.invoiceTotal,
  });
}

class PdfParserService {
  /// Extracts text and parses bank statements / credit card invoices
  static PdfParseResult parse(Uint8List bytes, {String? fileName}) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final String fullText = PdfTextExtractor(document).extractText();
    document.dispose();

    return parseText(fullText, fileName: fileName);
  }

  /// Parses raw extracted text from invoice/statement
  static PdfParseResult parseText(String text, {String? fileName}) {
    final lower = text.toLowerCase();

    final isNubank = lower.contains('nubank') ||
        lower.contains('nu pagamentos') ||
        lower.contains('nupay') ||
        lower.contains('resumo da fatura') ||
        (text.contains('••••') && lower.contains('transações de'));

    final isItau = lower.contains('itaú') ||
        lower.contains('itau') ||
        lower.contains('extrato conta / lançamentos') ||
        lower.contains('saldo do dia');

    if (isNubank) {
      return _parseNubankInvoice(text);
    } else if (isItau) {
      return _parseItauStatement(text);
    } else {
      return _parseGenericPdf(text, fileName ?? 'Documento PDF');
    }
  }

  /// Parses Nubank credit card invoice
  static PdfParseResult _parseNubankInvoice(String text) {
    final List<TransactionModel> transactions = [];
    final lines = text.split(RegExp(r'\r?\n'));

    // Try extracting owner and total
    String? owner;
    double? invoiceTotal;

    final totalRegex = RegExp(r'Total a pagar\s+R\$\s*([\d\.,]+)', caseSensitive: false);
    final totalMatch = totalRegex.firstMatch(text);
    if (totalMatch != null) {
      invoiceTotal = _parseAmount(totalMatch.group(1)!);
    }

    final ownerRegex = RegExp(r'(?:D\s*ENISON|DENISON)\s+LEANDRO\s+SIQUEIRA\s+CARNEIRO', caseSensitive: false);
    if (ownerRegex.hasMatch(text)) {
      owner = 'Denison Leandro Siqueira Carneiro';
    }

    // Identify statement year (defaults to current year or found in "FATURA 13 NOV 2026")
    int invoiceYear = DateTime.now().year;
    final yearMatch = RegExp(r'\b202[4-9]\b').firstMatch(text);
    if (yearMatch != null) {
      invoiceYear = int.tryParse(yearMatch.group(0)!) ?? invoiceYear;
    }

    final monthMap = {
      'jan': 1, 'fev': 2, 'mar': 3, 'abr': 4, 'mai': 5, 'jun': 6,
      'jul': 7, 'ago': 8, 'set': 9, 'out': 10, 'nov': 11, 'dez': 12,
    };

    // Regex for date prefix: e.g. "06 OUT" or "04 NOV"
    final datePrefixRegex = RegExp(r'^\s*(\d{2})\s+([A-Za-z]{3})\b');
    // Regex for money at end of line: e.g. "R$ 159,30" or "−R$ 152,42" or "-R$ 2.534,37"
    final moneyEndRegex = RegExp(r'(?:[−\-]?\s*R\$\s*|\b)([−\-]?)(\d{1,3}(?:\.\d{3})*,\d{2})\s*$');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Ignore headers, totals, and sections like "Pagamento em 06 OUT"
      if (line.contains('Pagamento em') ||
          line.contains('RESUMO DA FATURA') ||
          line.contains('PRÓXIMAS FATURAS') ||
          line.contains('LIMITES DISPONÍVEIS') ||
          line.contains('VALOR MÁXIMO PARA') ||
          line.contains('Pagamentos e Financiamentos') ||
          line.startsWith('Total de compras') ||
          line.startsWith('Total a pagar')) {
        continue;
      }

      final dateMatch = datePrefixRegex.firstMatch(line);
      if (dateMatch != null) {
        final day = int.tryParse(dateMatch.group(1)!) ?? 1;
        final monthStr = dateMatch.group(2)!.toLowerCase();
        final month = monthMap[monthStr] ?? 1;

        // Content after date
        String rest = line.substring(dateMatch.end).trim();

        // Check if amount is on the same line
        var moneyMatch = moneyEndRegex.firstMatch(rest);
        String title = '';
        double? amount;
        bool isNegative = false;

        if (moneyMatch != null) {
          final sign = moneyMatch.group(1);
          final rawVal = moneyMatch.group(2)!;
          amount = _parseAmount(rawVal);
          if (sign == '-' || rest.contains('−R\$') || rest.contains('-R\$') || rest.toLowerCase().contains('estorno')) {
            isNegative = true;
          }
          title = rest.substring(0, moneyMatch.start).trim();
        } else {
          // Amount might be on subsequent lines (e.g. multi-line transactions like Western Union or Steam)
          title = rest;
          for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
            final nextLine = lines[j].trim();
            if (datePrefixRegex.hasMatch(nextLine)) break; // Hit next transaction

            // Skip conversion info like "Conversão: BRL 5.24 = USD 1 = R$ 5,24" or "IOF + R$ 437,90"
            if (nextLine.toLowerCase().contains('conversão:') ||
                nextLine.toLowerCase().contains('conversao:') ||
                nextLine.toLowerCase().contains('total a pagar:') ||
                nextLine.toLowerCase().contains('divididos em')) {
              continue;
            }

            final nextMoneyMatch = moneyEndRegex.firstMatch(nextLine);
            if (nextMoneyMatch != null) {
              final sign = nextMoneyMatch.group(1);
              final rawVal = nextMoneyMatch.group(2)!;
              amount = _parseAmount(rawVal);
              if (sign == '-' || nextLine.contains('−R\$') || nextLine.contains('-R\$')) {
                isNegative = true;
              }
              i = j; // Advance
              break;
            }
          }
        }

        if (amount != null && amount > 0) {
          // Clean title
          title = _cleanDescription(title);
          if (title.isNotEmpty) {
            final category = _detectCategory(title);
            final type = isNegative ? TransactionType.income : TransactionType.expense;

            transactions.add(
              TransactionModel(
                title: title,
                amount: amount,
                date: DateTime(invoiceYear, month, day),
                type: type,
                category: category,
                bank: 'Nubank',
                source: TransactionSource.pdf,
                notes: isNegative ? 'Estorno / Devolução de compra' : 'Fatura Nubank',
              ),
            );
          }
        }
      }
    }

    return PdfParseResult(
      bankName: 'Nubank',
      transactions: transactions,
      accountOwner: owner,
      invoiceTotal: invoiceTotal,
    );
  }

  /// Parses Itaú checking account statement
  static PdfParseResult _parseItauStatement(String text) {
    final List<TransactionModel> transactions = [];
    final lines = text.split(RegExp(r'\r?\n'));

    String? owner;
    if (text.contains('DENISON LEANDRO SIQUEIRA CARNEIRO') || text.contains('D ENISON')) {
      owner = 'Denison Leandro Siqueira Carneiro';
    }

    // Pattern: 06/11/2026 FATURA PAGA Itaú Click M -83,42
    // or: 05/11/2026 PAGTO Salários 2.995,34
    final itauLineRegex = RegExp(r'^(\d{2}/\d{2}/\d{4})\s+(.+?)\s+([−\-]?\s*\d{1,3}(?:\.\d{3})*,\d{2})(?:\s+([−\-]?\s*\d{1,3}(?:\.\d{3})*,\d{2}))?$');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('SALDO DO DIA') || trimmed.contains('saldo em conta')) continue;

      final match = itauLineRegex.firstMatch(trimmed);
      if (match != null) {
        final dateStr = match.group(1)!;
        final rawTitle = match.group(2)!.trim();
        final rawVal = match.group(3)!.trim();

        // Date parse DD/MM/YYYY
        final dateParts = dateStr.split('/');
        final day = int.tryParse(dateParts[0]) ?? 1;
        final month = int.tryParse(dateParts[1]) ?? 1;
        final year = int.tryParse(dateParts[2]) ?? DateTime.now().year;

        final isNegative = rawVal.contains('-') || rawVal.contains('−');
        final cleanValStr = rawVal.replaceAll(RegExp(r'[^\d,]'), '');
        final amount = _parseAmount(cleanValStr);

        if (amount > 0) {
          final cleanTitle = _cleanDescription(rawTitle);
          final category = _detectItauCategory(cleanTitle, isNegative);
          final type = isNegative ? TransactionType.expense : TransactionType.income;

          transactions.add(
            TransactionModel(
              title: cleanTitle,
              amount: amount,
              date: DateTime(year, month, day),
              type: type,
              category: category,
              bank: 'Itaú',
              source: TransactionSource.pdf,
              notes: 'Extrato Itaú Conta Corrente',
            ),
          );
        }
      }
    }

    return PdfParseResult(
      bankName: 'Itaú',
      transactions: transactions,
      accountOwner: owner,
    );
  }

  /// Parses generic statements from PDF text
  static PdfParseResult _parseGenericPdf(String text, String defaultBank) {
    final List<TransactionModel> transactions = [];
    final lines = text.split(RegExp(r'\r?\n'));

    final genericRegex = RegExp(r'(\d{2}[/-]\d{2}(?:[/-]\d{2,4})?)\s+(.+?)\s+([−\-]?\s*(?:R\$\s*)?\d{1,3}(?:\.\d{3})*,\d{2})');

    for (final line in lines) {
      final match = genericRegex.firstMatch(line);
      if (match != null) {
        final rawDate = match.group(1)!;
        final rawTitle = match.group(2)!.trim();
        final rawVal = match.group(3)!.trim();

        final isNegative = rawVal.contains('-') || rawVal.contains('−');
        final cleanValStr = rawVal.replaceAll(RegExp(r'[^\d,]'), '');
        final amount = _parseAmount(cleanValStr);

        final parts = rawDate.split(RegExp(r'[/\\-]'));
        final day = int.tryParse(parts[0]) ?? 1;
        final month = int.tryParse(parts[1]) ?? 1;
        final year = parts.length > 2 ? (int.tryParse(parts[2]) ?? DateTime.now().year) : DateTime.now().year;

        if (amount > 0) {
          final cleanTitle = _cleanDescription(rawTitle);
          transactions.add(
            TransactionModel(
              title: cleanTitle,
              amount: amount,
              date: DateTime(year, month, day),
              type: isNegative ? TransactionType.expense : TransactionType.income,
              category: _detectCategory(cleanTitle),
              bank: defaultBank,
              source: TransactionSource.pdf,
            ),
          );
        }
      }
    }

    return PdfParseResult(
      bankName: defaultBank,
      transactions: transactions,
    );
  }

  static double _parseAmount(String val) {
    final clean = val.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  static String _cleanDescription(String text) {
    return text
        .replaceAll(RegExp(r'••••\s*\d{4}'), '') // Remove card digits like •••• 6377
        .replaceAll(RegExp(r'NuPay', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _detectCategory(String title) {
    final lower = title.toLowerCase();

    if (lower.contains('amazon') || lower.contains('magazine') || lower.contains('shopee') || lower.contains('mercado livre')) {
      return 'Compras';
    }
    if (lower.contains('studio z') || lower.contains('riachuelo') || lower.contains('renner') || lower.contains('zara')) {
      return 'Vestuário';
    }
    if (lower.contains('ifood') || lower.contains('anota ai') || lower.contains('sushi') || lower.contains('burger') ||
        lower.contains('espetinho') || lower.contains('pastel') || lower.contains('boteco') || lower.contains('restaurante') ||
        lower.contains('damaki') || lower.contains('galeteria') || lower.contains('meatz')) {
      return 'Alimentação';
    }
    if (lower.contains('supermercado') || lower.contains('cometa') || lower.contains('market') || lower.contains('pão de açúcar')) {
      return 'Supermercado';
    }
    if (lower.contains('drogasil') || lower.contains('farmacia') || lower.contains('raia') ||
        lower.contains('odonto') || lower.contains('total pass') || lower.contains('academia') || lower.contains('saúde')) {
      return 'Saúde';
    }
    if (lower.contains('uber') || lower.contains('posto') || lower.contains('petroleo') || lower.contains('estacionamento') ||
        lower.contains('park') || lower.contains('combustivel')) {
      return 'Transporte';
    }
    if (lower.contains('steam') || lower.contains('crunchy') || lower.contains('hbo') || lower.contains('netflix') ||
        lower.contains('spotify') || lower.contains('trupizupe') || lower.contains('taiba')) {
      return 'Lazer';
    }
    if (lower.contains('google') || lower.contains('linkedin') || lower.contains('tim pos') || lower.contains('telefonia')) {
      return 'Serviços';
    }
    if (lower.contains('western union') || lower.contains('cambio') || lower.contains('iof')) {
      return 'Financeiro';
    }

    return 'Outros';
  }

  static String _detectItauCategory(String title, bool isExpense) {
    final lower = title.toLowerCase();
    if (lower.contains('salário') || lower.contains('salarios')) return 'Salário';
    if (lower.contains('rend pago') || lower.contains('aplic aut')) return 'Rendimento';
    if (lower.contains('fatura paga')) return 'Cartão de Crédito';
    if (lower.contains('pix transf')) return 'Transferência Pix';
    return isExpense ? 'Outros' : 'Outras Receitas';
  }
}

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
        (text.contains('••••') && lower.contains('transações'));

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

  /// Parses Nubank credit card invoice (supports both single-line and multi-line Syncfusion extraction)
  static PdfParseResult _parseNubankInvoice(String text) {
    final List<TransactionModel> transactions = [];
    final lines = text.split(RegExp(r'\r?\n'));

    String? owner;
    double? invoiceTotal;

    final totalRegex = RegExp(r'Total a pagar[\s\r\n]+R\$\s*([\d\.,]+)', caseSensitive: false);
    final totalMatch = totalRegex.firstMatch(text);
    if (totalMatch != null) {
      invoiceTotal = _parseAmount(totalMatch.group(1)!);
    }

    final ownerRegex = RegExp(r'(?:D\s*ENISON|DENISON)\s+LEANDRO\s+SIQUEIRA\s+CARNEIRO', caseSensitive: false);
    if (ownerRegex.hasMatch(text)) {
      owner = 'Denison Leandro Siqueira Carneiro';
    }

    int invoiceYear = DateTime.now().year;
    final yearMatch = RegExp(r'FATURA\s+\d{1,2}\s+[A-Z]{3}\s+(202\d)', caseSensitive: false).firstMatch(text);
    if (yearMatch != null) {
      invoiceYear = int.tryParse(yearMatch.group(1)!) ?? invoiceYear;
    }

    final monthMap = {
      'jan': 1, 'fev': 2, 'mar': 3, 'abr': 4, 'mai': 5, 'jun': 6,
      'jul': 7, 'ago': 8, 'set': 9, 'out': 10, 'nov': 11, 'dez': 12,
    };

    // Date prefix: e.g. "06 OUT" or "04 NOV", NOT followed by a 4-digit year (which would be a due/closing date)
    final datePrefixRegex = RegExp(
      r'^\s*(\d{2})\s+(JAN|FEV|MAR|ABR|MAI|JUN|JUL|AGO|SET|OUT|NOV|DEZ)\b(?!\s+\d{4})',
      caseSensitive: false,
    );

    // Money at end of line or standalone line: e.g. "R$ 159,30" or "−R$ 152,42" or "-R$ 2.534,37"
    final moneyEndRegex = RegExp(r'([−\-]?\s*R\$\s*)([−\-]?)(\d{1,3}(?:\.\d{3})*,\d{2})\s*$');

    // Only parse transactions after the "TRANSAÇÕES" section header if present in the document
    final hasTransactionsSection = lines.any((l) => l.trim().toUpperCase().startsWith('TRANSAÇÕES'));
    bool inTransactionsSection = !hasTransactionsSection;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final upper = line.toUpperCase();
      if (upper.startsWith('TRANSAÇÕES')) {
        inTransactionsSection = true;
        continue;
      }

      // Stop if we hit legal footer notes at the end of page 7
      if (line.startsWith('Em cumprimento à regulação') ||
          line.startsWith('Como assegurado pela Resolução')) {
        inTransactionsSection = false;
        continue;
      }

      if (!inTransactionsSection) continue;

      // Ignore summary/header lines
      if (line.contains('Pagamento em') ||
          line.contains('Pagamentos e Financiamentos') ||
          line.startsWith('Total de compras') ||
          line.startsWith('Total a pagar') ||
          line.startsWith('D E L S Carneiro')) {
        continue;
      }

      final dateMatch = datePrefixRegex.firstMatch(line);
      if (dateMatch != null) {
        final day = int.tryParse(dateMatch.group(1)!) ?? 1;
        final monthStr = dateMatch.group(2)!.toLowerCase();
        final month = monthMap[monthStr] ?? 1;

        String rest = line.substring(dateMatch.end).trim();

        String title = '';
        double? amount;
        bool isNegative = false;

        final sameLineMoney = moneyEndRegex.firstMatch(rest);
        if (sameLineMoney != null) {
          final prefix = sameLineMoney.group(1)!;
          final sign = sameLineMoney.group(2)!;
          final rawVal = sameLineMoney.group(3)!;
          amount = _parseAmount(rawVal);
          if (prefix.contains('-') || prefix.contains('−') || sign.isNotEmpty || rest.toLowerCase().contains('estorno')) {
            isNegative = true;
          }
          title = rest.substring(0, sameLineMoney.start).trim();
        } else {
          // Multi-line transaction (Syncfusion default extraction puts date, card, description, and amount on separate lines)
          final List<String> titleParts = [];
          if (rest.isNotEmpty) {
            titleParts.add(rest);
          }

          for (int j = i + 1; j < lines.length && j <= i + 8; j++) {
            final nextLine = lines[j].trim();
            if (nextLine.isEmpty) continue;

            // Stop if we hit the next transaction date or page footer
            if (datePrefixRegex.hasMatch(nextLine) ||
                RegExp(r'^\d+\s*de\s*\d+$').hasMatch(nextLine) ||
                nextLine.startsWith('Pagamentos e Financiamentos') ||
                nextLine.startsWith('Em cumprimento')) {
              break;
            }

            // Skip card mask standalone lines like "•••• 5480"
            if (RegExp(r'^••••\s*\d{4}$').hasMatch(nextLine)) {
              continue;
            }

            // Skip intermediate currency conversion or financing info lines
            final lowerNext = nextLine.toLowerCase();
            if (lowerNext.startsWith('brl ') ||
                lowerNext.contains('conversão:') ||
                lowerNext.contains('conversao:') ||
                lowerNext.contains('total a pagar:') ||
                lowerNext.contains('divididos em')) {
              continue;
            }

            final nextMoneyMatch = moneyEndRegex.firstMatch(nextLine);
            if (nextMoneyMatch != null) {
              final beforeMoney = nextLine.substring(0, nextMoneyMatch.start).trim();
              if (beforeMoney.isNotEmpty) {
                titleParts.add(beforeMoney);
              }
              final prefix = nextMoneyMatch.group(1)!;
              final sign = nextMoneyMatch.group(2)!;
              final rawVal = nextMoneyMatch.group(3)!;
              amount = _parseAmount(rawVal);
              if (prefix.contains('-') || prefix.contains('−') || sign.isNotEmpty) {
                isNegative = true;
              }
              i = j; // Advance outer loop
              break;
            } else {
              titleParts.add(nextLine);
            }
          }
          title = titleParts.join(' ');
        }

        title = _cleanDescription(title);

        // Ignore "Pagamento em 06 OUT"
        if (title.toLowerCase().startsWith('pagamento em')) {
          continue;
        }

        if (title.toLowerCase().contains('estorno')) {
          isNegative = true;
        }

        if (amount != null && amount > 0 && title.isNotEmpty) {
          final category = _detectCategory(title);
          final type = isNegative ? TransactionType.income : TransactionType.expense;

          // Extract installment reference if present (e.g. "Parcela 4/10")
          String? installmentRef;
          final instMatch = RegExp(r'Parcela\s+(\d+/\d+)', caseSensitive: false).firstMatch(title);
          if (instMatch != null) {
            installmentRef = instMatch.group(1);
          }

          // Detect if it belongs to Sergio Lucas
          String? personName;
          if (title.toLowerCase().contains('sergio lucas')) {
            personName = 'Sergio Lucas';
          }

          transactions.add(
            TransactionModel(
              title: title,
              amount: amount,
              date: DateTime(invoiceYear, month, day),
              type: type,
              category: category,
              bank: 'Nubank',
              source: TransactionSource.pdf,
              installmentRef: installmentRef,
              personName: personName,
              notes: isNegative ? 'Estorno / Devolução de compra' : 'Fatura Nubank',
            ),
          );
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

  /// Parses Itaú checking account statement (supports both single-line and multi-line Syncfusion extraction)
  static PdfParseResult _parseItauStatement(String text) {
    final List<TransactionModel> transactions = [];
    final lines = text.split(RegExp(r'\r?\n'));

    String? owner;
    if (text.contains('DENISON LEANDRO SIQUEIRA CARNEIRO') || text.contains('D ENISON')) {
      owner = 'Denison Leandro Siqueira Carneiro';
    }

    final singleLineRegex = RegExp(
      r'^(\d{2}/\d{2}/\d{4})\s+(.+?)\s+([−\-]?\s*\d{1,3}(?:\.\d{3})*,\d{2})(?:\s+([−\-]?\s*\d{1,3}(?:\.\d{3})*,\d{2}))?$',
    );
    final standaloneDateRegex = RegExp(r'^(\d{2}/\d{2}/\d{4})$');
    final standaloneMoneyRegex = RegExp(r'^([−\-]?\s*\d{1,3}(?:\.\d{3})*,\d{2})$');

    for (int i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('SALDO DO DIA') || trimmed.contains('saldo em conta') || trimmed.contains('emitido em')) {
        continue;
      }

      // Case 1: Single line "06/11/2026 FATURA PAGA Itaú Click M -83,42"
      final singleMatch = singleLineRegex.firstMatch(trimmed);
      if (singleMatch != null) {
        final dateStr = singleMatch.group(1)!;
        final rawTitle = singleMatch.group(2)!.trim();
        final rawVal = singleMatch.group(3)!.trim();
        if (!rawTitle.contains('SALDO DO DIA')) {
          _addItauTransaction(transactions, dateStr, rawTitle, rawVal);
        }
        continue;
      }

      // Case 2: Multi-line Syncfusion extraction:
      // Line i: "06/11/2026"
      // Line i+1: "FATURA PAGA Itaú Click M"
      // Line i+2: "-83,42"
      final dateMatch = standaloneDateRegex.firstMatch(trimmed);
      if (dateMatch != null && i + 2 < lines.length) {
        // Check if previous line was "emitido em:"
        if (i > 0 && lines[i - 1].toLowerCase().contains('emitido em')) {
          continue;
        }
        final dateStr = dateMatch.group(1)!;
        final nextTitle = lines[i + 1].trim();
        final nextVal = lines[i + 2].trim();

        if (nextTitle.contains('SALDO DO DIA')) {
          i += 2;
          continue;
        }

        if (standaloneMoneyRegex.hasMatch(nextVal)) {
          _addItauTransaction(transactions, dateStr, nextTitle, nextVal);
          i += 2;
        }
      }
    }

    return PdfParseResult(
      bankName: 'Itaú',
      transactions: transactions,
      accountOwner: owner,
    );
  }

  static void _addItauTransaction(
    List<TransactionModel> transactions,
    String dateStr,
    String rawTitle,
    String rawVal,
  ) {
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
        .replaceAll(RegExp(r'••••\s*\d{4}'), '')
        .replaceAll(RegExp(r'\s*-\s*NuPay', caseSensitive: false), '')
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

import '../models/transaction_model.dart';

class OfxParseResult {
  final String? bankName;
  final String? accountId;
  final List<TransactionModel> transactions;

  OfxParseResult({
    this.bankName,
    this.accountId,
    required this.transactions,
  });
}

class OfxParserService {
  /// Parses OFX content (both SGML and XML variants)
  static OfxParseResult parse(String content, {String? defaultBank}) {
    final transactions = <TransactionModel>[];

    // Detect Bank from content
    String bank = defaultBank ?? 'Banco';
    if (content.contains('NU PAGAMENTOS') || content.contains('NUBANK') || content.contains('Nu Pagamentos')) {
      bank = 'Nubank';
    } else if (content.contains('ITAU') || content.contains('BANCO ITAU') || content.contains('Itau')) {
      bank = 'Itaú';
    } else if (content.contains('MERCADO PAGO') || content.contains('Mercado Pago')) {
      bank = 'Mercado Pago';
    }

    // Match each <STMTTRN> block
    final stmttrnRegex = RegExp(
      r'<STMTTRN>([\s\S]*?)<\/STMTTRN>',
      caseSensitive: false,
    );

    final matches = stmttrnRegex.allMatches(content);

    for (final match in matches) {
      final block = match.group(1) ?? '';

      final trnType = _extractTag(block, 'TRNTYPE');
      final dtPosted = _extractTag(block, 'DTPOSTED');
      final trnAmtStr = _extractTag(block, 'TRNAMT');
      final fitId = _extractTag(block, 'FITID');
      final memo = _extractTag(block, 'MEMO') ?? _extractTag(block, 'NAME') ?? 'Transação OFX';

      if (trnAmtStr != null) {
        final amountClean = trnAmtStr.replaceAll(',', '.').trim();
        final rawAmount = double.tryParse(amountClean) ?? 0.0;
        final isExpense = rawAmount < 0 || trnType?.toUpperCase() == 'DEBIT';
        final positiveAmount = rawAmount.abs();

        final date = _parseOfxDate(dtPosted);

        transactions.add(
          TransactionModel(
            id: fitId != null && fitId.isNotEmpty ? 'ofx_$fitId' : null,
            title: memo.trim(),
            amount: positiveAmount,
            date: date,
            type: isExpense ? TransactionType.expense : TransactionType.income,
            category: guessCategory(memo),
            bank: bank,
            source: TransactionSource.ofx,
            notes: 'Importado de extrato OFX ($bank)',
          ),
        );
      }
    }

    return OfxParseResult(
      bankName: bank,
      transactions: transactions,
    );
  }

  static String? _extractTag(String block, String tag) {
    // Matches <TAG>value</TAG> OR <TAG>value\n (SGML style)
    final regex = RegExp(
      '<$tag>([^<\\r\\n]+)(?:<\\/$tag>)?',
      caseSensitive: false,
    );
    final match = regex.firstMatch(block);
    return match?.group(1)?.trim();
  }

  static DateTime _parseOfxDate(String? dateStr) {
    if (dateStr == null || dateStr.length < 8) return DateTime.now();
    try {
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      return DateTime(year, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }

  static String normalizeCategory(String? rawCategory, [String? memo]) {
    final cat = (rawCategory ?? '').trim().toLowerCase();

    // Explicit English to Portuguese mapping
    if (cat == 'shopping' || cat == 'compras' || cat == 'retail') return 'Compras';
    if (cat == 'telecommunications' || cat == 'telecom' || cat == 'telefonia') return 'Telefonia & Internet';
    if (cat == 'services' || cat == 'serviços' || cat == 'servicos') return 'Serviços';
    if (cat == 'food & beverage' ||
        cat == 'food and beverage' ||
        cat == 'supermarket' ||
        cat == 'restaurants' ||
        cat == 'alimentação' ||
        cat == 'alimentacao' ||
        cat == 'groceries') {
      return 'Alimentação';
    }
    if (cat == 'transportation' ||
        cat == 'transport' ||
        cat == 'transporte' ||
        cat == 'travel & transportation') {
      return 'Transporte';
    }
    if (cat == 'entertainment' || cat == 'leisure' || cat == 'lazer' || cat == 'streaming') return 'Lazer';
    if (cat == 'health' || cat == 'healthcare' || cat == 'saúde' || cat == 'saude' || cat == 'pharmacy') return 'Saúde';
    if (cat == 'education' || cat == 'educação' || cat == 'educacao') return 'Educação';
    if (cat == 'housing' || cat == 'home' || cat == 'utilities' || cat == 'moradia' || cat == 'rent') return 'Moradia';
    if (cat == 'finances' || cat == 'financial' || cat == 'taxes' || cat == 'financeiro' || cat == 'impostos') return 'Financeiro';
    if (cat == 'travel' || cat == 'tourism' || cat == 'viagem') return 'Viagem';
    if (cat == 'salary' || cat == 'income' || cat == 'salário' || cat == 'salario') return 'Salário';

    // If memo is provided, try to guess
    if (memo != null && memo.isNotEmpty) {
      final guessed = guessCategory(memo);
      if (guessed != 'Outros') return guessed;
    }

    if (rawCategory != null &&
        rawCategory.trim().isNotEmpty &&
        rawCategory.toLowerCase() != 'other' &&
        rawCategory.toLowerCase() != 'outros') {
      final trimmed = rawCategory.trim();
      return trimmed[0].toUpperCase() + trimmed.substring(1);
    }

    return 'Outros';
  }

  static String guessCategory(String memo) {
    final lower = memo.toLowerCase();
    if (lower.contains('supermercado') ||
        lower.contains('mercado') ||
        lower.contains('padaria') ||
        lower.contains('restaurante') ||
        lower.contains('ifood') ||
        lower.contains('burger') ||
        lower.contains('mcdonalds') ||
        lower.contains('cafe')) {
      return 'Alimentação';
    }
    if (lower.contains('uber') ||
        lower.contains('99app') ||
        lower.contains('posto') ||
        lower.contains('combustivel') ||
        lower.contains('gasolina') ||
        lower.contains('estacionamento')) {
      return 'Transporte';
    }
    if (lower.contains('farmacia') ||
        lower.contains('drogaria') ||
        lower.contains('medico') ||
        lower.contains('hospital') ||
        lower.contains('consulta')) {
      return 'Saúde';
    }
    if (lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('amazon prime') ||
        lower.contains('disney') ||
        lower.contains('youtube') ||
        lower.contains('cinema')) {
      return 'Lazer';
    }
    if (lower.contains('salario') || lower.contains('remuneracao') || lower.contains('ted recebida') || lower.contains('pix recebido')) {
      return 'Salário';
    }
    return 'Outros';
  }
}

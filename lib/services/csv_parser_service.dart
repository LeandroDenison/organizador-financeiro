import 'package:csv/csv.dart';
import '../models/transaction_model.dart';
import 'ofx_parser_service.dart';

class CsvParseResult {
  final String bankName;
  final List<TransactionModel> transactions;

  CsvParseResult({
    required this.bankName,
    required this.transactions,
  });
}

class CsvParserService {
  static CsvParseResult parse(String content, {String? defaultBank}) {
    // Detect delimiter (; or ,)
    final delimiter = content.contains(';') && (!content.contains(',') || content.indexOf(';') < content.indexOf(','))
        ? ';'
        : ',';

    final csvConverter = CsvDecoder(
      fieldDelimiter: delimiter,
      skipEmptyLines: true,
      dynamicTyping: false,
    );

    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = csvConverter.convert(normalized);

    if (rows.isEmpty) {
      return CsvParseResult(bankName: defaultBank ?? 'Banco', transactions: []);
    }

    // Determine bank if not provided
    String bank = defaultBank ?? 'Banco';
    final headerStr = rows.first.join(' ').toLowerCase();

    if (headerStr.contains('categoria') && headerStr.contains('title')) {
      bank = 'Nubank (Cartão)';
    } else if (headerStr.contains('identificador') || headerStr.contains('nu pagamentos')) {
      bank = 'Nubank (Conta)';
    } else if (headerStr.contains('operacao') || headerStr.contains('mercado pago')) {
      bank = 'Mercado Pago';
    } else if (headerStr.contains('itau') || headerStr.contains('lancamento')) {
      bank = 'Itaú';
    }

    final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    int dateCol = -1;
    int titleCol = -1;
    int amountCol = -1;
    int categoryCol = -1;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (h.contains('date') || h.contains('data')) dateCol = i;
      if (h.contains('title') || h.contains('descri') || h.contains('memo') || h.contains('lancamento')) titleCol = i;
      if (h.contains('amount') || h.contains('valor')) amountCol = i;
      if (h.contains('category') || h.contains('categoria')) categoryCol = i;
    }

    // Fallbacks if header wasn't perfectly recognized
    if (dateCol == -1) dateCol = 0;
    if (titleCol == -1 && headers.length > 2) titleCol = 2;
    if (amountCol == -1 && headers.length > 3) amountCol = 3;
    if (amountCol == -1 && headers.length > 1) amountCol = 1;

    final transactions = <TransactionModel>[];

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.length <= 1 || (row.length == 1 && row[0].toString().trim().isEmpty)) continue;

      final dateStr = (dateCol < row.length) ? row[dateCol].toString().trim() : '';
      final titleStr = (titleCol < row.length && titleCol >= 0) ? row[titleCol].toString().trim() : 'Transação CSV';
      final amountRaw = (amountCol < row.length && amountCol >= 0) ? row[amountCol].toString().trim() : '0';
      final catStr = (categoryCol >= 0 && categoryCol < row.length) ? row[categoryCol].toString().trim() : '';

      final amount = _cleanAmount(amountRaw);
      if (amount == 0.0 && titleStr.isEmpty) continue;

      final isExpense = amountRaw.contains('-') || (amount > 0 && bank.contains('Cartão'));
      final positiveAmount = amount.abs();
      final date = _parseCsvDate(dateStr);

      String category = catStr.isNotEmpty ? _capitalize(catStr) : OfxParserService.guessCategory(titleStr);

      transactions.add(
        TransactionModel(
          title: titleStr.isEmpty ? 'Transação' : titleStr,
          amount: positiveAmount,
          date: date,
          type: isExpense ? TransactionType.expense : TransactionType.income,
          category: category,
          bank: bank.replaceAll(RegExp(r'\(.*\)'), '').trim(),
          source: TransactionSource.csv,
          notes: 'Importado de CSV ($bank)',
        ),
      );
    }

    return CsvParseResult(
      bankName: bank,
      transactions: transactions,
    );
  }

  static double _cleanAmount(String raw) {
    var clean = raw
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('"', '')
        .trim();

    // Check Brazilian format: 1.234,56
    if (clean.contains(',') && clean.contains('.')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }

    return double.tryParse(clean) ?? 0.0;
  }

  static DateTime _parseCsvDate(String raw) {
    if (raw.isEmpty) return DateTime.now();

    // Remove time if present (e.g., '2023-10-15 14:30:00' or '15/10/2023 14:30')
    final dateOnly = raw.split(' ').first.trim();

    // Format YYYY-MM-DD
    if (dateOnly.contains('-')) {
      final parts = dateOnly.split('-');
      if (parts.length >= 3) {
        final y = int.tryParse(parts[0]) ?? 2026;
        final m = int.tryParse(parts[1]) ?? 1;
        final d = int.tryParse(parts[2]) ?? 1;
        return DateTime(y, m, d);
      }
    }

    // Format DD/MM/YYYY
    if (dateOnly.contains('/')) {
      final parts = dateOnly.split('/');
      if (parts.length >= 3) {
        final d = int.tryParse(parts[0]) ?? 1;
        final m = int.tryParse(parts[1]) ?? 1;
        var y = int.tryParse(parts[2]) ?? 2026;
        if (y < 100) y += 2000;
        return DateTime(y, m, d);
      }
    }

    return DateTime.now();
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

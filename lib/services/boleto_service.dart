enum BoletoType {
  bancario,
  concessionaria,
  tributo,
  desconhecido,
}

class ParsedBoleto {
  final String rawCode;
  final String cleanCode;
  final BoletoType type;
  final double amount;
  final DateTime? dueDate;
  final String bankName;
  final bool isValid;

  const ParsedBoleto({
    required this.rawCode,
    required this.cleanCode,
    required this.type,
    required this.amount,
    this.dueDate,
    required this.bankName,
    required this.isValid,
  });
}

class BoletoService {
  static final Map<String, String> _knownBanks = {
    '001': 'Banco do Brasil',
    '033': 'Santander',
    '104': 'Caixa Econômica',
    '237': 'Bradesco',
    '260': 'Nubank',
    '341': 'Itaú',
    '077': 'Banco Inter',
    '380': 'PicPay',
    '212': 'Banco Original',
    '336': 'C6 Bank',
    '422': 'Banco Safra',
    '748': 'Sicredi',
    '756': 'Sicoob',
  };

  /// Decodifica uma linha digitável de boleto bancário (47 dígitos) ou concessionária (48 dígitos)
  static ParsedBoleto? parse(String input) {
    final clean = input.replaceAll(RegExp(r'\D'), '');

    if (clean.length == 47) {
      return _parseBoletoBancario(input, clean);
    } else if (clean.length == 48) {
      return _parseBoletoConcessionaria(input, clean);
    }
    return null;
  }

  static ParsedBoleto _parseBoletoBancario(String raw, String clean) {
    // Código do Banco: 3 primeiros dígitos
    final bankCode = clean.substring(0, 3);
    final bankName = _knownBanks[bankCode] ?? 'Banco ($bankCode)';

    // Fator de vencimento: posições 33 a 37 (4 dígitos)
    final factorStr = clean.substring(33, 37);
    final factor = int.tryParse(factorStr) ?? 0;

    DateTime? dueDate;
    if (factor > 0) {
      // Regra Febraban: Data base 07/10/1997. Após fator 9999 (fev/2025) entra no ciclo 2 (+3000)
      final baseDate = DateTime(1997, 10, 7);
      if (factor >= 1000) {
        dueDate = baseDate.add(Duration(days: factor));
      } else {
        // Novo ciclo após 2025
        dueDate = baseDate.add(Duration(days: factor + 9000));
      }
    }

    // Valor nominal: posições 37 a 47 (10 dígitos em centavos)
    final amountCents = int.tryParse(clean.substring(37, 47)) ?? 0;
    final amount = amountCents / 100.0;

    return ParsedBoleto(
      rawCode: raw,
      cleanCode: clean,
      type: BoletoType.bancario,
      amount: amount,
      dueDate: dueDate,
      bankName: bankName,
      isValid: true,
    );
  }

  static ParsedBoleto _parseBoletoConcessionaria(String raw, String clean) {
    // Boletos de concessionárias (água, luz, telefone, tributos) iniciam com 8
    final amountCents = int.tryParse(clean.substring(4, 15)) ?? 0;
    final amount = amountCents / 100.0;

    String segment = 'Concessionária (Água/Luz/Gás/Telefonia)';
    final segmentCode = clean.length > 2 ? clean[1] : '0';
    if (segmentCode == '1') segment = 'Prefeitura / Tributos Municipais';
    if (segmentCode == '2') segment = 'Saneamento / Água';
    if (segmentCode == '3') segment = 'Energia Elétrica / Luz';
    if (segmentCode == '4') segment = 'Telecomunicações / Internet / Telefone';
    if (segmentCode == '5') segment = 'Órgãos Governamentais';

    return ParsedBoleto(
      rawCode: raw,
      cleanCode: clean,
      type: segmentCode == '1' || segmentCode == '5' ? BoletoType.tributo : BoletoType.concessionaria,
      amount: amount,
      dueDate: null,
      bankName: segment,
      isValid: true,
    );
  }
}

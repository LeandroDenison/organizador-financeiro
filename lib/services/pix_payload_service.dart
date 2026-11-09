import 'dart:convert';

class PixPayloadService {
  /// Cleans and sanitizes a Pix key according to BACEN / DICT standards:
  /// - CPF: 11 numeric digits only (removes '.', '-', ' ')
  /// - CNPJ: 14 numeric digits only (removes '.', '/', '-', ' ')
  /// - Telefone: international format with '+' and country code 55 (+55DD9XXXXXXXX)
  /// - E-mail: trimmed and lowercased
  /// - Chave Aleatória (EVP): trimmed, lowercased UUID
  static String sanitizePixKey(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) return '';

    // 1. E-mail: contains @
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }

    // 2. Chave Aleatória (UUID / EVP): 32 hex chars with 4 hyphens
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(trimmed)) {
      return trimmed.toLowerCase();
    }

    final hasPhoneIndicator = trimmed.startsWith('+') || trimmed.contains('(') || trimmed.contains(')');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');

    // 3. CNPJ: 14 digits
    if (digits.length == 14) {
      return digits;
    }

    // 4. Telefone with country code: 12 or 13 digits starting with 55
    if ((digits.length == 12 || digits.length == 13) && digits.startsWith('55')) {
      return '+$digits';
    }

    // 5. Telefone with explicit indicator (+ or parens)
    if (hasPhoneIndicator && (digits.length == 10 || digits.length == 11)) {
      return '+55$digits';
    }

    // 6. CPF: standard 11 digits (if user typed 11 digits without phone indicators)
    if (digits.length == 11) {
      return digits;
    }

    // 7. Telefone without country code (10 digits landline)
    if (digits.length == 10) {
      return '+55$digits';
    }

    return digits.isNotEmpty ? digits : trimmed;
  }

  /// Generates the standard EMV BR Code / Pix Copia e Cola string
  /// conforming to the Banco Central do Brasil (BACEN) specification.
  static String generatePixCopiaECola({
    required String pixKey,
    required double? amount,
    String merchantName = 'LEANDRO DENISON',
    String merchantCity = 'BRASILIA',
    String txId = '***',
  }) {
    final cleanKey = sanitizePixKey(pixKey);
    if (cleanKey.isEmpty) return '';

    // 1. Format Merchant Account Information (Tag 26)
    // In standard static Pix (BR Code estático), Tag 26 contains strictly:
    // Subtag 00: 'br.gov.bcb.pix'
    // Subtag 01: clean Pix key
    // Subtag 02 (description) is omitted because many banking apps (Nubank, Caixa, Inter)
    // reject or fail to parse static Pix when subtag 02 is present in Tag 26.
    final gui = _formatTlv('00', 'br.gov.bcb.pix');
    final key = _formatTlv('01', cleanKey);
    final tag26 = _formatTlv('26', '$gui$key');

    // 2. Format basic tags
    final tag00 = _formatTlv('00', '01'); // Payload Format Indicator
    final tag52 = _formatTlv('52', '0000'); // Merchant Category Code
    final tag53 = _formatTlv('53', '986'); // Transaction Currency (BRL = 986)

    // 3. Amount (Tag 54) - included only if amount > 0
    String tag54 = '';
    if (amount != null && amount > 0) {
      tag54 = _formatTlv('54', amount.toStringAsFixed(2));
    }

    final cleanName = _sanitizeString(merchantName.isNotEmpty ? merchantName : 'LEANDRO DENISON', 25);
    final cleanCity = _sanitizeString(merchantCity.isNotEmpty ? merchantCity : 'BRASILIA', 15);

    final tag58 = _formatTlv('58', 'BR'); // Country Code
    final tag59 = _formatTlv('59', cleanName); // Merchant Name
    final tag60 = _formatTlv('60', cleanCity); // Merchant City

    // 4. Additional Data Field (Tag 62) - TxID
    final cleanTxId = _sanitizeString(txId.isNotEmpty ? txId : '***', 25);
    final tag62 = _formatTlv('62', _formatTlv('05', cleanTxId));

    // Assemble payload before CRC
    final payloadWithoutCrc = '$tag00$tag26$tag52$tag53$tag54$tag58$tag59$tag60$tag62\x36\x33\x30\x34';

    // Calculate CRC16-CCITT (0xFFFF initial, 0x1021 polynomial)
    final crc = _crc16Ccitt(payloadWithoutCrc);
    final crcHex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');

    return '$payloadWithoutCrc$crcHex';
  }

  static String _formatTlv(String id, String value) {
    final len = utf8.encode(value).length.toString().padLeft(2, '0');
    return '$id$len$value';
  }

  static String _sanitizeString(String input, int maxLength) {
    // Remove Brazilian accents and special characters
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNn';

    String result = input;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }

    // Keep alphanumeric and spaces only
    result = result.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-_*]'), '').toUpperCase();
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }
    return result;
  }

  static int _crc16Ccitt(String data) {
    int crc = 0xFFFF;
    const polynomial = 0x1021;
    final bytes = utf8.encode(data);

    for (final byte in bytes) {
      for (int i = 0; i < 8; i++) {
        final bit = ((byte >> (7 - i) & 1) == 1);
        final c15 = ((crc >> 15 & 1) == 1);
        crc <<= 1;
        if (c15 ^ bit) {
          crc ^= polynomial;
        }
      }
    }

    crc &= 0xFFFF;
    return crc;
  }
}

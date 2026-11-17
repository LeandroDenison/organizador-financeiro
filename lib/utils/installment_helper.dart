/// Helper utilitário universal para extração e manipulação de parcelamentos
/// Funciona de forma automática e genérica para qualquer usuário e banco,
/// sem depender de nomes de estabelecimentos ou regras manuais.
class InstallmentHelper {
  /// Extrai a referência de parcelamento (ex: "1/4", "3/10") de qualquer texto ou título de transação.
  /// Compatível com notificações bancárias, extratos em PDF, OFX e Open Finance.
  static String? extractInstallmentRef(String text, {String? existingRef}) {
    if (existingRef != null && existingRef.trim().isNotEmpty) {
      final match = RegExp(r'^(\d+)/(\d+)$').firstMatch(existingRef.trim());
      if (match != null) {
        final cur = int.tryParse(match.group(1) ?? '1') ?? 1;
        final tot = int.tryParse(match.group(2) ?? '1') ?? 1;
        if (tot > 1 && tot <= 48 && cur <= tot) {
          return '$cur/$tot';
        }
      }
    }

    if (text.isEmpty) return null;

    // 1. Padrão explícito: "Parcela 1/4", "Parc. 2/6", "Parcela 3 de 10", ou "- 12/12" no final
    final explicitMatch = RegExp(
      r'(?:(?:parcela|parc\.?)\s*(\d{1,2})\s*(?:/|de)\s*(\d{1,2})|-\s*(\d{1,2})\s*/\s*(\d{1,2})\s*$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (explicitMatch != null) {
      final g1 = explicitMatch.group(1) ?? explicitMatch.group(3) ?? '1';
      final g2 = explicitMatch.group(2) ?? explicitMatch.group(4) ?? '1';
      final cur = int.tryParse(g1) ?? 1;
      final tot = int.tryParse(g2) ?? 1;
      if (tot > 1 && tot <= 48 && cur <= tot) {
        return '$cur/$tot';
      }
    }

    // 2. Padrão de notificação/compra: "em 4x", "4x no cartão", "em 10x"
    final timesMatch = RegExp(
      r'(?:em\s+)?(\d{1,2})\s*x\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (timesMatch != null) {
      final count = int.tryParse(timesMatch.group(1) ?? '1') ?? 1;
      if (count > 1 && count <= 48) {
        return '1/$count';
      }
    }

    // 3. Fração avulsa X/Y: ex: "Loja ABC 1/4", "Amazon 2/6"
    // Evita falsos positivos de datas (ex: 1/11, 4/11, 25/10)
    final fractionMatch = RegExp(r'\b(\d{1,2})\s*/\s*(\d{1,2})\b').firstMatch(text);
    if (fractionMatch != null) {
      final cur = int.tryParse(fractionMatch.group(1) ?? '1') ?? 1;
      final tot = int.tryParse(fractionMatch.group(2) ?? '1') ?? 1;
      // No Brasil, datas nos extratos costumam ser dd/MM (ex: 1/11, 4/11).
      // Frações avulsas são parcelas se tot <= 48 e tot não for mês (10, 11, 12),
      // a menos que venha precedido explicitamente por "parcela" (regra 1).
      if (tot > 1 && tot <= 48 && cur <= tot && tot != 10 && tot != 11 && tot != 12) {
        return '$cur/$tot';
      }
    }

    return null;
  }
}

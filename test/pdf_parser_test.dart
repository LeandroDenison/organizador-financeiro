import 'package:flutter_test/flutter_test.dart';
import 'package:organizador_financeiro/services/pdf_parser_service.dart';
import 'package:organizador_financeiro/models/transaction_model.dart';

void main() {
  group('PdfParserService Tests', () {
    test('Parse Nubank Invoice Text', () {
      const sampleNubank = '''
D ENISON LEANDRO SIQUEIRA CARNEIRO
FATURA 13 NOV 2026 EMISSÃO E ENVIO 06 NOV 2026
Total a pagar R\$ 3.042,66
TRANSAÇÕES DE 06 OUT A 06 NOV
D E L S Carneiro R\$ 2.877,78
06 OUT •••• 5480 Amazon - Parcela 4/10 R\$ 159,30
06 OUT •••• 0799 Amazonmktplc*Taxconfig - Parcela 4/10 R\$ 98,76
09 OUT •••• 6377 Ifd*Ifood Club R\$ 7,95
09 OUT •••• 6377 Dl*Google Google R\$ 21,74
10 OUT •••• 6377 Linkedin R\$ 69,99
11 OUT •••• 6377 Boteco do Baba R\$ 78,65
11 OUT •••• 4311 Tim Pos R\$ 89,99
18 OUT iFood - NuPay R\$ 85,09
18 OUT •••• 6377 Damaki Sushi R\$ 105,60
22 OUT •••• 6377 Farmacia Center Popula - Parcela 1/2 R\$ 71,07
23 OUT Estorno de Raia Drogasil - NuPay −R\$ 152,42
23 OUT Raia Drogasil - NuPay R\$ 152,42
26 OUT •••• 6377 Steamgames.Com
BRL 97.19 = USD 19.29
Conversão: BRL 5.24 = USD 1 = R\$ 5,24
R\$ 101,08
01 NOV •••• 6377 Meatz Burger Fortaleza R\$ 70,00
04 NOV •••• 6377 Jim.Com* Sergio Lucas R\$ 641,78
06 OUT WESTERN UNION CORRETORA DE CAMBIO SA - Parcela 11/12
Total a pagar: R\$ 1.978,50 divididos em 12 parcelas de R\$ 164,88.
R\$ 164,88
Pagamentos e Financiamentos -R\$ 2.369,49
06 OUT Pagamento em 06 OUT −R\$ 2.534,37
''';

      final result = PdfParserService.parseText(sampleNubank);

      expect(result.bankName, equals('Nubank'));
      expect(result.accountOwner, contains('Denison Leandro'));
      expect(result.invoiceTotal, equals(3042.66));
      expect(result.transactions.isNotEmpty, isTrue);

      final amazon = result.transactions.firstWhere((t) => t.title.contains('Amazon - Parcela'));
      expect(amazon.amount, equals(159.30));
      expect(amazon.category, equals('Compras'));

      final sergio = result.transactions.firstWhere((t) => t.title.contains('Sergio Lucas'));
      expect(sergio.amount, equals(641.78));

      final estorno = result.transactions.firstWhere((t) => t.title.contains('Estorno'));
      expect(estorno.amount, equals(152.42));
      expect(estorno.type, equals(TransactionType.income));

      final steam = result.transactions.firstWhere((t) => t.title.contains('Steamgames'));
      expect(steam.amount, equals(101.08));

      final wu = result.transactions.firstWhere((t) => t.title.contains('WESTERN UNION'));
      expect(wu.amount, equals(164.88));
    });

    test('Parse Itau Statement Text', () {
      const sampleItau = '''
D ENISON LEANDRO SIQUEIRA CARNEIRO 620.861.813-45 agência: 7366 conta: 060301-2
saldo em conta R\$ 0,01
extrato conta / lançamentos
período de visualização: 10/10/2026 até 09/11/2026
data lançamentos valor (R\$) saldo (R\$)
07/11/2026 SALDO DO DIA 0,01
06/11/2026 FATURA PAGA Itaú Click M -83,42
06/11/2026 FATURA PAGA Samsung Itaú -216,62
06/11/2026 PIX TRANSF D Eniso06/11 -2.695,31
06/11/2026 REND PAGO APLIC AUT APR 0,01
06/11/2026 SALDO DO DIA 0,01
05/11/2026 PAGTO Salários 2.995,34
05/11/2026 SALDO DO DIA 2.995,35
''';

      final result = PdfParserService.parseText(sampleItau);

      expect(result.bankName, equals('Itaú'));
      expect(result.accountOwner, contains('Denison Leandro'));
      expect(result.transactions.length, equals(5));

      final salario = result.transactions.firstWhere((t) => t.title.contains('Salários'));
      expect(salario.amount, equals(2995.34));
      expect(salario.type, equals(TransactionType.income));
      expect(salario.category, equals('Salário'));

      final pix = result.transactions.firstWhere((t) => t.title.contains('PIX TRANSF'));
      expect(pix.amount, equals(2695.31));
      expect(pix.type, equals(TransactionType.expense));

      final samsung = result.transactions.firstWhere((t) => t.title.contains('Samsung Itaú'));
      expect(samsung.amount, equals(216.62));
      expect(samsung.category, equals('Cartão de Crédito'));
    });
  });
}

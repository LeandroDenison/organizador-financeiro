import 'package:flutter_test/flutter_test.dart';
import 'package:organizador_financeiro/models/debt_model.dart';
import 'package:organizador_financeiro/models/transaction_model.dart';
import 'package:organizador_financeiro/services/ofx_parser_service.dart';

void main() {
  group('Category Normalization Tests (Pluggy EN -> PT)', () {
    test('Translates English categories to Portuguese', () {
      expect(OfxParserService.normalizeCategory('Shopping'), 'Compras');
      expect(OfxParserService.normalizeCategory('Telecommunications'), 'Telefonia & Internet');
      expect(OfxParserService.normalizeCategory('Services'), 'Serviços');
      expect(OfxParserService.normalizeCategory('Food & Beverage'), 'Alimentação');
      expect(OfxParserService.normalizeCategory('Transportation'), 'Transporte');
      expect(OfxParserService.normalizeCategory('Entertainment'), 'Lazer');
      expect(OfxParserService.normalizeCategory('Health'), 'Saúde');
      expect(OfxParserService.normalizeCategory('Housing'), 'Moradia');
      expect(OfxParserService.normalizeCategory('Finances'), 'Financeiro');
    });

    test('Falls back to memo guessing when category is missing or generic', () {
      expect(OfxParserService.normalizeCategory(null, 'COMPRA IFOOD RESTAURANTE'), 'Alimentação');
      expect(OfxParserService.normalizeCategory('Other', 'UBER TRIP 123'), 'Transporte');
      expect(OfxParserService.normalizeCategory('', 'FARMACIA DROGASIL'), 'Saúde');
      expect(OfxParserService.normalizeCategory(null, 'NETFLIX ASSINATURA'), 'Lazer');
    });
  });

  group('Debt and Abatement Calculations', () {
    test('Calculates Sergio Lucas gross dues, abatements and remaining monthly balance', () {
      final now = DateTime(2026, 11, 11);

      // Sergio has debts totaling R$ 1.483,36 in November
      final debt1 = DebtModel(
        id: 'd1',
        personName: 'Sergio Lucas',
        description: 'Mercado Livre Notebook',
        totalAmount: 6000.0,
        totalInstallments: 6,
        remainingInstallments: 5,
        installmentValue: 1000.0,
        dueDay: 15,
        createdAt: DateTime(2026, 10, 1),
        paymentHistory: [
          DebtPaymentRecord(
            id: 'p1',
            date: DateTime(2026, 11, 10),
            amount: 1000.0,
            installmentNumber: 1,
            note: 'Pix recebido de Sérgio para abater parcelas do mês',
          ),
        ],
      );

      final debt2 = DebtModel(
        id: 'd2',
        personName: 'Sergio Lucas',
        description: 'Amazon Monitor',
        totalAmount: 1450.08,
        totalInstallments: 3,
        remainingInstallments: 2,
        installmentValue: 483.36,
        dueDay: 20,
        createdAt: DateTime(2026, 10, 1),
        paymentHistory: [],
      );

      final sergioDebts = [debt1, debt2];

      // 1. Gross month installments
      final gross = sergioDebts.fold(0.0, (sum, d) {
        final val = d.remainingAmount < d.installmentValue ? d.remainingAmount : d.installmentValue;
        return sum + val;
      });
      expect(gross, closeTo(1483.36, 0.01));

      // 2. Paid abatements this month
      final paidThisMonth = sergioDebts.fold(0.0, (sum, d) {
        return sum + d.paymentHistory
            .where((p) => p.date.year == now.year && p.date.month == now.month)
            .fold(0.0, (s, p) => s + p.amount);
      });
      expect(paidThisMonth, 1000.0);

      // 3. Remaining balance due this month = Gross - Paid
      final netDue = (gross - paidThisMonth).clamp(0.0, double.infinity);
      expect(netDue, closeTo(483.36, 0.01));
    });
  });

  group('Personal Net Expense Logic', () {
    test('Deducts third party debt from owner personal expense total', () {
      final txs = [
        TransactionModel(
          id: 'tx1',
          title: 'Supermercado Mensal',
          amount: 500.0,
          date: DateTime(2026, 11, 5),
          type: TransactionType.expense,
          category: 'Alimentação',
          source: TransactionSource.ofx,
        ),
        TransactionModel(
          id: 'tx2',
          title: 'MERCADOLIVRE*COMPRA',
          amount: 1000.0,
          date: DateTime(2026, 11, 6),
          type: TransactionType.expense,
          category: 'Compras',
          source: TransactionSource.ofx,
          personName: 'Sergio Lucas', // Third party
        ),
      ];

      final totalExpense = txs.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + t.amount);
      expect(totalExpense, 1500.0);

      final thirdParty = txs.where((t) => t.personName != null && t.personName!.isNotEmpty).fold(0.0, (s, t) => s + t.amount);
      expect(thirdParty, 1000.0);

      final myNetExpense = totalExpense - thirdParty;
      expect(myNetExpense, 500.0);
    });
  });
}

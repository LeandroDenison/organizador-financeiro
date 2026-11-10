import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador_financeiro/services/pdf_parser_service.dart';
import 'package:organizador_financeiro/models/transaction_model.dart';

void main() {
  group('PdfParserService Real PDF Files Tests', () {
    test('Parse real Nubank_2026-11-13.pdf file from Downloads', () {
      final file = File(r'C:\Users\leand\Downloads\Nubank_2026-11-13.pdf');
      if (file.existsSync()) {
        final result = PdfParserService.parse(file.readAsBytesSync(), fileName: 'Nubank_2026-11-13.pdf');
        print('Nubank real PDF parsed ${result.transactions.length} transactions:');
        double totalExpenses = 0;
        double totalIncomes = 0;
        for (final t in result.transactions) {
          if (t.type == TransactionType.expense) {
            totalExpenses += t.amount;
          } else {
            totalIncomes += t.amount;
          }
          print('  [${t.date.day}/${t.date.month}] ${t.title} -> ${t.type.name}: R\$ ${t.amount} (${t.category})');
        }
        print('Total Expenses: R\$ ${totalExpenses.toStringAsFixed(2)}');
        print('Total Incomes (Estornos): R\$ ${totalIncomes.toStringAsFixed(2)}');
        print('Net Invoice Total: R\$ ${(totalExpenses - totalIncomes).toStringAsFixed(2)}');

        expect(result.bankName, equals('Nubank'));
        expect(result.transactions.length, equals(46));
        expect(totalExpenses - totalIncomes, closeTo(3042.66, 0.05));
      }
    });

    test('Parse real itau_extrato_102026_261109_153654.pdf file from Downloads', () {
      final file = File(r'C:\Users\leand\Downloads\itau_extrato_102026_261109_153654.pdf');
      if (file.existsSync()) {
        final result = PdfParserService.parse(file.readAsBytesSync(), fileName: 'itau_extrato.pdf');
        print('Itau real PDF parsed ${result.transactions.length} transactions:');
        for (final t in result.transactions) {
          print('  [${t.date.day}/${t.date.month}/${t.date.year}] ${t.title} -> ${t.type.name}: R\$ ${t.amount} (${t.category})');
        }
        expect(result.bankName, equals('Itaú'));
        expect(result.transactions.length, equals(4));
      }
    });
  });
}

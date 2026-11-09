import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:organizador_financeiro/main.dart';
import 'package:organizador_financeiro/providers/app_state_provider.dart';
import 'package:organizador_financeiro/providers/finance_provider.dart';
import 'package:organizador_financeiro/providers/debt_provider.dart';
import 'package:organizador_financeiro/providers/notification_provider.dart';
import 'package:organizador_financeiro/providers/budget_provider.dart';
import 'package:organizador_financeiro/providers/savings_provider.dart';
import 'package:organizador_financeiro/providers/subscription_provider.dart';
import 'package:organizador_financeiro/services/firebase_service.dart';
import 'package:organizador_financeiro/services/pdf_parser_service.dart';
import 'package:organizador_financeiro/views/bank_import/widgets/import_preview_dialog.dart';

void main() {
  testWidgets('App basic smoke test on mobile screen (360dp width)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ChangeNotifierProvider(create: (_) => FinanceProvider()),
          ChangeNotifierProvider(create: (_) => DebtProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => FirebaseService()),
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
          ChangeNotifierProvider(create: (_) => SavingsProvider()),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ],
        child: const FinancialOrganizerApp(),
      ),
    );
    expect(find.byType(FinancialOrganizerApp), findsOneWidget);
  });

  testWidgets('ImportPreviewDialog renders 46 real Nubank transactions on 360dp mobile screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final file = File(r'C:\Users\leand\Downloads\Nubank_2026-11-13.pdf');
    final parsed = file.existsSync()
        ? PdfParserService.parse(file.readAsBytesSync()).transactions
        : PdfParserService.parseText('TRANSAÇÕES\n06 OUT\n•••• 5480\nAmazon - Parcela 4/10\nR\$ 159,30').transactions;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FinanceProvider()),
          ChangeNotifierProvider(create: (_) => DebtProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ImportPreviewDialog(
              bankName: 'Nubank',
              parsedTransactions: parsed,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Extrato: Nubank'), findsOneWidget);
    expect(find.textContaining('Amazon - Parcela 4/10'), findsOneWidget);
  });
}

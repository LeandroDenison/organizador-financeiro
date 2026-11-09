import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:organizador_financeiro/views/transactions/transactions_view.dart';
import 'package:organizador_financeiro/views/transactions/widgets/add_transaction_dialog.dart';
import 'package:organizador_financeiro/views/transactions/widgets/assign_to_debt_dialog.dart';
import 'package:organizador_financeiro/views/debts/debts_view.dart';
import 'package:organizador_financeiro/views/settings/settings_view.dart';

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

  testWidgets('AddTransactionDialog, TransactionsView and DebtsView render on 360dp mobile screen without overflow', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final financeProvider = FinanceProvider();
    final parsed = PdfParserService.parseText(
      'TRANSAÇÕES\n06 OUT\n•••• 5480\nAmazon - Parcela 4/10\nR\$ 159,30\n01 NOV\n•••• 9736\nMeatz Burger Fortaleza\nR\$ 70,00\n28 OUT\n•••• 9736\nSupermercado Cometa\nR\$ 18,19',
    ).transactions;
    await financeProvider.addMultipleTransactions(parsed);

    // 0. Test AssignToDebtDialog auto-recognizes Parcela 4/10 (7 remaining of R$ 159,30 = R$ 1.115,10)
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: financeProvider),
          ChangeNotifierProvider(create: (_) => DebtProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AssignToDebtDialog(transaction: parsed.first),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Parcela 4 de 10'), findsOneWidget);
    expect(find.textContaining('Faltam 7 parcelas'), findsOneWidget);

    // 1. Test AddTransactionDialog
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: financeProvider),
          ChangeNotifierProvider(create: (_) => DebtProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddTransactionDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nova Transação'), findsOneWidget);

    // 2. Test TransactionsView
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: financeProvider),
          ChangeNotifierProvider(create: (_) => DebtProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TransactionsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meatz Burger Fortaleza'), findsOneWidget);

    // 3. Test DebtsView
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: financeProvider),
          ChangeNotifierProvider(create: (_) => DebtProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DebtsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ativos'), findsOneWidget);
    expect(find.text('Quitados'), findsOneWidget);

    // 4. Test SettingsView (Firebase + Google Drive cards on 360dp mobile screen)
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ChangeNotifierProvider.value(value: financeProvider),
          ChangeNotifierProvider(create: (_) => DebtProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => FirebaseService()),
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
          ChangeNotifierProvider(create: (_) => SavingsProvider()),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SettingsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Google Drive'), findsWidgets);
  });
}

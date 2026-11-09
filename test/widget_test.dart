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

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
}

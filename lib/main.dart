import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/app_state_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/savings_provider.dart';
import 'providers/subscription_provider.dart';
import 'services/firebase_service.dart';
import 'utils/constants.dart';
import 'views/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppStateProvider();
  await appState.init();

  final financeProvider = FinanceProvider();
  await financeProvider.init();

  final debtProvider = DebtProvider();
  await debtProvider.init();

  final notificationProvider = NotificationProvider();
  await notificationProvider.init(financeProvider, debtProvider);

  final firebaseService = FirebaseService();
  await firebaseService.init();

  final budgetProvider = BudgetProvider();
  await budgetProvider.init();

  final savingsProvider = SavingsProvider();
  await savingsProvider.init();

  final subscriptionProvider = SubscriptionProvider();
  await subscriptionProvider.init();
  await subscriptionProvider.syncFromTransactions(financeProvider.transactions);

  // Start real-time two-way cloud synchronization (Phone <-> Browser via Firestore)
  unawaited(
    firebaseService.startRealtimeSync(
      onRemoteUpdated: () async {
        await financeProvider.init();
        await debtProvider.init();
        await budgetProvider.init();
        await savingsProvider.init();
        await subscriptionProvider.init();
        await subscriptionProvider.syncFromTransactions(financeProvider.transactions);
      },
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: financeProvider),
        ChangeNotifierProvider.value(value: debtProvider),
        ChangeNotifierProvider.value(value: notificationProvider),
        ChangeNotifierProvider.value(value: firebaseService),
        ChangeNotifierProvider.value(value: budgetProvider),
        ChangeNotifierProvider.value(value: savingsProvider),
        ChangeNotifierProvider.value(value: subscriptionProvider),
      ],
      child: const FinancialOrganizerApp(),
    ),
  );
}

class FinancialOrganizerApp extends StatelessWidget {
  const FinancialOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

    return MaterialApp(
      title: 'Organizador Financeiro Multiplataforma',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.light,
          primary: AppConstants.primaryColor,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.dark,
          primary: AppConstants.primaryColor,
          surface: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
      ),
      home: const MainLayout(),
    );
  }
}

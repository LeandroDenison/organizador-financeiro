import 'package:flutter/foundation.dart';
import '../models/notification_event_model.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import '../services/sample_data_service.dart';
import '../services/notification_service.dart';
import '../services/ofx_parser_service.dart';
import 'finance_provider.dart';
import 'debt_provider.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationEventModel> _notifications = [];
  bool _isLoading = true;
  bool _autoAdd = true;
  bool _isListenerPermissionGranted = false;

  List<NotificationEventModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get autoAdd => _autoAdd;
  bool get isListenerPermissionGranted => _isListenerPermissionGranted;

  List<NotificationEventModel> get pendingNotifications =>
      _notifications.where((n) => n.status == NotificationStatus.pending).toList();

  Future<void> init([FinanceProvider? financeProvider, DebtProvider? debtProvider]) async {
    _isLoading = true;
    notifyListeners();

    _autoAdd = await StorageService.isAutoAddNotificationsEnabled();
    _isListenerPermissionGranted = await NotificationService.isPermissionGranted();

    // Register Android native listener
    NotificationService.registerNativeListener((pkg, title, text) {
      if (financeProvider != null) {
        onNotificationReceived(
          appPackage: pkg,
          title: title,
          text: text,
          financeProvider: financeProvider,
          debtProvider: debtProvider,
        );
      }
    });

    var stored = await StorageService.loadNotifications();
    final hasFakes = stored.any((n) => n.rawText.contains('Pão de Açúcar') || n.rawText.contains('Farmácia São Paulo'));
    if (hasFakes) {
      stored = [];
      await StorageService.saveNotifications([]);
    }
    _notifications = stored;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setAutoAdd(bool value) async {
    _autoAdd = value;
    await StorageService.setAutoAddNotifications(value);
    notifyListeners();
  }

  Future<void> checkPermission() async {
    _isListenerPermissionGranted = await NotificationService.isPermissionGranted();
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    final granted = await NotificationService.requestPermission();
    _isListenerPermissionGranted = granted;
    notifyListeners();
    return granted;
  }

  /// Called when a notification is captured from Android or simulated
  Future<void> onNotificationReceived({
    required String appPackage,
    required String title,
    required String text,
    required FinanceProvider financeProvider,
    DebtProvider? debtProvider,
  }) async {
    final parsed = NotificationService.parseNotificationText(
      appPackage: appPackage,
      title: title,
      text: text,
    );

    // Check if Pix sender or exact amount matches any active debtor
    String? matchedPerson;
    if (parsed != null && parsed.type == TransactionType.income && debtProvider != null) {
      final sender = parsed.senderName ?? parsed.merchant;
      matchedPerson = debtProvider.findMatchingPerson(sender, amount: parsed.amount);
      matchedPerson ??= debtProvider.findMatchingPerson('$title $text', amount: parsed.amount);
    }

    String? createdTxId;
    final bool shouldAutoAdd = _autoAdd && parsed != null && parsed.amount > 0;

    // If it's a Pix from a recognized debtor and auto-add is enabled, auto-abate (identifying exact account by value if matched)!
    if (shouldAutoAdd && matchedPerson != null && debtProvider != null) {
      final matchedDebt = debtProvider.findExactDebtByAmount(
        personName: matchedPerson,
        amount: parsed.amount,
      );
      await debtProvider.abatePersonDebts(
        personName: matchedPerson,
        amount: parsed.amount,
        financeProvider: financeProvider,
        note: matchedDebt != null
            ? 'Pix automático reconhecido para "${matchedDebt.description}" ($appPackage)'
            : 'Pix automático ($appPackage)',
      );
    } else if (shouldAutoAdd) {
      final tx = TransactionModel(
        title: parsed!.merchant,
        amount: parsed.amount,
        date: DateTime.now(),
        type: parsed.type,
        category: OfxParserService.guessCategory(parsed.merchant),
        bank: parsed.bankName,
        source: TransactionSource.notification,
        notes: 'Captura automática via notificação ($appPackage)',
      );
      await financeProvider.addTransaction(tx);
      createdTxId = tx.id;
    }

    final event = NotificationEventModel(
      appPackage: appPackage,
      bankName: parsed?.bankName ?? NotificationService.getBankNameFromPackage(appPackage),
      rawTitle: title,
      rawText: text,
      parsedAmount: parsed?.amount,
      parsedMerchant: parsed?.merchant,
      status: shouldAutoAdd ? NotificationStatus.approved : NotificationStatus.pending,
      autoAdded: shouldAutoAdd,
      createdTransactionId: createdTxId,
      matchedPersonName: matchedPerson,
      isDebtAbatementCandidate: matchedPerson != null,
    );

    _notifications.insert(0, event);
    await _persist();
    notifyListeners();
  }

  /// Manually trigger debt abatement from a received Pix notification
  Future<void> abateFromNotification({
    required NotificationEventModel event,
    required String personName,
    required DebtProvider debtProvider,
    required FinanceProvider financeProvider,
  }) async {
    final amount = event.parsedAmount ?? 0.0;
    if (amount <= 0) return;

    await debtProvider.abatePersonDebts(
      personName: personName,
      amount: amount,
      financeProvider: financeProvider,
      note: 'Pix de $personName abatido pelo usuário',
    );

    event.status = NotificationStatus.approved;
    event.matchedPersonName = personName;
    event.isDebtAbatementCandidate = true;

    await _persist();
    notifyListeners();
  }

  Future<void> approveNotification(
    NotificationEventModel event,
    FinanceProvider financeProvider, {
    String? customCategory,
  }) async {
    final index = _notifications.indexWhere((n) => n.id == event.id);
    if (index == -1) return;

    final amount = event.parsedAmount ?? 0.0;
    final merchant = event.parsedMerchant ?? event.rawTitle;

    if (amount > 0) {
      final tx = TransactionModel(
        title: merchant,
        amount: amount,
        date: event.timestamp,
        type: TransactionType.expense,
        category: customCategory ?? OfxParserService.guessCategory(merchant),
        bank: event.bankName,
        source: TransactionSource.notification,
        notes: 'Aprovado a partir da notificação',
      );
      await financeProvider.addTransaction(tx);
      event.createdTransactionId = tx.id;
    }

    event.status = NotificationStatus.approved;
    _notifications[index] = event;

    await _persist();
    notifyListeners();
  }

  Future<void> ignoreNotification(NotificationEventModel event) async {
    final index = _notifications.indexWhere((n) => n.id == event.id);
    if (index == -1) return;

    event.status = NotificationStatus.ignored;
    _notifications[index] = event;

    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.saveNotifications(_notifications);
  }
}

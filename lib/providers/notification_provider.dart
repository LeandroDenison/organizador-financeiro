import 'package:flutter/foundation.dart';
import '../models/notification_event_model.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
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
    // Remove any promotional marketing push notifications that were captured
    final hadPromos = stored.any((n) => NotificationService.isMarketingOrPromotional('${n.rawTitle} ${n.rawText}'));
    if (hadPromos) {
      stored.removeWhere((n) => NotificationService.isMarketingOrPromotional('${n.rawTitle} ${n.rawText}'));
      await StorageService.saveNotifications(stored);
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

  /// Checks if a DDA notification has already been captured from another bank (e.g. Nubank vs Itaú)
  NotificationEventModel? findDdaDuplicate({
    required String? signature,
    required double? amount,
    required String? beneficiary,
    DateTime? dueDate,
  }) {
    if (amount == null || amount <= 0) return null;

    for (final n in _notifications) {
      if (!n.isDdaBoleto) continue;

      // 1. Direct signature exact match
      if (signature != null && n.ddaSignature != null && n.ddaSignature == signature) {
        return n;
      }

      // 2. Value match + Beneficiary similarity match + Date window
      if (n.parsedAmount != null && (n.parsedAmount! - amount).abs() < 0.01) {
        final b1 = (n.ddaBeneficiary ?? n.parsedMerchant ?? '').toUpperCase();
        final b2 = (beneficiary ?? '').toUpperCase();

        bool benMatches = false;
        if (b1.isNotEmpty && b2.isNotEmpty) {
          if (b1.contains(b2) || b2.contains(b1)) {
            benMatches = true;
          } else {
            // First significant word comparison (e.g. "ENEL", "CAGECE", "UNIMED", "CLARO")
            final w1 = b1.split(RegExp(r'[\s\.\-]+')).firstWhere((w) => w.length >= 3, orElse: () => '');
            final w2 = b2.split(RegExp(r'[\s\.\-]+')).firstWhere((w) => w.length >= 3, orElse: () => '');
            if (w1.isNotEmpty && w2.isNotEmpty && (w1 == w2 || w1.contains(w2) || w2.contains(w1))) {
              benMatches = true;
            }
          }
        }

        if (benMatches) {
          if (n.ddaDueDate != null && dueDate != null) {
            if (n.ddaDueDate!.difference(dueDate).inDays.abs() <= 5) {
              return n;
            }
          } else {
            // Fallback: events received within a 20-day timeframe
            return n;
          }
        }
      }
    }
    return null;
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

    // --- DDA DEDUPLICATION CHECK ---
    // If Itaú and Nubank both notify about the same DDA boleto under the user's CPF,
    // intercept and block the duplicate from creating double transactions or noise.
    if (parsed != null && parsed.isDda) {
      final duplicateMatch = findDdaDuplicate(
        signature: parsed.ddaSignature,
        amount: parsed.amount,
        beneficiary: parsed.ddaBeneficiary,
        dueDate: parsed.ddaDueDate,
      );

      if (duplicateMatch != null) {
        // DUPLICATE DETECTED!
        final duplicateEvent = NotificationEventModel(
          appPackage: appPackage,
          bankName: parsed.bankName,
          rawTitle: title,
          rawText: text,
          parsedAmount: parsed.amount,
          parsedMerchant: parsed.merchant,
          status: NotificationStatus.ignored, // Automatically ignored
          autoAdded: false,
          isDdaBoleto: true,
          ddaBeneficiary: parsed.ddaBeneficiary,
          ddaDueDate: parsed.ddaDueDate,
          ddaSignature: parsed.ddaSignature,
          isDuplicateDda: true,
          duplicateOfBank: duplicateMatch.bankName,
          duplicateOfId: duplicateMatch.id,
          notes: 'DDA já capturado via ${duplicateMatch.bankName}. Notificação do ${parsed.bankName} descartada para não duplicar o boleto.',
        );

        _notifications.insert(0, duplicateEvent);
        await _persist();
        notifyListeners();
        return; // Halt: no double transaction or double commitment created!
      }
    }

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
        title: parsed.merchant,
        amount: parsed.amount,
        date: parsed.isDda && parsed.ddaDueDate != null ? parsed.ddaDueDate! : DateTime.now(),
        type: parsed.type,
        category: parsed.isDda ? 'Contas & Boletos' : OfxParserService.guessCategory(parsed.merchant),
        bank: parsed.bankName,
        source: TransactionSource.notification,
        notes: parsed.isDda
            ? 'Boleto DDA capturado automaticamente via notificação (${parsed.bankName})'
            : 'Captura automática via notificação ($appPackage)',
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
      isDdaBoleto: parsed?.isDda ?? false,
      ddaBeneficiary: parsed?.ddaBeneficiary,
      ddaDueDate: parsed?.ddaDueDate,
      ddaSignature: parsed?.ddaSignature,
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
        date: event.isDdaBoleto && event.ddaDueDate != null ? event.ddaDueDate! : event.timestamp,
        type: TransactionType.expense,
        category: customCategory ?? (event.isDdaBoleto ? 'Contas & Boletos' : OfxParserService.guessCategory(merchant)),
        bank: event.bankName,
        source: TransactionSource.notification,
        notes: event.isDdaBoleto
            ? 'Boleto DDA aprovado a partir da notificação (${event.bankName})'
            : 'Aprovado a partir da notificação',
      );
      await financeProvider.addTransaction(tx);
      event.createdTransactionId = tx.id;
    }

    event.status = NotificationStatus.approved;
    _notifications[index] = event;

    await _persist();
    notifyListeners();
  }

  Future<void> approveAsIncome(
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
        title: 'Pix Recebido - $merchant',
        amount: amount,
        date: event.timestamp,
        type: TransactionType.income,
        category: customCategory ?? 'Outros',
        bank: event.bankName,
        source: TransactionSource.notification,
        notes: 'Pix aprovado como receita comum (não vinculado a devedor)',
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

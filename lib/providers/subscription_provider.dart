import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import 'debt_provider.dart';

class DetectedSubscriptionInfo {
  final String cleanName;
  final String category;

  const DetectedSubscriptionInfo({
    required this.cleanName,
    required this.category,
  });
}

class SubscriptionProvider extends ChangeNotifier {
  static const String _storageKey = 'financial_subscriptions_v1';
  static const String _dismissedKey = 'financial_subscriptions_dismissed_v1';

  List<SubscriptionModel> _subscriptions = [];
  Set<String> _dismissedSignatures = {};

  List<SubscriptionModel> get subscriptions => _subscriptions;
  List<SubscriptionModel> get activeSubscriptions =>
      _subscriptions.where((s) => s.isActive).toList();
  List<SubscriptionModel> get pausedSubscriptions =>
      _subscriptions.where((s) => !s.isActive).toList();
  List<SubscriptionModel> get sharedSubscriptions =>
      activeSubscriptions.where((s) => s.isShared).toList();

  /// Quanto realmente sai do bolso do titular por mês (descontando divisões como Crunchyroll)
  double get totalMonthlyCost =>
      activeSubscriptions.fold(0.0, (s, sub) => s + sub.effectiveMyCost);

  /// Valor bruto total nas faturas (incluindo parte de terceiros)
  double get totalGrossMonthlyCost =>
      activeSubscriptions.fold(0.0, (s, sub) => s + sub.amount);

  /// Quanto terceiros pagam nas assinaturas divididas (ex: R$ 20,00 do Sergio Lucas no Crunchyroll)
  double get totalSharedThirdPartyCost =>
      activeSubscriptions.fold(0.0, (s, sub) => s + sub.thirdPartyShare);

  double get totalPausedMonthlyCost =>
      pausedSubscriptions.fold(0.0, (s, sub) => s + sub.effectiveMyCost);

  double get totalAnnualCost => totalMonthlyCost * 12;

  /// Detects if a transaction is a recurring subscription/streaming/club/plan
  static DetectedSubscriptionInfo? detectSubscription(TransactionModel tx) {
    if (tx.type != TransactionType.expense) return null;
    final raw = tx.title.trim();
    final lower = raw.toLowerCase();

    // Never classify Pix transfers, person-to-person transfers or credit card bill payments as subscriptions
    if (lower.contains('transferência') ||
        lower.contains('transferencia') ||
        lower.contains('pix') ||
        lower.contains('pagamento de fatura') ||
        lower.contains('fatura paga') ||
        lower.contains('parcela paga') ||
        lower.contains('claudete') ||
        lower.contains('sergio') ||
        lower.contains('clecio')) {
      return null;
    }

    // Ignore installment purchases (e.g. "Parcela 4/10") as those are finite installments, not recurring subscriptions
    if (lower.contains('parcela ') || tx.installmentRef != null) {
      return null;
    }

    // 1. Delivery & Mobility Clubs (distinguish from normal iFood order or Uber ride!)
    if (lower.contains('ifood club') || lower.contains('ifd*ifood club') || lower.contains('clube ifood')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'iFood Club',
        category: 'Clubes & Delivery',
      );
    }
    if (lower.contains('uber *one') ||
        lower.contains('uber one') ||
        (lower.contains('uber') && lower.contains('membership'))) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Uber One',
        category: 'Clubes & Mobilidade',
      );
    }
    if (lower.contains('rappi prime') || lower.contains('meli+') || lower.contains('meli mais')) {
      return DetectedSubscriptionInfo(
        cleanName: lower.contains('rappi') ? 'Rappi Prime' : 'Meli+ (Mercado Livre)',
        category: 'Clubes & Delivery',
      );
    }

    // 2. Video & Music Streaming
    if (lower.contains('hbomax') || lower.contains('helphbomax') || lower.contains('hbo max') || lower == 'max') {
      return const DetectedSubscriptionInfo(
        cleanName: 'Max (HBO Max)',
        category: 'Streaming',
      );
    }
    if (lower.contains('crunchyro') || lower.contains('crunchyroll')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Crunchyroll',
        category: 'Streaming',
      );
    }
    if (lower.contains('netflix')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Netflix',
        category: 'Streaming',
      );
    }
    if (lower.contains('spotify')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Spotify',
        category: 'Streaming de Música',
      );
    }
    if (lower.contains('disney') || lower.contains('star+')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Disney+',
        category: 'Streaming',
      );
    }
    if (lower.contains('prime video') || lower.contains('amazon prime')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Amazon Prime',
        category: 'Streaming & Clubes',
      );
    }
    if (lower.contains('globoplay')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Globoplay',
        category: 'Streaming',
      );
    }
    if (lower.contains('deezer') || lower.contains('apple music') || lower.contains('paramount')) {
      return DetectedSubscriptionInfo(
        cleanName: raw,
        category: 'Streaming',
      );
    }

    // 3. Google Play / YouTube / Lightroom / Cloud Subscriptions
    if (lower.contains('dl*google lightr') || lower.contains('lightroom') || lower.contains('adobe')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Adobe Lightroom (Google Play)',
        category: 'Apps & Software',
      );
    }
    if (lower.contains('dl*google youtube') || lower.contains('youtube premium')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'YouTube Premium',
        category: 'Streaming',
      );
    }
    if (lower.contains('dl*google') || lower.contains('google one') || lower.contains('google play')) {
      if ((tx.amount - 35.99).abs() < 1.0 || (tx.amount - 24.90).abs() < 1.0 || (tx.amount - 41.90).abs() < 1.0) {
        return const DetectedSubscriptionInfo(
          cleanName: 'YouTube Premium (Google)',
          category: 'Streaming',
        );
      }
      return const DetectedSubscriptionInfo(
        cleanName: 'Google One (Armazenamento)',
        category: 'Apps & Nuvem',
      );
    }
    if (lower.contains('apple.com/bill') || lower.contains('icloud')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Apple / iCloud+',
        category: 'Apps & Nuvem',
      );
    }

    // 4. Career, AI & Productivity Software
    if (lower.contains('linkedin')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'LinkedIn Premium',
        category: 'Profissional & Software',
      );
    }
    if (lower.contains('chatgpt') || lower.contains('openai') || lower.contains('claude') || lower.contains('canva') || lower.contains('microsoft 365')) {
      return DetectedSubscriptionInfo(
        cleanName: raw,
        category: 'Profissional & Software',
      );
    }

    // 5. Gym, Fitness & Health Plans
    if (lower.contains('total pass') || lower.contains('totalpass')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'TotalPass (Academia)',
        category: 'Saúde & Academia',
      );
    }
    if (lower.contains('gympass') || lower.contains('wellhub') || lower.contains('smart fit') || lower.contains('smartfit')) {
      return DetectedSubscriptionInfo(
        cleanName: lower.contains('smart') ? 'Smart Fit' : 'Wellhub (Gympass)',
        category: 'Saúde & Academia',
      );
    }
    if (lower.contains('odontoart') || lower.contains('planos o') || lower.contains('plano odonto')) {
      return const DetectedSubscriptionInfo(
        cleanName: 'Odontoart (Plano Odontológico)',
        category: 'Saúde & Planos',
      );
    }

    // 6. Telecom & Internet Plans
    if (lower.contains('tim pos') || lower.contains('tim controle') || lower.contains('tim s.a') || lower.contains('vivo movel') || lower.contains('claro movel') || lower.contains('brisanet')) {
      final clean = lower.contains('tim pos')
          ? 'TIM Pós (Plano Celular)'
          : (lower.contains('tim') ? 'Plano TIM' : raw);
      return DetectedSubscriptionInfo(
        cleanName: clean,
        category: 'Telefonia & Internet',
      );
    }

    return null;
  }

  static String _signatureFor(String cleanName, double amount) {
    return '${cleanName.toLowerCase().trim()}_${amount.toStringAsFixed(2)}';
  }

  Future<void> init() async {
    final rawDismissed = await StorageService.getStoredData(_dismissedKey);
    if (rawDismissed != null && rawDismissed.isNotEmpty) {
      try {
        final List<dynamic> dList = jsonDecode(rawDismissed);
        _dismissedSignatures = dList.map((e) => e.toString()).toSet();
      } catch (_) {
        _dismissedSignatures = {};
      }
    }

    final raw = await StorageService.getStoredData(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        _subscriptions = list
            .map((item) => SubscriptionModel.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        _subscriptions = [];
      }
    } else {
      _subscriptions = [];
      await _persist(syncCloud: false);
    }
    // Remove legacy fake subscriptions or invalid transfer detections (e.g. Pix to relatives or duplicate Google entries)
    bool cleaned = false;
    final validSubs = <SubscriptionModel>[];
    final seenNames = <String>{};

    for (final s in _subscriptions) {
      final lower = s.name.toLowerCase();
      // Remove transfers incorrectly classified as subscriptions (including encoding variations)
      if (lower.contains('claudete') ||
          lower.contains('transfer') ||
          lower.contains('pix') ||
          lower.contains('fatura paga') ||
          lower.contains('pagamento') ||
          lower.contains('ted') ||
          lower.contains('doc')) {
        cleaned = true;
        continue;
      }

      // Normalize and unify all Google One entries
      String normalizedName = s.name;
      if (lower.contains('google one') || lower.contains('google play / google one')) {
        normalizedName = 'Google One (Armazenamento)';
      }

      final key = normalizedName.toLowerCase().trim();
      if (seenNames.contains(key)) {
        cleaned = true;
        continue;
      }
      seenNames.add(key);

      if (normalizedName != s.name) {
        cleaned = true;
        validSubs.add(s.copyWith(name: normalizedName, billingDay: 14));
      } else {
        validSubs.add(s);
      }
    }

    if (cleaned) {
      _subscriptions = validSubs;
    }

    // Ensure Crunchyroll default split (Denison pays R$ 4,90; Sergio Lucas pays the rest R$ 20,00)
    bool updatedSplit = false;
    for (final sub in _subscriptions) {
      if (sub.name.toLowerCase().contains('crunchyroll') && (sub.myShareAmount == null || sub.sharedWithPerson == null)) {
        sub.myShareAmount = 4.90;
        sub.sharedWithPerson = 'Sergio Lucas';
        updatedSplit = true;
      }
    }
    if (cleaned || updatedSplit) {
      await _persist();
    }
    notifyListeners();
  }

  /// Automatically recognizes and adds recurring subscriptions from transactions
  Future<int> syncFromTransactions(
    List<TransactionModel> transactions, {
    bool ignoreDismissed = false,
    DebtProvider? debtProvider,
  }) async {
    int addedCount = 0;

    for (final tx in transactions) {
      final detected = detectSubscription(tx);
      if (detected == null) continue;

      final sig = _signatureFor(detected.cleanName, tx.amount);
      if (!ignoreDismissed && _dismissedSignatures.contains(sig)) {
        continue;
      }

      // Check if already exists by signature (same clean name & similar amount, or same source title + amount)
      final existingIndex = _subscriptions.indexWhere((s) =>
          s.name.toLowerCase() == detected.cleanName.toLowerCase() ||
          (s.sourceTransactionTitle != null &&
              s.sourceTransactionTitle!.toLowerCase() == tx.title.toLowerCase() &&
              (s.amount - tx.amount).abs() < 0.05));

      final isCrunchyroll = detected.cleanName.toLowerCase().contains('crunchyroll');

      if (existingIndex == -1) {
        _subscriptions.add(
          SubscriptionModel(
            name: detected.cleanName,
            amount: tx.amount,
            billingDay: tx.date.day,
            category: detected.category,
            bank: tx.bank,
            sourceTransactionTitle: tx.title,
            myShareAmount: isCrunchyroll ? 4.90 : null,
            sharedWithPerson: isCrunchyroll ? 'Sergio Lucas' : null,
            isActive: true,
          ),
        );
        addedCount++;
      } else if (isCrunchyroll && _subscriptions[existingIndex].myShareAmount == null) {
        _subscriptions[existingIndex].myShareAmount = 4.90;
        _subscriptions[existingIndex].sharedWithPerson = 'Sergio Lucas';
        addedCount++;
      }
    }

    if (debtProvider != null) {
      for (final sub in activeSubscriptions.where((s) => s.isShared)) {
        await debtProvider.syncSharedSubscriptionDebt(
          subscriptionName: sub.name,
          personName: sub.sharedWithPerson,
          thirdPartyAmount: sub.thirdPartyShare,
          billingDay: sub.billingDay,
        );
      }
    }

    // Auto-audit lapsed subscriptions: if charged in month retrasado but missing in month passado, deactivate
    await auditLapsedSubscriptions(transactions, debtProvider: debtProvider);

    if (addedCount > 0) {
      // Sort by billing day ascending
      _subscriptions.sort((a, b) => a.billingDay.compareTo(b.billingDay));
      await _persist();
      notifyListeners();
    }
    return addedCount;
  }

  /// Auditoria inteligente de ciclo de vida das assinaturas:
  /// 1. Pega a data exata da verificação (hoje = DateTime.now()).
  /// 2. Se já cobrou no mês atual: 100% Ativa!
  /// 3. Se cobrou no mês passado e o dia da cobrança (vencimento) deste mês ainda não passou
  ///    (ou hoje é o dia da cobrança), permanece ATIVA, pois ainda virá este mês.
  /// 4. Se cobrou mês passado mas o dia esperado já passou (com folga após o dia seguinte)
  ///    e não cobrou no mês atual: marca como Pausada.
  /// 5. Se não cobrou nem mês passado nem no mês atual: marca como Pausada.
  Future<List<String>> auditLapsedSubscriptions(
    List<TransactionModel> transactions, {
    DateTime? referenceDate,
    bool deleteInstead = false,
    DebtProvider? debtProvider,
  }) async {
    if (transactions.isEmpty || _subscriptions.isEmpty) return [];

    // A data de referência é estritamente o momento atual (hoje)
    final DateTime today = referenceDate ?? DateTime.now();
    final int currentYear = today.year;
    final int currentMonth = today.month;
    final int currentDay = today.day;

    // Mês passado real
    final int prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;
    final int prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;

    final affectedNames = <String>[];
    final remaining = <SubscriptionModel>[];
    bool changed = false;

    for (final sub in _subscriptions) {
      final matchingTxs = transactions.where((tx) {
        if (tx.type != TransactionType.expense) return false;
        final detected = detectSubscription(tx);
        final matchByName = detected != null && detected.cleanName.toLowerCase() == sub.name.toLowerCase();
        final matchByTitle = sub.sourceTransactionTitle != null &&
            tx.title.toLowerCase().contains(sub.sourceTransactionTitle!.toLowerCase());
        final matchDirect = tx.title.toLowerCase().contains(sub.name.toLowerCase());
        return matchByName || matchByTitle || matchDirect;
      }).toList();

      if (matchingTxs.isEmpty) {
        remaining.add(sub);
        continue;
      }

      DateTime? latestDate;
      for (final tx in matchingTxs) {
        if (latestDate == null || tx.date.isAfter(latestDate)) {
          latestDate = tx.date;
        }
      }

      // 1. Cobrança no mês corrente (atual)
      final hadInCurrentMonth = matchingTxs.any((tx) =>
          tx.date.year == currentYear && tx.date.month == currentMonth);

      // 2. Cobrança no mês passado
      final hadInPrevMonth = matchingTxs.any((tx) =>
          tx.date.year == prevYear && tx.date.month == prevMonth);

      // O dia esperado de cobrança: prioriza a data da última fatura real
      final int expectedDay = latestDate != null ? latestDate.day : sub.billingDay;

      bool shouldBeActive = true;
      String? reason;

      if (hadInCurrentMonth) {
        // Já cobrou neste mês corrente -> 100% Ativa!
        shouldBeActive = true;
        reason = null;
      } else if (hadInPrevMonth) {
        // Veio cobrando mês passado (ex: 14/10):
        // Se a data de cobrança neste mês ainda não passou (ou hoje é a data de cobrança),
        // esperamos até o dia seguinte antes de desativar!
        if (currentDay <= expectedDay) {
          // Ainda vai ser cobrada este mês! Ex: hoje é dia 10, cobrança prevista para dia 14
          shouldBeActive = true;
          reason = null;
        } else {
          // O dia esperado (ex: dia 1..9) já passou com folga e não houve cobrança neste mês
          shouldBeActive = false;
          reason = 'Não cobrada este mês (vencimento era dia $expectedDay)';
        }
      } else {
        // NÃO teve cobrança nem mês passado nem no mês atual:
        // Veio no mês retrasado ou antes, ou nunca cobrou recentemente -> Pausada
        shouldBeActive = false;
        final dateStr = latestDate != null
            ? '${latestDate.day.toString().padLeft(2, '0')}/${latestDate.month.toString().padLeft(2, '0')}/${latestDate.year}'
            : 'anteriormente';
        reason = 'Sem cobrança no mês passado (última em $dateStr)';
      }

      if (!shouldBeActive) {
        if (deleteInstead) {
          changed = true;
          affectedNames.add(sub.name);
          continue;
        }

        if (sub.isActive || sub.inactiveReason != reason || sub.billingDay != expectedDay) {
          changed = true;
          affectedNames.add(sub.name);
        }

        remaining.add(
          sub.copyWith(
            isActive: false,
            billingDay: expectedDay,
            lastChargeDate: latestDate,
            inactiveReason: reason,
          ),
        );
      } else {
        // Assinatura deve estar Ativa!
        if (!sub.isActive || sub.inactiveReason != null || sub.billingDay != expectedDay) {
          changed = true;
        }
        remaining.add(
          sub.copyWith(
            isActive: true,
            billingDay: expectedDay,
            lastChargeDate: latestDate,
            inactiveReason: null,
          ),
        );
      }
    }

    if (changed) {
      _subscriptions = remaining;
      await _persist();
      notifyListeners();
    }
    return affectedNames;
  }

  /// Remove definitivamente todas as assinaturas que estão inativas / pausadas
  Future<int> purgeInactiveSubscriptions() async {
    final count = _subscriptions.where((s) => !s.isActive).length;
    if (count > 0) {
      _subscriptions.removeWhere((s) => !s.isActive);
      await _persist();
      notifyListeners();
    }
    return count;
  }

  /// Updates or clears the split (divisão de conta) for a subscription
  Future<void> updateSubscriptionSplit({
    required String id,
    double? myShareAmount,
    String? sharedWithPerson,
    DebtProvider? debtProvider,
    bool syncToDebts = true,
  }) async {
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final sub = _subscriptions[index];
    sub.myShareAmount = myShareAmount;
    sub.sharedWithPerson = (sharedWithPerson != null && sharedWithPerson.trim().isNotEmpty)
        ? sharedWithPerson.trim()
        : null;

    await _persist();
    notifyListeners();

    if (debtProvider != null && syncToDebts) {
      await debtProvider.syncSharedSubscriptionDebt(
        subscriptionName: sub.name,
        personName: sub.isShared ? sub.sharedWithPerson : null,
        thirdPartyAmount: sub.thirdPartyShare,
        billingDay: sub.billingDay,
      );
    }
  }

  Future<void> clearSubscriptions() async {
    _subscriptions = [];
    _dismissedSignatures = {};
    await StorageService.setStoredData(_dismissedKey, jsonEncode([]));
    await _persist();
    notifyListeners();
  }

  Future<void> toggleSubscription(String id) async {
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _subscriptions[index].isActive = !_subscriptions[index].isActive;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> addSubscription(SubscriptionModel sub) async {
    final sig = _signatureFor(sub.name, sub.amount);
    _dismissedSignatures.remove(sig);
    await StorageService.setStoredData(_dismissedKey, jsonEncode(_dismissedSignatures.toList()));
    _subscriptions.insert(0, sub);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteSubscription(String id) async {
    final existing = _subscriptions.where((s) => s.id == id).firstOrNull;
    if (existing != null) {
      final sig = _signatureFor(existing.name, existing.amount);
      _dismissedSignatures.add(sig);
      await StorageService.setStoredData(_dismissedKey, jsonEncode(_dismissedSignatures.toList()));
    }
    _subscriptions.removeWhere((s) => s.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist({bool syncCloud = true}) async {
    final list = _subscriptions.map((s) => s.toMap()).toList();
    await StorageService.setStoredData(_storageKey, jsonEncode(list));
    if (syncCloud) {
      FirebaseService().triggerSync();
    }
  }
}

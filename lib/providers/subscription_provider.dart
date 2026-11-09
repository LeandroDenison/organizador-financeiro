import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../services/storage_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  static const String _storageKey = 'financial_subscriptions_v1';
  List<SubscriptionModel> _subscriptions = [];

  List<SubscriptionModel> get subscriptions => _subscriptions;
  List<SubscriptionModel> get activeSubscriptions =>
      _subscriptions.where((s) => s.isActive).toList();

  double get totalMonthlyCost =>
      activeSubscriptions.fold(0.0, (s, sub) => s + sub.amount);

  double get totalAnnualCost => totalMonthlyCost * 12;

  Future<void> init() async {
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
      await _persist();
    }
    // Remove legacy fake subscriptions
    final hasFakes = _subscriptions.any((s) => s.name == 'Netflix Premium' && s.amount == 55.90);
    if (hasFakes) {
      _subscriptions = [];
      await _persist();
    }
    notifyListeners();
  }

  Future<void> clearSubscriptions() async {
    _subscriptions = [];
    await _persist();
    notifyListeners();
  }

  void _loadDefaults() {
    _subscriptions = [
      SubscriptionModel(
        name: 'Netflix Premium',
        amount: 55.90,
        billingDay: 10,
        bank: 'Nubank',
      ),
      SubscriptionModel(
        name: 'Spotify Familiar',
        amount: 34.90,
        billingDay: 15,
        bank: 'Nubank',
      ),
      SubscriptionModel(
        name: 'Academia',
        amount: 119.90,
        billingDay: 5,
        bank: 'Itaú',
      ),
      SubscriptionModel(
        name: 'Amazon Prime',
        amount: 19.90,
        billingDay: 20,
        bank: 'Mercado Pago',
      ),
    ];
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
    _subscriptions.insert(0, sub);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final list = _subscriptions.map((s) => s.toMap()).toList();
    await StorageService.setStoredData(_storageKey, jsonEncode(list));
  }
}

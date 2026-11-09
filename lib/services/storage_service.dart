import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/debt_model.dart';
import '../models/notification_event_model.dart';

class StorageService {
  static const String _transactionsKey = 'financial_transactions_v1';
  static const String _debtsKey = 'financial_debts_v1';
  static const String _notificationsKey = 'financial_notifications_v1';
  static const String _autoAddNotificationKey = 'config_auto_add_notification';
  static const String _firebaseConfigKey = 'config_firebase_credentials';

  static Future<List<TransactionModel>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_transactionsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((item) => TransactionModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTransactions(List<TransactionModel> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final list = transactions.map((t) => t.toMap()).toList();
    await prefs.setString(_transactionsKey, jsonEncode(list));
  }

  static Future<List<DebtModel>> loadDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_debtsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((item) => DebtModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveDebts(List<DebtModel> debts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = debts.map((d) => d.toMap()).toList();
    await prefs.setString(_debtsKey, jsonEncode(list));
  }

  static Future<List<NotificationEventModel>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_notificationsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((item) => NotificationEventModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveNotifications(List<NotificationEventModel> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final list = notifications.map((n) => n.toMap()).toList();
    await prefs.setString(_notificationsKey, jsonEncode(list));
  }

  static Future<bool> isAutoAddNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoAddNotificationKey) ?? true;
  }

  static Future<void> setAutoAddNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAddNotificationKey, enabled);
  }

  static Future<String?> getFirebaseProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_firebaseConfigKey);
  }

  static Future<void> setFirebaseProjectId(String? projectId) async {
    final prefs = await SharedPreferences.getInstance();
    if (projectId == null || projectId.isEmpty) {
      await prefs.remove(_firebaseConfigKey);
    } else {
      await prefs.setString(_firebaseConfigKey, projectId);
    }
  }

  static Future<String> getUserPixKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_pix_key') ?? '11987654321';
  }

  static Future<void> setUserPixKey(String pixKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pix_key', pixKey);
  }

  static Future<String?> getStoredData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> setStoredData(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

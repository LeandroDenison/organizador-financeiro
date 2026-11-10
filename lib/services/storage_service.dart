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
    return prefs.getString('user_pix_key') ?? '';
  }

  static Future<void> setUserPixKey(String pixKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pix_key', pixKey);
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_pix_name') ?? 'LEANDRO DENISON';
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pix_name', name);
  }

  static Future<String> getUserCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_pix_city') ?? 'BRASILIA';
  }

  static Future<void> setUserCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pix_city', city);
  }

  static Future<String?> getStoredData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> setStoredData(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// Limpa todos os dados falsos e transações armazenadas, resetando a base de dados
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transactionsKey);
    await prefs.remove(_debtsKey);
    await prefs.remove(_notificationsKey);
    await prefs.remove('financial_savings_goals_v1');
    await prefs.remove('financial_subscriptions_v1');
    await prefs.remove('financial_budgets_v1');
    await prefs.setBool('clean_real_data_v1', true);
  }

  static Future<bool> hasCleanedFakeData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('clean_real_data_v1') ?? false;
  }

  static Future<void> markFakeDataCleaned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clean_real_data_v1', true);
  }

  /// Exports all app state (transactions, debts, savings, subscriptions, budgets, pix config) into a single JSON string
  static Future<String> exportFullBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'projectId': prefs.getString(_firebaseConfigKey) ?? 'organizador-financeiro-d77b4',
      'driveFolders': {
        'root': '1pRtJIwSE7_YEmAkoosnIdc-zYNO3PBW2',
        'pdfs': '1D8OZczH_kSg9YdOwRsw6SjkG17Wmb7JC',
        'backups': '1pdakzzI9FxXu9lLXMgrZNm-hhdxmKxM0',
      },
      'transactions': jsonDecode(prefs.getString(_transactionsKey) ?? '[]'),
      'debts': jsonDecode(prefs.getString(_debtsKey) ?? '[]'),
      'savings_goals': jsonDecode(prefs.getString('financial_savings_goals_v1') ?? '[]'),
      'subscriptions': jsonDecode(prefs.getString('financial_subscriptions_v1') ?? '[]'),
      'budgets': jsonDecode(prefs.getString('financial_budgets_v1') ?? '[]'),
      'pix': {
        'key': prefs.getString('user_pix_key') ?? '',
        'name': prefs.getString('user_pix_name') ?? 'LEANDRO DENISON',
        'city': prefs.getString('user_pix_city') ?? 'FORTALEZA',
      },
      'open_finance_bank_balances_v1': prefs.getString('open_finance_bank_balances_v1') ?? '[]',
      'open_finance_pluggy_config_v2': prefs.getString('open_finance_pluggy_config_v2') ?? '',
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Restores all app state from a full backup JSON string
  static Future<bool> importFullBackupJson(String jsonStr) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      if (data['transactions'] is List) {
        await prefs.setString(_transactionsKey, jsonEncode(data['transactions']));
      }
      if (data['debts'] is List) {
        await prefs.setString(_debtsKey, jsonEncode(data['debts']));
      }
      if (data['savings_goals'] is List) {
        await prefs.setString('financial_savings_goals_v1', jsonEncode(data['savings_goals']));
      }
      if (data['subscriptions'] is List) {
        await prefs.setString('financial_subscriptions_v1', jsonEncode(data['subscriptions']));
      }
      if (data['budgets'] is List) {
        await prefs.setString('financial_budgets_v1', jsonEncode(data['budgets']));
      }
      if (data['open_finance_bank_balances_v1'] != null) {
        final val = data['open_finance_bank_balances_v1'];
        await prefs.setString('open_finance_bank_balances_v1', val is String ? val : jsonEncode(val));
      }
      if (data['open_finance_pluggy_config_v2'] != null) {
        final val = data['open_finance_pluggy_config_v2'];
        await prefs.setString('open_finance_pluggy_config_v2', val is String ? val : jsonEncode(val));
      }
      if (data['pix'] is Map) {
        final pix = data['pix'] as Map;
        if (pix['key'] != null) await prefs.setString('user_pix_key', pix['key'].toString());
        if (pix['name'] != null) await prefs.setString('user_pix_name', pix['name'].toString());
        if (pix['city'] != null) await prefs.setString('user_pix_city', pix['city'].toString());
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

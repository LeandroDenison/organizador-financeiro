import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/savings_goal_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

class SavingsProvider extends ChangeNotifier {
  static const String _storageKey = 'financial_savings_goals_v1';
  List<SavingsGoalModel> _goals = [];

  List<SavingsGoalModel> get goals => _goals;

  double get totalSaved => _goals.fold(0.0, (s, g) => s + g.currentAmount);
  double get totalTarget => _goals.fold(0.0, (s, g) => s + g.targetAmount);

  Future<void> init() async {
    final raw = await StorageService.getStoredData(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        _goals = list
            .map((item) => SavingsGoalModel.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        _goals = [];
      }
    } else {
      _goals = [];
      await _persist(syncCloud: false);
    }
    // Remove legacy fake goals if existing
    final hasFakes = _goals.any((g) => g.title == 'Reserva de Emergência' && g.currentAmount == 1850.0);
    if (hasFakes) {
      _goals = [];
      await _persist(syncCloud: false);
    }
    notifyListeners();
  }

  Future<void> clearGoals() async {
    _goals = [];
    await _persist();
    notifyListeners();
  }

  Future<void> addGoal(SavingsGoalModel goal) async {
    _goals.insert(0, goal);
    await _persist();
    notifyListeners();
  }

  Future<void> deposit(String id, double amount) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index != -1) {
      _goals[index].currentAmount += amount;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> withdraw(String id, double amount) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index != -1) {
      final current = _goals[index].currentAmount;
      _goals[index].currentAmount = (current - amount).clamp(0.0, double.infinity);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist({bool syncCloud = true}) async {
    final list = _goals.map((g) => g.toMap()).toList();
    await StorageService.setStoredData(_storageKey, jsonEncode(list));
    if (syncCloud) {
      FirebaseService().triggerSync();
    }
  }
}

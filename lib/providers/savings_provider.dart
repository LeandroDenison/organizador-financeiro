import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/savings_goal_model.dart';
import '../services/storage_service.dart';

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
        _loadDefaults();
      }
    } else {
      _loadDefaults();
      await _persist();
    }
    notifyListeners();
  }

  void _loadDefaults() {
    _goals = [
      SavingsGoalModel(
        title: 'Reserva de Emergência',
        targetAmount: 5000.0,
        currentAmount: 1850.0,
        iconName: 'security',
        colorValue: 0xFF10B981, // Emerald
      ),
      SavingsGoalModel(
        title: 'Troca de Celular',
        targetAmount: 3500.0,
        currentAmount: 1400.0,
        iconName: 'phone',
        colorValue: 0xFF6366F1, // Indigo
      ),
      SavingsGoalModel(
        title: 'Viagem de Férias',
        targetAmount: 2500.0,
        currentAmount: 600.0,
        iconName: 'flight',
        colorValue: 0xFFF59E0B, // Amber
      ),
    ];
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

  Future<void> _persist() async {
    final list = _goals.map((g) => g.toMap()).toList();
    await StorageService.setStoredData(_storageKey, jsonEncode(list));
  }
}

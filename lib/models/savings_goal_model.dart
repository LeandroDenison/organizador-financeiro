import 'package:uuid/uuid.dart';

class SavingsGoalModel {
  final String id;
  final String title;
  final double targetAmount;
  double currentAmount;
  final DateTime? targetDate;
  final String iconName;
  final int colorValue;

  SavingsGoalModel({
    String? id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    this.iconName = 'savings',
    this.colorValue = 0xFF6366F1,
  }) : id = id ?? const Uuid().v4();

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 1.0;

  double get remainingAmount =>
      (targetAmount - currentAmount) > 0 ? (targetAmount - currentAmount) : 0.0;

  bool get isCompleted => currentAmount >= targetAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': targetDate?.toIso8601String(),
        'iconName': iconName,
        'colorValue': colorValue,
      };

  factory SavingsGoalModel.fromMap(Map<String, dynamic> map) {
    return SavingsGoalModel(
      id: map['id'] as String?,
      title: map['title'] as String? ?? 'Meta',
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 1000.0,
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['targetDate'] != null
          ? DateTime.tryParse(map['targetDate'] as String)
          : null,
      iconName: map['iconName'] as String? ?? 'savings',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF6366F1,
    );
  }
}

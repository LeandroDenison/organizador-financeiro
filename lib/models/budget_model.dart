class BudgetModel {
  final String category;
  double monthlyLimit;

  BudgetModel({
    required this.category,
    required this.monthlyLimit,
  });

  Map<String, dynamic> toMap() => {
        'category': category,
        'monthlyLimit': monthlyLimit,
      };

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      category: map['category'] as String? ?? 'Geral',
      monthlyLimit: (map['monthlyLimit'] as num?)?.toDouble() ?? 500.0,
    );
  }
}

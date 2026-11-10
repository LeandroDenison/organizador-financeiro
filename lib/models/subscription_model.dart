import 'package:uuid/uuid.dart';

class SubscriptionModel {
  final String id;
  final String name;
  final double amount;
  final int billingDay;
  final String category;
  final String? bank;
  final String? sourceTransactionTitle;
  bool isActive;

  SubscriptionModel({
    String? id,
    required this.name,
    required this.amount,
    this.billingDay = 1,
    this.category = 'Assinaturas',
    this.bank,
    this.sourceTransactionTitle,
    this.isActive = true,
  }) : id = id ?? const Uuid().v4();

  double get annualAmount => amount * 12;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'billingDay': billingDay,
        'category': category,
        'bank': bank,
        'sourceTransactionTitle': sourceTransactionTitle,
        'isActive': isActive,
      };

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionModel(
      id: map['id'] as String?,
      name: map['name'] as String? ?? 'Assinatura',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      billingDay: (map['billingDay'] as num?)?.toInt() ?? 1,
      category: map['category'] as String? ?? 'Assinaturas',
      bank: map['bank'] as String?,
      sourceTransactionTitle: map['sourceTransactionTitle'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

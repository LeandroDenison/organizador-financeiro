import 'package:uuid/uuid.dart';

class SubscriptionModel {
  final String id;
  final String name;
  final double amount;
  final int billingDay;
  final String category;
  final String? bank;
  final String? sourceTransactionTitle;
  double? myShareAmount;
  String? sharedWithPerson;
  bool isActive;

  SubscriptionModel({
    String? id,
    required this.name,
    required this.amount,
    this.billingDay = 1,
    this.category = 'Assinaturas',
    this.bank,
    this.sourceTransactionTitle,
    this.myShareAmount,
    this.sharedWithPerson,
    this.isActive = true,
  }) : id = id ?? const Uuid().v4();

  bool get isShared =>
      myShareAmount != null &&
      myShareAmount! >= 0 &&
      myShareAmount! < amount &&
      sharedWithPerson != null &&
      sharedWithPerson!.trim().isNotEmpty;

  /// Quanto realmente sai do bolso do titular
  double get effectiveMyCost => isShared ? myShareAmount! : amount;

  /// Quanto a outra pessoa paga na divisão
  double get thirdPartyShare => isShared ? (amount - myShareAmount!) : 0.0;

  double get annualAmount => effectiveMyCost * 12;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'billingDay': billingDay,
        'category': category,
        'bank': bank,
        'sourceTransactionTitle': sourceTransactionTitle,
        'myShareAmount': myShareAmount,
        'sharedWithPerson': sharedWithPerson,
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
      myShareAmount: (map['myShareAmount'] as num?)?.toDouble(),
      sharedWithPerson: map['sharedWithPerson'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

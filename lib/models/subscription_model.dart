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
  final DateTime? lastChargeDate;
  final String? inactiveReason;

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
    this.lastChargeDate,
    this.inactiveReason,
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

  SubscriptionModel copyWith({
    String? id,
    String? name,
    double? amount,
    int? billingDay,
    String? category,
    String? bank,
    String? sourceTransactionTitle,
    double? myShareAmount,
    String? sharedWithPerson,
    bool? isActive,
    DateTime? lastChargeDate,
    String? inactiveReason,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      billingDay: billingDay ?? this.billingDay,
      category: category ?? this.category,
      bank: bank ?? this.bank,
      sourceTransactionTitle: sourceTransactionTitle ?? this.sourceTransactionTitle,
      myShareAmount: myShareAmount ?? this.myShareAmount,
      sharedWithPerson: sharedWithPerson ?? this.sharedWithPerson,
      isActive: isActive ?? this.isActive,
      lastChargeDate: lastChargeDate ?? this.lastChargeDate,
      inactiveReason: inactiveReason ?? this.inactiveReason,
    );
  }

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
        'lastChargeDate': lastChargeDate?.toIso8601String(),
        'inactiveReason': inactiveReason,
      };

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedLastDate;
    if (map['lastChargeDate'] != null) {
      parsedLastDate = DateTime.tryParse(map['lastChargeDate'].toString());
    }

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
      lastChargeDate: parsedLastDate,
      inactiveReason: map['inactiveReason'] as String?,
    );
  }
}

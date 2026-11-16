import 'package:uuid/uuid.dart';

enum PayableType {
  creditCard,
  boletoDDA,
  subscription,
  loan,
  manual,
}

class PayableModel {
  final String id;
  final String title;
  final double totalAmount;
  final double myShareAmount;
  final double debtorShareAmount;
  final double debtorPaidAmount;
  final DateTime dueDate;
  final int dueDay;
  final String category;
  final String? bank;
  final PayableType type;
  final bool isPaid;
  final DateTime? paidDate;
  final bool isRecurring;
  final String? notes;
  final bool isAutoDetected;
  final String? externalRefId;

  PayableModel({
    String? id,
    required this.title,
    required this.totalAmount,
    double? myShareAmount,
    this.debtorShareAmount = 0.0,
    this.debtorPaidAmount = 0.0,
    required this.dueDate,
    int? dueDay,
    required this.category,
    this.bank,
    required this.type,
    this.isPaid = false,
    this.paidDate,
    this.isRecurring = false,
    this.notes,
    this.isAutoDetected = false,
    this.externalRefId,
  })  : id = id ?? const Uuid().v4(),
        myShareAmount = myShareAmount ?? (totalAmount - debtorShareAmount),
        dueDay = dueDay ?? dueDate.day;

  double get debtorPendingAmount {
    final pending = debtorShareAmount - debtorPaidAmount;
    return pending > 0 ? pending : 0.0;
  }

  double get netOutflowAmount {
    // Valor que sai do bolso do usuário hoje
    final val = totalAmount - debtorPaidAmount;
    return val > 0 ? val : 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'totalAmount': totalAmount,
      'myShareAmount': myShareAmount,
      'debtorShareAmount': debtorShareAmount,
      'debtorPaidAmount': debtorPaidAmount,
      'dueDate': dueDate.toIso8601String(),
      'dueDay': dueDay,
      'category': category,
      'bank': bank,
      'type': type.name,
      'isPaid': isPaid,
      'paidDate': paidDate?.toIso8601String(),
      'isRecurring': isRecurring,
      'notes': notes,
      'isAutoDetected': isAutoDetected,
      'externalRefId': externalRefId,
    };
  }

  factory PayableModel.fromMap(Map<String, dynamic> map) {
    final due = map['dueDate'] != null
        ? DateTime.tryParse(map['dueDate'] as String) ?? DateTime.now()
        : DateTime.now();

    return PayableModel(
      id: map['id'] as String?,
      title: map['title'] as String? ?? 'Conta',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      myShareAmount: (map['myShareAmount'] as num?)?.toDouble(),
      debtorShareAmount: (map['debtorShareAmount'] as num?)?.toDouble() ?? 0.0,
      debtorPaidAmount: (map['debtorPaidAmount'] as num?)?.toDouble() ?? 0.0,
      dueDate: due,
      dueDay: (map['dueDay'] as num?)?.toInt() ?? due.day,
      category: map['category'] as String? ?? 'Outros',
      bank: map['bank'] as String?,
      type: PayableType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PayableType.manual,
      ),
      isPaid: map['isPaid'] as bool? ?? false,
      paidDate: map['paidDate'] != null
          ? DateTime.tryParse(map['paidDate'] as String)
          : null,
      isRecurring: map['isRecurring'] as bool? ?? false,
      notes: map['notes'] as String?,
      isAutoDetected: map['isAutoDetected'] as bool? ?? false,
      externalRefId: map['externalRefId'] as String?,
    );
  }

  PayableModel copyWith({
    String? id,
    String? title,
    double? totalAmount,
    double? myShareAmount,
    double? debtorShareAmount,
    double? debtorPaidAmount,
    DateTime? dueDate,
    int? dueDay,
    String? category,
    String? bank,
    PayableType? type,
    bool? isPaid,
    DateTime? paidDate,
    bool? isRecurring,
    String? notes,
    bool? isAutoDetected,
    String? externalRefId,
  }) {
    return PayableModel(
      id: id ?? this.id,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      myShareAmount: myShareAmount ?? this.myShareAmount,
      debtorShareAmount: debtorShareAmount ?? this.debtorShareAmount,
      debtorPaidAmount: debtorPaidAmount ?? this.debtorPaidAmount,
      dueDate: dueDate ?? this.dueDate,
      dueDay: dueDay ?? this.dueDay,
      category: category ?? this.category,
      bank: bank ?? this.bank,
      type: type ?? this.type,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      isRecurring: isRecurring ?? this.isRecurring,
      notes: notes ?? this.notes,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
      externalRefId: externalRefId ?? this.externalRefId,
    );
  }
}

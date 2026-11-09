import 'package:uuid/uuid.dart';

class DebtPaymentRecord {
  final String id;
  final DateTime date;
  final double amount;
  final int installmentNumber;
  final String? note;

  DebtPaymentRecord({
    String? id,
    required this.date,
    required this.amount,
    required this.installmentNumber,
    this.note,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'installmentNumber': installmentNumber,
        'note': note,
      };

  factory DebtPaymentRecord.fromMap(Map<String, dynamic> map) {
    return DebtPaymentRecord(
      id: map['id'] as String?,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      installmentNumber: (map['installmentNumber'] as num?)?.toInt() ?? 1,
      note: map['note'] as String?,
    );
  }
}

class DebtModel {
  final String id;
  final String personName;
  final String description;
  final String? contact; // Celular, Pix ou WhatsApp
  final double totalAmount;
  final int totalInstallments;
  final int remainingInstallments;
  final double installmentValue;
  final int dueDay; // Dia do mês (1 a 31)
  final DateTime createdAt;
  final bool isSettled; // Se já foi quitada
  final List<DebtPaymentRecord> paymentHistory;

  DebtModel({
    String? id,
    required this.personName,
    required this.description,
    this.contact,
    required this.totalAmount,
    required this.totalInstallments,
    required this.remainingInstallments,
    double? installmentValue,
    this.dueDay = 10,
    DateTime? createdAt,
    this.isSettled = false,
    List<DebtPaymentRecord>? paymentHistory,
  })  : id = id ?? const Uuid().v4(),
        installmentValue = installmentValue ??
            (totalInstallments > 0 ? (totalAmount / totalInstallments) : totalAmount),
        createdAt = createdAt ?? DateTime.now(),
        paymentHistory = paymentHistory ?? [];

  int get paidInstallments {
    if (installmentValue > 0) {
      return (paidAmount / installmentValue).floor().clamp(0, totalInstallments);
    }
    return totalInstallments - remainingInstallments;
  }

  double get paidAmount {
    if (paymentHistory.isNotEmpty) {
      return paymentHistory.fold(0.0, (sum, p) => sum + p.amount);
    }
    return totalAmount - (remainingInstallments * installmentValue);
  }

  double get remainingAmount {
    final rem = totalAmount - paidAmount;
    return rem > 0.01 ? rem : 0.0;
  }

  double get progress =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 1.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'description': description,
      'contact': contact,
      'totalAmount': totalAmount,
      'totalInstallments': totalInstallments,
      'remainingInstallments': remainingInstallments,
      'installmentValue': installmentValue,
      'dueDay': dueDay,
      'createdAt': createdAt.toIso8601String(),
      'isSettled': isSettled,
      'paymentHistory': paymentHistory.map((p) => p.toMap()).toList(),
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    final rawPayments = map['paymentHistory'] as List<dynamic>? ?? [];
    return DebtModel(
      id: map['id'] as String?,
      personName: map['personName'] as String? ?? 'Desconhecido',
      description: map['description'] as String? ?? 'Empréstimo',
      contact: map['contact'] as String?,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalInstallments: (map['totalInstallments'] as num?)?.toInt() ?? 1,
      remainingInstallments: (map['remainingInstallments'] as num?)?.toInt() ?? 1,
      installmentValue: (map['installmentValue'] as num?)?.toDouble(),
      dueDay: (map['dueDay'] as num?)?.toInt() ?? 10,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSettled: map['isSettled'] as bool? ?? false,
      paymentHistory: rawPayments
          .map((p) => DebtPaymentRecord.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }

  DebtModel copyWith({
    String? personName,
    String? description,
    String? contact,
    double? totalAmount,
    int? totalInstallments,
    int? remainingInstallments,
    double? installmentValue,
    int? dueDay,
    bool? isSettled,
    List<DebtPaymentRecord>? paymentHistory,
  }) {
    return DebtModel(
      id: id,
      personName: personName ?? this.personName,
      description: description ?? this.description,
      contact: contact ?? this.contact,
      totalAmount: totalAmount ?? this.totalAmount,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      remainingInstallments: remainingInstallments ?? this.remainingInstallments,
      installmentValue: installmentValue ?? this.installmentValue,
      dueDay: dueDay ?? this.dueDay,
      createdAt: createdAt,
      isSettled: isSettled ?? this.isSettled,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }
}

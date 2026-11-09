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

class ParsedInstallmentInfo {
  final int currentInstallment;
  final int totalInstallments;

  const ParsedInstallmentInfo({
    required this.currentInstallment,
    required this.totalInstallments,
  });

  /// How many installments remain including the current one on the invoice (e.g. 4/10 -> 7 remaining: 4,5,6,7,8,9,10)
  int get remainingIncludingCurrent =>
      (totalInstallments - currentInstallment + 1).clamp(1, totalInstallments);

  /// How many installments were already paid in previous invoices before this one (e.g. 4/10 -> 3 paid: 1,2,3)
  int get priorPaidInstallments =>
      (currentInstallment - 1).clamp(0, totalInstallments);
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
  final double? customRemainingAmount;
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
    this.customRemainingAmount,
    this.dueDay = 10,
    DateTime? createdAt,
    this.isSettled = false,
    List<DebtPaymentRecord>? paymentHistory,
  })  : id = id ?? const Uuid().v4(),
        installmentValue = installmentValue ??
            (totalInstallments > 0 ? (totalAmount / totalInstallments) : totalAmount),
        createdAt = createdAt ?? DateTime.now(),
        paymentHistory = paymentHistory ?? [];

  /// Extracts installment info (e.g. "Parcela 4/10", "Parc 1/2", "- 11/12") from a transaction title
  static ParsedInstallmentInfo? parseInstallmentInfo(String text) {
    if (text.isEmpty) return null;

    // 1. Explicit "Parcela X/Y" or "Parc X/Y" or "Parcela X de Y"
    final explicitRegex = RegExp(
      r'(?:parcela|parc\.?)\s*(\d{1,2})\s*(?:/|de)\s*(\d{1,2})\b',
      caseSensitive: false,
    );
    final explicitMatch = explicitRegex.firstMatch(text);
    if (explicitMatch != null) {
      final current = int.tryParse(explicitMatch.group(1)!) ?? 0;
      final total = int.tryParse(explicitMatch.group(2)!) ?? 0;
      if (current >= 1 && total > 1 && current <= total && total <= 72) {
        return ParsedInstallmentInfo(
          currentInstallment: current,
          totalInstallments: total,
        );
      }
    }

    // 2. Trailing "- X/Y" or "(X/Y)" pattern in card descriptions
    final trailingRegex = RegExp(r'(?:-\s*|\()(\d{1,2})\s*/\s*(\d{1,2})\)?\s*$');
    final trailingMatch = trailingRegex.firstMatch(text.trim());
    if (trailingMatch != null) {
      final current = int.tryParse(trailingMatch.group(1)!) ?? 0;
      final total = int.tryParse(trailingMatch.group(2)!) ?? 0;
      if (current >= 1 && total > 1 && current <= total && total <= 72) {
        return ParsedInstallmentInfo(
          currentInstallment: current,
          totalInstallments: total,
        );
      }
    }

    return null;
  }

  int get paidInstallments {
    return (totalInstallments - remainingInstallments).clamp(0, totalInstallments);
  }

  double get remainingAmount {
    if (isSettled || remainingInstallments <= 0) return 0.0;
    if (customRemainingAmount != null) {
      return customRemainingAmount!.clamp(0.0, totalAmount);
    }
    final calc = remainingInstallments * installmentValue;
    return calc > 0.01 ? calc.clamp(0.0, totalAmount) : 0.0;
  }

  double get paidAmount {
    final paid = totalAmount - remainingAmount;
    return paid > 0.01 ? paid.clamp(0.0, totalAmount) : 0.0;
  }

  /// Sum of payments explicitly recorded in the app's paymentHistory
  double get receivedInAppAmount {
    return paymentHistory.fold(0.0, (sum, p) => sum + p.amount);
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
      'customRemainingAmount': customRemainingAmount,
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
      customRemainingAmount: (map['customRemainingAmount'] as num?)?.toDouble(),
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
    double? customRemainingAmount,
    bool clearCustomRemainingAmount = false,
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
      customRemainingAmount: clearCustomRemainingAmount
          ? null
          : (customRemainingAmount ?? this.customRemainingAmount),
      dueDay: dueDay ?? this.dueDay,
      createdAt: createdAt,
      isSettled: isSettled ?? this.isSettled,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }
}

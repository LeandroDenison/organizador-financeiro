import 'package:uuid/uuid.dart';

class BankLoanModel {
  final String id;
  final String bankName; // Ex: 'Nubank', 'Itaú'
  final String productName; // Ex: 'Crédito Pessoal'
  final String contractNumber;
  final double contractAmount; // Valor contratado
  final double totalRemainingAmount; // Saldo devedor total
  final double installmentAmount; // Valor da parcela mensal
  final int totalInstallments; // Total de parcelas
  final int paidInstallments; // Parcelas pagas
  final int remainingInstallments; // Parcelas restantes
  final DateTime? firstDueDate;
  final DateTime? finalDueDate;
  final double? annualCet; // Custo Efetivo Total
  final bool isSettled;

  BankLoanModel({
    String? id,
    required this.bankName,
    required this.productName,
    required this.contractNumber,
    required this.contractAmount,
    required this.totalRemainingAmount,
    required this.installmentAmount,
    required this.totalInstallments,
    this.paidInstallments = 0,
    this.remainingInstallments = 0,
    this.firstDueDate,
    this.finalDueDate,
    this.annualCet,
    this.isSettled = false,
  }) : id = id ?? const Uuid().v4();

  double get progress => totalInstallments > 0
      ? (paidInstallments / totalInstallments).clamp(0.0, 1.0)
      : (isSettled ? 1.0 : 0.0);

  Map<String, dynamic> toMap() => {
        'id': id,
        'bankName': bankName,
        'productName': productName,
        'contractNumber': contractNumber,
        'contractAmount': contractAmount,
        'totalRemainingAmount': totalRemainingAmount,
        'installmentAmount': installmentAmount,
        'totalInstallments': totalInstallments,
        'paidInstallments': paidInstallments,
        'remainingInstallments': remainingInstallments,
        'firstDueDate': firstDueDate?.toIso8601String(),
        'finalDueDate': finalDueDate?.toIso8601String(),
        'annualCet': annualCet,
        'isSettled': isSettled,
      };

  factory BankLoanModel.fromMap(Map<String, dynamic> map) {
    return BankLoanModel(
      id: map['id']?.toString(),
      bankName: map['bankName']?.toString() ?? 'Banco',
      productName: map['productName']?.toString() ?? 'Empréstimo',
      contractNumber: map['contractNumber']?.toString() ?? '',
      contractAmount: (map['contractAmount'] as num?)?.toDouble() ?? 0.0,
      totalRemainingAmount: (map['totalRemainingAmount'] as num?)?.toDouble() ?? 0.0,
      installmentAmount: (map['installmentAmount'] as num?)?.toDouble() ?? 0.0,
      totalInstallments: (map['totalInstallments'] as num?)?.toInt() ?? 1,
      paidInstallments: (map['paidInstallments'] as num?)?.toInt() ?? 0,
      remainingInstallments: (map['remainingInstallments'] as num?)?.toInt() ?? 0,
      firstDueDate: map['firstDueDate'] != null ? DateTime.tryParse(map['firstDueDate'] as String) : null,
      finalDueDate: map['finalDueDate'] != null ? DateTime.tryParse(map['finalDueDate'] as String) : null,
      annualCet: (map['annualCet'] as num?)?.toDouble(),
      isSettled: map['isSettled'] as bool? ?? false,
    );
  }
}

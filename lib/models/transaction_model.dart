import 'package:uuid/uuid.dart';

enum TransactionType { income, expense }

enum TransactionSource { manual, ofx, csv, notification, pdf }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String category;
  final String? bank; // 'Nubank', 'Itaú', 'Mercado Pago', 'Outro'
  final TransactionSource source;
  final String? personId; // Se vinculado a um empréstimo/pessoa
  final String? personName;
  final String? installmentRef; // Ex: '2/5'
  final String? notes;

  TransactionModel({
    String? id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.bank,
    this.source = TransactionSource.manual,
    this.personId,
    this.personName,
    this.installmentRef,
    this.notes,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'category': category,
      'bank': bank,
      'source': source.name,
      'personId': personId,
      'personName': personName,
      'installmentRef': installmentRef,
      'notes': notes,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String?,
      title: map['title'] as String? ?? 'Sem título',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      type: map['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      category: map['category'] as String? ?? 'Geral',
      bank: map['bank'] as String?,
      source: TransactionSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => TransactionSource.manual,
      ),
      personId: map['personId'] as String?,
      personName: map['personName'] as String?,
      installmentRef: map['installmentRef'] as String?,
      notes: map['notes'] as String?,
    );
  }

  TransactionModel copyWith({
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? category,
    String? bank,
    TransactionSource? source,
    String? personId,
    String? personName,
    String? installmentRef,
    String? notes,
  }) {
    return TransactionModel(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      bank: bank ?? this.bank,
      source: source ?? this.source,
      personId: personId ?? this.personId,
      personName: personName ?? this.personName,
      installmentRef: installmentRef ?? this.installmentRef,
      notes: notes ?? this.notes,
    );
  }
}

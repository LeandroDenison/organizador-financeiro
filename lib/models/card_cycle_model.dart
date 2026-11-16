import 'package:flutter/material.dart';
import 'transaction_model.dart';
import 'subscription_model.dart';

class CardConfig {
  final String id;
  final String cardName;
  final String bank;
  final int closingDay;
  final int dueDay;
  final Color color;
  final IconData icon;

  const CardConfig({
    required this.id,
    required this.cardName,
    required this.bank,
    required this.closingDay,
    required this.dueDay,
    required this.color,
    this.icon = Icons.credit_card_rounded,
  });

  static const List<CardConfig> defaultCards = [
    CardConfig(
      id: 'nubank',
      cardName: 'Nubank Roxinho',
      bank: 'Nubank',
      closingDay: 6,
      dueDay: 13,
      color: Color(0xFF820AD1),
    ),
    CardConfig(
      id: 'itau_click',
      cardName: 'Itaú Click',
      bank: 'Itaú',
      closingDay: 3,
      dueDay: 10,
      color: Color(0xFFEC7000),
    ),
    CardConfig(
      id: 'itau_samsung',
      cardName: 'Samsung Itaú',
      bank: 'Itaú',
      closingDay: 3,
      dueDay: 10,
      color: Color(0xFF003399),
    ),
    CardConfig(
      id: 'mercado_pago',
      cardName: 'Mercado Pago',
      bank: 'Mercado Pago',
      closingDay: 5,
      dueDay: 10,
      color: Color(0xFF009EE3),
    ),
  ];
}

class CardOpenInvoice {
  final CardConfig config;
  final DateTime targetDueDate;
  final DateTime cycleStartDate;
  final DateTime cycleEndDate;
  final List<TransactionModel> transactions;
  final List<SubscriptionModel> projectedSubscriptions;

  CardOpenInvoice({
    required this.config,
    required this.targetDueDate,
    required this.cycleStartDate,
    required this.cycleEndDate,
    required this.transactions,
    this.projectedSubscriptions = const [],
  });

  double get transactionsTotal =>
      transactions.fold(0.0, (sum, tx) => sum + tx.amount);

  double get projectedSubsTotal =>
      projectedSubscriptions.fold(0.0, (sum, sub) => sum + sub.amount);

  /// Fatura real oficial: apenas as compras reais já lançadas no cartão!
  double get totalAmount => transactionsTotal;

  /// Projeção geral com assinaturas que ainda não caíram no extrato
  double get totalProjectedWithSubscriptions => transactionsTotal + projectedSubsTotal;

  double get myShareAmount {
    return transactions.fold(0.0, (sum, tx) {
      if (tx.personName != null && tx.personName!.trim().isNotEmpty) {
        return sum; // Pertence a devedor
      }
      return sum + tx.amount;
    });
  }

  double get debtorShareAmount => totalAmount - myShareAmount;
}

class NextConsolidatedInvoice {
  final DateTime targetDueDate;
  final List<CardOpenInvoice> cardInvoices;

  NextConsolidatedInvoice({
    required this.targetDueDate,
    required this.cardInvoices,
  });

  /// Total consolidado oficial das faturas (apenas compras reais lançadas)
  double get totalAmount =>
      cardInvoices.fold(0.0, (sum, card) => sum + card.totalAmount);

  /// Total projetado adicional de assinaturas ainda não lançadas
  double get projectedSubscriptionsTotal =>
      cardInvoices.fold(0.0, (sum, card) => sum + card.projectedSubsTotal);

  /// Total geral projetado (faturas reais + assinaturas futuras)
  double get projectedTotalWithSubscriptions =>
      totalAmount + projectedSubscriptionsTotal;

  double get myShareAmount =>
      cardInvoices.fold(0.0, (sum, card) => sum + card.myShareAmount);

  double get debtorShareAmount =>
      cardInvoices.fold(0.0, (sum, card) => sum + card.debtorShareAmount);

  int get totalTransactionsCount =>
      cardInvoices.fold(0, (sum, card) => sum + card.transactions.length);
}

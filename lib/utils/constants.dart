import 'package:flutter/material.dart';

class AppConstants {
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accentGreen = Color(0xFF10B981); // Emerald
  static const Color accentRed = Color(0xFFEF4444); // Rose/Red
  static const Color accentAmber = Color(0xFFF59E0B); // Amber
  static const Color nubankPurple = Color(0xFF820AD1);
  static const Color itauOrange = Color(0xFFEC7000);
  static const Color mercadoPagoBlue = Color(0xFF009EE3);

  static const List<String> defaultExpenseCategories = [
    'Alimentação',
    'Transporte',
    'Moradia',
    'Saúde',
    'Educação',
    'Lazer',
    'Compras',
    'Assinaturas',
    'Outros',
  ];

  static const List<String> defaultIncomeCategories = [
    'Salário',
    'Investimentos',
    'Empréstimo Recebido',
    'Freelance',
    'Outros',
  ];

  static const List<String> supportedBanks = [
    'Nubank',
    'Itaú',
    'Mercado Pago',
    'Bradesco',
    'Santander',
    'Inter',
    'Outro',
  ];

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'alimentação':
        return Icons.restaurant_rounded;
      case 'transporte':
        return Icons.directions_car_rounded;
      case 'moradia':
        return Icons.home_rounded;
      case 'saúde':
        return Icons.local_hospital_rounded;
      case 'educação':
        return Icons.school_rounded;
      case 'lazer':
        return Icons.sports_esports_rounded;
      case 'compras':
        return Icons.shopping_bag_rounded;
      case 'assinaturas':
        return Icons.subscriptions_rounded;
      case 'salário':
        return Icons.account_balance_wallet_rounded;
      case 'investimentos':
        return Icons.trending_up_rounded;
      case 'empréstimo recebido':
        return Icons.handshake_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static Color getBankColor(String? bank) {
    switch (bank?.toLowerCase()) {
      case 'nubank':
        return nubankPurple;
      case 'itaú':
      case 'itau':
        return itauOrange;
      case 'mercado pago':
        return mercadoPagoBlue;
      default:
        return primaryColor;
    }
  }
}

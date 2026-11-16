import 'package:flutter/material.dart';

class AppConstants {
  // FinTech Minimalist Palette (Nubank / Revolut / Apple Style)
  static const Color primaryColor = Color(0xFF10B981); // Emerald Green principal
  static const Color primaryDark = Color(0xFF059669);
  static const Color accentGreen = Color(0xFF10B981); // Emerald
  static const Color accentRed = Color(0xFFF43F5E); // Elegant Rose Red
  static const Color accentAmber = Color(0xFFF59E0B); // Amber
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan
  static const Color accentIndigo = Color(0xFF6366F1); // Indigo
  static const Color nubankPurple = Color(0xFF820AD1);
  static const Color itauOrange = Color(0xFFEC7000);
  static const Color mercadoPagoBlue = Color(0xFF009EE3);

  // True OLED Black Minimalist Theme (Pixels desligados para Samsung Galaxy S24+ Dynamic AMOLED)
  static const Color oledBlack = Color(0xFF000000); // 100% Preto Puro
  static const Color oledSurface = Color(0xFF0D0D0F); // Superfície primária
  static const Color oledCard = Color(0xFF141417); // Cartões grafite obsidiana
  static const Color oledCardElevated = Color(0xFF1C1C20); // Destaque/Inputs
  static const Color oledBorder = Color(0xFF27272A); // Borda sutil neutra
  static const Color oledSubtext = Color(0xFFA1A1AA); // Cinza neutro legível (sem azul)

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

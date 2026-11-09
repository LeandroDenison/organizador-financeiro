import '../models/transaction_model.dart';
import '../models/debt_model.dart';
import '../models/notification_event_model.dart';

class SampleDataService {
  static List<TransactionModel> getInitialTransactions() {
    final now = DateTime.now();
    return [
      TransactionModel(
        title: 'Salário Mensal',
        amount: 4500.00,
        date: DateTime(now.year, now.month, 5),
        type: TransactionType.income,
        category: 'Salário',
        bank: 'Itaú',
        source: TransactionSource.manual,
        notes: 'Pagamento CLT',
      ),
      TransactionModel(
        title: 'Supermercado Pão de Açúcar',
        amount: 382.40,
        date: DateTime(now.year, now.month, 6),
        type: TransactionType.expense,
        category: 'Alimentação',
        bank: 'Nubank',
        source: TransactionSource.notification,
        notes: 'Capturado automaticamente via notificação',
      ),
      TransactionModel(
        title: 'Posto Shell Combustível',
        amount: 150.00,
        date: DateTime(now.year, now.month, 7),
        type: TransactionType.expense,
        category: 'Transporte',
        bank: 'Nubank',
        source: TransactionSource.ofx,
        notes: 'Importado de extrato OFX',
      ),
      TransactionModel(
        title: 'Netflix & Spotify',
        amount: 55.90,
        date: DateTime(now.year, now.month, 8),
        type: TransactionType.expense,
        category: 'Lazer',
        bank: 'Mercado Pago',
        source: TransactionSource.csv,
        notes: 'Importado de CSV',
      ),
      TransactionModel(
        title: 'Carlos Silva - Parcela 3/6',
        amount: 250.00,
        date: DateTime(now.year, now.month, 8),
        type: TransactionType.income,
        category: 'Empréstimo Recebido',
        personName: 'Carlos Silva',
        installmentRef: '3/6',
        notes: 'Pagamento recebido via Pix',
      ),
    ];
  }

  static List<DebtModel> getInitialDebts() {
    final now = DateTime.now();
    return [
      DebtModel(
        personName: 'Carlos Silva',
        description: 'Empréstimo celular novo',
        contact: '(11) 98765-4321',
        totalAmount: 1500.00,
        totalInstallments: 6,
        remainingInstallments: 3,
        installmentValue: 250.00,
        dueDay: 10,
        createdAt: DateTime(now.year, now.month - 3, 10),
        paymentHistory: [
          DebtPaymentRecord(
            date: DateTime(now.year, now.month - 2, 10),
            amount: 250.00,
            installmentNumber: 1,
            note: 'Pix recebido',
          ),
          DebtPaymentRecord(
            date: DateTime(now.year, now.month - 1, 10),
            amount: 250.00,
            installmentNumber: 2,
            note: 'Pix recebido',
          ),
          DebtPaymentRecord(
            date: DateTime(now.year, now.month, 8),
            amount: 250.00,
            installmentNumber: 3,
            note: 'Pix antecipado',
          ),
        ],
      ),
      DebtModel(
        personName: 'Mariana Costa',
        description: 'Passagens aéreas da viagem',
        contact: 'mariana.costa@email.com',
        totalAmount: 1200.00,
        totalInstallments: 4,
        remainingInstallments: 1,
        installmentValue: 300.00,
        dueDay: 20,
        createdAt: DateTime(now.year, now.month - 3, 20),
        paymentHistory: [
          DebtPaymentRecord(
            date: DateTime(now.year, now.month - 2, 20),
            amount: 300.00,
            installmentNumber: 1,
          ),
          DebtPaymentRecord(
            date: DateTime(now.year, now.month - 1, 20),
            amount: 300.00,
            installmentNumber: 2,
          ),
          DebtPaymentRecord(
            date: DateTime(now.year, now.month, 5),
            amount: 300.00,
            installmentNumber: 3,
          ),
        ],
      ),
    ];
  }

  static List<NotificationEventModel> getInitialNotifications() {
    final now = DateTime.now();
    return [
      NotificationEventModel(
        appPackage: 'com.nu.production',
        bankName: 'Nubank',
        rawTitle: 'Compra aprovada no Cartão Nubank',
        rawText: 'Compra de R\$ 382,40 aprovada em Pão de Açúcar.',
        parsedAmount: 382.40,
        parsedMerchant: 'Pão de Açúcar',
        timestamp: DateTime(now.year, now.month, 6, 18, 30),
        status: NotificationStatus.approved,
        autoAdded: true,
      ),
      NotificationEventModel(
        appPackage: 'com.mercadopago.wallet',
        bankName: 'Mercado Pago',
        rawTitle: 'Pagamento aprovado',
        rawText: 'Você pagou R\$ 45,00 para Farmácia São Paulo.',
        parsedAmount: 45.00,
        parsedMerchant: 'Farmácia São Paulo',
        timestamp: DateTime(now.year, now.month, 7, 10, 15),
        status: NotificationStatus.pending,
        autoAdded: false,
      ),
    ];
  }
}

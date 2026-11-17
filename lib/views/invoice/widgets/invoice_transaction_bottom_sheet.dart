import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/currency_formatter.dart';
import '../../debts/widgets/whatsapp_reminder_dialog.dart';
import '../../transactions/widgets/add_transaction_dialog.dart';
import '../../transactions/widgets/assign_to_debt_dialog.dart';

class InvoiceTransactionBottomSheet extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onUpdated;

  const InvoiceTransactionBottomSheet({
    super.key,
    required this.transaction,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required TransactionModel transaction,
    VoidCallback? onUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvoiceTransactionBottomSheet(
        transaction: transaction,
        onUpdated: onUpdated,
      ),
    );
  }

  Color _getBankColor(String? bank) {
    final b = (bank ?? '').toLowerCase();
    if (b.contains('nubank')) return AppConstants.nubankPurple;
    if (b.contains('itau') || b.contains('itaú')) return AppConstants.itauOrange;
    if (b.contains('mercado pago')) return AppConstants.mercadoPagoBlue;
    return AppConstants.primaryColor;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'alimentação':
      case 'restaurante':
        return Icons.restaurant_rounded;
      case 'supermercado':
        return Icons.shopping_cart_rounded;
      case 'transporte':
      case 'uber':
        return Icons.directions_car_rounded;
      case 'saúde':
      case 'farmácia':
        return Icons.local_hospital_rounded;
      case 'lazer':
        return Icons.movie_rounded;
      case 'serviços':
        return Icons.miscellaneous_services_rounded;
      case 'compras':
        return Icons.shopping_bag_rounded;
      case 'moradia':
        return Icons.home_rounded;
      case 'telefonia & internet':
        return Icons.wifi_rounded;
      case 'financeiro':
        return Icons.account_balance_rounded;
      default:
        return Icons.credit_card_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtProvider = context.watch<DebtProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final bankColor = _getBankColor(transaction.bank);
    final hasDebtor = transaction.personName != null && transaction.personName!.trim().isNotEmpty;

    final dateStr = DateFormat('dd/MM/yyyy • HH:mm', 'pt_BR').format(transaction.date);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppConstants.oledBorder : Colors.grey.shade300,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.oledBorder : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Icon & Merchant Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bankColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getCategoryIcon(transaction.category),
                    color: bankColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Amount Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppConstants.oledSurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valor da Compra',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(transaction.amount),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Bank Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: bankColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          transaction.bank ?? 'Cartão',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: bankColor,
                          ),
                        ),
                      ),
                      // Category Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppConstants.oledCard : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          transaction.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      // Installment Tag
                      if (transaction.installmentRef != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppConstants.accentAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Parcela ${transaction.installmentRef}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.accentAmber,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Ownership / Debtor Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasDebtor
                    ? AppConstants.accentIndigo.withValues(alpha: 0.12)
                    : AppConstants.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasDebtor
                      ? AppConstants.accentIndigo.withValues(alpha: 0.3)
                      : AppConstants.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasDebtor ? Icons.handshake_rounded : Icons.person_rounded,
                    size: 18,
                    color: hasDebtor ? AppConstants.accentIndigo : AppConstants.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasDebtor
                          ? 'Comprado por ${transaction.personName} (Devedor)'
                          : 'Sua Compra Pessoal (Não atribuída a devedores)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: hasDebtor ? AppConstants.accentIndigo : AppConstants.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: isDark ? AppConstants.oledBorder : Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: Text(
                      hasDebtor ? 'Alterar Devedor' : 'Atribuir Devedor',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => AssignToDebtDialog(transaction: transaction),
                      ).then((_) => onUpdated?.call());
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: transaction.installmentRef != null
                            ? AppConstants.accentAmber
                            : (isDark ? AppConstants.oledBorder : Colors.grey.shade300),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 16,
                      color: transaction.installmentRef != null ? AppConstants.accentAmber : null,
                    ),
                    label: Text(
                      transaction.installmentRef != null
                          ? 'Parcela ${transaction.installmentRef}'
                          : 'Definir Parcelas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: transaction.installmentRef != null ? AppConstants.accentAmber : null,
                      ),
                    ),
                    onPressed: () => _showInstallmentDialog(context, financeProvider),
                  ),
                ),
              ],
            ),
            if (hasDebtor) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                  label: const Text(
                    'Cobrar WhatsApp',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    final personDebts = debtProvider.activeDebtsByPerson[transaction.personName!] ?? [];
                    showDialog(
                      context: context,
                      builder: (_) => WhatsAppReminderDialog(
                        personName: transaction.personName!,
                        debts: personDebts,
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? AppConstants.oledSubtext : Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Nova Transação Manual', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => const AddTransactionDialog(),
                      ).then((_) => onUpdated?.call());
                    },
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppConstants.accentRed,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Excluir', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    Navigator.pop(context);
                    await financeProvider.deleteTransaction(transaction.id);
                    onUpdated?.call();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInstallmentDialog(BuildContext context, FinanceProvider financeProvider) {
    int current = 1;
    int total = 4;
    if (transaction.installmentRef != null) {
      final parts = transaction.installmentRef!.split('/');
      if (parts.length == 2) {
        current = int.tryParse(parts[0]) ?? 1;
        total = int.tryParse(parts[1]) ?? 4;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentController = TextEditingController(text: current.toString());
    final totalController = TextEditingController(text: total.toString());
    bool divideAmount = transaction.installmentRef == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final parsedTot = (int.tryParse(totalController.text.trim()) ?? total).clamp(1, 48);
          final previewInstallmentVal = transaction.amount / parsedTot;

          return AlertDialog(
          backgroundColor: isDark ? AppConstants.oledCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: AppConstants.accentAmber, size: 20),
              SizedBox(width: 8),
              Text('Definir Parcelamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Indique qual parcela desta compra você está visualizando e o total de parcelas.',
                style: TextStyle(fontSize: 12, color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: currentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Parcela Atual',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('/', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: totalController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDlgState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Total Parcelas',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [2, 3, 4, 5, 6, 10, 12].map((n) {
                  final isSelected = totalController.text == n.toString();
                  return InkWell(
                    onTap: () {
                      setDlgState(() {
                        totalController.text = n.toString();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppConstants.oledSurface : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppConstants.accentAmber
                              : (isDark ? AppConstants.oledBorder : Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        '${n}x',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppConstants.accentAmber : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppConstants.accentAmber,
                value: divideAmount,
                onChanged: (val) => setDlgState(() => divideAmount = val ?? false),
                title: Text(
                  'Dividir valor total (${CurrencyFormatter.format(transaction.amount)}) em ${parsedTot}x de ${CurrencyFormatter.format(previewInstallmentVal)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Recomendado para compras vindas da notificação do celular',
                  style: TextStyle(fontSize: 10, color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600),
                ),
              ),
            ],
          ),
          actions: [
            if (transaction.installmentRef != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final updated = transaction.copyWith(installmentRef: null);
                  await financeProvider.updateTransaction(updated);
                  Navigator.pop(context);
                  onUpdated?.call();
                },
                child: const Text('Remover Parcelas', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentAmber,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final cur = int.tryParse(currentController.text.trim()) ?? 1;
                final tot = (int.tryParse(totalController.text.trim()) ?? 1).clamp(1, 48);
                final ref = '$cur/$tot';
                final newAmount = (divideAmount && tot > 1)
                    ? double.parse((transaction.amount / tot).toStringAsFixed(2))
                    : transaction.amount;
                Navigator.pop(ctx);
                final updated = transaction.copyWith(
                  installmentRef: ref,
                  amount: newAmount,
                );
                await financeProvider.updateTransaction(updated);
                Navigator.pop(context);
                onUpdated?.call();
              },
              child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
        },
      ),
    );
  }
}

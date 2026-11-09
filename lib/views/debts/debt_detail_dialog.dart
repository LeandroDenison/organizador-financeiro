import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/debt_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import 'widgets/whatsapp_reminder_dialog.dart';
import 'widgets/abatement_dialog.dart';

class DebtDetailDialog extends StatelessWidget {
  final DebtModel debt;

  const DebtDetailDialog({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    final debtProvider = context.watch<DebtProvider>();
    final financeProvider = context.read<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find updated version from provider
    final currentDebt = debtProvider.debts.firstWhere(
      (d) => d.id == debt.id,
      orElse: () => debt,
    );

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                  child: Text(
                    currentDebt.personName.isNotEmpty ? currentDebt.personName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentDebt.personName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        currentDebt.description,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact info if available
              if (currentDebt.contact != null && currentDebt.contact!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Contato / Pix: ${currentDebt.contact}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Key numbers row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat('Total Emprestado', CurrencyFormatter.format(currentDebt.totalAmount), isDark),
                        _buildStat('Falta Receber', CurrencyFormatter.format(currentDebt.remainingAmount), isDark,
                            color: AppConstants.accentAmber),
                        _buildStat('Já Amortizado', CurrencyFormatter.format(currentDebt.paidAmount), isDark,
                            color: AppConstants.accentGreen),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: currentDebt.progress,
                        minHeight: 10,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.accentGreen),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${currentDebt.paidInstallments} pagas de ${currentDebt.totalInstallments}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Vencimento: todo dia ${currentDebt.dueDay}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Installment Quick Adjuster
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Parcelas Restantes:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        onPressed: currentDebt.remainingInstallments > 0
                            ? () {
                                debtProvider.updateRemainingInstallments(
                                  currentDebt.id,
                                  currentDebt.remainingInstallments - 1,
                                );
                              }
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${currentDebt.remainingInstallments} / ${currentDebt.totalInstallments}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        onPressed: currentDebt.remainingInstallments < currentDebt.totalInstallments
                            ? () {
                                debtProvider.updateRemainingInstallments(
                                  currentDebt.id,
                                  currentDebt.remainingInstallments + 1,
                                );
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons: Pay Next Installment or Settle
              if (!currentDebt.isSettled) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(
                          'Receber Parcela (${CurrencyFormatter.format(currentDebt.installmentValue)})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          debtProvider.payInstallment(
                            debtId: currentDebt.id,
                            financeProvider: financeProvider,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Parcela recebida de ${currentDebt.personName}! Adicionada às receitas.',
                              ),
                              backgroundColor: AppConstants.accentGreen,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      onPressed: () {
                        debtProvider.settleEntireDebt(
                          debtId: currentDebt.id,
                          financeProvider: financeProvider,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${currentDebt.personName} quitou a dívida por completo!'),
                            backgroundColor: AppConstants.accentGreen,
                          ),
                        );
                      },
                      child: const Text('Quitar Tudo'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.accentAmber,
                          side: const BorderSide(color: AppConstants.accentAmber),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.price_check_rounded, size: 18),
                        label: const Text('Abater Valor Avulso'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AbatementDialog(
                              personName: currentDebt.personName,
                              specificDebt: currentDebt,
                              totalOwed: currentDebt.remainingAmount,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        label: const Text('Cobrar WhatsApp'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => WhatsAppReminderDialog.single(currentDebt),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppConstants.accentGreen),
                      SizedBox(width: 8),
                      Text(
                        'Esta dívida já foi totalmente quitada!',
                        style: TextStyle(color: AppConstants.accentGreen, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Payment History
              const Text(
                'Histórico de Amortizações',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (currentDebt.paymentHistory.isEmpty)
                Text(
                  'Nenhuma parcela paga ainda.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentDebt.paymentHistory.length,
                  itemBuilder: (context, index) {
                    final p = currentDebt.paymentHistory[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline_rounded,
                          color: AppConstants.accentGreen, size: 20),
                      title: Text(
                        'Parcela ${p.installmentNumber} • ${CurrencyFormatter.format(p.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${CurrencyFormatter.formatDate(p.date)}${p.note != null ? " (${p.note})" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, bool isDark, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? Colors.white : Colors.grey.shade900),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/finance_provider.dart';
import '../../models/subscription_model.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/constants.dart';

class SubscriptionsView extends StatelessWidget {
  const SubscriptionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assinaturas & Custos Recorrentes',
                      style: (isMobile
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.headlineSmall)
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reconhecimento automático de streamings, clubes (Uber, iFood) e planos na fatura',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final added = await subProvider.syncFromTransactions(
                          financeProvider.transactions,
                          ignoreDismissed: true,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                added > 0
                                    ? '$added novas assinaturas reconhecidas da fatura!'
                                    : 'Todas as assinaturas da fatura já estão listadas abaixo.',
                              ),
                              backgroundColor: AppConstants.primaryColor,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 17),
                      label: const Text('Reconhecer da Fatura'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.primaryColor,
                        side: const BorderSide(color: AppConstants.primaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddSubscriptionDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nova Assinatura'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Annual Drain Awareness Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dreno Anual em Assinaturas Ativas',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 22),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(subProvider.totalAnnualCost),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Você gasta ${CurrencyFormatter.format(subProvider.totalMonthlyCost)}/mês em ${subProvider.activeSubscriptions.length} assinaturas ativas'
                    '${subProvider.pausedSubscriptions.isNotEmpty ? ' • ${subProvider.pausedSubscriptions.length} pausada(s) (${CurrencyFormatter.format(subProvider.totalPausedMonthlyCost)}/mês economizados)' : ''}.',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Subscriptions list
            if (subProvider.subscriptions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(Icons.subscriptions_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhuma assinatura cadastrada.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Importe sua fatura ou clique em "Reconhecer da Fatura" para detectar automaticamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subProvider.subscriptions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final sub = subProvider.subscriptions[index];
                  return _buildSubscriptionCard(context, sub, isDark);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, SubscriptionModel sub, bool isDark) {
    final subProvider = context.read<SubscriptionProvider>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: sub.isActive
              ? (isDark ? const Color(0xFF334155) : Colors.grey.shade200)
              : Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: sub.isActive
                    ? AppConstants.primaryColor.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.15),
                child: Icon(
                  sub.isActive ? Icons.repeat_rounded : Icons.pause_circle_outline_rounded,
                  color: sub.isActive ? AppConstants.primaryColor : Colors.amber.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            sub.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: sub.isActive ? null : TextDecoration.lineThrough,
                              color: sub.isActive ? null : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${CurrencyFormatter.format(sub.amount)}/mês',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: sub.isActive ? AppConstants.accentRed : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dia ${sub.billingDay} • ${sub.category} • ${CurrencyFormatter.format(sub.annualAmount)}/ano',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    if (sub.sourceTransactionTitle != null &&
                        sub.sourceTransactionTitle!.toLowerCase() != sub.name.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reconhecida de: "${sub.sourceTransactionTitle}"',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sub.isActive
                            ? AppConstants.accentGreen.withValues(alpha: 0.14)
                            : Colors.amber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sub.isActive ? '● Ativa' : '⏸ Pausada',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: sub.isActive ? AppConstants.accentGreen : Colors.amber.shade700,
                        ),
                      ),
                    ),
                    if (sub.bank != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppConstants.getBankColor(sub.bank).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sub.bank!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.getBankColor(sub.bank),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => subProvider.toggleSubscription(sub.id),
                    style: TextButton.styleFrom(
                      foregroundColor: sub.isActive ? Colors.amber.shade700 : AppConstants.accentGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      sub.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(
                      sub.isActive ? 'Pausar' : 'Ativar',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Excluir assinatura',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.grey),
                    onPressed: () => subProvider.deleteSubscription(sub.id),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController();
    String? selectedBank = 'Nubank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nova Assinatura'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome (ex: Netflix, Spotify, Academia)',
                  prefixIcon: Icon(Icons.subscriptions_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor Mensal (R\$)',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dia do Vencimento (1 a 31)',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedBank,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Banco / Cartão',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'Nubank', child: Text('Nubank')),
                  DropdownMenuItem(value: 'Itaú', child: Text('Itaú')),
                  DropdownMenuItem(value: 'Mercado Pago', child: Text('Mercado Pago')),
                  DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                ],
                onChanged: (val) => setState(() => selectedBank = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
                final day = int.tryParse(dayController.text) ?? 1;

                if (name.isNotEmpty && amount > 0) {
                  ctx.read<SubscriptionProvider>().addSubscription(
                        SubscriptionModel(
                          name: name,
                          amount: amount,
                          billingDay: day.clamp(1, 31),
                          bank: selectedBank,
                        ),
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}

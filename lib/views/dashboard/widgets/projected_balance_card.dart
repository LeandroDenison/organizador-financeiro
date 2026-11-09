import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/constants.dart';

class ProjectedBalanceCard extends StatelessWidget {
  const ProjectedBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final debts = context.watch<DebtProvider>();
    final subscriptions = context.watch<SubscriptionProvider>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final currentBalance = finance.balance;
    final expectedReceivables = debts.activeDebts.fold(0.0, (sum, d) => sum + d.installmentValue);
    final expectedSubscriptions = subscriptions.totalMonthlyCost;
    final projectedBalance = currentBalance + expectedReceivables - expectedSubscriptions;

    final isPositive = projectedBalance >= 0;
    final isTight = isPositive && projectedBalance < 300;

    final statusColor = isTight
        ? AppConstants.accentAmber
        : (isPositive ? AppConstants.accentGreen : AppConstants.accentRed);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.auto_graph_rounded, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Previsão de Saldo (Fim do Mês)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Fluxo projetado: Saldo + Devedores - Assinaturas',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isTight ? 'Margem Apertada' : (isPositive ? 'Positivo' : 'Risco Negativo'),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Projected Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Saldo Estimado: ',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Text(
                CurrencyFormatter.format(projectedBalance),
                style: TextStyle(
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Breakdown pills/tiles
          if (isMobile)
            Column(
              children: [
                _buildBreakdownTile(
                  label: 'Saldo Atual em Conta',
                  amount: currentBalance,
                  icon: Icons.account_balance_wallet_outlined,
                  color: currentBalance >= 0 ? AppConstants.accentGreen : AppConstants.accentRed,
                  prefix: '',
                ),
                const SizedBox(height: 6),
                _buildBreakdownTile(
                  label: 'A Receber (Devedores este mês)',
                  amount: expectedReceivables,
                  icon: Icons.arrow_downward_rounded,
                  color: AppConstants.accentGreen,
                  prefix: '+ ',
                ),
                const SizedBox(height: 6),
                _buildBreakdownTile(
                  label: 'Assinaturas & Custos Fixos',
                  amount: expectedSubscriptions,
                  icon: Icons.repeat_rounded,
                  color: AppConstants.accentRed,
                  prefix: '- ',
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildBreakdownTile(
                    label: 'Saldo Atual',
                    amount: currentBalance,
                    icon: Icons.account_balance_wallet_outlined,
                    color: currentBalance >= 0 ? AppConstants.accentGreen : AppConstants.accentRed,
                    prefix: '',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBreakdownTile(
                    label: 'A Receber (Devedores)',
                    amount: expectedReceivables,
                    icon: Icons.arrow_downward_rounded,
                    color: AppConstants.accentGreen,
                    prefix: '+ ',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBreakdownTile(
                    label: 'Assinaturas Fixas',
                    amount: expectedSubscriptions,
                    icon: Icons.repeat_rounded,
                    color: AppConstants.accentRed,
                    prefix: '- ',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTile({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required String prefix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
          Text(
            '$prefix${CurrencyFormatter.format(amount)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

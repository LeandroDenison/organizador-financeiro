import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/constants.dart';

class ProjectedBalanceCard extends StatefulWidget {
  const ProjectedBalanceCard({super.key});

  @override
  State<ProjectedBalanceCard> createState() => _ProjectedBalanceCardState();
}

class _ProjectedBalanceCardState extends State<ProjectedBalanceCard> {
  bool _onlyMyBills = true; // Padrão: Previsão real considerando apenas as minhas contas

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final debts = context.watch<DebtProvider>();
    final subscriptions = context.watch<SubscriptionProvider>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    // Saldo real consolidado dos 3 bancos pelo Open Finance
    final openFinanceTotal = finance.openFinanceCashBalance;
    final currentCashBalance = openFinanceTotal;

    // Fluxo mensal realizado (Receitas - Despesas do mês selecionado)
    final monthlyFlowBalance = finance.balance;

    // Parcelas de devedores que ainda NÃO foram pagas neste mês
    final selectedMonth = finance.selectedMonth;
    final pendingDebtorReceivables = debts.activeDebts.where((d) {
      final alreadyPaidThisMonth = d.paymentHistory.any((p) =>
          p.date.year == selectedMonth.year && p.date.month == selectedMonth.month);
      return !alreadyPaidThisMonth;
    }).fold(0.0, (sum, d) {
      final val = d.remainingAmount < d.installmentValue ? d.remainingAmount : d.installmentValue;
      return sum + val;
    });

    // Assinaturas que ainda faltam cobrar neste mês
    final unbilledSubs = subscriptions.activeSubscriptions.where((sub) {
      final alreadyInTransactions = finance.scopedTransactions.any((tx) =>
          (tx.amount - sub.amount).abs() < 0.05 &&
          (tx.title.toLowerCase() == sub.sourceTransactionTitle?.toLowerCase() ||
              tx.title.toLowerCase() == sub.name.toLowerCase()));
      return !alreadyInTransactions;
    }).fold(0.0, (sum, s) => sum + (_onlyMyBills ? s.effectiveMyCost : s.amount));

    // Saldo final estimado do MÊS (projeção do fluxo mensal real):
    // Fluxo do mês (Receitas - Despesas) + O que os devedores ainda vão pagar - Contas que ainda faltam cobrar
    final projectedBalance = _onlyMyBills
        ? (monthlyFlowBalance - unbilledSubs)
        : (monthlyFlowBalance + pendingDebtorReceivables - unbilledSubs);

    final isPositive = projectedBalance >= 0;
    final isTight = isPositive && projectedBalance < 300;

    final statusColor = isTight
        ? AppConstants.accentAmber
        : (isPositive ? AppConstants.accentGreen : AppConstants.accentRed);

    final nubankBal = finance.getBankBalance('Nubank');
    final itauBal = finance.getBankBalance('Itaú');
    final mpBal = finance.getBankBalance('Mercado Pago');

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
          // Header: Mode Switcher & Status Badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _onlyMyBills ? Icons.savings_rounded : Icons.auto_graph_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _onlyMyBills
                            ? 'Previsão do Salário (Apenas Minhas Contas)'
                            : 'Previsão Completa (Com Devedores)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        _onlyMyBills
                            ? 'Sobra real do seu bolso sem depender de terceiros'
                            : 'Fluxo mensal: Receitas - Despesas + Devedores deste mês - Assinaturas',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Segmented Button Toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _onlyMyBills = true),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _onlyMyBills ? AppConstants.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 13,
                              color: _onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Apenas Minhas Contas',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _onlyMyBills = false),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: !_onlyMyBills ? AppConstants.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.group_rounded,
                              size: 13,
                              color: !_onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Com Devedores',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: !_onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                _onlyMyBills ? 'Sobra Real Estimada: ' : 'Saldo Final Estimado: ',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Expanded(
                child: Text(
                  CurrencyFormatter.format(projectedBalance),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          const SizedBox(height: 14),

          // Open Finance Multi-Bank Live Balance Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hub_rounded, size: 14, color: AppConstants.accentCyan),
                        const SizedBox(width: 6),
                        Text(
                          'Saldo Consolidado (3 Bancos Open Finance):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.format(currentCashBalance),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        finance.isSyncingBalances
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : InkWell(
                                onTap: () => finance.refreshBankBalances(),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.sync_rounded, size: 15, color: Colors.grey),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildBankChip(
                      name: 'Nubank',
                      amount: nubankBal,
                      color: AppConstants.nubankPurple,
                      isDark: isDark,
                    ),
                    _buildBankChip(
                      name: 'Itaú',
                      amount: itauBal,
                      color: AppConstants.itauOrange,
                      isDark: isDark,
                    ),
                    _buildBankChip(
                      name: 'Mercado Pago',
                      amount: mpBal,
                      color: AppConstants.mercadoPagoBlue,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Breakdown pills/tiles
          if (isMobile)
            Column(
              children: [
                _buildBreakdownTile(
                  label: 'Fluxo Atual do Mês',
                  amount: monthlyFlowBalance,
                  icon: Icons.trending_up_rounded,
                  color: monthlyFlowBalance >= 0 ? AppConstants.accentGreen : AppConstants.accentAmber,
                  prefix: '',
                ),
                const SizedBox(height: 6),
                _buildBreakdownTile(
                  label: _onlyMyBills ? 'Devedores (Desconsiderados)' : 'A Receber (Devedores este mês)',
                  amount: _onlyMyBills ? 0.0 : pendingDebtorReceivables,
                  icon: Icons.arrow_downward_rounded,
                  color: _onlyMyBills ? Colors.grey : AppConstants.accentGreen,
                  prefix: _onlyMyBills ? '' : '+ ',
                ),
                const SizedBox(height: 6),
                _buildBreakdownTile(
                  label: _onlyMyBills ? 'Minhas Contas Restantes' : 'Contas Restantes a Vencer',
                  amount: unbilledSubs,
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
                    label: 'Fluxo Atual do Mês',
                    amount: monthlyFlowBalance,
                    icon: Icons.trending_up_rounded,
                    color: monthlyFlowBalance >= 0 ? AppConstants.accentGreen : AppConstants.accentAmber,
                    prefix: '',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBreakdownTile(
                    label: _onlyMyBills ? 'Devedores (Desconsiderados)' : 'A Receber (Devedores este mês)',
                    amount: _onlyMyBills ? 0.0 : pendingDebtorReceivables,
                    icon: Icons.arrow_downward_rounded,
                    color: _onlyMyBills ? Colors.grey : AppConstants.accentGreen,
                    prefix: _onlyMyBills ? '' : '+ ',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBreakdownTile(
                    label: _onlyMyBills ? 'Minhas Contas Restantes' : 'Contas Restantes a Vencer',
                    amount: unbilledSubs,
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

  Widget _buildBankChip({
    required String name,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$name: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
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
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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

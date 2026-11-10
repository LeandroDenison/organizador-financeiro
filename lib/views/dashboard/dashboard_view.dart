import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/bank_loan_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/constants.dart';
import '../../models/transaction_model.dart';
import 'widgets/summary_card.dart';
import 'widgets/category_pie_chart.dart';
import 'widgets/projected_balance_card.dart';
import 'widgets/budget_alert_banner.dart';
import 'widgets/future_commitments_card.dart';
import 'widgets/debtor_pix_alert_banner.dart';
import '../transactions/widgets/add_transaction_dialog.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final debts = context.watch<DebtProvider>();
    final appState = context.watch<AppStateProvider>();
    final firebase = context.watch<FirebaseService>();
    final bankLoans = context.watch<BankLoanProvider>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title & Firebase status
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visão Geral Financeira',
                      style: (isMobile
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.headlineSmall)
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Saldo, devedores, empréstimos e extratos bancários',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // Firebase Sync Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: firebase.isConnected
                        ? AppConstants.accentGreen.withOpacity(0.12)
                        : Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: firebase.isConnected
                          ? AppConstants.accentGreen.withOpacity(0.3)
                          : Colors.amber.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        firebase.isConnected ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                        size: 15,
                        color: firebase.isConnected ? AppConstants.accentGreen : Colors.amber.shade700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        firebase.isConnected ? 'Firebase' : 'Modo Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: firebase.isConnected ? AppConstants.accentGreen : Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month Selector Toolbar
            _buildMonthSelector(context, finance, isDark),
            const SizedBox(height: 16),

            // Bank Loans Alert Banner
            _buildBankLoansBanner(context, isDark, bankLoans, appState),
            const SizedBox(height: 16),

            // Debtor Pix Recognition Alert (if someone sent Pix to abate accounts)
            const DebtorPixAlertBanner(),

            // Feature 4: Budget Limit Alerts (if any threshold reached)
            const BudgetAlertBanner(),

            // Feature 3: Projected Balance at End of Month
            const ProjectedBalanceCard(),
            const SizedBox(height: 20),

            // Summary Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth < 600
                    ? 1
                    : constraints.maxWidth < 1000
                        ? 2
                        : 4;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: constraints.maxWidth < 600 ? 2.4 : 1.7,
                  children: [
                    SummaryCard(
                      title: 'Saldo em Conta (3 Bancos)',
                      value: CurrencyFormatter.format(finance.openFinanceCashBalance),
                      icon: Icons.account_balance_rounded,
                      color: finance.openFinanceCashBalance >= 0 ? AppConstants.accentGreen : AppConstants.accentRed,
                      subtitle: 'Dinheiro real disponível nos bancos',
                      onTap: () => appState.setTab(8), // Aba Configurações / Bancos
                    ),
                    SummaryCard(
                      title: 'Sobra do Mês (Fluxo)',
                      value: CurrencyFormatter.format(finance.balance),
                      icon: Icons.trending_up_rounded,
                      color: finance.balance >= 0 ? AppConstants.accentGreen : AppConstants.accentAmber,
                      subtitle: 'Receitas menos despesas do mês',
                    ),
                    SummaryCard(
                      title: 'Despesas (Mês)',
                      value: CurrencyFormatter.format(finance.totalExpense),
                      icon: Icons.arrow_upward_rounded,
                      color: AppConstants.accentRed,
                      subtitle: 'Cartões, compras e contas do mês',
                      onTap: () => appState.setTab(1), // Extrato de Transações
                    ),
                    SummaryCard(
                      title: debts.viewMode == DebtViewMode.month
                          ? 'Quem me Deve (Mês)'
                          : 'Quem me Deve (Total)',
                      value: CurrencyFormatter.format(
                        debts.viewMode == DebtViewMode.month
                            ? debts.totalOwedThisMonth
                            : debts.totalOwedToMe,
                      ),
                      icon: Icons.handshake_rounded,
                      color: AppConstants.primaryColor,
                      actionWidget: SegmentedButton<DebtViewMode>(
                        segments: const [
                          ButtonSegment(
                            value: DebtViewMode.month,
                            label: Text('Mês', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          ButtonSegment(
                            value: DebtViewMode.total,
                            label: Text('Total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        selected: {debts.viewMode},
                        onSelectionChanged: (val) => debts.setViewMode(val.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 6, vertical: 0)),
                        ),
                      ),
                      subtitle: debts.viewMode == DebtViewMode.month
                          ? '${debts.totalPendingInstallments} parcelas • Total: ${CurrencyFormatter.format(debts.totalOwedToMe)}'
                          : '${debts.totalPendingInstallments} parcelas • Mês: ${CurrencyFormatter.format(debts.totalOwedThisMonth)}',
                      onTap: () => appState.setTab(2), // Navega para aba Quem me deve
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Feature 2: Future Commitments Radar (Next 6 Months)
            const FutureCommitmentsCard(),
            const SizedBox(height: 24),

            // Middle section: Charts & "Quem me deve" preview
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildChartCard(context, isDark, finance),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: _buildDebtsCard(context, isDark, debts, appState),
                  ),
                ],
              )
            else ...[
              _buildChartCard(context, isDark, finance),
              const SizedBox(height: 20),
              _buildDebtsCard(context, isDark, debts, appState),
            ],

            const SizedBox(height: 24),

            // Recent Transactions Section
            _buildRecentTransactions(context, isDark, finance, appState),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Transação'),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddTransactionDialog(),
          );
        },
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, bool isDark, FinanceProvider finance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Expanded(
                child: Text(
                  'Despesas por Categoria',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.pie_chart_rounded, color: AppConstants.primaryColor, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          CategoryPieChart(expensesByCategory: finance.expensesByCategory),
        ],
      ),
    );
  }

  Widget _buildDebtsCard(BuildContext context, bool isDark, DebtProvider debts, AppStateProvider appState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Quem me deve',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<DebtViewMode>(
                      segments: const [
                        ButtonSegment(
                          value: DebtViewMode.month,
                          label: Text('Mês', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        ButtonSegment(
                          value: DebtViewMode.total,
                          label: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      selected: {debts.viewMode},
                      onSelectionChanged: (newVal) => debts.setViewMode(newVal.first),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => appState.setTab(2),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Ver todas'),
                style: TextButton.styleFrom(
                  foregroundColor: AppConstants.primaryColor,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (debts.activeDebts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text('Nenhum empréstimo ativo no momento!'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: debts.activeDebts.take(3).length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final debt = debts.activeDebts[index];
                final isMonth = debts.viewMode == DebtViewMode.month;
                final monthVal = debt.remainingAmount < debt.installmentValue ? debt.remainingAmount : debt.installmentValue;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            debt.personName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMonth
                              ? '${CurrencyFormatter.format(monthVal)}/mês'
                              : CurrencyFormatter.format(debt.remainingAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppConstants.accentAmber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${debt.description} • Faltam ${debt.remainingInstallments} de ${debt.totalInstallments} parcelas (${CurrencyFormatter.format(debt.installmentValue)}/mês)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: debt.progress,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.accentGreen),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    bool isDark,
    FinanceProvider finance,
    AppStateProvider appState,
  ) {
    final recent = finance.transactions.take(6).toList();
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Últimas Movimentações',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => appState.setTab(1),
                icon: const Icon(Icons.list_alt_rounded, size: 16),
                label: Text(screenWidth < 400 ? 'Ver extrato' : 'Ver extrato completo'),
                style: TextButton.styleFrom(
                  foregroundColor: AppConstants.primaryColor,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('Nenhuma movimentação registrada')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => Divider(
                height: 12,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final tx = recent[index];
                final isIncome = tx.type == TransactionType.income;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: isIncome
                            ? AppConstants.accentGreen.withValues(alpha: 0.15)
                            : AppConstants.accentRed.withValues(alpha: 0.15),
                        child: Icon(
                          AppConstants.getCategoryIcon(tx.category),
                          color: isIncome ? AppConstants.accentGreen : AppConstants.accentRed,
                          size: 18,
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
                                    tx.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(tx.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isIncome ? AppConstants.accentGreen : AppConstants.accentRed,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${CurrencyFormatter.formatDate(tx.date)} • ${tx.category}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            if (tx.bank != null || tx.source != TransactionSource.manual) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  if (tx.bank != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppConstants.getBankColor(tx.bank).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tx.bank!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.getBankColor(tx.bank),
                                        ),
                                      ),
                                    ),
                                  if (tx.source == TransactionSource.notification)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.notifications_active_rounded, size: 10, color: Colors.blue),
                                          SizedBox(width: 2),
                                          Text(
                                            'Notificação',
                                            style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, FinanceProvider finance, bool isDark) {
    const monthNames = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    final selected = finance.selectedMonth;
    final label = '${monthNames[selected.month]} de ${selected.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Mês anterior',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final prev = DateTime(selected.year, selected.month - 1);
                  finance.setSelectedMonth(prev);
                },
              ),
              const SizedBox(width: 4),
              const Icon(Icons.calendar_month_rounded, size: 18, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Próximo mês',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final next = DateTime(selected.year, selected.month + 1);
                  finance.setSelectedMonth(next);
                },
              ),
            ],
          ),
          if (selected.year != 2026 || selected.month != 11)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppConstants.primaryColor,
              ),
              onPressed: () => finance.setSelectedMonth(DateTime(2026, 11)),
              child: const Text('Voltar para Nov/2026'),
            ),
        ],
      ),
    );
  }

  Widget _buildBankLoansBanner(BuildContext context, bool isDark, BankLoanProvider bankLoans, AppStateProvider appState) {
    if (bankLoans.activeLoans.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.nubankPurple.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppConstants.nubankPurple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_rounded, color: AppConstants.nubankPurple, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Empréstimos Bancários Ativos (Nubank)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppConstants.accentAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${bankLoans.activeLoans.length} contratos',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppConstants.accentAmber),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Saldo devedor total: ${CurrencyFormatter.format(bankLoans.totalRemainingDebt)} • Parcela mensal: ${CurrencyFormatter.format(bankLoans.totalMonthlyInstallment)}/mês',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.nubankPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => appState.setTab(3), // Tab 3 is Empréstimos Bancários
            child: const Text('Ver Detalhes'),
          ),
        ],
      ),
    );
  }
}

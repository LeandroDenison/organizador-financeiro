import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/debt_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import 'widgets/add_debt_dialog.dart';
import 'debt_detail_dialog.dart';

class DebtsView extends StatefulWidget {
  const DebtsView({super.key});

  @override
  State<DebtsView> createState() => _DebtsViewState();
}

class _DebtsViewState extends State<DebtsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtProvider = context.watch<DebtProvider>();
    final financeProvider = context.read<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMobile ? 'Quem me Deve' : 'Quem me Deve (Empréstimos)',
                        style: (isMobile
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.headlineSmall)
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Controle de empréstimos e parcelas',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 12,
                    ),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: Text(isMobile ? 'Novo' : 'Adicionar Pessoa'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddDebtDialog(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Metric Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMetric(
                      'Total a Receber',
                      CurrencyFormatter.format(debtProvider.totalOwedToMe),
                      Icons.pending_actions_rounded,
                      AppConstants.accentAmber,
                    ),
                    _buildDivider(isDark),
                    _buildMetric(
                      'Já Recebido',
                      CurrencyFormatter.format(debtProvider.totalAlreadyReceived),
                      Icons.check_circle_rounded,
                      AppConstants.accentGreen,
                    ),
                    _buildDivider(isDark),
                    _buildMetric(
                      'Parcelas Pendentes',
                      '${debtProvider.totalPendingInstallments} parcelas',
                      Icons.calendar_month_rounded,
                      AppConstants.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tabs: Ativos / Quitados
            TabBar(
              controller: _tabController,
              indicatorColor: AppConstants.primaryColor,
              labelColor: AppConstants.primaryColor,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Ativos'),
                      const SizedBox(width: 8),
                      Badge(
                        label: Text('${debtProvider.activeDebts.length}'),
                        backgroundColor: AppConstants.primaryColor,
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Quitados'),
                      const SizedBox(width: 8),
                      Badge(
                        label: Text('${debtProvider.settledDebts.length}'),
                        backgroundColor: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDebtList(
                    context,
                    debtProvider.activeDebts,
                    isDark,
                    debtProvider,
                    financeProvider,
                    isActiveTab: true,
                  ),
                  _buildDebtList(
                    context,
                    debtProvider.settledDebts,
                    isDark,
                    debtProvider,
                    financeProvider,
                    isActiveTab: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 36,
      width: 1,
      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
    );
  }

  Widget _buildDebtList(
    BuildContext context,
    List<DebtModel> list,
    bool isDark,
    DebtProvider debtProvider,
    FinanceProvider financeProvider, {
    required bool isActiveTab,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActiveTab ? Icons.sentiment_satisfied_rounded : Icons.check_circle_outline_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isActiveTab
                  ? 'Ninguém está te devendo no momento!'
                  : 'Nenhum empréstimo quitado arquivado.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isActiveTab
                  ? 'Clique em "Adicionar Pessoa / Dívida" para registrar.'
                  : 'Quando uma dívida for 100% paga, ela aparecerá aqui.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 700 ? 1 : 2;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: constraints.maxWidth < 700 ? 2.1 : 2.0,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final debt = list[index];

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header of card: Avatar, Name, Description, Menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                          child: Text(
                            debt.personName.isNotEmpty ? debt.personName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                debt.personName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                debt.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(debt.remainingAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: debt.isSettled ? AppConstants.accentGreen : AppConstants.accentAmber,
                              ),
                            ),
                            Text(
                              'de ${CurrencyFormatter.format(debt.totalAmount)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Progress bar & installments
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Parcelas: ${debt.remainingInstallments} restantes de ${debt.totalInstallments}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${CurrencyFormatter.format(debt.installmentValue)}/mês • Dia ${debt.dueDay}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: debt.progress,
                            minHeight: 8,
                            backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              debt.isSettled ? AppConstants.accentGreen : AppConstants.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Bottom Actions: Receive Installment & Details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!debt.isSettled)
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppConstants.accentGreen.withOpacity(0.15),
                              foregroundColor: AppConstants.accentGreen,
                            ),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text('Receber 1 Parcela (${CurrencyFormatter.format(debt.installmentValue)})'),
                            onPressed: () {
                              debtProvider.payInstallment(
                                debtId: debt.id,
                                financeProvider: financeProvider,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Parcela recebida de ${debt.personName}! Adicionada às receitas.',
                                  ),
                                  backgroundColor: AppConstants.accentGreen,
                                ),
                              );
                            },
                          )
                        else
                          const Row(
                            children: [
                              Icon(Icons.verified_rounded, size: 16, color: AppConstants.accentGreen),
                              SizedBox(width: 4),
                              Text(
                                'Quitado com sucesso',
                                style: TextStyle(color: AppConstants.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => DebtDetailDialog(debt: debt),
                                );
                              },
                              child: const Text('Ver Detalhes'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              color: Colors.grey.shade400,
                              onPressed: () {
                                debtProvider.deleteDebt(debt.id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

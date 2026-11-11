import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/debt_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import 'widgets/add_debt_dialog.dart';
import 'widgets/whatsapp_reminder_dialog.dart';
import 'widgets/abatement_dialog.dart';
import 'debt_detail_dialog.dart';

class DebtsView extends StatefulWidget {
  const DebtsView({super.key});

  @override
  State<DebtsView> createState() => _DebtsViewState();
}

class _DebtsViewState extends State<DebtsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _groupByPerson = true;

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
            // Header (responsive for mobile)
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quem me Deve',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Contas por pessoa, cobrança e abatimentos',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Novo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const AddDebtDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<DebtViewMode>(
                      segments: const [
                        ButtonSegment(
                          value: DebtViewMode.month,
                          icon: Icon(Icons.calendar_month_rounded, size: 14),
                          label: Text('Mês', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        ButtonSegment(
                          value: DebtViewMode.total,
                          icon: Icon(Icons.all_inclusive_rounded, size: 14),
                          label: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      selected: {debtProvider.viewMode},
                      onSelectionChanged: (newVal) => debtProvider.setViewMode(newVal.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quem me Deve (Empréstimos)',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Controle de contas por pessoa, cobrança no WhatsApp e abatimentos',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<DebtViewMode>(
                        segments: const [
                          ButtonSegment(
                            value: DebtViewMode.month,
                            icon: Icon(Icons.calendar_month_rounded, size: 15),
                            label: Text('Mês', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          ButtonSegment(
                            value: DebtViewMode.total,
                            icon: Icon(Icons.all_inclusive_rounded, size: 15),
                            label: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        selected: {debtProvider.viewMode},
                        onSelectionChanged: (newVal) => debtProvider.setViewMode(newVal.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Adicionar Conta'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const AddDebtDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Top Metric Bar (responsive 2x2 grid on mobile, horizontal row on desktop)
            if (isMobile)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetric(
                            debtProvider.viewMode == DebtViewMode.month ? 'A Receber no Mês' : 'Total a Receber',
                            CurrencyFormatter.format(
                              debtProvider.viewMode == DebtViewMode.month
                                  ? debtProvider.totalOwedThisMonth
                                  : debtProvider.totalOwedToMe,
                            ),
                            debtProvider.viewMode == DebtViewMode.month
                                ? Icons.calendar_month_rounded
                                : Icons.pending_actions_rounded,
                            AppConstants.accentAmber,
                          ),
                        ),
                        _buildDivider(isDark),
                        Expanded(
                          child: _buildMetric(
                            debtProvider.viewMode == DebtViewMode.month ? 'Total Acumulado' : 'A Receber no Mês',
                            CurrencyFormatter.format(
                              debtProvider.viewMode == DebtViewMode.month
                                  ? debtProvider.totalOwedToMe
                                  : debtProvider.totalOwedThisMonth,
                            ),
                            debtProvider.viewMode == DebtViewMode.month
                                ? Icons.all_inclusive_rounded
                                : Icons.calendar_month_rounded,
                            Colors.indigoAccent,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 16, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetric(
                            'Já Recebido',
                            CurrencyFormatter.format(debtProvider.totalAlreadyReceived),
                            Icons.check_circle_rounded,
                            AppConstants.accentGreen,
                          ),
                        ),
                        _buildDivider(isDark),
                        Expanded(
                          child: _buildMetric(
                            'Parcelas Pendentes',
                            '${debtProvider.totalPendingInstallments} parcelas',
                            Icons.calendar_today_rounded,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetric(
                        debtProvider.viewMode == DebtViewMode.month ? 'A Receber no Mês' : 'Total a Receber',
                        CurrencyFormatter.format(
                          debtProvider.viewMode == DebtViewMode.month
                              ? debtProvider.totalOwedThisMonth
                              : debtProvider.totalOwedToMe,
                        ),
                        debtProvider.viewMode == DebtViewMode.month
                            ? Icons.calendar_month_rounded
                            : Icons.pending_actions_rounded,
                        AppConstants.accentAmber,
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _buildMetric(
                        debtProvider.viewMode == DebtViewMode.month ? 'Total Acumulado' : 'A Receber no Mês',
                        CurrencyFormatter.format(
                          debtProvider.viewMode == DebtViewMode.month
                              ? debtProvider.totalOwedToMe
                              : debtProvider.totalOwedThisMonth,
                        ),
                        debtProvider.viewMode == DebtViewMode.month
                            ? Icons.all_inclusive_rounded
                            : Icons.calendar_month_rounded,
                        Colors.indigoAccent,
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _buildMetric(
                        'Já Recebido',
                        CurrencyFormatter.format(debtProvider.totalAlreadyReceived),
                        Icons.check_circle_rounded,
                        AppConstants.accentGreen,
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _buildMetric(
                        'Pessoas Devedoras',
                        '${debtProvider.activeDebtsByPerson.keys.length} pessoas',
                        Icons.people_rounded,
                        AppConstants.primaryColor,
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _buildMetric(
                        'Parcelas Pendentes',
                        '${debtProvider.totalPendingInstallments} parcelas',
                        Icons.calendar_today_rounded,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // Mode Toggle (Por Pessoa vs Todas as Contas) & Tabs (Ativos / Quitados)
            if (isMobile) ...[
              TabBar(
                controller: _tabController,
                indicatorColor: AppConstants.primaryColor,
                labelColor: AppConstants.primaryColor,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                isScrollable: false,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(child: Text('Ativos', overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
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
                        const Flexible(child: Text('Quitados', overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Badge(
                          label: Text('${debtProvider.settledDebts.length}'),
                          backgroundColor: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.group_rounded, size: 16),
                      label: Text('Por Pessoa', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.list_alt_rounded, size: 16),
                      label: Text('Por Conta', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {_groupByPerson},
                  onSelectionChanged: (newVal) {
                    setState(() => _groupByPerson = newVal.first);
                  },
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppConstants.primaryColor,
                      labelColor: AppConstants.primaryColor,
                      isScrollable: true,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Ativos'),
                              const SizedBox(width: 6),
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
                              const SizedBox(width: 6),
                              Badge(
                                label: Text('${debtProvider.settledDebts.length}'),
                                backgroundColor: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle Group by Person
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.group_rounded, size: 16),
                        label: Text('Por Pessoa', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.list_alt_rounded, size: 16),
                        label: Text('Por Conta', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_groupByPerson},
                    onSelectionChanged: (newVal) {
                      setState(() => _groupByPerson = newVal.first);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 14),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _groupByPerson
                      ? _buildGroupedByPersonList(
                          context,
                          debtProvider.activeDebtsByPerson,
                          isDark,
                          debtProvider,
                          financeProvider,
                        )
                      : _buildDebtList(
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 36,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
    );
  }

  /// Grouped by Person View (handles Sérgio having multiple accounts & consolidated billing!)
  Widget _buildGroupedByPersonList(
    BuildContext context,
    Map<String, List<DebtModel>> grouped,
    bool isDark,
    DebtProvider debtProvider,
    FinanceProvider financeProvider,
  ) {
    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_satisfied_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Nenhum devedor ativo no momento!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Cadastre um empréstimo ou atribua uma fatura para começar.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final entries = grouped.entries.toList();

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        final personName = entries[index].key;
        final debts = entries[index].value;

        final isMonthMode = debtProvider.viewMode == DebtViewMode.month;
        final personMonthVal = debtProvider.personOwedThisMonth(personName);
        final personGrossMonth = debtProvider.personGrossMonthInstallments(personName);
        final personPaidMonth = debtProvider.personPaidThisMonth(personName);
        final personTotalVal = debtProvider.personTotalOwed(personName);
        final displayVal = isMonthMode ? personMonthVal : personTotalVal;

        final totalRemaining = personTotalVal;
        final totalOriginal = debts.fold(0.0, (s, d) => s + d.totalAmount);
        final totalPaid = debts.fold(0.0, (s, d) => s + d.paidAmount);
        final totalMonthlyInstallment = personMonthVal;
        final overallProgress = totalOriginal > 0 ? (totalPaid / totalOriginal).clamp(0.0, 1.0) : 1.0;

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
              children: [
                // Person header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                            child: Text(
                              personName.isNotEmpty ? personName[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.primaryColor),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  personName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${debts.length} ${debts.length == 1 ? "conta ativa" : "contas ativas"}',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(displayVal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppConstants.accentAmber,
                          ),
                        ),
                        Text(
                          isMonthMode
                              ? (personPaidMonth > 0
                                  ? 'Subtotal: ${CurrencyFormatter.format(personGrossMonth)} • Abatido: -${CurrencyFormatter.format(personPaidMonth)}'
                                  : 'Neste mês • Total: ${CurrencyFormatter.format(personTotalVal)}')
                              : 'Total geral • Mês: ${CurrencyFormatter.format(personMonthVal)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isMonthMode && personPaidMonth > 0)
                          Text(
                            'Total geral acumulado: ${CurrencyFormatter.format(personTotalVal)}',
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                          )
                        else if (totalPaid > 0)
                          Text(
                            'Já pago: ${CurrencyFormatter.format(totalPaid)}',
                            style: const TextStyle(fontSize: 11, color: AppConstants.accentGreen, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Overall progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.accentGreen),
                  ),
                ),
                const SizedBox(height: 14),

                // Sub-accounts / Debts list for this person
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalhamento das Contas de $personName:',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...debts.map((d) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.receipt_outlined, size: 16, color: AppConstants.primaryColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            d.description,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isMonthMode
                                              ? '${CurrencyFormatter.format(d.remainingAmount < d.installmentValue ? d.remainingAmount : d.installmentValue)}/mês'
                                              : CurrencyFormatter.format(d.remainingAmount),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Faltam ${d.remainingInstallments} de ${d.totalInstallments}x (${CurrencyFormatter.format(d.installmentValue)}/mês) • Dia ${d.dueDay}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        // Botão manual para receber parcela desta conta específica
                                        InkWell(
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: () {
                                            debtProvider.payInstallment(
                                              debtId: d.id,
                                              financeProvider: financeProvider,
                                            );
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Parcela de "${d.description}" (${CurrencyFormatter.format(d.installmentValue)}) recebida de $personName!',
                                                ),
                                                backgroundColor: AppConstants.accentGreen,
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppConstants.accentGreen.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_rounded, size: 13, color: AppConstants.accentGreen),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Receber',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppConstants.accentGreen,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => WhatsAppReminderDialog(
                                                personName: personName,
                                                debts: [d],
                                                initialSelectedDebt: d,
                                              ),
                                            );
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            child: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF25D366)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Consolidated Actions for the Person (Responsive for Mobile)
                if (isMobile) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppConstants.accentGreen.withValues(alpha: 0.15),
                            foregroundColor: AppConstants.accentGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 15),
                          label: Text(
                            debts.length > 1
                                ? 'Receber (${CurrencyFormatter.format(totalMonthlyInstallment)})'
                                : 'Receber (${CurrencyFormatter.format(totalMonthlyInstallment)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () async {
                            await debtProvider.abatePersonDebts(
                              personName: personName,
                              amount: totalMonthlyInstallment,
                              financeProvider: financeProvider,
                              note: 'Recebimento manual das parcelas de $personName',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Recebido ${CurrencyFormatter.format(totalMonthlyInstallment)} de $personName! Adicionado às receitas.',
                                  ),
                                  backgroundColor: AppConstants.accentGreen,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppConstants.accentAmber,
                            side: const BorderSide(color: AppConstants.accentAmber),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          ),
                          icon: const Icon(Icons.price_check_rounded, size: 15),
                          label: const Text(
                            'Abater Valor',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AbatementDialog(
                                personName: personName,
                                totalOwed: totalRemaining,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (debts.any((d) => d.paymentHistory.isNotEmpty)) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.undo_rounded, size: 15),
                        label: const Text('Desfazer Abatimentos', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text('Desfazer Abatimentos'),
                                ],
                              ),
                              content: Text(
                                'Deseja desfazer os abatimentos registrados para $personName e restaurar o saldo original de todas as contas?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    final reverted = await debtProvider.revertPersonPayments(
                                      personName: personName,
                                      financeProvider: financeProvider,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Abatimentos de ${CurrencyFormatter.format(reverted)} desfeitos! Saldo restaurado.'),
                                          backgroundColor: AppConstants.accentGreen,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Sim, Restaurar Saldo'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                      label: Text(
                        debts.length > 1 ? 'Cobrar Conta Toda (WhatsApp)' : 'Cobrar no WhatsApp',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => WhatsAppReminderDialog(
                            personName: personName,
                            debts: debts,
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppConstants.accentGreen.withValues(alpha: 0.15),
                          foregroundColor: AppConstants.accentGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(
                          debts.length > 1
                              ? 'Receber Mês (${CurrencyFormatter.format(totalMonthlyInstallment)})'
                              : 'Receber (${CurrencyFormatter.format(totalMonthlyInstallment)})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          await debtProvider.abatePersonDebts(
                            personName: personName,
                            amount: totalMonthlyInstallment,
                            financeProvider: financeProvider,
                            note: 'Recebimento manual das parcelas de $personName',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Recebido ${CurrencyFormatter.format(totalMonthlyInstallment)} de $personName! Adicionado às receitas.',
                                ),
                                backgroundColor: AppConstants.accentGreen,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.accentAmber,
                          side: const BorderSide(color: AppConstants.accentAmber),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.price_check_rounded, size: 16),
                        label: const Text('Abater Valor Avulso'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AbatementDialog(
                              personName: personName,
                              totalOwed: totalRemaining,
                            ),
                          );
                        },
                      ),
                      if (debts.any((d) => d.paymentHistory.isNotEmpty))
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          icon: const Icon(Icons.undo_rounded, size: 16),
                          label: const Text('Desfazer Abatimentos'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Desfazer Abatimentos'),
                                  ],
                                ),
                                content: Text(
                                  'Deseja desfazer os abatimentos registrados para $personName e restaurar o saldo original de todas as contas?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      final reverted = await debtProvider.revertPersonPayments(
                                        personName: personName,
                                        financeProvider: financeProvider,
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Abatimentos de ${CurrencyFormatter.format(reverted)} desfeitos! Saldo restaurado.'),
                                            backgroundColor: AppConstants.accentGreen,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Sim, Restaurar Saldo'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                        label: Text(
                          debts.length > 1 ? 'Cobrar Conta Toda (WhatsApp)' : 'Cobrar no WhatsApp',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => WhatsAppReminderDialog(
                              personName: personName,
                              debts: debts,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Individual Debts List View
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
                  ? 'Clique em "Adicionar Conta" para registrar.'
                  : 'Quando uma dívida for 100% paga, ela aparecerá aqui.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                      child: Text(
                        debt.personName.isNotEmpty ? debt.personName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
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
                    Builder(
                      builder: (_) {
                        final isMonth = debtProvider.viewMode == DebtViewMode.month;
                        final debtMonthVal = debt.remainingAmount < debt.installmentValue ? debt.remainingAmount : debt.installmentValue;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isMonth && !debt.isSettled
                                  ? '${CurrencyFormatter.format(debtMonthVal)}/mês'
                                  : CurrencyFormatter.format(debt.remainingAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: debt.isSettled ? AppConstants.accentGreen : AppConstants.accentAmber,
                              ),
                            ),
                            Text(
                              isMonth && !debt.isSettled
                                  ? 'de ${CurrencyFormatter.format(debt.remainingAmount)} total'
                                  : 'de ${CurrencyFormatter.format(debt.totalAmount)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
                          '${CurrencyFormatter.format(debt.installmentValue)}/mês',
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
                const SizedBox(height: 12),

                // Bottom Actions: Receive Installment, Abate, WhatsApp & Details
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (!debt.isSettled) ...[
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppConstants.accentGreen.withOpacity(0.15),
                          foregroundColor: AppConstants.accentGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text('Receber (${CurrencyFormatter.format(debt.installmentValue)})'),
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
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.accentAmber,
                          side: const BorderSide(color: AppConstants.accentAmber),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.price_check_rounded, size: 15),
                        label: const Text('Abater'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AbatementDialog(
                              personName: debt.personName,
                              specificDebt: debt,
                              totalOwed: debt.remainingAmount,
                            ),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                        label: const Text('Cobrar WhatsApp'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => WhatsAppReminderDialog.single(debt),
                          );
                        },
                      ),
                    ] else
                      const Row(
                        mainAxisSize: MainAxisSize.min,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => DebtDetailDialog(debt: debt),
                            );
                          },
                          child: const Text('Detalhes'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          color: Colors.grey.shade400,
                          tooltip: 'Excluir cobrança',
                          onPressed: () {
                            final desc = debt.description;
                            debtProvider.deleteDebt(debt.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cobrança "$desc" removida.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
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
  }
}

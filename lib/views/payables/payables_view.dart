import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/payable_model.dart';
import '../../providers/payable_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/bank_loan_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/constants.dart';
import '../invoice/unified_invoice_view.dart';

class PayablesView extends StatefulWidget {
  const PayablesView({super.key});

  @override
  State<PayablesView> createState() => _PayablesViewState();
}

class _PayablesViewState extends State<PayablesView> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'paid'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPayables();
    });
  }

  void _syncPayables() {
    if (!mounted) return;
    final payableProvider = context.read<PayableProvider>();
    final finance = context.read<FinanceProvider>();
    final debts = context.read<DebtProvider>();
    final subs = context.read<SubscriptionProvider>();
    final loans = context.read<BankLoanProvider>();

    payableProvider.syncWithProviders(
      finance: finance,
      debts: debts,
      subscriptions: subs,
      loans: loans,
    );
  }

  @override
  Widget build(BuildContext context) {
    final payables = context.watch<PayableProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final allItems = payables.payables;
    final filteredItems = allItems.where((p) {
      if (_selectedFilter == 'pending') return !p.isPaid;
      if (_selectedFilter == 'paid') return p.isPaid;
      return true;
    }).toList();

    final urgentItems = payables.urgentPayables;

    return Scaffold(
      backgroundColor: isDark ? AppConstants.oledBlack : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          _syncPayables();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top Overview Metrics
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCycleSelector(context, payables, isDark),
                    _buildOverviewCard(context, payables, isDark, isMobile),
                    if (urgentItems.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildUrgentBanner(context, urgentItems, isDark),
                    ],
                    const SizedBox(height: 16),
                    _buildFilterTabs(context, isDark, allItems.length, payables.pendingCount),
                  ],
                ),
              ),
            ),

            // Payables Timeline
            if (filteredItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedFilter == 'pending'
                            ? Icons.check_circle_outline_rounded
                            : Icons.receipt_long_outlined,
                        size: 56,
                        color: isDark ? AppConstants.oledSubtext : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFilter == 'pending'
                            ? 'Nenhuma conta pendente para este mês!'
                            : 'Nenhuma conta encontrada.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 4,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filteredItems[index];
                      return _buildPayableTile(context, item, payables, isDark, isMobile);
                    },
                    childCount: filteredItems.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nova Conta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddPayableDialog(context, payables),
      ),
    );
  }

  Widget _buildCycleSelector(
    BuildContext context,
    PayableProvider payables,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledCard : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppConstants.oledBorder : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                payables.toggleViewingMode(true);
                _syncPayables();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: payables.isViewingOpenNextMonth
                      ? AppConstants.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upcoming_rounded,
                      size: 15,
                      color: payables.isViewingOpenNextMonth
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Fatura Aberta (Dez)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: payables.isViewingOpenNextMonth
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                payables.toggleViewingMode(false);
                _syncPayables();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: !payables.isViewingOpenNextMonth
                      ? AppConstants.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 15,
                      color: !payables.isViewingOpenNextMonth
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Fatura Paga (Nov)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: !payables.isViewingOpenNextMonth
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    PayableProvider payables,
    bool isDark,
    bool isMobile,
  ) {
    final isOpen = payables.isViewingOpenNextMonth;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      color: AppConstants.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOpen ? Icons.credit_score_rounded : Icons.check_circle_rounded,
                      color: AppConstants.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      isOpen ? 'Agenda Aberta • Dezembro' : 'Contas Pagas • Novembro',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen
                      ? (payables.pendingCount > 0
                          ? AppConstants.accentAmber.withValues(alpha: 0.15)
                          : AppConstants.accentGreen.withValues(alpha: 0.15))
                      : AppConstants.accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOpen
                      ? '${payables.pendingCount} a pagar'
                      : '100% Quitado!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOpen
                        ? (payables.pendingCount > 0
                            ? AppConstants.accentAmber
                            : AppConstants.accentGreen)
                        : AppConstants.accentGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Total Amount Breakdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpen ? 'TOTAL ABERTO (PREVISTO)' : 'TOTAL PAGO NO MÊS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(payables.totalDue),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Sub-metrics: Minha Parte vs Devedores vs Pago
          Row(
            children: [
              Expanded(
                child: _buildMetricMini(
                  title: 'Minha Parte',
                  amount: payables.myShareDue,
                  color: AppConstants.primaryColor,
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
              ),
              Expanded(
                child: _buildMetricMini(
                  title: 'Devedores',
                  amount: payables.debtorShareDue,
                  color: AppConstants.accentIndigo,
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
              ),
              Expanded(
                child: _buildMetricMini(
                  title: 'Já Pago',
                  amount: payables.totalPaid,
                  color: AppConstants.accentGreen,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
                side: BorderSide(
                  color: AppConstants.primaryColor.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.credit_card_rounded, size: 16),
              label: const Text(
                'Abrir Fatura Unificada (Estilo Nubank)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnifiedInvoiceView()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMini({
    required String title,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(amount),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentBanner(
    BuildContext context,
    List<PayableModel> urgentItems,
    bool isDark,
  ) {
    final first = urgentItems.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.accentAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppConstants.accentAmber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atenção ao Vencimento: ${first.title}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Vence dia ${first.dueDay} • ${CurrencyFormatter.format(first.totalAmount)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppConstants.oledSubtext : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(
    BuildContext context,
    bool isDark,
    int totalCount,
    int pendingCount,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', 'Todas ($totalCount)', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('pending', 'Pendentes ($pendingCount)', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('paid', 'Pagas (${totalCount - pendingCount})', isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.primaryColor
              : (isDark ? AppConstants.oledCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppConstants.primaryColor
                : (isDark ? AppConstants.oledBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildPayableTile(
    BuildContext context,
    PayableModel item,
    PayableProvider provider,
    bool isDark,
    bool isMobile,
  ) {
    Color typeColor;
    IconData typeIcon;

    switch (item.type) {
      case PayableType.creditCard:
        if (item.bank?.toLowerCase() == 'nubank') {
          typeColor = const Color(0xFF820AD1);
        } else if (item.bank?.toLowerCase() == 'itaú' || item.bank?.toLowerCase() == 'itau') {
          typeColor = const Color(0xFFEC7000);
        } else {
          typeColor = AppConstants.accentIndigo;
        }
        typeIcon = Icons.credit_card_rounded;
        break;
      case PayableType.subscription:
        typeColor = AppConstants.primaryColor;
        typeIcon = Icons.repeat_rounded;
        break;
      case PayableType.loan:
        typeColor = AppConstants.accentAmber;
        typeIcon = Icons.account_balance_rounded;
        break;
      case PayableType.boletoDDA:
      case PayableType.manual:
        typeColor = AppConstants.accentCyan;
        typeIcon = Icons.receipt_rounded;
        break;
    }

    final isPaid = item.isPaid;
    final hasDebtor = item.debtorShareAmount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? (isDark ? AppConstants.oledBorder : Colors.grey.shade200)
              : typeColor.withValues(alpha: 0.35),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            provider.togglePaid(item.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPaid
                        ? (isDark ? AppConstants.oledBorder : Colors.grey.shade200)
                        : typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'DIA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isPaid
                              ? (isDark ? AppConstants.oledSubtext : Colors.grey.shade600)
                              : typeColor,
                        ),
                      ),
                      Text(
                        '${item.dueDay}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPaid
                              ? (isDark ? AppConstants.oledSubtext : Colors.grey.shade600)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Info Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(typeIcon, size: 14, color: typeColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: isPaid ? TextDecoration.lineThrough : null,
                                color: isPaid
                                    ? (isDark ? AppConstants.oledSubtext : Colors.grey.shade500)
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Net & Debtor Tagging
                      if (hasDebtor) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Sua parte: ${CurrencyFormatter.format(item.myShareAmount)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.primaryColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppConstants.accentIndigo.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Devedores: ${CurrencyFormatter.format(item.debtorShareAmount)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.accentIndigo,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      if (item.notes != null && item.notes!.isNotEmpty)
                        Text(
                          item.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Amount & Paid Toggle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(item.totalAmount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: isPaid ? TextDecoration.lineThrough : null,
                        color: isPaid
                            ? (isDark ? AppConstants.oledSubtext : Colors.grey.shade500)
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        provider.togglePaid(item.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? AppConstants.accentGreen.withValues(alpha: 0.15)
                              : (isDark ? AppConstants.oledBorder : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              size: 14,
                              color: isPaid ? AppConstants.accentGreen : (isDark ? AppConstants.oledSubtext : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPaid ? 'Pago' : 'Pagar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? AppConstants.accentGreen : (isDark ? AppConstants.oledSubtext : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPayableDialog(BuildContext context, PayableProvider provider) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController(text: '${DateTime.now().day}');
    final notesController = TextEditingController();
    bool isRecurring = true;
    PayableType selectedType = PayableType.manual;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppConstants.oledCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: isDark ? AppConstants.oledBorder : Colors.transparent,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cadastrar Conta a Pagar',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Nome da Conta',
                        hintText: 'Ex: Aluguel, Condomínio, Energia, IPTU',
                        filled: true,
                        fillColor: isDark ? AppConstants.oledSurface : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Valor Total (R\$)',
                              hintText: '0,00',
                              filled: true,
                              fillColor: isDark ? AppConstants.oledSurface : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Dia Venc.',
                              hintText: '1 a 31',
                              filled: true,
                              fillColor: isDark ? AppConstants.oledSurface : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Observações (opcional)',
                        filled: true,
                        fillColor: isDark ? AppConstants.oledSurface : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repetir todos os meses'),
                      subtitle: const Text('Conta fixa ou recorrente'),
                      value: isRecurring,
                      activeColor: AppConstants.primaryColor,
                      onChanged: (val) {
                        setDialogState(() {
                          isRecurring = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final title = titleController.text.trim();
                          final amount = double.tryParse(
                                  amountController.text.replaceAll(',', '.')) ??
                              0.0;
                          final day = int.tryParse(dayController.text) ?? 10;

                          if (title.isEmpty || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Preencha nome e valor válidos.')),
                            );
                            return;
                          }

                          final now = DateTime.now();
                          final due = DateTime(now.year, now.month, day.clamp(1, 28));

                          final newPayable = PayableModel(
                            title: title,
                            totalAmount: amount,
                            myShareAmount: amount,
                            dueDate: due,
                            dueDay: day,
                            category: 'Contas Fixas',
                            type: selectedType,
                            isRecurring: isRecurring,
                            notes: notesController.text.trim().isNotEmpty
                                ? notesController.text.trim()
                                : null,
                          );

                          await provider.addManualPayable(newPayable);
                          _syncPayables();
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                        },
                        child: const Text(
                          'Salvar Conta',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
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

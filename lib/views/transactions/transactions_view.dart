import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../models/debt_model.dart';
import '../../providers/finance_provider.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import 'widgets/add_transaction_dialog.dart';
import 'widgets/assign_to_debt_dialog.dart';

class TransactionsView extends StatelessWidget {
  const TransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactions = finance.filteredTransactions;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extrato de Transações',
                        style: (isMobile
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.headlineSmall)
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${transactions.length} movimentações ${finance.filterBySelectedMonth ? "(filtrando por mês)" : "(todas)"}',
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
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(isMobile ? 'Nova' : 'Nova Transação'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddTransactionDialog(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Month Selector Toolbar
            _buildMonthSelector(context, finance, isDark, isMobile),
            const SizedBox(height: 14),

            // Search Bar & Filter Row (Stacked on Mobile)
            if (isMobile) ...[
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar transações...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) => finance.setSearchQuery(val),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Todas'),
                      selected: finance.typeFilter == null,
                      onSelected: (_) => finance.setTypeFilter(null),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Receitas'),
                      selected: finance.typeFilter == TransactionType.income,
                      avatar: const Icon(Icons.arrow_downward_rounded,
                          size: 14, color: AppConstants.accentGreen),
                      onSelected: (_) => finance.setTypeFilter(TransactionType.income),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Despesas'),
                      selected: finance.typeFilter == TransactionType.expense,
                      avatar: const Icon(Icons.arrow_upward_rounded,
                          size: 14, color: AppConstants.accentRed),
                      onSelected: (_) => finance.setTypeFilter(TransactionType.expense),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por descrição, banco, pessoa ou categoria...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) => finance.setSearchQuery(val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Todas'),
                        selected: finance.typeFilter == null,
                        onSelected: (_) => finance.setTypeFilter(null),
                      ),
                      FilterChip(
                        label: const Text('Receitas'),
                        selected: finance.typeFilter == TransactionType.income,
                        avatar: const Icon(Icons.arrow_downward_rounded,
                            size: 16, color: AppConstants.accentGreen),
                        onSelected: (_) => finance.setTypeFilter(TransactionType.income),
                      ),
                      FilterChip(
                        label: const Text('Despesas'),
                        selected: finance.typeFilter == TransactionType.expense,
                        avatar: const Icon(Icons.arrow_upward_rounded,
                            size: 16, color: AppConstants.accentRed),
                        onSelected: (_) => finance.setTypeFilter(TransactionType.expense),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Transactions List
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma transação encontrada',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tente ajustar seus filtros de busca.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final isIncome = tx.type == TransactionType.income;
                        final instInfo = !isIncome
                            ? (DebtModel.parseInstallmentInfo(tx.title) ??
                                (tx.installmentRef != null
                                    ? DebtModel.parseInstallmentInfo('Parcela ${tx.installmentRef}')
                                    : null))
                            : null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                            ),
                          ),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isIncome
                                      ? AppConstants.accentGreen.withValues(alpha: 0.15)
                                      : AppConstants.accentRed.withValues(alpha: 0.15),
                                  child: Icon(
                                    AppConstants.getCategoryIcon(tx.category),
                                    color: isIncome
                                        ? AppConstants.accentGreen
                                        : AppConstants.accentRed,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Row 1: Full Title + Amount
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              tx.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(tx.amount)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isIncome
                                                  ? AppConstants.accentGreen
                                                  : AppConstants.accentRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Row 2: Full Date & Category
                                      Text(
                                        '${CurrencyFormatter.formatDate(tx.date)} • ${tx.category}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Row 3: Badges on left + Action buttons (responsive wrap to prevent mobile overflow)
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                                if (tx.bank != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants.getBankColor(tx.bank)
                                                          .withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(5),
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
                                                if (tx.source != TransactionSource.manual)
                                                  _buildSourceBadge(tx.source),
                                                if (instInfo != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants.accentAmber
                                                          .withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(5),
                                                    ),
                                                    child: Text(
                                                      'Parcela ${instInfo.currentInstallment}/${instInfo.totalInstallments} • Faltam ${instInfo.remainingIncludingCurrent}x (${CurrencyFormatter.format(tx.amount * instInfo.remainingIncludingCurrent)})',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppConstants.accentAmber,
                                                      ),
                                                    ),
                                                  ),
                                                if (tx.personName != null)
                                                  InkWell(
                                                    borderRadius: BorderRadius.circular(5),
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (_) =>
                                                            AssignToDebtDialog(transaction: tx),
                                                      );
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppConstants.primaryColor
                                                            .withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(5),
                                                        border: Border.all(
                                                          color: AppConstants.primaryColor
                                                              .withValues(alpha: 0.3),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'Devedor: ${tx.personName}',
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppConstants.primaryColor,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          const Icon(
                                                            Icons.edit_outlined,
                                                            size: 10,
                                                            color: AppConstants.primaryColor,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (!isIncome) ...[
                                                InkWell(
                                                  borderRadius: BorderRadius.circular(6),
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (_) =>
                                                          AssignToDebtDialog(transaction: tx),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: (tx.personName != null
                                                              ? AppConstants.accentAmber
                                                              : AppConstants.primaryColor)
                                                          .withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          tx.personName != null
                                                              ? Icons.edit_note_rounded
                                                              : Icons.person_add_alt_1_rounded,
                                                          size: 14,
                                                          color: tx.personName != null
                                                              ? AppConstants.accentAmber
                                                              : AppConstants.primaryColor,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          tx.personName != null
                                                              ? 'Editar Devedor'
                                                              : 'Cobrar',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: tx.personName != null
                                                                ? AppConstants.accentAmber
                                                                : AppConstants.primaryColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              InkWell(
                                                borderRadius: BorderRadius.circular(6),
                                                onTap: () {
                                                  finance.deleteTransaction(tx.id);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Transação "${tx.title}" removida'),
                                                      duration: const Duration(seconds: 2),
                                                    ),
                                                  );
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.all(4),
                                                  child: Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 18,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge(TransactionSource source) {
    switch (source) {
      case TransactionSource.notification:
        return Container(
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
        );
      case TransactionSource.pdf:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'PDF',
            style: TextStyle(fontSize: 10, color: Colors.deepPurple, fontWeight: FontWeight.bold),
          ),
        );
      case TransactionSource.ofx:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'OFX',
            style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
          ),
        );
      case TransactionSource.csv:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'CSV',
            style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMonthSelector(
    BuildContext context,
    FinanceProvider finance,
    bool isDark,
    bool isMobile,
  ) {
    final selected = finance.selectedMonth;
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
      'Dezembro'
    ];
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Mês anterior',
                visualDensity: VisualDensity.compact,
                onPressed: finance.filterBySelectedMonth
                    ? () {
                        final prev = DateTime(selected.year, selected.month - 1);
                        finance.setSelectedMonth(prev);
                      }
                    : null,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.calendar_month_rounded, size: 18, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text(
                finance.filterBySelectedMonth ? label : 'Todos os Meses (Sem Filtro)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Próximo mês',
                visualDensity: VisualDensity.compact,
                onPressed: finance.filterBySelectedMonth
                    ? () {
                        final next = DateTime(selected.year, selected.month + 1);
                        finance.setSelectedMonth(next);
                      }
                    : null,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilterChip(
                label: Text(finance.filterBySelectedMonth ? 'Filtrando Mês' : 'Todos os Meses'),
                selected: finance.filterBySelectedMonth,
                avatar: Icon(
                  finance.filterBySelectedMonth ? Icons.filter_alt_rounded : Icons.all_inclusive_rounded,
                  size: 14,
                  color: AppConstants.primaryColor,
                ),
                onSelected: (val) => finance.toggleMonthFilter(val),
              ),
              if (finance.filterBySelectedMonth && (selected.year != 2026 || selected.month != 11)) ...[
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppConstants.primaryColor,
                  ),
                  onPressed: () => finance.setSelectedMonth(DateTime(2026, 11)),
                  child: const Text('Ir para Nov/2026'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

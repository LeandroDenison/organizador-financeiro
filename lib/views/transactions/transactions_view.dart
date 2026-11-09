import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/finance_provider.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import 'widgets/add_transaction_dialog.dart';

class TransactionsView extends StatelessWidget {
  const TransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactions = finance.filteredTransactions;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extrato de Transações',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transactions.length} movimentações encontradas',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nova Transação'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddTransactionDialog(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar & Filter Row
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => finance.setSearchQuery(val),
                  ),
                ),
                const SizedBox(width: 12),
                // Type Filter Chips
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
                      avatar: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppConstants.accentGreen),
                      onSelected: (_) => finance.setTypeFilter(TransactionType.income),
                    ),
                    FilterChip(
                      label: const Text('Despesas'),
                      selected: finance.typeFilter == TransactionType.expense,
                      avatar: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppConstants.accentRed),
                      onSelected: (_) => finance.setTypeFilter(TransactionType.expense),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Transactions List
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma transação encontrada',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tente ajustar seus filtros de busca ou adicione uma nova transação.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final isIncome = tx.type == TransactionType.income;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                            ),
                          ),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isIncome
                                  ? AppConstants.accentGreen.withOpacity(0.15)
                                  : AppConstants.accentRed.withOpacity(0.15),
                              child: Icon(
                                AppConstants.getCategoryIcon(tx.category),
                                color: isIncome ? AppConstants.accentGreen : AppConstants.accentRed,
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    tx.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (tx.bank != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppConstants.getBankColor(tx.bank).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tx.bank!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.getBankColor(tx.bank),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                _buildSourceBadge(tx.source),
                              ],
                            ),
                            subtitle: Text(
                              '${CurrencyFormatter.formatDate(tx.date)} • ${tx.category}${tx.personName != null ? " • Devedor: ${tx.personName}" : ""}${tx.installmentRef != null ? " (${tx.installmentRef})" : ""}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(tx.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isIncome ? AppConstants.accentGreen : AppConstants.accentRed,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                  color: Colors.grey.shade400,
                                  onPressed: () {
                                    finance.deleteTransaction(tx.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Transação "${tx.title}" removida'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
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
            color: Colors.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_active_rounded, size: 11, color: Colors.blue),
              SizedBox(width: 2),
              Text(
                'Notificação',
                style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      case TransactionSource.ofx:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.15),
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
            color: Colors.amber.withOpacity(0.15),
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
}

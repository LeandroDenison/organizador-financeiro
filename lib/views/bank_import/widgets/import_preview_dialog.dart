import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/finance_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/currency_formatter.dart';
import '../../transactions/widgets/assign_to_debt_dialog.dart';

class ImportPreviewDialog extends StatefulWidget {
  final String bankName;
  final List<TransactionModel> parsedTransactions;

  const ImportPreviewDialog({
    super.key,
    required this.bankName,
    required this.parsedTransactions,
  });

  @override
  State<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<ImportPreviewDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.parsedTransactions.map((t) => t.id).toSet();
  }

  void _importSelected() {
    final selectedList = widget.parsedTransactions
        .where((t) => _selectedIds.contains(t.id))
        .toList();

    context.read<FinanceProvider>().addMultipleTransactions(selectedList);
    Navigator.of(context).pop(selectedList.length);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedList = widget.parsedTransactions
        .where((t) => _selectedIds.contains(t.id))
        .toList();

    final totalExpenses = selectedList
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);

    final totalIncomes = selectedList
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.getBankColor(widget.bankName).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: AppConstants.getBankColor(widget.bankName),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extrato: ${widget.bankName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.parsedTransactions.length} movimentações encontradas',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
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
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            // Top Selection & Totals bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selectedIds.length == widget.parsedTransactions.length,
                        tristate: _selectedIds.isNotEmpty &&
                            _selectedIds.length < widget.parsedTransactions.length,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds = widget.parsedTransactions.map((t) => t.id).toSet();
                            } else {
                              _selectedIds.clear();
                            }
                          });
                        },
                      ),
                      Text(
                        'Selecionados (${_selectedIds.length}/${widget.parsedTransactions.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Despesas: ${CurrencyFormatter.format(totalExpenses)}',
                        style: const TextStyle(color: AppConstants.accentRed, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Receitas: ${CurrencyFormatter.format(totalIncomes)}',
                        style: const TextStyle(color: AppConstants.accentGreen, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Transactions list with checkboxes
            Expanded(
              child: ListView.separated(
                itemCount: widget.parsedTransactions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tx = widget.parsedTransactions[index];
                  final isSelected = _selectedIds.contains(tx.id);
                  final isIncome = tx.type == TransactionType.income;

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(tx.id);
                        } else {
                          _selectedIds.remove(tx.id);
                        }
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor: isIncome
                          ? AppConstants.accentGreen.withOpacity(0.15)
                          : AppConstants.accentRed.withOpacity(0.15),
                      child: Icon(
                        AppConstants.getCategoryIcon(tx.category),
                        color: isIncome ? AppConstants.accentGreen : AppConstants.accentRed,
                        size: 18,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tx.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(tx.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isIncome ? AppConstants.accentGreen : AppConstants.accentRed,
                              ),
                            ),
                            if (!isIncome) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                color: AppConstants.primaryColor,
                                tooltip: 'Atribuir a Quem me Deve',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final assigned = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AssignToDebtDialog(transaction: tx),
                                  );
                                  if (assigned == true) {
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${CurrencyFormatter.formatDate(tx.date)} • ${tx.category}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        if (tx.personName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Atribuído a: ${tx.personName}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.download_done_rounded),
          label: Text('Importar (${_selectedIds.length}) Transações'),
          onPressed: _selectedIds.isEmpty ? null : _importSelected,
        ),
      ],
    );
  }
}

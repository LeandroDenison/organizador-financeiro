import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/debt_provider.dart';
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

  Future<void> _importSelected() async {
    final selectedList = widget.parsedTransactions
        .where((t) => _selectedIds.contains(t.id))
        .toList();

    final financeProvider = context.read<FinanceProvider>();
    final debtProvider = context.read<DebtProvider>();

    // Check if any imported income (Pix received) matches an active debtor / specific debt amount
    final List<TransactionModel> finalTransactions = [];
    for (final tx in selectedList) {
      if (tx.type == TransactionType.income) {
        final matchedPerson = debtProvider.findMatchingPerson(tx.title, amount: tx.amount);
        if (matchedPerson != null) {
          final matchedDebt = debtProvider.findExactDebtByAmount(
            personName: matchedPerson,
            amount: tx.amount,
          );
          await debtProvider.abatePersonDebts(
            personName: matchedPerson,
            amount: tx.amount,
            financeProvider: financeProvider,
            note: matchedDebt != null
                ? 'Pix reconhecido no extrato para "${matchedDebt.description}"'
                : 'Pix reconhecido no extrato (${widget.bankName})',
            addToTransactions: false,
          );
          finalTransactions.add(
            tx.copyWith(
              personName: matchedPerson,
              personId: matchedDebt?.id,
              category: 'Empréstimo Recebido',
              notes: matchedDebt != null
                  ? 'Abatido automaticamente da conta: ${matchedDebt.description}'
                  : 'Abatido automaticamente das contas de $matchedPerson',
            ),
          );
          continue;
        }
      }
      finalTransactions.add(tx);
    }

    await financeProvider.addMultipleTransactions(finalTransactions);
    if (mounted) {
      Navigator.of(context).pop(finalTransactions.length);
    }
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.getBankColor(widget.bankName).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: AppConstants.getBankColor(widget.bankName),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extrato: ${widget.bankName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
            visualDensity: VisualDensity.compact,
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
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: _selectedIds.length == widget.parsedTransactions.length
                              ? true
                              : (_selectedIds.isEmpty ? false : null),
                          tristate: true,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Selecionados (${_selectedIds.length}/${widget.parsedTransactions.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Despesas: ${CurrencyFormatter.format(totalExpenses)}',
                        style: const TextStyle(
                          color: AppConstants.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Receitas: ${CurrencyFormatter.format(totalIncomes)}',
                        style: const TextStyle(
                          color: AppConstants.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Transactions list with custom responsive row
            Expanded(
              child: ListView.separated(
                itemCount: widget.parsedTransactions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tx = widget.parsedTransactions[index];
                  final isSelected = _selectedIds.contains(tx.id);
                  final isIncome = tx.type == TransactionType.income;
                  final debtProvider = context.watch<DebtProvider>();
                  final autoMatchedPerson = isIncome
                      ? debtProvider.findMatchingPerson(tx.title, amount: tx.amount)
                      : null;
                  final autoMatchedDebt = autoMatchedPerson != null
                      ? debtProvider.findExactDebtByAmount(personName: autoMatchedPerson, amount: tx.amount)
                      : null;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(tx.id);
                        } else {
                          _selectedIds.add(tx.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: isIncome
                                ? AppConstants.accentGreen.withValues(alpha: 0.15)
                                : AppConstants.accentRed.withValues(alpha: 0.15),
                            child: Icon(
                              AppConstants.getCategoryIcon(tx.category),
                              color: isIncome ? AppConstants.accentGreen : AppConstants.accentRed,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${CurrencyFormatter.formatDate(tx.date)} • ${tx.category}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                if (tx.personName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Devedor: ${tx.personName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primaryColor,
                                    ),
                                  ),
                                ] else if (autoMatchedPerson != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    autoMatchedDebt != null
                                        ? '✓ Abater de $autoMatchedPerson (${autoMatchedDebt.description})'
                                        : '✓ Abater dívida de $autoMatchedPerson',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.accentGreen,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(tx.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isIncome ? AppConstants.accentGreen : AppConstants.accentRed,
                                ),
                              ),
                              if (!isIncome) ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () async {
                                    final assigned = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AssignToDebtDialog(transaction: tx),
                                    );
                                    if (assigned == true) {
                                      setState(() {});
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppConstants.primaryColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 13,
                                          color: AppConstants.primaryColor,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Cobrar',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Checkbox(
                              value: isSelected,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedIds.add(tx.id);
                                  } else {
                                    _selectedIds.remove(tx.id);
                                  }
                                });
                              },
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
          icon: const Icon(Icons.download_done_rounded, size: 18),
          label: Text('Importar (${_selectedIds.length}) Transações'),
          onPressed: _selectedIds.isEmpty ? null : _importSelected,
        ),
      ],
    );
  }
}

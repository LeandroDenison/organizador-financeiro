import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/debt_model.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/currency_formatter.dart';

class AbatementDialog extends StatefulWidget {
  final String personName;
  final DebtModel? specificDebt;
  final double totalOwed;

  const AbatementDialog({
    super.key,
    required this.personName,
    this.specificDebt,
    required this.totalOwed,
  });

  @override
  State<AbatementDialog> createState() => _AbatementDialogState();
}

class _AbatementDialogState extends State<AbatementDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController(text: 'Pagamento avulso / Pix recebido');
  bool _recordAsIncome = true;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) return;

    final debtProvider = context.read<DebtProvider>();
    final financeProvider = context.read<FinanceProvider>();

    if (widget.specificDebt != null) {
      debtProvider.abateDebtAmount(
        debtId: widget.specificDebt!.id,
        amount: amount,
        financeProvider: financeProvider,
        note: _noteController.text.trim(),
        addToTransactions: _recordAsIncome,
      );
    } else {
      debtProvider.abatePersonDebts(
        personName: widget.personName,
        amount: amount,
        financeProvider: financeProvider,
        note: _noteController.text.trim(),
        addToTransactions: _recordAsIncome,
      );
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Abatimento de ${CurrencyFormatter.format(amount)} registrado para ${widget.personName}!',
        ),
        backgroundColor: AppConstants.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.accentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.price_check_rounded, color: AppConstants.accentGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abater Valor: ${widget.personName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.specificDebt != null
                      ? 'Conta: ${widget.specificDebt!.description}'
                      : 'Distribuir entre todas as contas de ${widget.personName}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 600 ? double.maxFinite : 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saldo em Aberto:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    CurrencyFormatter.format(widget.totalOwed),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor Pago / Abatido (R\$)',
                hintText: 'Ex: 1000,00',
                prefixIcon: Icon(Icons.monetization_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Observação',
                prefixIcon: Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _recordAsIncome,
              title: const Text('Registrar entrada nas receitas (Extrato)', style: TextStyle(fontSize: 12)),
              onChanged: (val) => setState(() => _recordAsIncome = val ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.accentGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Confirmar Abatimento'),
        ),
      ],
    );
  }
}

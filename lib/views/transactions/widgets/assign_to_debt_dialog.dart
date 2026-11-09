import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction_model.dart';
import '../../../models/debt_model.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/currency_formatter.dart';

class AssignToDebtDialog extends StatefulWidget {
  final TransactionModel transaction;

  const AssignToDebtDialog({super.key, required this.transaction});

  @override
  State<AssignToDebtDialog> createState() => _AssignToDebtDialogState();
}

class _AssignToDebtDialogState extends State<AssignToDebtDialog> {
  final _descriptionController = TextEditingController();
  final _newPersonController = TextEditingController();
  final _currentInstallmentController = TextEditingController(text: '1');
  final _installmentsController = TextEditingController(text: '1');
  final _dueDayController = TextEditingController(text: '10');

  String? _selectedPerson;
  bool _isCreatingNewPerson = false;
  bool _isInstallmentValue = false; // true when transaction.amount is 1 installment (e.g. "Parcela 4/10")

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.transaction.title;

    final parsedInfo = DebtModel.parseInstallmentInfo(widget.transaction.title) ??
        (widget.transaction.installmentRef != null
            ? DebtModel.parseInstallmentInfo('Parcela ${widget.transaction.installmentRef}')
            : null);

    if (parsedInfo != null) {
      _isInstallmentValue = true;
      _currentInstallmentController.text = '${parsedInfo.currentInstallment}';
      _installmentsController.text = '${parsedInfo.totalInstallments}';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final names = context.read<DebtProvider>().uniquePersonNames;
    if (_selectedPerson == null && names.isNotEmpty) {
      _selectedPerson = names.first;
    } else if (names.isEmpty) {
      _isCreatingNewPerson = true;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _newPersonController.dispose();
    _currentInstallmentController.dispose();
    _installmentsController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  void _save() {
    final personName = _isCreatingNewPerson
        ? _newPersonController.text.trim()
        : (_selectedPerson ?? _newPersonController.text.trim());

    if (personName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe o nome da pessoa.')),
      );
      return;
    }

    final totalInst = (int.tryParse(_installmentsController.text) ?? 1).clamp(1, 72);
    final currentInst = (int.tryParse(_currentInstallmentController.text) ?? 1).clamp(1, totalInst);
    final dueDay = (int.tryParse(_dueDayController.text) ?? 10).clamp(1, 31);
    final description = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : widget.transaction.title;

    final int remainingInst = _isInstallmentValue
        ? (totalInst - currentInst + 1).clamp(1, totalInst)
        : totalInst;

    final double instVal = _isInstallmentValue
        ? widget.transaction.amount
        : (totalInst > 0 ? (widget.transaction.amount / totalInst) : widget.transaction.amount);

    final double fullTotalAmount = _isInstallmentValue
        ? (widget.transaction.amount * totalInst)
        : widget.transaction.amount;

    final double remainingTotalAmount = instVal * remainingInst;

    final debt = DebtModel(
      personName: personName,
      description: description,
      totalAmount: fullTotalAmount,
      totalInstallments: totalInst,
      remainingInstallments: remainingInst,
      installmentValue: instVal,
      customRemainingAmount: remainingTotalAmount,
      dueDay: dueDay,
    );

    // 1. Add debt to DebtProvider
    context.read<DebtProvider>().addDebt(debt);

    // 2. Link transaction to this person
    context.read<FinanceProvider>().updateTransaction(
          widget.transaction.copyWith(
            personName: personName,
            personId: debt.id,
            installmentRef: totalInst > 1 ? '$currentInst/$totalInst' : widget.transaction.installmentRef,
            notes: '${widget.transaction.notes ?? ""}\nAtribuído a $personName em Quem me Deve'
                .trim(),
          ),
        );

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          totalInst > 1
              ? 'Atribuído a $personName: Parcela $currentInst/$totalInst (restam $remainingInst de ${CurrencyFormatter.format(instVal)})!'
              : 'Despesa atribuída com sucesso a $personName!',
        ),
        backgroundColor: AppConstants.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debtProvider = context.watch<DebtProvider>();
    final names = debtProvider.uniquePersonNames;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int totalInst = (int.tryParse(_installmentsController.text) ?? 1).clamp(1, 72);
    final int currentInst = (int.tryParse(_currentInstallmentController.text) ?? 1).clamp(1, totalInst);
    final int remainingInst = _isInstallmentValue
        ? (totalInst - currentInst + 1).clamp(1, totalInst)
        : totalInst;
    final double instVal = _isInstallmentValue
        ? widget.transaction.amount
        : (totalInst > 0 ? (widget.transaction.amount / totalInst) : widget.transaction.amount);
    final double fullTotalAmount = _isInstallmentValue
        ? (widget.transaction.amount * totalInst)
        : widget.transaction.amount;
    final double remainingTotalAmount = instVal * remainingInst;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded, color: AppConstants.primaryColor),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Atribuir Conta a Alguém',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary of expense
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.transaction.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${CurrencyFormatter.formatDate(widget.transaction.date)} • ${widget.transaction.bank ?? "Conta"}',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(widget.transaction.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppConstants.accentRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Select or Add Person
              const Text(
                'Quem deve pagar por essa despesa?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (names.isNotEmpty && !_isCreatingNewPerson) ...[
                DropdownButtonFormField<String>(
                  value: _selectedPerson,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Selecionar Pessoa Cadastrada',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: names.map((name) {
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedPerson = val);
                  },
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => setState(() => _isCreatingNewPerson = true),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Cadastrar outra pessoa'),
                ),
              ] else ...[
                TextField(
                  controller: _newPersonController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nome da Pessoa (ex: Sérgio, Lucas)',
                    prefixIcon: const Icon(Icons.person_add_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: names.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.list_rounded),
                            tooltip: 'Escolher da lista existente',
                            onPressed: () => setState(() => _isCreatingNewPerson = false),
                          )
                        : null,
                  ),
                ),
                if (names.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: TextButton(
                      onPressed: () => setState(() => _isCreatingNewPerson = false),
                      child: const Text('Voltar para lista de pessoas existentes'),
                    ),
                  ),
              ],
              const SizedBox(height: 12),

              // Description
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição da Conta',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Toggle whether invoice value is 1 installment or total amount
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Valor acima é de 1 parcela da fatura',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _isInstallmentValue
                      ? 'Multiplica pelas parcelas restantes (ideal p/ compras parceladas no cartão)'
                      : 'Divide o valor pelo número de parcelas',
                  style: const TextStyle(fontSize: 11),
                ),
                value: _isInstallmentValue,
                onChanged: (val) => setState(() => _isInstallmentValue = val),
              ),
              const SizedBox(height: 8),

              // Installments & Due Day
              Row(
                children: [
                  if (_isInstallmentValue) ...[
                    Expanded(
                      child: TextField(
                        controller: _currentInstallmentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Parcela Atual',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _installmentsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _isInstallmentValue ? 'Total Parcelas' : 'Nº Parcelas',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _dueDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dia Venc.',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Installment value preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isInstallmentValue
                          ? 'Parcela $currentInst de $totalInst (${CurrencyFormatter.format(instVal)}/mês)'
                          : '$totalInst x de ${CurrencyFormatter.format(instVal)}/mês',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isInstallmentValue
                          ? 'Faltam $remainingInst parcelas • Saldo restante: ${CurrencyFormatter.format(remainingTotalAmount)} (Total ${totalInst}x: ${CurrencyFormatter.format(fullTotalAmount)})'
                          : 'Total a cobrar: ${CurrencyFormatter.format(fullTotalAmount)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: const Text('Salvar em Quem me Deve'),
        ),
      ],
    );
  }
}

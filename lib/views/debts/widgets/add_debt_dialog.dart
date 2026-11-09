import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/debt_model.dart';
import '../../../providers/debt_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/currency_formatter.dart';

class AddDebtDialog extends StatefulWidget {
  const AddDebtDialog({super.key});

  @override
  State<AddDebtDialog> createState() => _AddDebtDialogState();
}

class _AddDebtDialogState extends State<AddDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  final _personNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _totalInstallmentsController = TextEditingController(text: '1');
  final _remainingInstallmentsController = TextEditingController(text: '1');
  final _dueDayController = TextEditingController(text: '10');

  double _calculatedInstallment = 0.0;

  @override
  void initState() {
    super.initState();
    _totalAmountController.addListener(_recalc);
    _totalInstallmentsController.addListener(_recalc);
  }

  void _recalc() {
    final clean = _totalAmountController.text.replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(clean) ?? 0.0;
    final installments = int.tryParse(_totalInstallmentsController.text) ?? 1;

    setState(() {
      _calculatedInstallment = installments > 0 ? (amount / installments) : amount;
    });
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _totalAmountController.dispose();
    _totalInstallmentsController.dispose();
    _remainingInstallmentsController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final clean = _totalAmountController.text.replaceAll('.', '').replaceAll(',', '.');
    final totalAmount = double.tryParse(clean) ?? 0.0;
    final totalInstallments = int.tryParse(_totalInstallmentsController.text) ?? 1;
    final remainingInstallments = int.tryParse(_remainingInstallmentsController.text) ?? totalInstallments;
    final dueDay = int.tryParse(_dueDayController.text) ?? 10;

    final debt = DebtModel(
      personName: _personNameController.text.trim(),
      description: _descriptionController.text.trim(),
      contact: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
      totalAmount: totalAmount,
      totalInstallments: totalInstallments,
      remainingInstallments: remainingInstallments.clamp(0, totalInstallments),
      dueDay: dueDay.clamp(1, 31),
      installmentValue: _calculatedInstallment,
    );

    context.read<DebtProvider>().addDebt(debt);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add_rounded, color: AppConstants.primaryColor),
          SizedBox(width: 8),
          Text('Registrar Empréstimo / Dívida'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Person Name
                TextFormField(
                  controller: _personNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Pessoa',
                    hintText: 'Ex: Carlos Silva, Juliana, etc.',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome da pessoa' : null,
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Descrição',
                    hintText: 'Ex: Celular, Viagem, Divisão de conta',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
                ),
                const SizedBox(height: 12),

                // Contact
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contato / Chave Pix (Opcional)',
                    hintText: 'Ex: (11) 98765-4321 ou pix@email.com',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Total Amount
                TextFormField(
                  controller: _totalAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor Total Emprestado (R\$)',
                    hintText: 'Ex: 1200,00',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o valor total';
                    final clean = v.replaceAll('.', '').replaceAll(',', '.');
                    final val = double.tryParse(clean);
                    if (val == null || val <= 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Installments Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _totalInstallmentsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Parcelas',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Mínimo 1';
                          return null;
                        },
                        onChanged: (val) {
                          if (_remainingInstallmentsController.text.isEmpty ||
                              _remainingInstallmentsController.text == '1') {
                            _remainingInstallmentsController.text = val;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _remainingInstallmentsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Parcelas Restantes',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _dueDayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dia Venc.',
                          hintText: '1 a 31',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1 || n > 31) return '1 a 31';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calculation Preview Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate_rounded, color: AppConstants.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Valor de cada parcela: ${CurrencyFormatter.format(_calculatedInstallment)}/mês',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Salvar Empréstimo'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/debt_model.dart';
import '../../../services/storage_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/currency_formatter.dart';

class WhatsAppReminderDialog extends StatefulWidget {
  final String personName;
  final List<DebtModel> debts;
  final DebtModel? initialSelectedDebt;

  const WhatsAppReminderDialog({
    super.key,
    required this.personName,
    required this.debts,
    this.initialSelectedDebt,
  });

  /// Factory helper for single debt
  factory WhatsAppReminderDialog.single(DebtModel debt) {
    return WhatsAppReminderDialog(
      personName: debt.personName,
      debts: [debt],
      initialSelectedDebt: debt,
    );
  }

  @override
  State<WhatsAppReminderDialog> createState() => _WhatsAppReminderDialogState();
}

class _WhatsAppReminderDialogState extends State<WhatsAppReminderDialog> {
  final _messageController = TextEditingController();
  final _pixKeyController = TextEditingController();
  bool _isLoading = true;

  // Charge mode: true = charge whole balance (all accounts), false = specific account
  bool _chargeAllAccounts = true;
  DebtModel? _selectedDebt;
  bool _includeAbatements = true;

  @override
  void initState() {
    super.initState();
    _selectedDebt = widget.initialSelectedDebt ?? (widget.debts.isNotEmpty ? widget.debts.first : null);
    if (widget.debts.length == 1) {
      _chargeAllAccounts = false;
    }
    _loadPixKeyAndGenerate();
  }

  Future<void> _loadPixKeyAndGenerate() async {
    final pixKey = await StorageService.getUserPixKey();
    _pixKeyController.text = pixKey;
    _generateMessage(pixKey);
    setState(() => _isLoading = false);
  }

  void _generateMessage(String pixKey) {
    final buffer = StringBuffer();
    buffer.writeln('Olá ${widget.personName}! Tudo bem?');
    buffer.writeln('Passando para te mandar o resumo financeiro das suas contas em aberto:');
    buffer.writeln();

    if (_chargeAllAccounts && widget.debts.length > 1) {
      // Consolidated bill for ALL accounts
      double totalOriginal = 0.0;
      double totalPaid = 0.0;
      double totalRemaining = 0.0;
      double totalThisMonth = 0.0;

      for (int i = 0; i < widget.debts.length; i++) {
        final d = widget.debts[i];
        totalOriginal += d.totalAmount;
        totalPaid += d.paidAmount;
        totalRemaining += d.remainingAmount;
        totalThisMonth += d.installmentValue;

        final nextInst = d.paidInstallments + 1;
        buffer.writeln(
          '📌 ${d.description}: Parcela $nextInst de ${d.totalInstallments} no valor de ${CurrencyFormatter.format(d.installmentValue)} (Vencimento dia ${d.dueDay})',
        );
      }

      buffer.writeln();
      buffer.writeln('💰 Total das parcelas deste mês: ${CurrencyFormatter.format(totalThisMonth)}');

      if (_includeAbatements && totalPaid > 0) {
        buffer.writeln('📊 Valor total original: ${CurrencyFormatter.format(totalOriginal)}');
        buffer.writeln('✅ Já recebido/abatido: ${CurrencyFormatter.format(totalPaid)}');
      }

      buffer.writeln('🎯 Saldo total restante em aberto: ${CurrencyFormatter.format(totalRemaining)}');
    } else {
      // Specific single account bill
      final target = _selectedDebt ?? widget.debts.first;
      final nextInst = target.paidInstallments + 1;
      final valueStr = CurrencyFormatter.format(target.installmentValue);

      buffer.writeln(
        'Lembrando da parcela $nextInst de ${target.totalInstallments} (${CurrencyFormatter.format(target.installmentValue)}/mês) referente a "${target.description}", com vencimento dia ${target.dueDay}.',
      );

      if (_includeAbatements && target.paidAmount > 0) {
        buffer.writeln();
        buffer.writeln('📊 Valor original: ${CurrencyFormatter.format(target.totalAmount)}');
        buffer.writeln('✅ Já recebido/abatido: ${CurrencyFormatter.format(target.paidAmount)}');
        buffer.writeln('🎯 Restante a pagar: ${CurrencyFormatter.format(target.remainingAmount)}');
      }
    }

    buffer.writeln();
    buffer.writeln('Minha chave Pix: ${pixKey.isNotEmpty ? pixKey : "[INSERIR SUA CHAVE PIX]"}');
    buffer.writeln();
    buffer.writeln('Qualquer dúvida ou comprovante me manda aqui, valeu!');

    _messageController.text = buffer.toString();
  }

  void _onPixKeyChanged(String newKey) {
    StorageService.setUserPixKey(newKey.trim());
    setState(() {
      _generateMessage(newKey.trim());
    });
  }

  Future<void> _openWhatsApp() async {
    final text = _messageController.text.trim();
    String? phone = _selectedDebt?.contact ?? widget.debts.firstOrNull?.contact;

    String cleanPhone = '';
    if (phone != null && phone.isNotEmpty) {
      cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (!cleanPhone.startsWith('55') && cleanPhone.length >= 10) {
        cleanPhone = '55$cleanPhone';
      }
    }

    final encodedText = Uri.encodeComponent(text);
    final urlString = cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=$encodedText'
        : 'https://wa.me/?text=$encodedText';

    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensagem copiada! Abra o WhatsApp e cole para o contato.'),
            backgroundColor: AppConstants.accentGreen,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pixKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMultiple = widget.debts.length > 1;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cobrança WhatsApp: ${widget.personName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  hasMultiple
                      ? '${widget.debts.length} contas ativas cadastradas'
                      : 'Lembrete educado com chave Pix',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Selector if person has multiple debts
                    if (hasMultiple) ...[
                      const Text(
                        'O que você deseja cobrar?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Conta Toda (Consolidada)', style: TextStyle(fontSize: 12)),
                              selected: _chargeAllAccounts,
                              onSelected: (val) {
                                setState(() {
                                  _chargeAllAccounts = true;
                                  _generateMessage(_pixKeyController.text);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Conta Específica', style: TextStyle(fontSize: 12)),
                              selected: !_chargeAllAccounts,
                              onSelected: (val) {
                                setState(() {
                                  _chargeAllAccounts = false;
                                  _generateMessage(_pixKeyController.text);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // If specific account selected, choose which one
                      if (!_chargeAllAccounts) ...[
                        DropdownButtonFormField<DebtModel>(
                          value: _selectedDebt,
                          decoration: const InputDecoration(
                            labelText: 'Selecione a conta para cobrar',
                            prefixIcon: Icon(Icons.receipt_rounded),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: widget.debts.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(
                                '${d.description} (${CurrencyFormatter.format(d.installmentValue)}/mês)',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (d) {
                            if (d != null) {
                              setState(() {
                                _selectedDebt = d;
                                _generateMessage(_pixKeyController.text);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    // Checkbox for Abatements
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Exibir abatimentos já pagos (ex: R\$ 1.000 já abatidos)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      value: _includeAbatements,
                      onChanged: (val) {
                        setState(() {
                          _includeAbatements = val ?? true;
                          _generateMessage(_pixKeyController.text);
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Chave Pix
                    TextField(
                      controller: _pixKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Sua Chave Pix para Recebimento',
                        hintText: 'CPF, Celular, E-mail ou Chave Aleatória',
                        prefixIcon: Icon(Icons.pix_rounded, color: AppConstants.accentGreen),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: _onPixKeyChanged,
                    ),
                    const SizedBox(height: 12),

                    // Mensagem pré-formatada editável
                    TextField(
                      controller: _messageController,
                      maxLines: 7,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Mensagem Formatada (Você pode editar antes de enviar)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Copiar texto
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copiar Texto'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _messageController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mensagem e chave Pix copiadas!'),
                              backgroundColor: AppConstants.accentGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.send_rounded),
          label: const Text('Abrir no WhatsApp'),
          onPressed: _openWhatsApp,
        ),
      ],
    );
  }
}

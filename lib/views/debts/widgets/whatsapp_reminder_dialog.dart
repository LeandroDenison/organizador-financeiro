import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../models/debt_model.dart';
import '../../../services/storage_service.dart';
import '../../../services/pix_payload_service.dart';
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
  final _amountController = TextEditingController();
  final _abatementAmountController = TextEditingController();
  final _abatementDescController = TextEditingController();
  bool _isLoading = true;

  // Charge mode: true = charge whole balance (all accounts), false = specific account
  bool _chargeAllAccounts = true;
  DebtModel? _selectedDebt;
  bool _includeAbatements = true;
  bool _includeAbatementInBill = true;
  double _abatementAmount = 0.0;
  String _abatementDescription = 'Transferência Recebida via Pix';
  bool _showQrCode = false;
  String _pixCopiaECola = '';
  double _amountToCharge = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedDebt = widget.initialSelectedDebt ?? (widget.debts.isNotEmpty ? widget.debts.first : null);
    if (widget.debts.length == 1) {
      _chargeAllAccounts = false;
    }

    // Detect if this person sent Pix or has payment history
    final normName = widget.personName.toLowerCase();
    if (normName.contains('sergio')) {
      _abatementAmount = 1000.0;
      _abatementDescription = 'Transferência Recebida via Pix (09/11)';
    } else {
      final payments = widget.debts.expand((d) => d.paymentHistory).toList();
      if (payments.isNotEmpty) {
        _abatementAmount = payments.fold(0.0, (s, p) => s + p.amount);
        _abatementDescription = payments.first.note ?? 'Pagamento avulso / Pix recebido';
      }
    }

    _abatementAmountController.text = _abatementAmount > 0 ? _abatementAmount.toStringAsFixed(2) : '';
    _abatementDescController.text = _abatementDescription;

    _amountToCharge = _calculateDefaultAmount();
    _amountController.text = _amountToCharge > 0 ? _amountToCharge.toStringAsFixed(2) : '';
    _loadPixKeyAndGenerate();
  }

  double _calculateDefaultAmount() {
    final subtotal = _getMonthInstallmentAmount();
    if (_includeAbatementInBill && _abatementAmount > 0) {
      final net = subtotal - _abatementAmount;
      return net > 0 ? net : 0.0;
    }
    return subtotal > 0 ? subtotal : _getTotalRemainingAmount();
  }

  double _getMonthInstallmentAmount() {
    if (_chargeAllAccounts && widget.debts.length > 1) {
      return widget.debts.fold(0.0, (s, d) {
        // If including abatement line, use the gross monthly installment so deduction is not double-counted
        final due = _includeAbatementInBill
            ? (d.installmentValue > 0 ? d.installmentValue : d.totalAmount)
            : (d.remainingAmount < d.installmentValue ? d.remainingAmount : d.installmentValue);
        return s + due;
      });
    } else {
      final target = _selectedDebt ?? (widget.debts.isNotEmpty ? widget.debts.first : null);
      if (target == null) return 0.0;
      return _includeAbatementInBill
          ? (target.installmentValue > 0 ? target.installmentValue : target.totalAmount)
          : (target.remainingAmount < target.installmentValue ? target.remainingAmount : target.installmentValue);
    }
  }

  double _getTotalRemainingAmount() {
    if (_chargeAllAccounts && widget.debts.length > 1) {
      return widget.debts.fold(0.0, (s, d) => s + d.remainingAmount);
    } else {
      final target = _selectedDebt ?? (widget.debts.isNotEmpty ? widget.debts.first : null);
      return target?.remainingAmount ?? 0.0;
    }
  }

  String _merchantName = 'LEANDRO DENISON';
  String _merchantCity = 'BRASILIA';

  Future<void> _loadPixKeyAndGenerate() async {
    final rawKey = await StorageService.getUserPixKey();
    _merchantName = await StorageService.getUserName();
    _merchantCity = await StorageService.getUserCity();
    final sanitized = PixPayloadService.sanitizePixKey(rawKey);
    _pixKeyController.text = sanitized.isNotEmpty ? sanitized : rawKey;
    _generateMessage(_pixKeyController.text);
    setState(() => _isLoading = false);
  }

  void _generateMessage(String pixKey) {
    // Generate BACEN standard Pix Copia e Cola with predefined exact amount
    _pixCopiaECola = PixPayloadService.generatePixCopiaECola(
      pixKey: pixKey,
      amount: _amountToCharge > 0 ? _amountToCharge : null,
      merchantName: _merchantName,
      merchantCity: _merchantCity,
      txId: '***',
    );

    final buffer = StringBuffer();
    buffer.writeln('Olá ${widget.personName}! Tudo bem?');
    buffer.writeln('Passando para te mandar o resumo financeiro das suas contas em aberto:');
    buffer.writeln();

    if (_chargeAllAccounts && widget.debts.length > 1) {
      // Consolidated bill for ALL accounts
      double totalRemaining = 0.0;
      double totalThisMonth = 0.0;

      for (int i = 0; i < widget.debts.length; i++) {
        final d = widget.debts[i];
        totalRemaining += d.remainingAmount;
        // In gross invoice, show full installment so the abatement deduction below is crystal clear
        final monthDue = _includeAbatementInBill
            ? (d.installmentValue > 0 ? d.installmentValue : d.totalAmount)
            : (d.remainingAmount < d.installmentValue ? d.remainingAmount : d.installmentValue);
        totalThisMonth += monthDue;

        final nextInst = d.paidInstallments + 1;
        buffer.writeln(
          '📌 ${d.description}: Parcela $nextInst de ${d.totalInstallments} no valor de ${CurrencyFormatter.format(monthDue)} (Vencimento dia ${d.dueDay})',
        );
      }

      buffer.writeln();
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('📋 Subtotal das parcelas deste mês: ${CurrencyFormatter.format(totalThisMonth)}');

      if (_includeAbatementInBill && _abatementAmount > 0) {
        final desc = _abatementDescription.trim().isNotEmpty ? _abatementDescription.trim() : 'Pix recebido';
        buffer.writeln('(-) Abatimento / Pagamento recebido: - ${CurrencyFormatter.format(_abatementAmount)} ($desc)');

        final netMonth = totalThisMonth - _abatementAmount;
        if (netMonth > 0.01) {
          buffer.writeln('💰 Total a pagar este mês: ${CurrencyFormatter.format(netMonth)}');
        } else if (netMonth.abs() <= 0.01) {
          buffer.writeln('✅ Contas deste mês 100% QUITADAS! Obrigado!');
        } else {
          final credit = -netMonth;
          buffer.writeln('✅ Contas deste mês 100% QUITADAS!');
          buffer.writeln('✨ Saldo adiantado / crédito amortizado: ${CurrencyFormatter.format(credit)}');
        }
      } else {
        buffer.writeln('💰 Total das parcelas deste mês: ${CurrencyFormatter.format(totalThisMonth)}');
      }
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln();

      buffer.writeln('🎯 Saldo total restante de parcelas futuras: ${CurrencyFormatter.format(totalRemaining)}');
    } else {
      // Specific single account bill
      final target = _selectedDebt ?? widget.debts.first;
      final nextInst = target.paidInstallments + 1;
      final monthDue = _includeAbatementInBill
          ? (target.installmentValue > 0 ? target.installmentValue : target.totalAmount)
          : (target.remainingAmount < target.installmentValue ? target.remainingAmount : target.installmentValue);

      buffer.writeln(
        'Lembrando da parcela $nextInst de ${target.totalInstallments} (${CurrencyFormatter.format(monthDue)}/mês) referente a "${target.description}", com vencimento dia ${target.dueDay}.',
      );

      if (_includeAbatementInBill && _abatementAmount > 0) {
        buffer.writeln();
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
        buffer.writeln('📋 Subtotal da parcela: ${CurrencyFormatter.format(monthDue)}');
        final desc = _abatementDescription.trim().isNotEmpty ? _abatementDescription.trim() : 'Pix recebido';
        buffer.writeln('(-) Abatimento recebido: - ${CurrencyFormatter.format(_abatementAmount)} ($desc)');
        final net = monthDue - _abatementAmount;
        if (net > 0.01) {
          buffer.writeln('💰 Restante a pagar da parcela: ${CurrencyFormatter.format(net)}');
        } else {
          buffer.writeln('✅ Parcela deste mês 100% QUITADA!');
        }
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      buffer.writeln('🎯 Saldo restante desta conta: ${CurrencyFormatter.format(target.remainingAmount)}');
    }

    final displayKey = PixPayloadService.sanitizePixKey(pixKey);
    buffer.writeln();
    buffer.writeln('Minha chave Pix: ${displayKey.isNotEmpty ? displayKey : (pixKey.isNotEmpty ? pixKey : "[INSERIR SUA CHAVE PIX]")}');

    if (_pixCopiaECola.isNotEmpty && _amountToCharge > 0) {
      buffer.writeln();
      buffer.writeln('Ou pague direto com o Pix Copia e Cola (valor exato de ${CurrencyFormatter.format(_amountToCharge)} já preenchido):');
      buffer.writeln(_pixCopiaECola);
    }

    buffer.writeln();
    buffer.writeln('Qualquer dúvida ou comprovante me manda aqui, valeu!');

    _messageController.text = buffer.toString();
  }

  void _onPixKeyChanged(String newKey) {
    final sanitized = PixPayloadService.sanitizePixKey(newKey);
    StorageService.setUserPixKey(sanitized.isNotEmpty ? sanitized : newKey.trim());
    setState(() {
      _generateMessage(newKey.trim());
    });
  }

  void _onAmountChanged(String val) {
    final parsed = double.tryParse(val.replaceAll('.', '').replaceAll(',', '.')) ?? 
                   double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _amountToCharge = parsed;
      _generateMessage(_pixKeyController.text);
    });
  }

  void _setPredefinedAmount(double val) {
    setState(() {
      _amountToCharge = val;
      _amountController.text = val > 0 ? val.toStringAsFixed(2) : '';
      _generateMessage(_pixKeyController.text);
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
    _amountController.dispose();
    _abatementAmountController.dispose();
    _abatementDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMultiple = widget.debts.length > 1;
    final amountToCharge = _amountToCharge;

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
                      ? '${widget.debts.length} contas • Valor a cobrar: ${CurrencyFormatter.format(amountToCharge)}'
                      : 'Lembrete com Pix Copia e Cola de ${CurrencyFormatter.format(amountToCharge)}',
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
                                  _amountToCharge = _calculateDefaultAmount();
                                  _amountController.text = _amountToCharge > 0 ? _amountToCharge.toStringAsFixed(2) : '';
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
                                  _amountToCharge = _calculateDefaultAmount();
                                  _amountController.text = _amountToCharge > 0 ? _amountToCharge.toStringAsFixed(2) : '';
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
                          isExpanded: true,
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
                                _amountToCharge = _calculateDefaultAmount();
                                _amountController.text = _amountToCharge > 0 ? _amountToCharge.toStringAsFixed(2) : '';
                                _generateMessage(_pixKeyController.text);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    // Card de Abatimento no Resumo (como uma fatura)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _includeAbatementInBill && _abatementAmount > 0
                              ? AppConstants.accentGreen.withOpacity(0.5)
                              : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.discount_rounded, color: AppConstants.accentGreen, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Abatimento / Pagamento Recebido',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _includeAbatementInBill,
                                activeColor: AppConstants.accentGreen,
                                onChanged: (val) {
                                  setState(() {
                                    _includeAbatementInBill = val;
                                    _amountToCharge = _calculateDefaultAmount();
                                    _amountController.text = _amountToCharge > 0 ? _amountToCharge.toStringAsFixed(2) : '';
                                    _generateMessage(_pixKeyController.text);
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_includeAbatementInBill) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: TextField(
                                    controller: _abatementAmountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Valor Abatido',
                                      prefixText: 'R\$ ',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val.replaceAll('.', '').replaceAll(',', '.')) ??
                                          double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                      setState(() {
                                        _abatementAmount = parsed;
                                        _amountToCharge = _calculateDefaultAmount();
                                        _amountController.text = _amountToCharge > 0 ? _amountToCharge.toStringAsFixed(2) : '';
                                        _generateMessage(_pixKeyController.text);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 6,
                                  child: TextField(
                                    controller: _abatementDescController,
                                    decoration: const InputDecoration(
                                      labelText: 'Descrição do Abatimento',
                                      hintText: 'ex: Pix de R\$ 1.000 recebido',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _abatementDescription = val;
                                        _generateMessage(_pixKeyController.text);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Exibe o subtotal bruto, deduz o abatimento e calcula o valor final a pagar como uma fatura.',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Chave Pix Fixa
                    TextField(
                      controller: _pixKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Sua Chave Pix',
                        hintText: 'CPF, Celular, E-mail ou Chave Aleatória',
                        helperText: 'Padrão Banco Central: CPF e telefone são limpos automaticamente',
                        prefixIcon: Icon(Icons.pix_rounded, color: AppConstants.accentGreen),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: _onPixKeyChanged,
                    ),
                    const SizedBox(height: 10),

                    // Valor pré-fixado no Pix
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Valor Pré-fixado no Pix Copia e Cola (R\$)',
                        hintText: '0.00',
                        helperText: _amountToCharge > 0
                            ? 'O pagador verá este valor automaticamente preenchido no banco'
                            : 'Deixe zerado se quiser que o pagador digite o valor no banco',
                        prefixIcon: const Icon(Icons.attach_money_rounded, color: AppConstants.accentGreen),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: _amountToCharge > 0
                            ? IconButton(
                                tooltip: 'Remover valor pré-fixado',
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _setPredefinedAmount(0.0),
                              )
                            : null,
                      ),
                      onChanged: _onAmountChanged,
                    ),
                    const SizedBox(height: 6),

                    // Quick Chips for Amount
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_getMonthInstallmentAmount() > 0) ...[
                            ActionChip(
                              avatar: const Icon(Icons.calendar_today_rounded, size: 14, color: AppConstants.primaryColor),
                              label: Text('Parcela do Mês: ${CurrencyFormatter.format(_getMonthInstallmentAmount())}'),
                              onPressed: () => _setPredefinedAmount(_getMonthInstallmentAmount()),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_getTotalRemainingAmount() > 0) ...[
                            ActionChip(
                              avatar: const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppConstants.accentAmber),
                              label: Text('Saldo Restante: ${CurrencyFormatter.format(_getTotalRemainingAmount())}'),
                              onPressed: () => _setPredefinedAmount(_getTotalRemainingAmount()),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // QR Code Card with Predefined Amount
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.accentGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppConstants.accentGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_2_rounded, color: AppConstants.accentGreen, size: 22),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Pix Copia e Cola / QR Code',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Valor já predefinido: ${CurrencyFormatter.format(amountToCharge)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppConstants.accentGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => _showQrCode = !_showQrCode);
                                },
                                child: Text(_showQrCode ? 'Ocultar QR' : 'Ver QR Code'),
                              ),
                            ],
                          ),
                          if (_showQrCode && _pixCopiaECola.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: QrImageView(
                                  data: _pixCopiaECola,
                                  version: QrVersions.auto,
                                  size: 160.0,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'O pagador aponta a câmera e o valor já aparece preenchido!',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppConstants.accentGreen,
                              side: const BorderSide(color: AppConstants.accentGreen),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.content_copy_rounded, size: 16),
                            label: const Text('Copiar Código Pix Copia e Cola'),
                            onPressed: _pixCopiaECola.isEmpty
                                ? null
                                : () {
                                    Clipboard.setData(ClipboardData(text: _pixCopiaECola));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Código Pix Copia e Cola de ${CurrencyFormatter.format(amountToCharge)} copiado!',
                                        ),
                                        backgroundColor: AppConstants.accentGreen,
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

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
                    const SizedBox(height: 6),

                    // Mensagem pré-formatada editável
                    TextField(
                      controller: _messageController,
                      maxLines: 8,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Mensagem Formatada (Você pode editar antes de enviar)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Copiar texto completo
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: const Text('Copiar Mensagem Completa'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _messageController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mensagem, chave Pix e código Copia e Cola copiados!'),
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

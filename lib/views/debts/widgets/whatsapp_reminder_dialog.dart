import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _includeAbatementInBill = true;
  double _abatementAmount = 0.0;
  String _abatementDescription = 'Transferência Recebida via Pix';
  bool _showQrCode = false;
  String _pixCopiaECola = '';
  double _amountToCharge = 0.0;
  String _merchantName = 'LEANDRO DENISON';
  String _merchantCity = 'BRASILIA';

  @override
  void initState() {
    super.initState();
    _selectedDebt =
        widget.initialSelectedDebt ??
        (widget.debts.isNotEmpty ? widget.debts.first : null);
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
        _abatementDescription =
            payments.first.note ?? 'Pagamento avulso / Pix recebido';
      }
    }

    _abatementAmountController.text = _abatementAmount > 0
        ? _abatementAmount.toStringAsFixed(2)
        : '';
    _abatementDescController.text = _abatementDescription;

    _amountToCharge = _calculateDefaultAmount();
    _amountController.text = _amountToCharge > 0
        ? _amountToCharge.toStringAsFixed(2)
        : '';
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
        final due = _includeAbatementInBill
            ? (d.installmentValue > 0 ? d.installmentValue : d.totalAmount)
            : (d.remainingAmount < d.installmentValue
                  ? d.remainingAmount
                  : d.installmentValue);
        return s + due;
      });
    } else {
      final target =
          _selectedDebt ??
          (widget.debts.isNotEmpty ? widget.debts.first : null);
      if (target == null) return 0.0;
      return _includeAbatementInBill
          ? (target.installmentValue > 0
                ? target.installmentValue
                : target.totalAmount)
          : (target.remainingAmount < target.installmentValue
                ? target.remainingAmount
                : target.installmentValue);
    }
  }

  double _getTotalRemainingAmount() {
    if (_chargeAllAccounts && widget.debts.length > 1) {
      return widget.debts.fold(0.0, (s, d) => s + d.remainingAmount);
    } else {
      final target =
          _selectedDebt ??
          (widget.debts.isNotEmpty ? widget.debts.first : null);
      return target?.remainingAmount ?? 0.0;
    }
  }

  Future<void> _loadPixKeyAndGenerate() async {
    final rawKey = await StorageService.getUserPixKey();
    _merchantName = await StorageService.getUserName();
    _merchantCity = await StorageService.getUserCity();
    final sanitized = PixPayloadService.sanitizePixKey(rawKey);
    _pixKeyController.text = sanitized.isNotEmpty ? sanitized : rawKey;
    _generateMessage(_pixKeyController.text);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _generateMessage(String pixKey) {
    _pixCopiaECola = PixPayloadService.generatePixCopiaECola(
      pixKey: pixKey,
      amount: _amountToCharge > 0 ? _amountToCharge : null,
      merchantName: _merchantName,
      merchantCity: _merchantCity,
      txId: '***',
    );

    final buffer = StringBuffer();
    buffer.writeln('Olá ${widget.personName}! Tudo bem?');
    buffer.writeln(
      'Passando para te mandar o resumo financeiro das suas contas em aberto:',
    );
    buffer.writeln();

    if (_chargeAllAccounts && widget.debts.length > 1) {
      double totalRemaining = 0.0;
      double totalThisMonth = 0.0;

      for (int i = 0; i < widget.debts.length; i++) {
        final d = widget.debts[i];
        totalRemaining += d.remainingAmount;
        final monthDue = _includeAbatementInBill
            ? (d.installmentValue > 0 ? d.installmentValue : d.totalAmount)
            : (d.remainingAmount < d.installmentValue
                  ? d.remainingAmount
                  : d.installmentValue);
        totalThisMonth += monthDue;

        final nextInst = d.paidInstallments + 1;
        buffer.writeln(
          '📌 ${d.description}: Parcela $nextInst de ${d.totalInstallments} no valor de ${CurrencyFormatter.format(monthDue)} (Vencimento dia ${d.dueDay})',
        );
      }

      buffer.writeln();
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln(
        '📋 Subtotal das parcelas deste mês: ${CurrencyFormatter.format(totalThisMonth)}',
      );

      if (_includeAbatementInBill && _abatementAmount > 0) {
        final desc = _abatementDescription.trim().isNotEmpty
            ? _abatementDescription.trim()
            : 'Pix recebido';
        buffer.writeln(
          '(-) Abatimento / Pagamento recebido: - ${CurrencyFormatter.format(_abatementAmount)} ($desc)',
        );

        final netMonth = totalThisMonth - _abatementAmount;
        if (netMonth > 0.01) {
          buffer.writeln(
            '💰 Total a pagar este mês: ${CurrencyFormatter.format(netMonth)}',
          );
        } else if (netMonth.abs() <= 0.01) {
          buffer.writeln('✅ Contas deste mês 100% QUITADAS! Obrigado!');
        } else {
          final credit = -netMonth;
          buffer.writeln('✅ Contas deste mês 100% QUITADAS!');
          buffer.writeln(
            '✨ Saldo adiantado / crédito amortizado: ${CurrencyFormatter.format(credit)}',
          );
        }
      } else {
        buffer.writeln(
          '💰 Total das parcelas deste mês: ${CurrencyFormatter.format(totalThisMonth)}',
        );
      }
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln();

      buffer.writeln(
        '🎯 Saldo total restante de parcelas futuras: ${CurrencyFormatter.format(totalRemaining)}',
      );
    } else {
      final target = _selectedDebt ?? widget.debts.first;
      final nextInst = target.paidInstallments + 1;
      final monthDue = _includeAbatementInBill
          ? (target.installmentValue > 0
                ? target.installmentValue
                : target.totalAmount)
          : (target.remainingAmount < target.installmentValue
                ? target.remainingAmount
                : target.installmentValue);

      buffer.writeln(
        'Lembrando da parcela $nextInst de ${target.totalInstallments} (${CurrencyFormatter.format(monthDue)}/mês) referente a "${target.description}", com vencimento dia ${target.dueDay}.',
      );

      if (_includeAbatementInBill && _abatementAmount > 0) {
        buffer.writeln();
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
        buffer.writeln(
          '📋 Subtotal da parcela: ${CurrencyFormatter.format(monthDue)}',
        );
        final desc = _abatementDescription.trim().isNotEmpty
            ? _abatementDescription.trim()
            : 'Pix recebido';
        buffer.writeln(
          '(-) Abatimento recebido: - ${CurrencyFormatter.format(_abatementAmount)} ($desc)',
        );
        final net = monthDue - _abatementAmount;
        if (net > 0.01) {
          buffer.writeln(
            '💰 Restante a pagar da parcela: ${CurrencyFormatter.format(net)}',
          );
        } else {
          buffer.writeln('✅ Parcela deste mês 100% QUITADA!');
        }
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      buffer.writeln(
        '🎯 Saldo restante desta conta: ${CurrencyFormatter.format(target.remainingAmount)}',
      );
    }

    final displayKey = PixPayloadService.sanitizePixKey(pixKey);
    buffer.writeln();
    buffer.writeln(
      'Minha chave Pix: ${displayKey.isNotEmpty ? displayKey : (pixKey.isNotEmpty ? pixKey : "[INSERIR SUA CHAVE PIX]")}',
    );

    if (_pixCopiaECola.isNotEmpty && _amountToCharge > 0) {
      buffer.writeln();
      buffer.writeln(
        'Ou pague direto com o Pix Copia e Cola (valor exato de ${CurrencyFormatter.format(_amountToCharge)} já preenchido):',
      );
      buffer.writeln(_pixCopiaECola);
    }

    buffer.writeln();
    buffer.writeln('Qualquer dúvida ou comprovante me manda aqui, valeu!');

    _messageController.text = buffer.toString();
  }

  void _onPixKeyChanged(String newKey) {
    final sanitized = PixPayloadService.sanitizePixKey(newKey);
    StorageService.setUserPixKey(
      sanitized.isNotEmpty ? sanitized : newKey.trim(),
    );
    setState(() {
      _generateMessage(newKey.trim());
    });
  }

  void _onAmountChanged(String val) {
    final parsed =
        double.tryParse(val.replaceAll('.', '').replaceAll(',', '.')) ??
        double.tryParse(val.replaceAll(',', '.')) ??
        0.0;
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

  Future<void> _shareInvoice() async {
    final text = _messageController.text.trim();
    try {
      await Share.share(text, subject: 'Cobrança - ${widget.personName}');
    } catch (_) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensagem copiada para a área de transferência!'),
            backgroundColor: AppConstants.accentGreen,
          ),
        );
      }
    }
  }

  void _copyPixCode() {
    if (_pixCopiaECola.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pixCopiaECola));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pix Copia e Cola (${CurrencyFormatter.format(_amountToCharge)}) copiado!',
        ),
        backgroundColor: AppConstants.accentGreen,
      ),
    );
  }

  void _copyFullMessage() {
    Clipboard.setData(ClipboardData(text: _messageController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensagem completa copiada!'),
        backgroundColor: AppConstants.accentGreen,
      ),
    );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final grossSubtotal = _getMonthInstallmentAmount();
    final hasAbatement = _includeAbatementInBill && _abatementAmount > 0;

    Widget header = Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppConstants.primaryColor.withValues(alpha: 0.15),
          child: Text(
            widget.personName.isNotEmpty
                ? widget.personName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppConstants.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cobrança • ${widget.personName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                hasMultiple
                    ? '${widget.debts.length} contas em aberto'
                    : '1 conta em aberto',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );

    Widget content = _isLoading
        ? const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Multiple account selector
              if (hasMultiple) ...[
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.all_inbox_rounded, size: 15),
                        label: Text(
                          isMobile
                              ? 'Conta Toda'
                              : 'Conta Toda (${widget.debts.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const ButtonSegment(
                        value: false,
                        icon: Icon(Icons.receipt_outlined, size: 15),
                        label: Text(
                          'Específica',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    selected: {_chargeAllAccounts},
                    onSelectionChanged: (val) {
                      setState(() {
                        _chargeAllAccounts = val.first;
                        _amountToCharge = _calculateDefaultAmount();
                        _amountController.text = _amountToCharge > 0
                            ? _amountToCharge.toStringAsFixed(2)
                            : '';
                        _generateMessage(_pixKeyController.text);
                      });
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                if (!_chargeAllAccounts) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<DebtModel>(
                    value: _selectedDebt,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Selecione a conta para cobrar',
                      prefixIcon: const Icon(Icons.receipt_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
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
                          _amountController.text = _amountToCharge > 0
                              ? _amountToCharge.toStringAsFixed(2)
                              : '';
                          _generateMessage(_pixKeyController.text);
                        });
                      }
                    },
                  ),
                ],
                const SizedBox(height: 14),
              ],

              // Modern Compact Invoice Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: AppConstants.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Resumo da Fatura',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Mês Atual',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Subtotal das parcelas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Subtotal das parcelas:',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(grossSubtotal),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // Abatimento recebido (se houver)
                    if (hasAbatement) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: AppConstants.accentGreen,
                                ),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text(
                                    '(-) Abatimento recebido:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.accentGreen,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '- ${CurrencyFormatter.format(_abatementAmount)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.accentGreen,
                            ),
                          ),
                        ],
                      ),
                      if (_abatementDescription.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _abatementDescription.trim(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],

                    Divider(
                      height: 20,
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey.shade300,
                    ),

                    // Prominent Currency Display: Total a Cobrar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL A COBRAR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(_amountToCharge),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _amountToCharge > 0
                                        ? const Color(0xFF10B981)
                                        : AppConstants.accentGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_pixCopiaECola.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.accentGreen.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.pix_rounded,
                                  size: 14,
                                  color: AppConstants.accentGreen,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Pix Pronto',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.accentGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Direct Quick Action Buttons (Primary Share + Copiar Pix)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.accentGreen,
                        side: const BorderSide(color: AppConstants.accentGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text(
                        'Copiar Pix Copia e Cola',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _pixCopiaECola.isEmpty ? null : _copyPixCode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Copiar Mensagem Completa',
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    onPressed: _copyFullMessage,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Expandable Section: Editable message, QR Code, and Custom Pix Key
              Material(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      leading: const Icon(
                        Icons.tune_rounded,
                        color: AppConstants.primaryColor,
                        size: 20,
                      ),
                      title: const Text(
                        'Personalizar Mensagem, Pix e QR Code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Editar chave Pix, valor avulso ou ver QR Code',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      children: [
                        const Divider(height: 16),

                        // Chave Pix
                        TextField(
                          controller: _pixKeyController,
                          decoration: InputDecoration(
                            labelText: 'Sua Chave Pix',
                            hintText: 'CPF, Celular, E-mail ou Aleatória',
                            prefixIcon: const Icon(
                              Icons.pix_rounded,
                              color: AppConstants.accentGreen,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          onChanged: _onPixKeyChanged,
                        ),
                        const SizedBox(height: 10),

                        // Valor no Pix Copia e Cola
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Valor no Pix Copia e Cola (R\$)',
                            hintText: '0.00',
                            prefixIcon: const Icon(
                              Icons.attach_money_rounded,
                              color: AppConstants.accentGreen,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                            suffixIcon: _amountToCharge > 0
                                ? IconButton(
                                    tooltip: 'Limpar valor pré-fixado',
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () => _setPredefinedAmount(0.0),
                                  )
                                : null,
                          ),
                          onChanged: _onAmountChanged,
                        ),
                        const SizedBox(height: 8),

                        // Quick Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_getMonthInstallmentAmount() > 0)
                              ActionChip(
                                avatar: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 13,
                                  color: AppConstants.primaryColor,
                                ),
                                label: Text(
                                  'Mês: ${CurrencyFormatter.format(_getMonthInstallmentAmount())}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _setPredefinedAmount(
                                  _getMonthInstallmentAmount(),
                                ),
                              ),
                            if (_getTotalRemainingAmount() > 0)
                              ActionChip(
                                avatar: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 13,
                                  color: AppConstants.accentAmber,
                                ),
                                label: Text(
                                  'Total: ${CurrencyFormatter.format(_getTotalRemainingAmount())}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _setPredefinedAmount(
                                  _getTotalRemainingAmount(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Abatement Settings
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Deduzir abatimento na fatura',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Switch(
                                    value: _includeAbatementInBill,
                                    activeColor: AppConstants.accentGreen,
                                    onChanged: (val) {
                                      setState(() {
                                        _includeAbatementInBill = val;
                                        _amountToCharge =
                                            _calculateDefaultAmount();
                                        _amountController.text =
                                            _amountToCharge > 0
                                            ? _amountToCharge.toStringAsFixed(2)
                                            : '';
                                        _generateMessage(
                                          _pixKeyController.text,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_includeAbatementInBill) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 110,
                                      child: TextField(
                                        controller: _abatementAmountController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: 'Valor (R\$)',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                          isDense: true,
                                        ),
                                        onChanged: (val) {
                                          final parsed =
                                              double.tryParse(
                                                val
                                                    .replaceAll('.', '')
                                                    .replaceAll(',', '.'),
                                              ) ??
                                              double.tryParse(
                                                val.replaceAll(',', '.'),
                                              ) ??
                                              0.0;
                                          setState(() {
                                            _abatementAmount = parsed;
                                            _amountToCharge =
                                                _calculateDefaultAmount();
                                            _amountController.text =
                                                _amountToCharge > 0
                                                ? _amountToCharge
                                                      .toStringAsFixed(2)
                                                : '';
                                            _generateMessage(
                                              _pixKeyController.text,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _abatementDescController,
                                        decoration: InputDecoration(
                                          labelText: 'Descrição',
                                          hintText: 'ex: Pix recebido',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                          isDense: true,
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            _abatementDescription = val;
                                            _generateMessage(
                                              _pixKeyController.text,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // QR Code Preview Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 20,
                                  color: AppConstants.accentGreen,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'QR Code Pix',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _showQrCode = !_showQrCode),
                              child: Text(
                                _showQrCode
                                    ? 'Ocultar QR'
                                    : 'Visualizar QR Code',
                              ),
                            ),
                          ],
                        ),
                        if (_showQrCode && _pixCopiaECola.isNotEmpty) ...[
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: QrImageView(
                                data: _pixCopiaECola,
                                version: QrVersions.auto,
                                size: 150.0,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Center(
                            child: Text(
                              'Aponte a câmera no app do banco para pagar',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 6),

                        // Editable message preview
                        TextField(
                          controller: _messageController,
                          maxLines: 5,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            labelText:
                                'Mensagem (editável antes de compartilhar)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          );

    final primaryShareButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.share_rounded, size: 18),
      label: Text(
        'Compartilhar Cobrança (${CurrencyFormatter.format(_amountToCharge)})',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      onPressed: _shareInvoice,
    );

    if (isMobile) {
      final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
      return Dialog.fullscreen(
        backgroundColor: bg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 4, 8),
                child: header,
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: content,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: primaryShareButton,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: header,
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: content,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: SizedBox(
                width: double.infinity,
                child: primaryShareButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

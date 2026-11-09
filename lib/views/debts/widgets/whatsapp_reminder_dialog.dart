import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/debt_model.dart';
import '../../../services/storage_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/currency_formatter.dart';

class WhatsAppReminderDialog extends StatefulWidget {
  final DebtModel debt;

  const WhatsAppReminderDialog({super.key, required this.debt});

  @override
  State<WhatsAppReminderDialog> createState() => _WhatsAppReminderDialogState();
}

class _WhatsAppReminderDialogState extends State<WhatsAppReminderDialog> {
  final _messageController = TextEditingController();
  final _pixKeyController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPixKeyAndGenerateMessage();
  }

  Future<void> _loadPixKeyAndGenerateMessage() async {
    final pixKey = await StorageService.getUserPixKey();
    _pixKeyController.text = pixKey;

    final nextInstallment = widget.debt.paidInstallments + 1;
    final valueStr = CurrencyFormatter.format(widget.debt.installmentValue);

    _messageController.text =
        'Olá ${widget.debt.personName}! Tudo bem? Passando para lembrar com carinho da parcela $nextInstallment/${widget.debt.totalInstallments} no valor de $valueStr referente a "${widget.debt.description}", com vencimento dia ${widget.debt.dueDay}.\n\nMinha chave Pix: $pixKey\n\nQualquer dúvida me avisa!';

    setState(() => _isLoading = false);
  }

  void _onPixKeyChanged(String newKey) {
    StorageService.setUserPixKey(newKey.trim());
    final nextInstallment = widget.debt.paidInstallments + 1;
    final valueStr = CurrencyFormatter.format(widget.debt.installmentValue);
    setState(() {
      _messageController.text =
          'Olá ${widget.debt.personName}! Tudo bem? Passando para lembrar com carinho da parcela $nextInstallment/${widget.debt.totalInstallments} no valor de $valueStr referente a "${widget.debt.description}", com vencimento dia ${widget.debt.dueDay}.\n\nMinha chave Pix: ${newKey.trim()}\n\nQualquer dúvida me avisa!';
    });
  }

  Future<void> _openWhatsApp() async {
    final text = _messageController.text.trim();
    String? phone = widget.debt.contact;

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
          const Expanded(
            child: Text(
              'Lembrete via WhatsApp',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Envie uma mensagem amigável e educada para ${widget.debt.personName} com a sua chave Pix:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Sua Chave Pix
                    TextField(
                      controller: _pixKeyController,
                      decoration: InputDecoration(
                        labelText: 'Sua Chave Pix para Recebimento',
                        hintText: 'CPF, Celular, E-mail ou Chave Aleatória',
                        prefixIcon: const Icon(Icons.pix_rounded, color: AppConstants.accentGreen),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: _onPixKeyChanged,
                    ),
                    const SizedBox(height: 14),

                    // Mensagem pré-formatada editável
                    TextField(
                      controller: _messageController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem Formatada (Você pode editar)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Botão Copiar
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copiar Texto'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _messageController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mensagem e chave Pix copiadas para a área de transferência!'),
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

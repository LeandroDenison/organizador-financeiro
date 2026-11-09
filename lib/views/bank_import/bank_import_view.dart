import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../services/ofx_parser_service.dart';
import '../../services/csv_parser_service.dart';
import '../../utils/constants.dart';
import 'widgets/import_preview_dialog.dart';

class BankImportView extends StatefulWidget {
  const BankImportView({super.key});

  @override
  State<BankImportView> createState() => _BankImportViewState();
}

class _BankImportViewState extends State<BankImportView> {
  bool _isProcessing = false;
  final _rawTextController = TextEditingController();

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _isProcessing = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ofx', 'csv', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        String content = '';

        try {
          final bytes = await file.readAsBytes();
          try {
            content = utf8.decode(bytes);
          } catch (_) {
            content = latin1.decode(bytes);
          }
        } catch (_) {}

        if (content.isNotEmpty) {
          _processContent(content, file.name);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ler arquivo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _processContent(String content, String sourceName) {
    final lower = sourceName.toLowerCase();
    final isOfx = lower.endsWith('.ofx') || content.contains('<OFX>') || content.contains('<STMTTRN>');

    if (isOfx) {
      final result = OfxParserService.parse(content);
      if (result.transactions.isEmpty) {
        _showNoTransactionsAlert();
        return;
      }
      _showPreviewDialog(result.bankName ?? 'Banco', result.transactions);
    } else {
      final result = CsvParserService.parse(content);
      if (result.transactions.isEmpty) {
        _showNoTransactionsAlert();
        return;
      }
      _showPreviewDialog(result.bankName, result.transactions);
    }
  }

  void _showNoTransactionsAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nenhuma transação identificada'),
        content: const Text(
          'O arquivo não possui o formato esperado de extrato OFX ou CSV. Verifique se exportou o extrato da conta ou fatura do cartão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog(String bankName, List<dynamic> transactions) async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => ImportPreviewDialog(
        bankName: bankName,
        parsedTransactions: List.from(transactions),
      ),
    );

    if (count != null && count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count transações importadas com sucesso!'),
          backgroundColor: AppConstants.accentGreen,
        ),
      );
    }
  }

  // Sample data generators for instant testing
  void _loadSample(String type) {
    if (type == 'nubank_ofx') {
      const sample = '''OFXHEADER:100
DATA:OFXSGML
VERSION:102
SECURITY:NONE
ENCODING:USASCII
CHARSET:1252
COMPRESSION:NONE
OLDFILEUID:NONE
NEWFILEUID:NONE

<OFX>
<SIGNONMSGSRSV1>
<SONRS>
<STATUS>
<CODE>0
<SEVERITY>INFO
</STATUS>
<DTSERVER>20261109120000[-03:EST]
<LANGUAGE>POR
<FI>
<ORG>Nu Pagamentos S.A.
<FID>260
</FI>
</SONRS>
</SIGNONMSGSRSV1>
<BANKMSGSRSV1>
<STMTTRNRS>
<TRNUID>1001
<STATUS>
<CODE>0
<SEVERITY>INFO
</STATUS>
<STMTRS>
<CURDEF>BRL
<BANKACCTFROM>
<BANKID>260
<ACCTID>0001-998877
<ACCTTYPE>CHECKING
</BANKACCTFROM>
<BANKTRANLIST>
<DTSTART>20261101000000[-03:EST]
<DTEND>20261109235959[-03:EST]
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261102120000[-03:EST]
<TRNAMT>-142.80
<FITID>nu-20261102-01
<MEMO>Supermercado Pao de Acucar
</STMTTRN>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261103153000[-03:EST]
<TRNAMT>-32.50
<FITID>nu-20261103-02
<MEMO>Drogaria Sao Paulo
</STMTTRN>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261104190000[-03:EST]
<TRNAMT>-68.90
<FITID>nu-20261104-03
<MEMO>iFood Restaurante
</STMTTRN>
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20261105090000[-03:EST]
<TRNAMT>3500.00
<FITID>nu-20261105-04
<MEMO>Pix Recebido - Salario
</STMTTRN>
</BANKTRANLIST>
</STMTRS>
</STMTTRNRS>
</BANKMSGSRSV1>
</OFX>''';
      _processContent(sample, 'extrato_nubank.ofx');
    } else if (type == 'mercadopago_csv') {
      const sample = '''DATA,ID_DA_OPERACAO,DESCRICAO,VALOR_TOTAL,STATUS_DO_PAGAMENTO
02/11/2026 10:14:22,88192019,Pagamento no Mercado Livre,-129.90,Aprovado
04/11/2026 18:30:00,88192020,Recarga celular Vivo,-30.00,Aprovado
06/11/2026 12:45:10,88192021,Transferencia Pix recebida,200.00,Aprovado
08/11/2026 21:00:15,88192022,Spotify Premium,-21.90,Aprovado''';
      _processContent(sample, 'extrato_mercadopago.csv');
    } else if (type == 'itau_ofx') {
      const sample = '''<OFX>
<STMTRS>
<BANKTRANLIST>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261103120000
<TRNAMT>-180.00
<FITID>itau-001
<MEMO>POSTO IPIRANGA COMBUSTIVEL
</STMTTRN>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261104120000
<TRNAMT>-45.00
<FITID>itau-002
<MEMO>UBER TRIP RIO
</STMTTRN>
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20261105120000
<TRNAMT>1200.00
<FITID>itau-003
<MEMO>TED REMUNERACAO FREELANCE
</STMTTRN>
</BANKTRANLIST>
</STMTRS>
</OFX>''';
      _processContent(sample, 'extrato_itau.ofx');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Importar Extrato Bancário',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Importe arquivos .OFX ou .CSV retirados direto dos aplicativos do Nubank, Itaú e Mercado Pago',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // Drop zone / Upload area
            InkWell(
              onTap: _isProcessing ? null : _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppConstants.primaryColor.withOpacity(0.4),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        size: 40,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Clique para selecionar o arquivo de extrato',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Formatos suportados: .OFX (recomendado) e .CSV',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.file_open_rounded),
                      label: const Text('Selecionar do Computador / Celular'),
                      onPressed: _isProcessing ? null : _pickFile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instant Test Presets
            Text(
              'Testar Imediatamente com Modelos de Bancos:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildBankSampleCard(
                  title: 'Nubank (OFX)',
                  subtitle: 'Supermercado, Farmácia, iFood e Pix',
                  color: AppConstants.nubankPurple,
                  icon: Icons.credit_card_rounded,
                  onTap: () => _loadSample('nubank_ofx'),
                ),
                _buildBankSampleCard(
                  title: 'Mercado Pago (CSV)',
                  subtitle: 'Mercado Livre, Recarga e Assinatura',
                  color: AppConstants.mercadoPagoBlue,
                  icon: Icons.account_balance_wallet_rounded,
                  onTap: () => _loadSample('mercadopago_csv'),
                ),
                _buildBankSampleCard(
                  title: 'Itaú (OFX)',
                  subtitle: 'Posto, Uber e Remuneração',
                  color: AppConstants.itauOrange,
                  icon: Icons.account_balance_rounded,
                  onTap: () => _loadSample('itau_ofx'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // How to export guide
            Text(
              'Como retirar o extrato no app do seu banco:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth < 800 ? 1 : 3;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: constraints.maxWidth < 800 ? 3.0 : 1.3,
                  children: [
                    _buildGuideCard(
                      'Nubank',
                      '1. No app Nubank, clique em Conta ou Cartão de Crédito.\n2. Role até a fatura ou histórico.\n3. Toque em "Pedir extrato" ou "Exportar fatura".\n4. Selecione o formato OFX ou CSV e envie por e-mail/WhatsApp.',
                      AppConstants.nubankPurple,
                      isDark,
                    ),
                    _buildGuideCard(
                      'Itaú',
                      '1. Acesse sua conta corrente no app Itaú.\n2. Toque em "Extrato" no menu principal.\n3. Toque nos três pontinhos (...) ou no ícone de compartilhamento.\n4. Escolha "Exportar extrato (OFX)".',
                      AppConstants.itauOrange,
                      isDark,
                    ),
                    _buildGuideCard(
                      'Mercado Pago',
                      '1. Acesse o app Mercado Pago ou web.\n2. Vá em "Atividades" ou "Relatórios".\n3. Selecione o período desejado.\n4. Clique em "Baixar relatório" e escolha o formato CSV.',
                      AppConstants.mercadoPagoBlue,
                      isDark,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSampleCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard(String bank, String steps, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                bank,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              steps,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_event_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final _customTitleController = TextEditingController(text: 'Compra aprovada');
  final _customTextController = TextEditingController(
    text: 'Compra de R\$ 64,50 no Cartão Nubank aprovada em Restaurante Fogão Mineiro.',
  );
  String _selectedPackage = 'com.nu.production';

  @override
  void dispose() {
    _customTitleController.dispose();
    _customTextController.dispose();
    super.dispose();
  }

  void _simulatePreset(String bank) {
    final notifProvider = context.read<NotificationProvider>();
    final finProvider = context.read<FinanceProvider>();
    final debtProvider = context.read<DebtProvider>();

    if (bank == 'pix_sergio') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.nu.production',
        title: 'Transferência recebida',
        text: 'Você recebeu um Pix de R\$ 1.000,00 de Sérgio no Nubank.',
        financeProvider: finProvider,
        debtProvider: debtProvider,
      );
    } else if (bank == 'nubank') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.nu.production',
        title: 'Compra aprovada no Cartão Nubank',
        text: 'Compra de R\$ 98,50 aprovada em Outback Steakhouse.',
        financeProvider: finProvider,
        debtProvider: debtProvider,
      );
    } else if (bank == 'itau') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.itau',
        title: 'Cartão Itaú',
        text: 'Compra aprovada de R\$ 120,00 no cartão final 8821 em Posto Ipiranga.',
        financeProvider: finProvider,
        debtProvider: debtProvider,
      );
    } else if (bank == 'mercadopago') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.mercadopago.wallet',
        title: 'Pagamento aprovado',
        text: 'Você pagou R\$ 32,90 para Livraria Saraiva no débito Mercado Pago.',
        financeProvider: finProvider,
        debtProvider: debtProvider,
      );
    } else if (bank == 'dda_nubank_enel') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.nu.production',
        title: 'Buscador de Boletos',
        text: 'Você tem um novo boleto de R\$ 145,20 de ENEL DISTRIBUICAO com vencimento em 20/11.',
        financeProvider: finProvider,
        debtProvider: debtProvider,
      );
    } else if (bank == 'dda_itau_enel_duplicate') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.itau',
        title: 'DDA Itaú',
        text: 'Você recebeu um boleto eletrônico de R\$ 145,20 de ENEL DISTRIBUICAO com vencimento em 20/11.',
        financeProvider: finProvider,
        debtProvider: debtProvider,
      );
    } else if (bank == 'dda_itau_cagece') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.itau',
        title: 'DDA Itaú',
        text: 'Novo boleto eletrônico de R\$ 92,00 recebido de CAGECE com vencimento em 25/11.',
        financeProvider: finProvider,
        debtProvider: debtProvider,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notificação do $bank recebida e processada!'),
        backgroundColor: AppConstants.accentGreen,
      ),
    );
  }

  void _simulateCustom() {
    if (_customTextController.text.trim().isEmpty) return;

    final notifProvider = context.read<NotificationProvider>();
    final finProvider = context.read<FinanceProvider>();
    final debtProvider = context.read<DebtProvider>();

    notifProvider.onNotificationReceived(
      appPackage: _selectedPackage,
      title: _customTitleController.text.trim(),
      text: _customTextController.text.trim(),
      financeProvider: finProvider,
      debtProvider: debtProvider,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notificação personalizada disparada!'),
        backgroundColor: AppConstants.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final finProvider = context.read<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? screenWidth - 24 : 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMobile ? 'Captura de Notificações' : 'Captura Automática de Notificações',
                        style: (isMobile
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.headlineSmall)
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No Android, o app escuta notificações de bancos e adiciona as compras no crédito automaticamente',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notifProvider.notifications.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppConstants.accentRed),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Limpar Histórico'),
                    onPressed: () => notifProvider.clearAll(),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Android Permission Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (notifProvider.isListenerPermissionGranted ? AppConstants.accentGreen : AppConstants.accentAmber)
                                    .withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                notifProvider.isListenerPermissionGranted ? Icons.security_rounded : Icons.warning_amber_rounded,
                                color: notifProvider.isListenerPermissionGranted ? AppConstants.accentGreen : AppConstants.accentAmber,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                notifProvider.isListenerPermissionGranted
                                    ? 'Serviço Ativo no Android'
                                    : 'Permissão de Acesso (Android)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notifProvider.isListenerPermissionGranted
                              ? 'O sistema está monitorando compras em segundo plano.'
                              : 'Conceda a permissão nas configurações do sistema para captura em segundo plano.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: notifProvider.isListenerPermissionGranted ? Colors.grey : AppConstants.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.settings_rounded, size: 16),
                            label: Text(notifProvider.isListenerPermissionGranted ? 'Verificar Permissão' : 'Ativar no Android'),
                            onPressed: () async {
                              await notifProvider.requestPermission();
                            },
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (notifProvider.isListenerPermissionGranted ? AppConstants.accentGreen : AppConstants.accentAmber)
                                .withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            notifProvider.isListenerPermissionGranted ? Icons.security_rounded : Icons.warning_amber_rounded,
                            color: notifProvider.isListenerPermissionGranted ? AppConstants.accentGreen : AppConstants.accentAmber,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notifProvider.isListenerPermissionGranted
                                    ? 'Serviço de Notificações Ativo no Android'
                                    : 'Permissão de Acesso a Notificações (Android)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                notifProvider.isListenerPermissionGranted
                                    ? 'O sistema está monitorando compras em segundo plano.'
                                    : 'No seu aparelho Android, conceda a permissão nas configurações do sistema para captura em segundo plano.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: notifProvider.isListenerPermissionGranted ? Colors.grey : AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.settings_rounded, size: 16),
                          label: Text(notifProvider.isListenerPermissionGranted ? 'Verificar' : 'Ativar no Android'),
                          onPressed: () async {
                            await notifProvider.requestPermission();
                          },
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Automation settings card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Adicionar automaticamente ao detectar compra',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Se ativado, ao receber notificação do Nubank, Itaú ou Mercado Pago, ela vira despesa imediatamente sem precisar de confirmação manual.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  value: notifProvider.autoAdd,
                  activeColor: AppConstants.primaryColor,
                  onChanged: (val) => notifProvider.setAutoAdd(val),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Simulation Section
            Text(
              'Simulador de Notificações em Tempo Real (Teste Rápido):',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Clique nos botões abaixo para simular compras chegando dos bancos:',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppConstants.accentGreen,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.pix_rounded),
                  label: const Text('Simular Pix de Sérgio (R\$ 1.000,00)'),
                  onPressed: () => _simulatePreset('pix_sergio'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppConstants.nubankPurple,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Simular Nubank (R\$ 98,50)'),
                  onPressed: () => _simulatePreset('nubank'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppConstants.itauOrange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Simular Itaú (R\$ 120,00)'),
                  onPressed: () => _simulatePreset('itau'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppConstants.mercadoPagoBlue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Simular Mercado Pago (R\$ 32,90)'),
                  onPressed: () => _simulatePreset('mercadopago'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // DDA and Anti-Duplication Presets
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 18, color: AppConstants.accentCyan),
                      const SizedBox(width: 8),
                      Text(
                        'DDA / Boletos Eletrônicos (Detecção & Filtro Anti-Duplicação):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Se o Nubank e o Itaú notificarem sobre o mesmo boleto sob seu CPF, o app detecta a duplicata e ignora a segunda notificação automaticamente!',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppConstants.nubankPurple,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.receipt_rounded, size: 16),
                        label: const Text('1º DDA Nubank (ENEL R\$ 145,20)'),
                        onPressed: () => _simulatePreset('dda_nubank_enel'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppConstants.accentAmber,
                          foregroundColor: Colors.black87,
                        ),
                        icon: const Icon(Icons.shield_rounded, size: 16),
                        label: const Text('2º DDA Itaú Duplicado (Testar Bloqueio)'),
                        onPressed: () => _simulatePreset('dda_itau_enel_duplicate'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppConstants.itauOrange,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.receipt_rounded, size: 16),
                        label: const Text('DDA Itaú (CAGECE R\$ 92,00)'),
                        onPressed: () => _simulatePreset('dda_itau_cagece'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Custom Notification Simulator
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                title: const Text('Simular com texto personalizado'),
                subtitle: const Text('Digite qualquer texto de notificação para testar a extração do valor e estabelecimento'),
                leading: const Icon(Icons.tune_rounded, color: AppConstants.primaryColor),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedPackage,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Aplicativo / Banco Emissor',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'com.nu.production', child: Text('Nubank (com.nu.production)')),
                            DropdownMenuItem(value: 'com.itau', child: Text('Itaú (com.itau)')),
                            DropdownMenuItem(value: 'com.mercadopago.wallet', child: Text('Mercado Pago (com.mercadopago.wallet)')),
                          ],
                          onChanged: (val) => setState(() => _selectedPackage = val!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Título da Notificação',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customTextController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Texto da Notificação',
                            hintText: 'Ex: Compra de R\$ 45,00 aprovada em Padaria Sol.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Disparar Teste'),
                            onPressed: _simulateCustom,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notifications history
            Text(
              'Histórico de Notificações Processadas:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            if (notifProvider.notifications.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Nenhuma notificação capturada ainda.'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notifProvider.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final notif = notifProvider.notifications[index];
                  final bankColor = AppConstants.getBankColor(notif.bankName);

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                      ),
                    ),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: bankColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      notif.bankName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: bankColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    CurrencyFormatter.formatDate(notif.timestamp),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (notif.isDdaBoleto && !notif.isDuplicateDda) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: AppConstants.accentCyan.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DDA',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.accentCyan,
                                        ),
                                      ),
                                    ),
                                  ],
                                  _buildStatusBadge(notif),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notif.rawText,
                            style: const TextStyle(fontSize: 13),
                            softWrap: true,
                          ),
                          if (notif.isDuplicateDda) ...[
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.accentAmber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppConstants.accentAmber.withOpacity(0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.shield_outlined, size: 18, color: AppConstants.accentAmber),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Duplicata Prevenida Automaticamente',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.accentAmber,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Boleto de ${CurrencyFormatter.format(notif.parsedAmount ?? 0)} (${notif.ddaBeneficiary ?? "Beneficiário"}) já capturado via ${notif.duplicateOfBank ?? "outro banco"}. Esta notificação foi ignorada para não duplicar despesas.',
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
                          ] else if (notif.isDdaBoleto) ...[
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.accentCyan.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppConstants.accentCyan.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, size: 18, color: AppConstants.accentCyan),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Boleto DDA Eletrônico (${notif.bankName})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.accentCyan,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Beneficiário: ${notif.ddaBeneficiary ?? "Cedente"} • Vencimento: ${notif.ddaDueDate != null ? CurrencyFormatter.formatDate(notif.ddaDueDate!) : "A definir"}',
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
                          ],
                          const SizedBox(height: 8),
                          if (notif.matchedPersonName != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppConstants.accentAmber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppConstants.accentAmber.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_pin_rounded, size: 14, color: AppConstants.accentAmber),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Pix Reconhecido: ${notif.matchedPersonName}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.accentAmber,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (notif.parsedAmount != null)
                                Text(
                                  'Detectado: ${CurrencyFormatter.format(notif.parsedAmount!)} (${notif.parsedMerchant ?? "Estabelecimento"})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppConstants.accentGreen,
                                  ),
                                ),
                              if (notif.status == NotificationStatus.pending)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (notif.matchedPersonName != null)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppConstants.accentAmber,
                                          foregroundColor: Colors.black87,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        ),
                                        icon: const Icon(Icons.price_check_rounded, size: 15),
                                        label: Text('Abater Contas de ${notif.matchedPersonName}', style: const TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          notifProvider.abateFromNotification(
                                            event: notif,
                                            personName: notif.matchedPersonName!,
                                            debtProvider: context.read<DebtProvider>(),
                                            financeProvider: finProvider,
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Pix de ${CurrencyFormatter.format(notif.parsedAmount ?? 0)} abatido das contas de ${notif.matchedPersonName}!',
                                              ),
                                              backgroundColor: AppConstants.accentGreen,
                                            ),
                                          );
                                        },
                                      ),
                                    TextButton(
                                      onPressed: () => notifProvider.ignoreNotification(notif),
                                      child: const Text('Ignorar', style: TextStyle(fontSize: 12)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConstants.accentGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () => notifProvider.approveNotification(notif, finProvider),
                                      child: const Text('Aprovar e Adicionar', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(NotificationEventModel notif) {
    if (notif.isDuplicateDda) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppConstants.accentAmber.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, size: 13, color: AppConstants.accentAmber),
            SizedBox(width: 4),
            Text(
              'Duplicata Bloqueada',
              style: TextStyle(fontSize: 11, color: AppConstants.accentAmber, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (notif.autoAdded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppConstants.accentGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 13, color: AppConstants.accentGreen),
            SizedBox(width: 4),
            Text(
              'Automático',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppConstants.accentGreen,
              ),
            ),
          ],
        ),
      );
    }

    switch (notif.status) {
      case NotificationStatus.approved:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppConstants.accentGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Aprovado',
            style: TextStyle(fontSize: 11, color: AppConstants.accentGreen, fontWeight: FontWeight.bold),
          ),
        );
      case NotificationStatus.ignored:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Ignorado',
            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        );
      case NotificationStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppConstants.accentAmber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Pendente',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppConstants.accentAmber,
            ),
          ),
        );
    }
  }
}

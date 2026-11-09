import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_event_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/finance_provider.dart';
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

    if (bank == 'nubank') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.nu.production',
        title: 'Compra aprovada no Cartão Nubank',
        text: 'Compra de R\$ 98,50 aprovada em Outback Steakhouse.',
        financeProvider: finProvider,
      );
    } else if (bank == 'itau') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.itau',
        title: 'Cartão Itaú',
        text: 'Compra aprovada de R\$ 120,00 no cartão final 8821 em Posto Ipiranga.',
        financeProvider: finProvider,
      );
    } else if (bank == 'mercadopago') {
      notifProvider.onNotificationReceived(
        appPackage: 'com.mercadopago.wallet',
        title: 'Pagamento aprovado',
        text: 'Você pagou R\$ 32,90 para Livraria Saraiva no débito Mercado Pago.',
        financeProvider: finProvider,
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

    notifProvider.onNotificationReceived(
      appPackage: _selectedPackage,
      title: _customTitleController.text.trim(),
      text: _customTextController.text.trim(),
      financeProvider: finProvider,
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Captura Automática de Notificações',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No Android, o app escuta notificações de bancos e adiciona as compras no crédito automaticamente',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
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
            const SizedBox(height: 20),

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
              child: Row(
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

            // Custom Notification Simulator
            ExpansionTile(
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
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
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
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              _buildStatusBadge(notif.status, notif.autoAdded),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notif.rawText,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (notif.parsedAmount != null)
                                Text(
                                  'Detectado: ${CurrencyFormatter.format(notif.parsedAmount!)} (${notif.parsedMerchant ?? "Estabelecimento"})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.accentRed,
                                  ),
                                ),
                              if (notif.status == NotificationStatus.pending)
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => notifProvider.ignoreNotification(notif),
                                      child: const Text('Ignorar'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConstants.accentGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => notifProvider.approveNotification(notif, finProvider),
                                      child: const Text('Aprovar e Adicionar'),
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

  Widget _buildStatusBadge(NotificationStatus status, bool autoAdded) {
    if (autoAdded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppConstants.accentGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: AppConstants.accentGreen),
            SizedBox(width: 4),
            Text(
              'Adicionado Automaticamente',
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

    switch (status) {
      case NotificationStatus.approved:
        return const Text(
          'Aprovado Manualmente',
          style: TextStyle(fontSize: 11, color: AppConstants.accentGreen, fontWeight: FontWeight.bold),
        );
      case NotificationStatus.ignored:
        return const Text(
          'Ignorado',
          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
        );
      case NotificationStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppConstants.accentAmber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Pendente de Revisão',
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

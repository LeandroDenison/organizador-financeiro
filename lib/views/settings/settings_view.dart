import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/budget_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/storage_service.dart';
import '../../services/pix_payload_service.dart';
import '../../services/sample_data_service.dart';
import '../../utils/constants.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _projectIdController = TextEditingController();
  final _pixKeyController = TextEditingController();
  final _pixNameController = TextEditingController();
  final _pixCityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final firebase = context.read<FirebaseService>();
    if (firebase.projectId != null) {
      _projectIdController.text = firebase.projectId!;
    }
    _loadPixData();
  }

  Future<void> _loadPixData() async {
    final key = await StorageService.getUserPixKey();
    final name = await StorageService.getUserName();
    final city = await StorageService.getUserCity();
    setState(() {
      _pixKeyController.text = key;
      _pixNameController.text = name;
      _pixCityController.text = city;
    });
  }

  @override
  void dispose() {
    _projectIdController.dispose();
    _pixKeyController.dispose();
    _pixNameController.dispose();
    _pixCityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final firebase = context.watch<FirebaseService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Configurações & Conexão Online',
              style: (isMobile
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Gerencie a sincronização com o Firebase Cloud, preferências visuais e dados',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // Firebase Section Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_fire_department_rounded, color: Colors.amber, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Firebase Cloud Firestore',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    firebase.isConnected
                                        ? 'Sincronização em nuvem ativa'
                                        : 'Operando em Modo Offline / Local',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: firebase.isConnected ? AppConstants.accentGreen : Colors.amber.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: firebase.isConnected,
                        activeColor: AppConstants.accentGreen,
                        onChanged: (val) {
                          if (val) {
                            if (_projectIdController.text.trim().isNotEmpty) {
                              firebase.connectWithProjectId(_projectIdController.text.trim());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Insira o Project ID do Firebase primeiro')),
                              );
                            }
                          } else {
                            firebase.disconnect();
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'ID do Projeto Firebase (Project ID):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _projectIdController,
                          decoration: InputDecoration(
                            hintText: 'Ex: organizador-financeiro-123',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: const Icon(Icons.cloud_outlined),
                            suffixIcon: firebase.isConnected
                                ? const Icon(Icons.check_circle_rounded, color: AppConstants.accentGreen)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onPressed: () {
                          if (_projectIdController.text.trim().isNotEmpty) {
                            firebase.connectWithProjectId(_projectIdController.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Conexão com Firebase configurada com sucesso!'),
                                backgroundColor: AppConstants.accentGreen,
                              ),
                            );
                          }
                        },
                        child: const Text('Conectar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: const Text('Sincronizar Agora (Push)'),
                        onPressed: () async {
                          final ok = await firebase.pushToFirestore();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(firebase.lastSyncMessage),
                                backgroundColor: ok ? AppConstants.accentGreen : AppConstants.primaryColor,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.primaryColor,
                          side: const BorderSide(color: AppConstants.primaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.cloud_download_rounded, size: 18),
                        label: const Text('Restaurar da Nuvem (Pull)'),
                        onPressed: () async {
                          final ok = await firebase.pullFromFirestore();
                          if (ok && context.mounted) {
                            await context.read<FinanceProvider>().init();
                            await context.read<DebtProvider>().init();
                            await context.read<SavingsProvider>().init();
                            await context.read<SubscriptionProvider>().init();
                            await context.read<BudgetProvider>().init();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Dados restaurados do Firestore com sucesso!'
                                      : 'Nenhum snapshot remoto encontrado ainda no Firestore (${firebase.projectId}).',
                                ),
                                backgroundColor: ok ? AppConstants.accentGreen : Colors.amber.shade700,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Arquitetura Híbrida Gratuita (Firebase + Google Drive):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Firebase (${firebase.projectId}): Dados leves em JSON (transações, devedores, parcelas, caixinhas e tetos)\n'
                          '• Google Drive (${FirebaseService.driveAccountEmail}): Arquivos pesados (PDFs de faturas, extratos e backups completos)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Google Drive Heavy Storage & Backups Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_to_drive_rounded, color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Drive (Arquivos Pesados & Backups)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Conectado: ${FirebaseService.driveAccountEmail}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppConstants.accentGreen,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Pastas criadas automaticamente no seu Google Drive:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _buildDriveFolderRow(
                    context,
                    isDark: isDark,
                    title: '📁 Organizador Financeiro (Pasta Raiz)',
                    subtitle: 'ID: ${FirebaseService.driveRootFolderId}',
                    url: firebase.driveRootUrl,
                  ),
                  const SizedBox(height: 6),
                  _buildDriveFolderRow(
                    context,
                    isDark: isDark,
                    title: '📄 Faturas e Extratos (PDF)',
                    subtitle: '${firebase.driveFiles.length} PDFs arquivados (${firebase.driveFiles.map((f) => f.name).join(", ")})',
                    url: firebase.drivePdfFolderUrl,
                  ),
                  const SizedBox(height: 6),
                  _buildDriveFolderRow(
                    context,
                    isDark: isDark,
                    title: '💾 Backups (JSON)',
                    subtitle: 'Snapshots completos da base de dados',
                    url: firebase.driveBackupFolderUrl,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 18),
                        label: const Text('Copiar Backup JSON Completo'),
                        onPressed: () async {
                          final jsonStr = await StorageService.exportFullBackupJson();
                          await Clipboard.setData(ClipboardData(text: jsonStr));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backup JSON copiado para a área de transferência!'),
                                backgroundColor: AppConstants.accentGreen,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: const Text('Restaurar de JSON'),
                        onPressed: () => _showRestoreBackupDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pix Configuration Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppConstants.accentGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pix_rounded, color: AppConstants.accentGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuração do Pix & QR Code',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Dados usados na geração do QR Code e Pix Copia e Cola',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pixKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Sua Chave Pix Fixa',
                      hintText: 'Ex: CPF, Telefone, E-mail ou Chave Aleatória EVP',
                      prefixIcon: Icon(Icons.vpn_key_rounded, color: AppConstants.accentGreen),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    TextField(
                      controller: _pixNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Titular',
                        hintText: 'Ex: LEANDRO DENISON',
                        prefixIcon: Icon(Icons.person_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pixCityController,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        hintText: 'Ex: FORTALEZA ou BRASILIA',
                        prefixIcon: Icon(Icons.location_city_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pixNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome do Titular',
                              hintText: 'Ex: LEANDRO DENISON',
                              prefixIcon: Icon(Icons.person_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _pixCityController,
                            decoration: const InputDecoration(
                              labelText: 'Cidade',
                              hintText: 'Ex: FORTALEZA ou BRASILIA',
                              prefixIcon: Icon(Icons.location_city_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Salvar Dados do Pix'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final raw = _pixKeyController.text.trim();
                        final sanitized = PixPayloadService.sanitizePixKey(raw);
                        _pixKeyController.text = sanitized.isNotEmpty ? sanitized : raw;
                        await StorageService.setUserPixKey(_pixKeyController.text);
                        await StorageService.setUserName(_pixNameController.text.trim());
                        await StorageService.setUserCity(_pixCityController.text.trim());
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Dados do Pix salvos! Chave formatada no padrão BACEN: ${_pixKeyController.text}'),
                              backgroundColor: AppConstants.accentGreen,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Appearance Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            appState.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: AppConstants.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Modo Escuro (Dark Mode)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                appState.isDarkMode ? 'Tema escuro ativo' : 'Tema claro ativo',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: appState.isDarkMode,
                    activeThumbColor: AppConstants.primaryColor,
                    onChanged: (_) => appState.toggleDarkMode(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Data management Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gerenciamento de Dados Locais',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Controle os dados armazenados no dispositivo. Você pode zerar a base para começar limpo ou carregar os dados reais extraídos das faturas.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.accentGreen,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.download_done_rounded),
                        label: const Text('Carregar Minhas Faturas (Nubank + Itaú)'),
                        onPressed: () async {
                          final fin = context.read<FinanceProvider>();
                          final debt = context.read<DebtProvider>();
                          
                          // Limpa base e injeta dados reais do Denison
                          await fin.clearTransactions();
                          await debt.clearDebts();

                          final realTxs = SampleDataService.getDenisonRealTransactions();
                          await fin.addMultipleTransactions(realTxs);

                          final realDebts = SampleDataService.getDenisonRealDebts();
                          for (final d in realDebts) {
                            await debt.addDebt(d);
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sucesso! ${realTxs.length} transações e ${realDebts.length} dívida (Sergio Lucas) carregadas.'),
                                backgroundColor: AppConstants.accentGreen,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.accentRed,
                          side: const BorderSide(color: AppConstants.accentRed),
                        ),
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: const Text('Limpar Todos os Dados (Zerar App)'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Limpar Todos os Dados?'),
                              content: const Text(
                                'Esta ação apagará todas as transações, dívidas, notificações e caixinhas locais. Deseja continuar?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentRed),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sim, Limpar Tudo', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && context.mounted) {
                            await StorageService.clearAllData();
                            await context.read<FinanceProvider>().clearTransactions();
                            await context.read<DebtProvider>().clearDebts();
                            await context.read<NotificationProvider>().clearAll();
                            await context.read<SavingsProvider>().clearGoals();
                            await context.read<SubscriptionProvider>().clearSubscriptions();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Aplicativo zerado com sucesso! A base está 100% limpa.'),
                                  backgroundColor: AppConstants.accentGreen,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriveFolderRow(
    BuildContext context, {
    required bool isDark,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar Link da Pasta no Google Drive',
            icon: const Icon(Icons.link_rounded, size: 18, color: Colors.blue),
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Link do Google Drive copiado: $url'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreBackupDialog(BuildContext context) {
    final jsonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Backup JSON'),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: jsonController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Cole aqui o conteúdo do arquivo JSON de backup',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = jsonController.text.trim();
              if (raw.isEmpty) return;
              final ok = await StorageService.importFullBackupJson(raw);
              if (ok && context.mounted) {
                await context.read<FinanceProvider>().init();
                await context.read<DebtProvider>().init();
                await context.read<SavingsProvider>().init();
                await context.read<SubscriptionProvider>().init();
                await context.read<BudgetProvider>().init();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup restaurado com sucesso!'),
                      backgroundColor: AppConstants.accentGreen,
                    ),
                  );
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('JSON inválido. Verifique o conteúdo colado.'),
                    backgroundColor: AppConstants.accentRed,
                  ),
                );
              }
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }
}

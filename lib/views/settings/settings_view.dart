import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/bank_loan_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/storage_service.dart';
import '../../services/pix_payload_service.dart';
import '../../services/open_finance_service.dart';
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

  final _pluggyClientIdController = TextEditingController();
  final _pluggyClientSecretController = TextEditingController();
  final _newItemIdController = TextEditingController();
  String _selectedNewBank = 'Nubank';
  bool _isSyncingOpenFinance = false;
  List<ConnectedBankItem> _connectedBanks = [];

  @override
  void initState() {
    super.initState();
    final firebase = context.read<FirebaseService>();
    if (firebase.projectId != null) {
      _projectIdController.text = firebase.projectId!;
    }
    _loadPixData();
    _loadOpenFinanceData();
  }

  Future<void> _loadOpenFinanceData() async {
    final cfg = await OpenFinanceService.loadConfig();
    setState(() {
      _pluggyClientIdController.text = cfg.clientId;
      _pluggyClientSecretController.text = cfg.clientSecret;
      _connectedBanks = List.from(cfg.connectedBanks);
    });
  }

  Future<void> _saveOpenFinanceConfig() async {
    final cfg = OpenFinanceConfig(
      clientId: _pluggyClientIdController.text.trim(),
      clientSecret: _pluggyClientSecretController.text.trim(),
      connectedBanks: _connectedBanks,
    );
    await OpenFinanceService.saveConfig(cfg);
  }

  String _cleanItemId(String input) {
    final trimmed = input.trim();
    final match = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ).firstMatch(trimmed);
    return match?.group(0) ?? trimmed;
  }

  Future<void> _addBankConnection() async {
    final raw = _newItemIdController.text.trim();
    final cleanId = _cleanItemId(raw);
    if (cleanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insira o Item ID ou o link copiado do meu.pluggy.ai'),
          backgroundColor: AppConstants.accentAmber,
        ),
      );
      return;
    }

    final existingIndex = _connectedBanks.indexWhere((b) => b.id == cleanId);
    if (existingIndex == -1) {
      _connectedBanks.add(
        ConnectedBankItem(
          id: cleanId,
          bankName: _selectedNewBank,
          accountName: 'Conexão $_selectedNewBank',
        ),
      );
    } else {
      _connectedBanks[existingIndex] = ConnectedBankItem(
        id: cleanId,
        bankName: _selectedNewBank,
        accountName: 'Conexão $_selectedNewBank',
      );
    }

    await _saveOpenFinanceConfig();
    _newItemIdController.clear();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Banco $_selectedNewBank salvo com sucesso!'),
          backgroundColor: AppConstants.accentGreen,
        ),
      );
    }
  }

  Future<void> _removeBankConnection(String id) async {
    setState(() {
      _connectedBanks.removeWhere((b) => b.id == id);
    });
    await _saveOpenFinanceConfig();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conexão bancária removida.')),
      );
    }
  }

  Future<void> _syncAllBanks() async {
    setState(() => _isSyncingOpenFinance = true);
    try {
      await _saveOpenFinanceConfig();
      final finance = context.read<FinanceProvider>();
      final loanProvider = context.read<BankLoanProvider>();

      final txs = await OpenFinanceService.fetchTransactions();
      final fetchedLoans = await OpenFinanceService.fetchBankLoans();

      int addedCount = 0;
      for (final tx in txs) {
        final exists = finance.transactions.any((t) =>
            (t.id == tx.id) ||
            (t.title == tx.title &&
                (t.amount - tx.amount).abs() < 0.01 &&
                t.date.day == tx.date.day &&
                t.date.month == tx.date.month));
        if (!exists) {
          await finance.addTransaction(tx);
          addedCount++;
        }
      }

      await loanProvider.syncFromOpenFinance(fetchedLoans);
      await FirebaseService().pushToFirestore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Open Finance sincronizado com sucesso! ($addedCount novas transações, ${fetchedLoans.length} empréstimos)',
            ),
            backgroundColor: AppConstants.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na sincronização Open Finance: $e'),
            backgroundColor: AppConstants.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingOpenFinance = false);
    }
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
    _pluggyClientIdController.dispose();
    _pluggyClientSecretController.dispose();
    _newItemIdController.dispose();
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

            // Open Finance Brasil Section Card (Pluggy API)
            _buildOpenFinanceCard(context, isDark, isMobile),
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

  Widget _buildOpenFinanceCard(BuildContext context, bool isDark, bool isMobile) {
    return Container(
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppConstants.primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Open Finance Brasil (Pluggy API)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Sincronização bancária direta e automática (Nubank, Mercado Pago, Itaú)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Connected Banks List
          Text(
            'Bancos Conectados (${_connectedBanks.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          if (_connectedBanks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum banco conectado ainda. Adicione o Item ID gerado no meu.pluggy.ai abaixo.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _connectedBanks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final bank = _connectedBanks[idx];
                final color = AppConstants.getBankColor(bank.bankName);
                final isNubank = bank.bankName.toLowerCase().contains('nu');

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  bank.bankName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isNubank ? AppConstants.accentGreen : Colors.blue).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isNubank ? 'Ativo & Sincronizado' : 'Configurado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isNubank ? AppConstants.accentGreen : Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${bank.id}',
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
                        tooltip: 'Copiar Item ID',
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: bank.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ID do ${bank.bankName} copiado!'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Remover Conexão',
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeBankConnection(bank.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),

          // Add New Bank Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adicionar Conexão Bancária',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : 160,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedNewBank,
                        decoration: const InputDecoration(
                          labelText: 'Banco',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Nubank', child: Text('Nubank')),
                          DropdownMenuItem(value: 'Mercado Pago', child: Text('Mercado Pago')),
                          DropdownMenuItem(value: 'Itaú', child: Text('Itaú')),
                          DropdownMenuItem(value: 'Banco do Brasil', child: Text('Banco do Brasil')),
                          DropdownMenuItem(value: 'Bradesco', child: Text('Bradesco')),
                          DropdownMenuItem(value: 'Santander', child: Text('Santander')),
                          DropdownMenuItem(value: 'Inter', child: Text('Banco Inter')),
                          DropdownMenuItem(value: 'C6 Bank', child: Text('C6 Bank')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedNewBank = val);
                        },
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : 320,
                      child: TextField(
                        controller: _newItemIdController,
                        decoration: const InputDecoration(
                          labelText: 'Item ID ou Link do meu.pluggy.ai',
                          hintText: 'Ex: 22443998-... ou https://meu.pluggy.ai/connections/...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Adicionar'),
                      onPressed: _addBankConnection,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Action & Sync Button
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: _isSyncingOpenFinance
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(_isSyncingOpenFinance ? 'Sincronizando...' : 'Sincronizar Todos os Bancos Agora'),
                onPressed: _isSyncingOpenFinance ? null : _syncAllBanks,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.accentCyan,
                  side: const BorderSide(color: AppConstants.accentCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                label: const Text('Ajustar Saldos dos Bancos'),
                onPressed: () => _showEditBankBalancesDialog(context),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text('Limpar Tudo (Só Open Finance)'),
                onPressed: () => _showResetCleanDialog(context),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Abrir meu.pluggy.ai'),
                onPressed: () async {
                  const url = 'https://meu.pluggy.ai/connections';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    await Clipboard.setData(const ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copiado: https://meu.pluggy.ai/connections')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // API Credentials Collapsible Card
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_rounded, size: 20, color: Colors.amber),
                title: const Text(
                  'Credenciais da API Pluggy (Avançado)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Client ID e Client Secret da aplicação Open Finance',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        TextField(
                          controller: _pluggyClientIdController,
                          decoration: const InputDecoration(
                            labelText: 'Pluggy Client ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pluggyClientSecretController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Pluggy Client Secret',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _saveOpenFinanceConfig();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Chaves da API salvas com sucesso!'),
                                    backgroundColor: AppConstants.accentGreen,
                                  ),
                                );
                              }
                            },
                            child: const Text('Salvar Credenciais'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditBankBalancesDialog(BuildContext context) {
    final finance = context.read<FinanceProvider>();
    final nubankController = TextEditingController(
      text: finance.getBankBalance('Nubank').toStringAsFixed(2).replaceAll('.', ','),
    );
    final itauController = TextEditingController(
      text: finance.getBankBalance('Itaú').toStringAsFixed(2).replaceAll('.', ','),
    );
    final mpController = TextEditingController(
      text: finance.getBankBalance('Mercado Pago').toStringAsFixed(2).replaceAll('.', ','),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppConstants.accentCyan),
            SizedBox(width: 8),
            Text('Ajustar Saldos em Conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Defina o saldo real disponível em cada conta bancária. Estes valores aparecem no Painel Principal e na Previsão de Saldo:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nubankController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Nubank (Conta Corrente)',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: itauController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Itaú (Conta Corrente)',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: mpController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Mercado Pago (Carteira / Conta)',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final nu = double.tryParse(nubankController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
              final it = double.tryParse(itauController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
              final mp = double.tryParse(mpController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

              await finance.updateBankBalance('Nubank', nu);
              await finance.updateBankBalance('Itaú', it);
              await finance.updateBankBalance('Mercado Pago', mp);

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saldos bancários atualizados com sucesso!'),
                    backgroundColor: AppConstants.accentGreen,
                  ),
                );
              }
            },
            child: const Text('Salvar Saldos'),
          ),
        ],
      ),
    );
  }

  void _showResetCleanDialog(BuildContext context) {
    final finance = context.read<FinanceProvider>();
    final subscriptions = context.read<SubscriptionProvider>();
    final debts = context.read<DebtProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Limpar e Recomeçar?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Esta ação fará uma limpeza completa dos dados anteriores e importará exclusivamente os dados reais e saldos vindos do Open Finance (Pluggy API).\n\nDeseja continuar?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSyncingOpenFinance = true);

              final importedCount = await finance.resetAndImportFromOpenFinance();
              await subscriptions.syncFromTransactions(finance.transactions, debtProvider: debts);

              setState(() => _isSyncingOpenFinance = false);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Base limpa com sucesso! $importedCount transações importadas via Open Finance.'),
                    backgroundColor: AppConstants.accentGreen,
                  ),
                );
              }
            },
            child: const Text('Sim, Limpar e Reimportar'),
          ),
        ],
      ),
    );
  }
}

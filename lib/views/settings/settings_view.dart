import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/storage_service.dart';
import '../../services/pix_payload_service.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Configurações & Conexão Online',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                      Row(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Firebase Cloud Firestore',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                firebase.isConnected
                                    ? 'Sincronização em nuvem ativa'
                                    : 'Operando em Modo Offline / Local',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: firebase.isConnected ? AppConstants.accentGreen : Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                  const SizedBox(height: 16),
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
                          'Coleções sincronizadas automaticamente:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• /users/{userId}/transactions (Receitas e despesas)\n'
                          '• /users/{userId}/debts (Pessoas que me devem e parcelas)\n'
                          '• /users/{userId}/notifications (Histórico de capturas bancárias)',
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configuração do Pix & QR Code',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Dados usados na geração do QR Code e Pix Copia e Cola',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          appState.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: AppConstants.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Modo Escuro (Dark Mode)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            appState.isDarkMode ? 'Tema escuro ativo' : 'Tema claro ativo',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: appState.isDarkMode,
                    activeColor: AppConstants.primaryColor,
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
                    'Todos os seus dados estão salvos com persistência local e são mantidos mesmo após fechar o navegador ou reiniciar o app.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.primaryColor,
                    ),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restaurar Dados de Exemplo'),
                    onPressed: () async {
                      final finProvider = context.read<FinanceProvider>();
                      final debtProv = context.read<DebtProvider>();
                      final notifProv = context.read<NotificationProvider>();
                      await finProvider.init();
                      await debtProv.init();
                      await notifProv.init();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dados de exemplo restaurados com sucesso!'),
                            backgroundColor: AppConstants.accentGreen,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

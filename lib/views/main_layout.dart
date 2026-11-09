import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/debt_provider.dart';
import '../utils/constants.dart';
import 'dashboard/dashboard_view.dart';
import 'transactions/transactions_view.dart';
import 'debts/debts_view.dart';
import 'savings/savings_goals_view.dart';
import 'subscriptions/subscriptions_view.dart';
import 'budgets/budgets_view.dart';
import 'bank_import/bank_import_view.dart';
import 'notifications/notifications_view.dart';
import 'settings/settings_view.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final debtProvider = context.watch<DebtProvider>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    final List<Widget> pages = const [
      DashboardView(), // 0
      TransactionsView(), // 1
      DebtsView(), // 2
      SavingsGoalsView(), // 3
      SubscriptionsView(), // 4
      BudgetsView(), // 5
      BankImportView(), // 6
      NotificationsView(), // 7
      SettingsView(), // 8
    ];

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Left Desktop Sidebar
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // App Branding
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.wallet_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Finanças',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              'Organizador Multiplataforma',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Navigation Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildNavItem(
                          context,
                          index: 0,
                          icon: Icons.dashboard_rounded,
                          label: 'Visão Geral',
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 1,
                          icon: Icons.receipt_long_rounded,
                          label: 'Extrato / Transações',
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 2,
                          icon: Icons.handshake_rounded,
                          label: 'Quem me Deve',
                          badgeCount: debtProvider.activeDebts.length,
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 3,
                          icon: Icons.savings_rounded,
                          label: 'Caixinhas & Metas',
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 4,
                          icon: Icons.repeat_rounded,
                          label: 'Assinaturas Fixas',
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 5,
                          icon: Icons.pie_chart_rounded,
                          label: 'Tetos de Gastos',
                          currentIndex: appState.currentTabIndex,
                        ),
                        const Divider(height: 16),
                        _buildNavItem(
                          context,
                          index: 6,
                          icon: Icons.upload_file_rounded,
                          label: 'Importar Extrato',
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 7,
                          icon: Icons.notifications_active_rounded,
                          label: 'Captura Android',
                          badgeCount: notifProvider.pendingNotifications.length,
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 8,
                          icon: Icons.settings_rounded,
                          label: 'Configurações',
                          currentIndex: appState.currentTabIndex,
                        ),
                      ],
                    ),
                  ),

                  // Bottom Profile & Theme toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppConstants.primaryColor,
                              child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Meu Perfil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Online', style: TextStyle(fontSize: 10, color: AppConstants.accentGreen)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            appState.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            size: 20,
                          ),
                          onPressed: () => appState.toggleDarkMode(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: IndexedStack(
                index: appState.currentTabIndex,
                children: pages,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Navigation Drawer & Bottom Bar
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppConstants.primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wallet_rounded, color: AppConstants.primaryColor, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Organizador Financeiro',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Multiplataforma & Inteligente',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_rounded),
              title: const Text('Visão Geral'),
              selected: appState.currentTabIndex == 0,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('Extrato / Transações'),
              selected: appState.currentTabIndex == 1,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake_rounded),
              title: const Text('Quem me Deve'),
              trailing: debtProvider.activeDebts.isNotEmpty
                  ? Badge(label: Text('${debtProvider.activeDebts.length}'))
                  : null,
              selected: appState.currentTabIndex == 2,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.savings_rounded),
              title: const Text('Caixinhas & Metas'),
              selected: appState.currentTabIndex == 3,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Assinaturas Fixas'),
              selected: appState.currentTabIndex == 4,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart_rounded),
              title: const Text('Tetos de Gastos'),
              selected: appState.currentTabIndex == 5,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(5);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Importar Extrato (OFX/CSV)'),
              selected: appState.currentTabIndex == 6,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(6);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('Captura Android'),
              trailing: notifProvider.pendingNotifications.isNotEmpty
                  ? Badge(label: Text('${notifProvider.pendingNotifications.length}'))
                  : null,
              selected: appState.currentTabIndex == 7,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(7);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Configurações'),
              selected: appState.currentTabIndex == 8,
              onTap: () {
                Navigator.pop(context);
                appState.setTab(8);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wallet_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              _getPageTitle(appState.currentTabIndex),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(appState.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
            onPressed: () => appState.toggleDarkMode(),
          ),
        ],
      ),
      body: IndexedStack(
        index: appState.currentTabIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: appState.currentTabIndex < 4 ? appState.currentTabIndex : 4,
        onDestinationSelected: (idx) {
          if (idx < 4) {
            appState.setTab(idx);
          } else {
            _showMobileMoreMenu(context, appState, notifProvider);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Início',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Extrato',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: debtProvider.activeDebts.isNotEmpty,
              label: Text('${debtProvider.activeDebts.length}'),
              child: const Icon(Icons.handshake_outlined),
            ),
            selectedIcon: const Icon(Icons.handshake_rounded),
            label: 'Devedores',
          ),
          const NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings_rounded),
            label: 'Caixinhas',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: notifProvider.pendingNotifications.isNotEmpty,
              label: Text('${notifProvider.pendingNotifications.length}'),
              child: const Icon(Icons.grid_view_rounded),
            ),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: 'Mais',
          ),
        ],
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Visão Geral';
      case 1:
        return 'Extrato';
      case 2:
        return 'Quem me Deve';
      case 3:
        return 'Caixinhas & Metas';
      case 4:
        return 'Assinaturas Fixas';
      case 5:
        return 'Tetos de Gastos';
      case 6:
        return 'Importar Extrato';
      case 7:
        return 'Captura Android';
      case 8:
        return 'Configurações';
      default:
        return 'Organizador';
    }
  }

  void _showMobileMoreMenu(
    BuildContext context,
    AppStateProvider appState,
    NotificationProvider notifProvider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.repeat_rounded, color: AppConstants.primaryColor),
                  title: const Text('Assinaturas & Custos Fixos'),
                  subtitle: const Text('Detector de assinaturas e dreno anual'),
                  onTap: () {
                    Navigator.pop(ctx);
                    appState.setTab(4);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.pie_chart_rounded, color: AppConstants.accentAmber),
                  title: const Text('Tetos de Gastos por Categoria'),
                  subtitle: const Text('Limites mensais e alertas automáticos'),
                  onTap: () {
                    Navigator.pop(ctx);
                    appState.setTab(5);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded, color: AppConstants.accentGreen),
                  title: const Text('Importar Extrato Bancário'),
                  subtitle: const Text('Arquivos OFX e CSV (Nubank, Itaú, Mercado Pago)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    appState.setTab(6);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded, color: Colors.blue),
                  title: const Text('Captura Android de Pix & Compras'),
                  subtitle: const Text('Leitura de notificações em tempo real'),
                  trailing: notifProvider.pendingNotifications.isNotEmpty
                      ? Badge(label: Text('${notifProvider.pendingNotifications.length}'))
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    appState.setTab(7);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded, color: Colors.grey),
                  title: const Text('Configurações & Firebase'),
                  subtitle: const Text('Ajustes, sincronização e tema'),
                  onTap: () {
                    Navigator.pop(ctx);
                    appState.setTab(8);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required int currentIndex,
    int? badgeCount,
  }) {
    final isSelected = index == currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selected: isSelected,
        selectedTileColor: isDark
            ? AppConstants.primaryColor.withOpacity(0.2)
            : AppConstants.primaryColor.withOpacity(0.1),
        leading: Icon(
          icon,
          color: isSelected
              ? AppConstants.primaryColor
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? AppConstants.primaryColor
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
          ),
        ),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppConstants.primaryColor : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        onTap: () {
          context.read<AppStateProvider>().setTab(index);
        },
      ),
    );
  }
}

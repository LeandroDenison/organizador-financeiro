import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/debt_provider.dart';
import '../utils/constants.dart';
import 'dashboard/dashboard_view.dart';
import 'transactions/transactions_view.dart';
import 'debts/debts_view.dart';
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
      DashboardView(),
      TransactionsView(),
      DebtsView(),
      BankImportView(),
      NotificationsView(),
      SettingsView(),
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
                  const SizedBox(height: 12),

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
                          icon: Icons.upload_file_rounded,
                          label: 'Importar Extrato',
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 4,
                          icon: Icons.notifications_active_rounded,
                          label: 'Captura Android',
                          badgeCount: notifProvider.pendingNotifications.length,
                          currentIndex: appState.currentTabIndex,
                        ),
                        _buildNavItem(
                          context,
                          index: 5,
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

    // Mobile Layout with Bottom Navigation Bar
    return Scaffold(
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
            const Text('Organizador Financeiro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(appState.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
            onPressed: () => appState.toggleDarkMode(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => appState.setTab(5),
          ),
        ],
      ),
      body: IndexedStack(
        index: appState.currentTabIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: appState.currentTabIndex.clamp(0, 4),
        onDestinationSelected: (idx) => appState.setTab(idx),
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
            icon: Icon(Icons.upload_file_outlined),
            selectedIcon: Icon(Icons.upload_file_rounded),
            label: 'Importar',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: notifProvider.pendingNotifications.isNotEmpty,
              label: Text('${notifProvider.pendingNotifications.length}'),
              child: const Icon(Icons.notifications_active_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications_active_rounded),
            label: 'Notificações',
          ),
        ],
      ),
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
        selectedTileColor: isDark ? AppConstants.primaryColor.withOpacity(0.2) : AppConstants.primaryColor.withOpacity(0.1),
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

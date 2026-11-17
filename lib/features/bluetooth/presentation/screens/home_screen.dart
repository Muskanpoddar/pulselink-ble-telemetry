import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/ble_providers.dart';
import '../widgets/status_banner.dart';
import 'dashboard_screen.dart';
import 'gatt_explorer_screen.dart';
import 'scanner_screen.dart';

/// Shell holding the three tabs plus the connection monitor.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedTabProvider);
    final demoMode = ref.watch(demoModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text(
                  'Demo',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.secondaryInk,
                  ),
                ),
                Switch(
                  value: demoMode,
                  onChanged: (_) =>
                      ref.read(demoModeProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const StatusBanner(),
          Expanded(
            child: IndexedStack(
              index: index,
              children: const [
                ScannerScreen(),
                GattExplorerScreen(),
                DashboardScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(selectedTabProvider.notifier).select(value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth_searching),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: 'GATT',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}

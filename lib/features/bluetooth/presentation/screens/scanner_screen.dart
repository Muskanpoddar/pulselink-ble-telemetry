import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../domain/models/ble_device.dart';
import '../providers/ble_providers.dart';
import '../providers/connection_controller.dart';
import '../providers/scanner_controller.dart';
import '../widgets/device_tile.dart';
import 'device_details_screen.dart';

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanner = ref.watch(scannerControllerProvider);
    final adapter = ref.watch(adapterStateProvider);
    final connectedId = ref.watch(connectionControllerProvider).device?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _AdapterPill(state: adapter.value),
              const Spacer(),
              if (scanner.isScanning)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: FilledButton.icon(
            onPressed: scanner.isScanning
                ? () => ref.read(scannerControllerProvider.notifier).stopScan()
                : () => ref.read(scannerControllerProvider.notifier).startScan(),
            icon: Icon(scanner.isScanning ? Icons.stop : Icons.search),
            label: Text(
              scanner.isScanning ? 'STOP SCAN' : 'SCAN FOR DEVICES',
            ),
          ),
        ),
        if (scanner.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusCritical.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.statusCritical.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                scanner.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.statusCritical,
                ),
              ),
            ),
          ),
        SectionHeader(
          'Nearby devices',
          trailing: Text(
            '${scanner.devices.length} found',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.mutedInk,
            ),
          ),
        ),
        Expanded(
          child: scanner.devices.isEmpty
              ? const EmptyState(
                  icon: Icons.bluetooth_searching,
                  title: 'No devices found',
                  message:
                      'Start a scan to discover nearby BLE peripherals.\n'
                      'Turn on Demo mode to try the app without hardware.',
                )
              : ListView.separated(
                  itemCount: scanner.devices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = scanner.devices[index];
                    return DeviceTile(
                      device: device,
                      isConnected: device.id == connectedId,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DeviceDetailsScreen(device: device),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AdapterPill extends StatelessWidget {
  const _AdapterPill({required this.state});

  final BleAdapterState? state;

  @override
  Widget build(BuildContext context) {
    final adapter = state ?? BleAdapterState.unknown;
    final isOn = adapter == BleAdapterState.on;
    final color = isOn ? AppTheme.statusGood : AppTheme.mutedInk;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn ? AppTheme.statusGood : AppTheme.gridline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            isOn ? 'Bluetooth ON' : 'Bluetooth ${adapter.name.toUpperCase()}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

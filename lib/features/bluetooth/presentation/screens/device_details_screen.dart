import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/rssi.dart';
import '../../domain/models/ble_device.dart';
import '../../domain/models/connection.dart';
import '../providers/ble_providers.dart';
import '../providers/connection_controller.dart';
import '../widgets/signal_indicator.dart';

/// Details of one peripheral, with the connect / disconnect action.
class DeviceDetailsScreen extends ConsumerWidget {
  const DeviceDetailsScreen({super.key, required this.device});

  final DiscoveredDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionControllerProvider);
    final isThisDevice = connection.device?.id == device.id;
    final connected =
        isThisDevice && connection.status == ConnectionStatus.connected;
    final busy = isThisDevice &&
        (connection.status == ConnectionStatus.connecting ||
            connection.status == ConnectionStatus.reconnecting);

    return Scaffold(
      appBar: AppBar(title: const Text('Device details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.gridline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name.isEmpty ? 'Unknown device' : device.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  device.id,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryInk,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SignalIndicator(rssi: device.rssi),
                    const SizedBox(width: 10),
                    Text(
                      '${device.rssi} dBm · ${Rssi.quality(device.rssi)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (connection.errorMessage != null && isThisDevice) ...[
            const SizedBox(height: 16),
            Text(
              connection.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.statusCritical,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () {
                    final controller = ref.read(
                      connectionControllerProvider.notifier,
                    );
                    if (connected) {
                      controller.disconnect();
                    } else {
                      controller.connect(device);
                    }
                  },
            icon: Icon(connected ? Icons.link_off : Icons.link),
            label: Text(connected ? 'DISCONNECT' : 'CONNECT'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: connected
                ? () {
                    ref.read(selectedTabProvider.notifier).select(1);
                    Navigator.of(context).pop();
                  }
                : null,
            icon: const Icon(Icons.hub_outlined),
            label: const Text('OPEN GATT EXPLORER'),
          ),
        ],
      ),
    );
  }
}

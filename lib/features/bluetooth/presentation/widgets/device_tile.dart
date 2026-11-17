import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/rssi.dart';
import '../../domain/models/ble_device.dart';
import 'signal_indicator.dart';

/// One row of the scanner list.
class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.isConnected = false,
  });

  final DiscoveredDevice device;
  final VoidCallback onTap;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final name = device.name.isEmpty ? 'Unknown device' : device.name;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        backgroundColor: AppTheme.surface,
        child: Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: isConnected ? AppTheme.statusGood : AppTheme.series1,
          size: 20,
        ),
      ),
      title: Text(name),
      subtitle: Text(
        '${device.rssi} dBm · ${Rssi.quality(device.rssi)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.secondaryInk,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignalIndicator(rssi: device.rssi),
          const SizedBox(width: 12),
          Text(
            isConnected ? 'Connected' : 'Available',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isConnected ? AppTheme.statusGood : AppTheme.secondaryInk,
            ),
          ),
        ],
      ),
    );
  }
}

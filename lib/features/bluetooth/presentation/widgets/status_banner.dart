import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/models/connection.dart';
import '../providers/connection_controller.dart';

/// The connection monitor: shows the live link state of the selected device.
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionControllerProvider);

    final (color, label) = switch (state.status) {
      ConnectionStatus.connected => (AppTheme.statusGood, 'Connected'),
      ConnectionStatus.connecting => (AppTheme.series1, 'Connecting'),
      ConnectionStatus.reconnecting => (AppTheme.statusWarning, 'Reconnecting'),
      ConnectionStatus.failed => (AppTheme.statusCritical, 'Connection failed'),
      ConnectionStatus.disconnected => (AppTheme.mutedInk, 'Not connected'),
    };

    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (state.device != null)
            Flexible(
              child: Text(
                state.device!.name.isEmpty ? state.device!.id : state.device!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.secondaryInk,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

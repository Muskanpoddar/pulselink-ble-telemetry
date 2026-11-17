import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/byte_codec.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../domain/models/connection.dart';
import '../../domain/models/gatt.dart';
import '../providers/connection_controller.dart';
import '../providers/gatt_controller.dart';

/// Lists the services and characteristics of the connected peripheral.
class GattExplorerScreen extends ConsumerStatefulWidget {
  const GattExplorerScreen({super.key});

  @override
  ConsumerState<GattExplorerScreen> createState() => _GattExplorerScreenState();
}

class _GattExplorerScreenState extends ConsumerState<GattExplorerScreen> {
  /// The device whose services were loaded last, so we load once per device.
  String? _loadedFor;

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionControllerProvider);
    final gatt = ref.watch(gattControllerProvider);

    if (connection.status != ConnectionStatus.connected) {
      _loadedFor = null;
      return const EmptyState(
        icon: Icons.hub_outlined,
        title: 'No device connected',
        message:
            'Connect to a peripheral in the Scanner tab to explore its GATT '
            'database.',
      );
    }

    final deviceId = connection.device?.id;
    if (deviceId != null && deviceId != _loadedFor && !gatt.isLoading) {
      _loadedFor = deviceId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(gattControllerProvider.notifier).load();
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${gatt.services.length} services discovered',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryInk,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => ref.read(gattControllerProvider.notifier).load(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        if (gatt.isLoading) const LinearProgressIndicator(),
        if (gatt.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              gatt.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.statusCritical,
              ),
            ),
          ),
        const SectionHeader('GATT database'),
        Expanded(
          child: gatt.services.isEmpty
              ? const EmptyState(
                  icon: Icons.storage_outlined,
                  title: 'No services yet',
                  message: 'Tap Refresh to discover the services.',
                )
              : ListView(
                  children: [
                    for (final service in gatt.services)
                      _ServiceTile(service: service),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ServiceTile extends ConsumerWidget {
  const _ServiceTile({required this.service});

  final GattService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text(
        service.uuid,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${service.characteristics.length} characteristics'
        '${service.isPrimary ? '' : ' · secondary'}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.secondaryInk,
        ),
      ),
      children: [
        for (final characteristic in service.characteristics)
          _CharacteristicTile(characteristic: characteristic),
      ],
    );
  }
}

class _CharacteristicTile extends ConsumerWidget {
  const _CharacteristicTile({required this.characteristic});

  final GattCharacteristic characteristic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatt = ref.watch(gattControllerProvider);
    final value = gatt.values[characteristic.uuid];

    return ListTile(
      dense: true,
      title: Text(
        characteristic.uuid,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              if (characteristic.canRead) const _PropertyChip(label: 'R'),
              if (characteristic.canWrite) const _PropertyChip(label: 'W'),
              if (characteristic.canNotify) const _PropertyChip(label: 'N'),
              if (characteristic.canIndicate) const _PropertyChip(label: 'I'),
              if (value != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ByteCodec.toHex(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.mutedInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: characteristic.canRead
          ? IconButton(
              tooltip: 'Read',
              icon: const Icon(Icons.download_outlined, size: 20),
              onPressed: () => ref
                  .read(gattControllerProvider.notifier)
                  .read(characteristic.uuid),
            )
          : null,
    );
  }
}

class _PropertyChip extends StatelessWidget {
  const _PropertyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(right: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.series1.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.series1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../domain/models/connection.dart';
import '../providers/connection_controller.dart';
import '../providers/telemetry_controller.dart';
import '../widgets/sparkline_chart.dart';
import '../widgets/telemetry_gauge.dart';

/// Live sensor readings of the connected peripheral.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionControllerProvider);
    final telemetry = ref.watch(telemetryControllerProvider);

    if (connection.status != ConnectionStatus.connected) {
      return const EmptyState(
        icon: Icons.dashboard_outlined,
        title: 'Not connected',
        message:
            'Connect to a peripheral to receive telemetry on this dashboard.',
      );
    }

    final frame = telemetry.latest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        FilledButton.icon(
          onPressed: () {
            final controller = ref.read(telemetryControllerProvider.notifier);
            if (telemetry.isSubscribed) {
              controller.stop();
            } else {
              controller.start();
            }
          },
          icon: Icon(telemetry.isSubscribed ? Icons.pause : Icons.play_arrow),
          label: Text(
            telemetry.isSubscribed ? 'STOP TELEMETRY' : 'START TELEMETRY',
          ),
        ),
        if (telemetry.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            telemetry.errorMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.statusCritical,
            ),
          ),
        ],
        const SectionHeader('Incoming telemetry'),
        if (frame == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                telemetry.isSubscribed
                    ? 'Waiting for the first packet…'
                    : 'Start the telemetry stream to receive packets.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryInk,
                ),
              ),
            ),
          )
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: [
              TelemetryGauge(
                label: 'ACCELEROMETER X',
                value: frame.accelX.toStringAsFixed(2),
                unit: 'm/s²',
                accent: AppTheme.series1,
              ),
              TelemetryGauge(
                label: 'ACCELEROMETER Y',
                value: frame.accelY.toStringAsFixed(2),
                unit: 'm/s²',
                accent: AppTheme.series1,
              ),
              TelemetryGauge(
                label: 'ACCELEROMETER Z',
                value: frame.accelZ.toStringAsFixed(2),
                unit: 'm/s²',
                accent: AppTheme.series1,
              ),
              TelemetryGauge(
                label: 'GYROSCOPE X',
                value: frame.gyroX.toStringAsFixed(2),
                unit: '°/s',
                accent: AppTheme.series2,
              ),
              TelemetryGauge(
                label: 'GYROSCOPE Y',
                value: frame.gyroY.toStringAsFixed(2),
                unit: '°/s',
                accent: AppTheme.series2,
              ),
              TelemetryGauge(
                label: 'GYROSCOPE Z',
                value: frame.gyroZ.toStringAsFixed(2),
                unit: '°/s',
                accent: AppTheme.series2,
              ),
              TelemetryGauge(
                label: 'TEMPERATURE',
                value: frame.temperatureC.toStringAsFixed(1),
                unit: '°C',
              ),
              TelemetryGauge(
                label: 'SPEED',
                value: frame.speedKmh.toStringAsFixed(1),
                unit: 'km/h',
              ),
              TelemetryGauge(
                label: 'BATTERY',
                value: '${frame.batteryPercent}',
                unit: '%',
                accent: frame.lowBattery
                    ? AppTheme.statusCritical
                    : AppTheme.statusGood,
              ),
            ],
          ),
          const SectionHeader('Speed over time'),
          SparklineChart(
            values: telemetry.speedHistory,
            color: AppTheme.series1,
          ),
          const SizedBox(height: 20),
          const SectionHeader('Acceleration magnitude'),
          SparklineChart(
            values: telemetry.accelHistory,
            color: AppTheme.series2,
          ),
        ],
        const SectionHeader('Connection'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.gridline),
          ),
          child: Column(
            children: [
              _InfoRow(label: 'Device', value: connection.device?.name ?? '—'),
              _InfoRow(
                label: 'Characteristic',
                value: telemetry.sourceCharacteristic ?? '—',
              ),
              _InfoRow(
                label: 'Packets received',
                value: '${telemetry.packetsReceived}',
              ),
              _InfoRow(
                label: 'Malformed packets',
                value: '${telemetry.parseErrors}',
              ),
              _InfoRow(
                label: 'Sequence',
                value: frame == null ? '—' : '${frame.sequence}',
              ),
              _InfoRow(
                label: 'Flags',
                value: frame == null
                    ? '—'
                    : [
                        if (frame.moving) 'moving',
                        if (frame.lowBattery) 'low battery',
                        if (frame.charging) 'charging',
                      ].join(', '),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryInk,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.primaryInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

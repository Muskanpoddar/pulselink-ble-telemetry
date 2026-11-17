import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/ble_repository_impl.dart';
import '../../data/repositories/simulated_ble_repository.dart';
import '../../data/repositories/telemetry_repository_impl.dart';
import '../../data/services/ble_service.dart';
import '../../data/services/permission_service.dart';
import '../../domain/repositories/ble_repository.dart';
import '../../domain/repositories/telemetry_repository.dart';
import '../../domain/models/ble_device.dart';

/// Demo mode swaps the live backend for the simulated peripheral.
class DemoModeController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final demoModeProvider = NotifierProvider<DemoModeController, bool>(
  DemoModeController.new,
);

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);

final bleRepositoryProvider = Provider<BleRepository>((ref) {
  if (ref.watch(demoModeProvider)) {
    return SimulatedBleRepository();
  }
  final service = BleService();
  ref.onDispose(service.dispose);
  return BleRepositoryImpl(
    bleService: service,
    permissionService: ref.watch(permissionServiceProvider),
  );
});

final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  final repository = TelemetryRepositoryImpl(ref.watch(bleRepositoryProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

/// Live Bluetooth adapter state.
final adapterStateProvider = StreamProvider<BleAdapterState>(
  (ref) => ref.watch(bleRepositoryProvider).adapterState,
);

/// Index of the selected tab in the home shell.
class SelectedTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final selectedTabProvider = NotifierProvider<SelectedTabController, int>(
  SelectedTabController.new,
);

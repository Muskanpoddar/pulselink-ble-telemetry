import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_link/features/bluetooth/domain/models/ble_device.dart';
import 'package:pulse_link/features/bluetooth/presentation/providers/ble_providers.dart';
import 'package:pulse_link/features/bluetooth/presentation/providers/scanner_controller.dart';

import 'fakes/fake_ble_repository.dart';

void main() {
  const weak = DiscoveredDevice(id: 'a', name: 'Node A', rssi: -80);
  const strong = DiscoveredDevice(id: 'a', name: 'Node A', rssi: -50);
  const other = DiscoveredDevice(id: 'b', name: 'Node B', rssi: -60);

  test('keeps the strongest reading per device and sorts by signal', () async {
    final fake = FakeBleRepository();
    final container = ProviderContainer(
      overrides: [bleRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    // Build the controller so it starts listening.
    container.read(scannerControllerProvider);

    fake.emitScanResults([weak, other, strong]);
    // Broadcast streams deliver asynchronously.
    await Future<void>.delayed(Duration.zero);

    final devices = container.read(scannerControllerProvider).devices;
    expect(devices.length, 2);
    expect(devices.first.id, 'a');
    expect(devices.first.rssi, -50);
    expect(devices.last.id, 'b');
  });

  test('a failing scan reports the error and stops scanning', () async {
    final fake = FakeBleRepository()..failScan = true;
    final container = ProviderContainer(
      overrides: [bleRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    container.read(scannerControllerProvider);
    await container.read(scannerControllerProvider.notifier).startScan();

    final state = container.read(scannerControllerProvider);
    expect(state.isScanning, isFalse);
    expect(state.errorMessage, contains('permission denied'));
  });
}

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_link/features/bluetooth/domain/models/ble_device.dart';
import 'package:pulse_link/features/bluetooth/domain/models/connection.dart';
import 'package:pulse_link/features/bluetooth/presentation/providers/ble_providers.dart';
import 'package:pulse_link/features/bluetooth/presentation/providers/connection_controller.dart';

import 'fakes/fake_ble_repository.dart';

void main() {
  const device = DiscoveredDevice(id: 'a', name: 'Node A', rssi: -50);

  test('a successful connect moves the state to connected', () async {
    final fake = FakeBleRepository();
    final container = ProviderContainer(
      overrides: [bleRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    container.read(connectionControllerProvider);
    await container.read(connectionControllerProvider.notifier).connect(device);

    final state = container.read(connectionControllerProvider);
    expect(state.status, ConnectionStatus.connected);
    expect(state.device, device);
  });

  test('a failed connect reports the error', () async {
    final fake = FakeBleRepository()..failConnect = true;
    final container = ProviderContainer(
      overrides: [bleRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    container.read(connectionControllerProvider);
    await container.read(connectionControllerProvider.notifier).connect(device);

    final state = container.read(connectionControllerProvider);
    expect(state.status, ConnectionStatus.failed);
    expect(state.errorMessage, contains('connection refused'));
  });

  test('an unexpected drop triggers a delayed reconnect', () {
    fakeAsync((async) {
      final fake = FakeBleRepository();
      final container = ProviderContainer(
        overrides: [bleRepositoryProvider.overrideWithValue(fake)],
      );

      container.read(connectionControllerProvider);
      final controller = container.read(connectionControllerProvider.notifier);

      controller.connect(device);
      async.flushMicrotasks();
      expect(
        container.read(connectionControllerProvider).status,
        ConnectionStatus.connected,
      );

      // The peripheral drops the link on its own.
      fake.emitConnectionState(ConnectionStatus.disconnected);
      async.flushMicrotasks();
      expect(
        container.read(connectionControllerProvider).status,
        ConnectionStatus.reconnecting,
      );

      // The first retry fires after one second.
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(
        container.read(connectionControllerProvider).status,
        ConnectionStatus.connected,
      );
      expect(fake.connectCalls, 2);

      container.dispose();
    });
  });

  test('a user initiated disconnect does not reconnect', () async {
    final fake = FakeBleRepository();
    final container = ProviderContainer(
      overrides: [bleRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    container.read(connectionControllerProvider);
    final controller = container.read(connectionControllerProvider.notifier);

    await controller.connect(device);
    await controller.disconnect();

    expect(
      container.read(connectionControllerProvider).status,
      ConnectionStatus.disconnected,
    );
    expect(fake.connectCalls, 1);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_link/core/constants/ble_constants.dart';
import 'package:pulse_link/features/bluetooth/data/repositories/telemetry_repository_impl.dart';
import 'package:pulse_link/features/bluetooth/domain/models/gatt.dart';

import 'fakes/fake_ble_repository.dart';

void main() {
  const known = BleConstants.telemetryCharacteristicUuid;
  const other = '0000aaaa-0000-1000-8000-00805f9b34fb';

  FakeBleRepository buildFake() => FakeBleRepository()
    ..services = const [
      GattService(
        uuid: BleConstants.telemetryServiceUuid,
        characteristics: [
          GattCharacteristic(uuid: known, canRead: true, canNotify: true),
          GattCharacteristic(uuid: other, canRead: true, canNotify: true),
          GattCharacteristic(uuid: 'read-only', canRead: true),
        ],
      ),
    ];

  test('the known characteristic is used by default', () async {
    final fake = buildFake();
    final repository = TelemetryRepositoryImpl(fake);
    addTearDown(repository.dispose);
    addTearDown(fake.dispose);

    await repository.start();
    expect(repository.sourceCharacteristic, known);
  });

  test('an explicit characteristic wins over the known one', () async {
    final fake = buildFake();
    final repository = TelemetryRepositoryImpl(fake);
    addTearDown(repository.dispose);
    addTearDown(fake.dispose);

    await repository.start(characteristicUuid: other);
    expect(repository.sourceCharacteristic, other);
  });

  test('a characteristic that cannot notify is rejected', () async {
    final fake = buildFake();
    final repository = TelemetryRepositoryImpl(fake);
    addTearDown(repository.dispose);
    addTearDown(fake.dispose);

    expect(
      () => repository.start(characteristicUuid: 'read-only'),
      throwsA(isA<StateError>()),
    );
  });

  test('a peripheral without any notify characteristic is rejected', () async {
    final fake = FakeBleRepository()
      ..services = const [
        GattService(
          uuid: BleConstants.telemetryServiceUuid,
          characteristics: [GattCharacteristic(uuid: 'read-only', canRead: true)],
        ),
      ];
    final repository = TelemetryRepositoryImpl(fake);
    addTearDown(repository.dispose);
    addTearDown(fake.dispose);

    expect(() => repository.start(), throwsA(isA<StateError>()));
  });
}

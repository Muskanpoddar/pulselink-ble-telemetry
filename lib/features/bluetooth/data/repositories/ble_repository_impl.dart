import '../../domain/models/ble_device.dart';
import '../../domain/models/connection.dart';
import '../../domain/models/gatt.dart';
import '../../domain/repositories/ble_repository.dart';
import '../services/ble_service.dart';
import '../services/permission_service.dart';

/// Live backend on top of flutter_blue_plus.
class BleRepositoryImpl implements BleRepository {
  BleRepositoryImpl({
    required BleService bleService,
    required PermissionService permissionService,
  }) : _ble = bleService,
       _permissions = permissionService;

  final BleService _ble;
  final PermissionService _permissions;

  @override
  Stream<BleAdapterState> get adapterState => _ble.adapterState;

  @override
  Stream<ConnectionStatus> get connectionState => _ble.connectionState;

  @override
  Stream<List<DiscoveredDevice>> get scanResults => _ble.scanResults;

  @override
  Future<void> startScan() async {
    final granted = await _permissions.ensureBlePermissions();
    if (!granted) {
      throw const BleException(
        'Bluetooth permission is required to scan for nearby devices.',
      );
    }
    await _ble.startScan();
  }

  @override
  Future<void> stopScan() => _ble.stopScan();

  @override
  Future<void> connect(DiscoveredDevice device) => _ble.connect(device);

  @override
  Future<void> disconnect() => _ble.disconnect();

  @override
  Future<List<GattService>> discoverServices() => _ble.discoverServices();

  @override
  Future<List<int>> readCharacteristic(String uuid) =>
      _ble.readCharacteristic(uuid);

  @override
  Future<void> writeCharacteristic(String uuid, List<int> value) =>
      _ble.writeCharacteristic(uuid, value);

  @override
  Future<void> setNotifyEnabled(String uuid, bool enabled) =>
      _ble.setNotifyEnabled(uuid, enabled);

  @override
  Stream<List<int>> notifications(String uuid) => _ble.notifications(uuid);
}

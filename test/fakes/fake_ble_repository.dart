import 'dart:async';

import 'package:pulse_link/features/bluetooth/domain/models/ble_device.dart';
import 'package:pulse_link/features/bluetooth/domain/models/connection.dart';
import 'package:pulse_link/features/bluetooth/domain/models/gatt.dart';
import 'package:pulse_link/features/bluetooth/domain/repositories/ble_repository.dart';

/// A BLE repository whose behaviour the test drives by hand.
class FakeBleRepository implements BleRepository {
  final StreamController<BleAdapterState> _adapterController =
      StreamController<BleAdapterState>.broadcast();
  final StreamController<List<DiscoveredDevice>> _scanController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  final StreamController<ConnectionStatus> _connectionController =
      StreamController<ConnectionStatus>.broadcast();

  /// When true, [connect] throws instead of succeeding.
  bool failConnect = false;

  /// When true, [startScan] throws instead of succeeding.
  bool failScan = false;

  /// How many times [connect] was called.
  int connectCalls = 0;

  /// The GATT database the fake peripheral exposes.
  List<GattService> services = const [];

  final Map<String, StreamController<List<int>>> _notificationControllers = {};

  /// Pushes a notification payload to [uuid].
  void emitNotification(String uuid, List<int> bytes) =>
      _notificationControllers[uuid]?.add(bytes);

  @override
  Stream<BleAdapterState> get adapterState => _adapterController.stream;

  @override
  Stream<ConnectionStatus> get connectionState => _connectionController.stream;

  @override
  Stream<List<DiscoveredDevice>> get scanResults => _scanController.stream;

  /// Pushes a scan result to the listeners.
  void emitScanResults(List<DiscoveredDevice> devices) =>
      _scanController.add(devices);

  /// Pushes a connection state change to the listeners.
  void emitConnectionState(ConnectionStatus status) =>
      _connectionController.add(status);

  @override
  Future<void> startScan() async {
    if (failScan) {
      throw const BleException('bluetooth permission denied');
    }
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(DiscoveredDevice device) async {
    connectCalls++;
    if (failConnect) {
      throw const BleException('connection refused');
    }
    _connectionController.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _connectionController.add(ConnectionStatus.disconnected);
  }

  @override
  Future<List<GattService>> discoverServices() async => services;

  @override
  Future<List<int>> readCharacteristic(String uuid) async => const [];

  @override
  Future<void> writeCharacteristic(String uuid, List<int> value) async {}

  @override
  Future<void> setNotifyEnabled(String uuid, bool enabled) async {}

  @override
  Stream<List<int>> notifications(String uuid) => _notificationControllers
      .putIfAbsent(
        uuid,
        () => StreamController<List<int>>.broadcast(),
      )
      .stream;

  void dispose() {
    _adapterController.close();
    _scanController.close();
    _connectionController.close();
    for (final controller in _notificationControllers.values) {
      controller.close();
    }
    _notificationControllers.clear();
  }
}

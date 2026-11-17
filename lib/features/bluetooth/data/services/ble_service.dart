import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/ble_device.dart';
import '../../domain/models/connection.dart';
import '../../domain/models/gatt.dart';

/// The only class in the app that talks to flutter_blue_plus.
///
/// Everything above this layer works with domain models, so a plugin API change
/// stays contained in this file.
class BleService {
  BleService();

  final Map<String, BluetoothDevice> _devicesById = {};
  BluetoothDevice? _connected;

  final StreamController<ConnectionStatus> _connectionController =
      StreamController<ConnectionStatus>.broadcast();
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  /// Bluetooth adapter state, pushed by the plugin whenever it changes.
  Stream<BleAdapterState> get adapterState =>
      FlutterBluePlus.adapterState.map(_mapAdapterState);

  /// Connection state of the peripheral we are talking to.
  Stream<ConnectionStatus> get connectionState => _connectionController.stream;

  /// Devices seen so far during the current scan.
  Stream<List<DiscoveredDevice>> get scanResults =>
      FlutterBluePlus.scanResults.map((results) {
        final devices = <DiscoveredDevice>[];
        for (final result in results) {
          final id = result.device.remoteId.str;
          _devicesById[id] = result.device;
          final advertised = result.advertisementData.advName;
          devices.add(
            DiscoveredDevice(
              id: id,
              name: advertised.isNotEmpty
                  ? advertised
                  : result.device.platformName,
              rssi: result.rssi,
            ),
          );
        }
        return devices;
      });

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: AppConstants.scanTimeout);
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(DiscoveredDevice device) async {
    final target = _devicesById[device.id];
    if (target == null) {
      throw BleException('Device ${device.id} is unknown, please scan again.');
    }

    await _connectionSubscription?.cancel();
    _connectionSubscription = target.connectionState.listen(
      (state) => _connectionController.add(
        state == BluetoothConnectionState.connected
            ? ConnectionStatus.connected
            : ConnectionStatus.disconnected,
      ),
    );

    // The default mtu of 512 matters: our 41 byte packet does not fit into
    // the 23 byte default MTU.
    await target.connect(timeout: AppConstants.connectTimeout);
    _connected = target;
  }

  Future<void> disconnect() async {
    final device = _connected;
    _connected = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (device != null) {
      await device.disconnect();
    }
    _connectionController.add(ConnectionStatus.disconnected);
  }

  Future<List<GattService>> discoverServices() async {
    final device = _connected;
    if (device == null) {
      throw BleException('Not connected to a device.');
    }
    final services = await device.discoverServices();
    return [
      for (final service in services)
        GattService(
          uuid: service.uuid.str128,
          isPrimary: service.isPrimary,
          characteristics: [
            for (final characteristic in service.characteristics)
              GattCharacteristic(
                uuid: characteristic.uuid.str128,
                canRead: characteristic.properties.read,
                canWrite: characteristic.properties.write,
                canNotify: characteristic.properties.notify,
                canIndicate: characteristic.properties.indicate,
              ),
          ],
        ),
    ];
  }

  Future<List<int>> readCharacteristic(String uuid) async {
    final characteristic = _findCharacteristic(uuid);
    return characteristic.read();
  }

  Future<void> writeCharacteristic(String uuid, List<int> value) async {
    final characteristic = _findCharacteristic(uuid);
    await characteristic.write(value);
  }

  Future<void> setNotifyEnabled(String uuid, bool enabled) async {
    final characteristic = _findCharacteristic(uuid);
    await characteristic.setNotifyValue(enabled);
  }

  Stream<List<int>> notifications(String uuid) =>
      _findCharacteristic(uuid).onValueReceived;

  BluetoothCharacteristic _findCharacteristic(String uuid) {
    final device = _connected;
    if (device == null) {
      throw BleException('Not connected to a device.');
    }
    final target = uuid.toLowerCase();
    for (final service in device.servicesList) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid.str128.toLowerCase() == target) {
          return characteristic;
        }
      }
    }
    throw BleException('Characteristic $uuid not found.');
  }

  BleAdapterState _mapAdapterState(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.on:
        return BleAdapterState.on;
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
        return BleAdapterState.off;
      case BluetoothAdapterState.unauthorized:
        return BleAdapterState.unauthorized;
      case BluetoothAdapterState.unavailable:
        return BleAdapterState.unsupported;
      case BluetoothAdapterState.turningOn:
      case BluetoothAdapterState.unknown:
        return BleAdapterState.unknown;
    }
  }

  /// Releases the stream controllers and the connection subscription.
  void dispose() {
    _connectionSubscription?.cancel();
    _connectionController.close();
  }
}

import '../models/ble_device.dart';
import '../models/connection.dart';
import '../models/gatt.dart';

/// The BLE port used by the presentation layer.
///
/// Implemented by the live flutter_blue_plus backend and by the simulated
/// peripheral, so the UI never depends on the plugin.
abstract interface class BleRepository {
  /// Bluetooth adapter state, re-emitted while it changes.
  Stream<BleAdapterState> get adapterState;

  /// Connection state of the currently selected peripheral.
  Stream<ConnectionStatus> get connectionState;

  /// Devices seen so far during the current scan.
  Stream<List<DiscoveredDevice>> get scanResults;

  Future<void> startScan();

  Future<void> stopScan();

  Future<void> connect(DiscoveredDevice device);

  Future<void> disconnect();

  Future<List<GattService>> discoverServices();

  Future<List<int>> readCharacteristic(String uuid);

  Future<void> writeCharacteristic(String uuid, List<int> value);

  Future<void> setNotifyEnabled(String uuid, bool enabled);

  /// Raw notification payloads for [uuid].
  Stream<List<int>> notifications(String uuid);
}

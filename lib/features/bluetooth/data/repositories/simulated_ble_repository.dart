import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/ble_constants.dart';
import '../../domain/models/ble_device.dart';
import '../../domain/models/connection.dart';
import '../../domain/models/gatt.dart';
import '../../domain/models/telemetry_frame.dart';
import '../../domain/repositories/ble_repository.dart';

/// A fake peripheral that behaves like a real one.
///
/// It advertises two devices, exposes the PulseLink GATT profile and streams
/// telemetry packets encoded with the very same format the parser expects, so
/// the whole pipeline can be exercised without hardware.
class SimulatedBleRepository implements BleRepository {
  SimulatedBleRepository();

  final StreamController<List<DiscoveredDevice>> _scanController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  final StreamController<ConnectionStatus> _connectionController =
      StreamController<ConnectionStatus>.broadcast();
  final Map<String, StreamController<List<int>>> _notificationControllers = {};

  Timer? _telemetryTimer;
  DiscoveredDevice? _connectedDevice;
  List<int> _lastPacket = const [];
  int _sequence = 0;
  final math.Random _random = math.Random(7);

  static const List<DiscoveredDevice> _devices = [
    DiscoveredDevice(
      id: 'sim:esp32-0001',
      name: 'ESP32 Sensor Node',
      rssi: -54,
    ),
    DiscoveredDevice(
      id: 'sim:demo-0002',
      name: 'Demo Sensor Device',
      rssi: -71,
    ),
  ];

  @override
  Stream<BleAdapterState> get adapterState =>
      Stream.value(BleAdapterState.on);

  @override
  Stream<ConnectionStatus> get connectionState async* {
    yield ConnectionStatus.disconnected;
    yield* _connectionController.stream;
  }

  @override
  Stream<List<DiscoveredDevice>> get scanResults async* {
    yield const [];
    yield* _scanController.stream;
  }

  @override
  Future<void> startScan() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // The RSSI wobbles a little so the list looks alive.
    _scanController.add([
      for (final device in _devices)
        device.copyWith(rssi: device.rssi + _random.nextInt(5) - 2),
    ]);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(DiscoveredDevice device) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _connectedDevice = device;
    _connectionController.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _stopTelemetry();
    _connectedDevice = null;
    _connectionController.add(ConnectionStatus.disconnected);
  }

  @override
  Future<List<GattService>> discoverServices() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      GattService(
        uuid: BleConstants.telemetryServiceUuid,
        characteristics: [
          GattCharacteristic(
            uuid: BleConstants.telemetryCharacteristicUuid,
            canRead: true,
            canNotify: true,
          ),
          GattCharacteristic(
            uuid: BleConstants.commandCharacteristicUuid,
            canWrite: true,
          ),
          GattCharacteristic(
            uuid: BleConstants.deviceInfoCharacteristicUuid,
            canRead: true,
          ),
        ],
      ),
      GattService(
        uuid: '0000180f-0000-1000-8000-00805f9b34fb',
        characteristics: [
          GattCharacteristic(
            uuid: '00002a19-0000-1000-8000-00805f9b34fb',
            canRead: true,
            canNotify: true,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<int>> readCharacteristic(String uuid) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    switch (uuid.toLowerCase()) {
      case BleConstants.deviceInfoCharacteristicUuid:
        return utf8.encode(_connectedDevice?.name ?? 'PulseLink ESP32 Node');
      case '00002a19-0000-1000-8000-00805f9b34fb':
        return [87];
      default:
        return _lastPacket;
    }
  }

  @override
  Future<void> writeCharacteristic(String uuid, List<int> value) async {
    // Commands are accepted but ignored by the simulated node.
  }

  @override
  Future<void> setNotifyEnabled(String uuid, bool enabled) async {
    _notificationControllers.putIfAbsent(
      uuid.toLowerCase(),
      () => StreamController<List<int>>.broadcast(),
    );
    if (enabled) {
      _startTelemetry();
    } else {
      _stopTelemetry();
    }
  }

  @override
  Stream<List<int>> notifications(String uuid) {
    final controller = _notificationControllers.putIfAbsent(
      uuid.toLowerCase(),
      () => StreamController<List<int>>.broadcast(),
    );
    return controller.stream;
  }

  void _startTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(
      AppConstants.simulatedPacketInterval,
      (_) => _emitPacket(),
    );
  }

  void _stopTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  void _emitPacket() {
    final frame = _nextFrame();
    final bytes = frame.encode();
    _lastPacket = bytes;
    _notificationControllers[BleConstants.telemetryCharacteristicUuid]?.add(
      bytes,
    );
  }

  TelemetryFrame _nextFrame() {
    _sequence++;
    final t =
        _sequence * AppConstants.simulatedPacketInterval.inMilliseconds /
        1000;
    final battery = (87 - _sequence ~/ 40).clamp(0, 100);
    final speed = (18 + 6 * math.sin(t / 5)).clamp(0.0, 120.0);
    return TelemetryFrame(
      sequence: _sequence,
      accelX: 0.42 * math.sin(t),
      accelY: 0.42 * math.cos(t * 0.8),
      accelZ: 9.81,
      gyroX: 1.24 * math.sin(t * 0.7),
      gyroY: 0.60 * math.cos(t * 0.5),
      gyroZ: 0.10 * math.sin(t * 0.3),
      temperatureC: 32 + 2 * math.sin(t / 10),
      speedKmh: speed,
      batteryPercent: battery,
      moving: speed > 1,
      lowBattery: battery < 20,
      charging: false,
      receivedAt: DateTime.now(),
    );
  }

  /// Closes the stream controllers.
  void dispose() {
    _stopTelemetry();
    _scanController.close();
    _connectionController.close();
    for (final controller in _notificationControllers.values) {
      controller.close();
    }
    _notificationControllers.clear();
  }
}

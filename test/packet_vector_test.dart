import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_link/core/constants/ble_constants.dart';
import 'package:pulse_link/features/bluetooth/domain/models/telemetry_frame.dart';

/// The golden telemetry packet.
///
/// The same 41 bytes are produced by the Dart encoder, by the Python GATT
/// server and by the ESP32 sketch. If any of them drifts, this test fails.
///
/// ```
/// sequence 42, flags moving
/// accel 0.42 / -1.25 / 9.81 m/s^2
/// gyro  1.24 / 0.50 / -0.25 deg/s
/// temperature 31.5 C, speed 18.25 km/h, battery 87 %
/// ```
const String goldenPacketHex =
    'A5 01 01 2A 00 3D 0A D7 3E 00 00 A0 BF C3 F5 1C 41 52 B8 9E 3F 00 00 '
    '00 3F 00 00 80 BE 00 00 FC 41 00 00 92 41 57 00 6C 0B';

void main() {
  final golden = TelemetryFrame(
    sequence: 42,
    accelX: 0.42,
    accelY: -1.25,
    accelZ: 9.81,
    gyroX: 1.24,
    gyroY: 0.5,
    gyroZ: -0.25,
    temperatureC: 31.5,
    speedKmh: 18.25,
    batteryPercent: 87,
    moving: true,
    lowBattery: false,
    charging: false,
    receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  test('the encoder produces the golden packet', () {
    final bytes = golden.encode();
    expect(bytes.length, BleConstants.packetLength);
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();
    expect(hex, goldenPacketHex);
  });

  test('the decoder reads the golden packet back', () {
    final bytes = Uint8List.fromList(
      goldenPacketHex
          .split(' ')
          .map((part) => int.parse(part, radix: 16))
          .toList(),
    );
    final frame = TelemetryFrame.decode(bytes);
    expect(frame.sequence, 42);
    expect(frame.accelX, closeTo(0.42, 1e-6));
    expect(frame.accelY, closeTo(-1.25, 1e-6));
    expect(frame.accelZ, closeTo(9.81, 1e-6));
    expect(frame.gyroX, closeTo(1.24, 1e-6));
    expect(frame.gyroY, closeTo(0.5, 1e-6));
    expect(frame.gyroZ, closeTo(-0.25, 1e-6));
    expect(frame.temperatureC, closeTo(31.5, 1e-6));
    expect(frame.speedKmh, closeTo(18.25, 1e-6));
    expect(frame.batteryPercent, 87);
    expect(frame.moving, isTrue);
    expect(frame.lowBattery, isFalse);
    expect(frame.charging, isFalse);
  });
}

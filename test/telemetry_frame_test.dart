import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_link/core/constants/ble_constants.dart';
import 'package:pulse_link/features/bluetooth/domain/models/telemetry_frame.dart';

/// Builds a packet byte by byte so the test does not depend on the encoder.
Uint8List buildPacket({
  int magic = BleConstants.packetMagic,
  int version = BleConstants.packetVersion,
  int flags = 0,
  int sequence = 42,
  double accelX = 0.42,
  double accelY = -1.25,
  double accelZ = 9.81,
  double gyroX = 1.24,
  double gyroY = 0.5,
  double gyroZ = -0.25,
  double temperature = 31.5,
  double speed = 18.25,
  int battery = 87,
  bool breakChecksum = false,
}) {
  final bytes = Uint8List(BleConstants.packetLength);
  final data = ByteData.sublistView(bytes);

  bytes[0] = magic;
  bytes[1] = version;
  bytes[2] = flags;
  data.setUint16(3, sequence, Endian.little);
  data.setFloat32(5, accelX, Endian.little);
  data.setFloat32(9, accelY, Endian.little);
  data.setFloat32(13, accelZ, Endian.little);
  data.setFloat32(17, gyroX, Endian.little);
  data.setFloat32(21, gyroY, Endian.little);
  data.setFloat32(25, gyroZ, Endian.little);
  data.setFloat32(29, temperature, Endian.little);
  data.setFloat32(33, speed, Endian.little);
  data.setUint16(37, battery, Endian.little);

  var sum = 0;
  for (var i = 0; i < BleConstants.checksumOffset; i++) {
    sum += bytes[i];
  }
  data.setUint16(
    BleConstants.checksumOffset,
    breakChecksum ? (sum & 0xFFFF) + 1 : sum & 0xFFFF,
    Endian.little,
  );
  return bytes;
}

void main() {
  group('TelemetryFrame.decode', () {
    test('decodes a valid packet', () {
      final frame = TelemetryFrame.decode(
        buildPacket(
          flags: BleConstants.flagMoving,
          sequence: 7,
          accelX: 0.42,
          accelY: -1.25,
          accelZ: 9.81,
          gyroX: 1.24,
          temperature: 31.5,
          speed: 18.25,
          battery: 87,
        ),
      );

      expect(frame.sequence, 7);
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

    test('rejects a short packet', () {
      expect(
        () => TelemetryFrame.decode([0xA5, 0x01]),
        throwsA(
          isA<TelemetryParseException>().having(
            (e) => e.failure,
            'failure',
            TelemetryParseFailure.tooShort,
          ),
        ),
      );
    });

    test('rejects a foreign magic byte', () {
      expect(
        () => TelemetryFrame.decode(buildPacket(magic: 0x42)),
        throwsA(
          isA<TelemetryParseException>().having(
            (e) => e.failure,
            'failure',
            TelemetryParseFailure.badMagic,
          ),
        ),
      );
    });

    test('rejects an unknown version', () {
      expect(
        () => TelemetryFrame.decode(buildPacket(version: 9)),
        throwsA(
          isA<TelemetryParseException>().having(
            (e) => e.failure,
            'failure',
            TelemetryParseFailure.unsupportedVersion,
          ),
        ),
      );
    });

    test('rejects a broken checksum', () {
      expect(
        () => TelemetryFrame.decode(buildPacket(breakChecksum: true)),
        throwsA(
          isA<TelemetryParseException>().having(
            (e) => e.failure,
            'failure',
            TelemetryParseFailure.badChecksum,
          ),
        ),
      );
    });

    test('reads multi byte fields as little endian', () {
      final bytes = buildPacket(sequence: 0x0102, battery: 0x0304);
      expect(bytes[3], 0x02, reason: 'sequence low byte first');
      expect(bytes[4], 0x01, reason: 'sequence high byte second');
      expect(bytes[37], 0x04, reason: 'battery low byte first');
      expect(bytes[38], 0x03, reason: 'battery high byte second');
    });
  });

  group('TelemetryFrame.encode', () {
    test('round trips through the decoder', () {
      final original = TelemetryFrame(
        sequence: 1234,
        accelX: 1.5,
        accelY: -2.5,
        accelZ: 9.81,
        gyroX: 0.75,
        gyroY: -0.25,
        gyroZ: 0.125,
        temperatureC: 28.5,
        speedKmh: 44.25,
        batteryPercent: 64,
        moving: true,
        lowBattery: false,
        charging: true,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final bytes = original.encode();
      expect(bytes.length, BleConstants.packetLength);

      final decoded = TelemetryFrame.decode(bytes);
      expect(decoded.sequence, original.sequence);
      expect(decoded.accelX, closeTo(original.accelX, 1e-6));
      expect(decoded.gyroZ, closeTo(original.gyroZ, 1e-6));
      expect(decoded.temperatureC, closeTo(original.temperatureC, 1e-6));
      expect(decoded.speedKmh, closeTo(original.speedKmh, 1e-6));
      expect(decoded.batteryPercent, original.batteryPercent);
      expect(decoded.moving, isTrue);
      expect(decoded.charging, isTrue);
    });

    test('encodes the flags byte', () {
      final frame = TelemetryFrame(
        sequence: 0,
        accelX: 0,
        accelY: 0,
        accelZ: 0,
        gyroX: 0,
        gyroY: 0,
        gyroZ: 0,
        temperatureC: 0,
        speedKmh: 0,
        batteryPercent: 0,
        moving: true,
        lowBattery: true,
        charging: false,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final bytes = frame.encode();
      expect(
        bytes[2],
        BleConstants.flagMoving | BleConstants.flagLowBattery,
      );
    });
  });
}

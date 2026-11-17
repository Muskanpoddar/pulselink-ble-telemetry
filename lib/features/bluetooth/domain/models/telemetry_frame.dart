import 'dart:typed_data';

import '../../../../core/constants/ble_constants.dart';
import '../../../../core/utils/byte_codec.dart';

/// Why a packet was rejected.
enum TelemetryParseFailure {
  tooShort,
  badMagic,
  unsupportedVersion,
  badChecksum,
}

/// Raised when a notification is not a valid telemetry packet.
class TelemetryParseException implements Exception {
  const TelemetryParseException(this.failure, this.message);

  final TelemetryParseFailure failure;
  final String message;

  @override
  String toString() =>
      'TelemetryParseException(${failure.name}): $message';
}

/// A single decoded telemetry sample.
class TelemetryFrame {
  const TelemetryFrame({
    required this.sequence,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.temperatureC,
    required this.speedKmh,
    required this.batteryPercent,
    required this.moving,
    required this.lowBattery,
    required this.charging,
    required this.receivedAt,
  });

  final int sequence;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double temperatureC;
  final double speedKmh;
  final int batteryPercent;
  final bool moving;
  final bool lowBattery;
  final bool charging;
  final DateTime receivedAt;

  // Byte offsets inside the packet.
  static const int _offsetFlags = 2;
  static const int _offsetSequence = 3;
  static const int _offsetAccelX = 5;
  static const int _offsetAccelY = 9;
  static const int _offsetAccelZ = 13;
  static const int _offsetGyroX = 17;
  static const int _offsetGyroY = 21;
  static const int _offsetGyroZ = 25;
  static const int _offsetTemperature = 29;
  static const int _offsetSpeed = 33;
  static const int _offsetBattery = 37;

  /// Decodes a 41 byte telemetry packet.
  ///
  /// Throws [TelemetryParseException] when the packet is too short, carries the
  /// wrong magic byte, an unknown version or a broken checksum.
  static TelemetryFrame decode(List<int> raw) {
    if (raw.length < BleConstants.packetLength) {
      throw TelemetryParseException(
        TelemetryParseFailure.tooShort,
        'expected ${BleConstants.packetLength} bytes, got ${raw.length}',
      );
    }

    final bytes = Uint8List.fromList(raw);
    final data = ByteCodec.view(bytes);

    if (bytes[0] != BleConstants.packetMagic) {
      throw TelemetryParseException(
        TelemetryParseFailure.badMagic,
        'unexpected magic 0x${bytes[0].toRadixString(16)}',
      );
    }
    if (bytes[1] != BleConstants.packetVersion) {
      throw TelemetryParseException(
        TelemetryParseFailure.unsupportedVersion,
        'unsupported version ${bytes[1]}',
      );
    }

    final expected = ByteCodec.checksum(bytes, BleConstants.checksumOffset);
    final actual = data.getUint16(
      BleConstants.checksumOffset,
      Endian.little,
    );
    if (expected != actual) {
      throw TelemetryParseException(
        TelemetryParseFailure.badChecksum,
        'checksum 0x${actual.toRadixString(16)} != 0x${expected.toRadixString(16)}',
      );
    }

    final flags = bytes[_offsetFlags];
    return TelemetryFrame(
      sequence: data.getUint16(_offsetSequence, Endian.little),
      accelX: data.getFloat32(_offsetAccelX, Endian.little),
      accelY: data.getFloat32(_offsetAccelY, Endian.little),
      accelZ: data.getFloat32(_offsetAccelZ, Endian.little),
      gyroX: data.getFloat32(_offsetGyroX, Endian.little),
      gyroY: data.getFloat32(_offsetGyroY, Endian.little),
      gyroZ: data.getFloat32(_offsetGyroZ, Endian.little),
      temperatureC: data.getFloat32(_offsetTemperature, Endian.little),
      speedKmh: data.getFloat32(_offsetSpeed, Endian.little),
      batteryPercent: data.getUint16(_offsetBattery, Endian.little),
      moving: flags & BleConstants.flagMoving != 0,
      lowBattery: flags & BleConstants.flagLowBattery != 0,
      charging: flags & BleConstants.flagCharging != 0,
      receivedAt: DateTime.now(),
    );
  }

  /// The inverse of [decode]; used by the simulator and mirrored by the firmware.
  Uint8List encode() {
    final bytes = Uint8List(BleConstants.packetLength);
    final data = ByteCodec.view(bytes);

    bytes[0] = BleConstants.packetMagic;
    bytes[1] = BleConstants.packetVersion;
    bytes[_offsetFlags] =
        (moving ? BleConstants.flagMoving : 0) |
        (lowBattery ? BleConstants.flagLowBattery : 0) |
        (charging ? BleConstants.flagCharging : 0);

    data.setUint16(_offsetSequence, sequence, Endian.little);
    data.setFloat32(_offsetAccelX, accelX, Endian.little);
    data.setFloat32(_offsetAccelY, accelY, Endian.little);
    data.setFloat32(_offsetAccelZ, accelZ, Endian.little);
    data.setFloat32(_offsetGyroX, gyroX, Endian.little);
    data.setFloat32(_offsetGyroY, gyroY, Endian.little);
    data.setFloat32(_offsetGyroZ, gyroZ, Endian.little);
    data.setFloat32(_offsetTemperature, temperatureC, Endian.little);
    data.setFloat32(_offsetSpeed, speedKmh, Endian.little);
    data.setUint16(_offsetBattery, batteryPercent, Endian.little);

    data.setUint16(
      BleConstants.checksumOffset,
      ByteCodec.checksum(bytes, BleConstants.checksumOffset),
      Endian.little,
    );
    return bytes;
  }
}

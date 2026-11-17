/// The PulseLink telemetry GATT profile and packet layout.
///
/// The same constants are mirrored in `hardware/esp32_sensor_node/esp32_sensor_node.ino`
/// so that the firmware and the Dart parser cannot drift apart silently.
class BleConstants {
  const BleConstants._();

  // --- GATT profile -------------------------------------------------------

  /// Service grouping the telemetry characteristics.
  static const String telemetryServiceUuid =
      'f0a1c000-1a2b-4c3d-8e9f-001122334455';

  /// Notify characteristic carrying the binary telemetry packets.
  static const String telemetryCharacteristicUuid =
      'f0a1c001-1a2b-4c3d-8e9f-001122334455';

  /// Write characteristic used to send commands to the node.
  static const String commandCharacteristicUuid =
      'f0a1c002-1a2b-4c3d-8e9f-001122334455';

  /// Read characteristic exposing static device information.
  static const String deviceInfoCharacteristicUuid =
      'f0a1c003-1a2b-4c3d-8e9f-001122334455';

  // --- Packet layout (v1, 41 bytes, little-endian) ------------------------

  static const int packetMagic = 0xA5;
  static const int packetVersion = 1;
  static const int packetLength = 41;

  /// Offset of the two byte checksum, which covers bytes 0..38.
  static const int checksumOffset = 39;

  // Flag bits inside the `flags` byte.
  static const int flagMoving = 0x01;
  static const int flagLowBattery = 0x02;
  static const int flagCharging = 0x04;
}

/// A BLE peripheral seen while scanning.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  /// Platform specific identifier of the peripheral.
  final String id;

  /// Advertised name, falling back to the platform name.
  final String name;

  /// Signal strength in dBm.
  final int rssi;

  DiscoveredDevice copyWith({int? rssi}) =>
      DiscoveredDevice(id: id, name: name, rssi: rssi ?? this.rssi);

  @override
  bool operator ==(Object other) =>
      other is DiscoveredDevice &&
      other.id == id &&
      other.name == name &&
      other.rssi == rssi;

  @override
  int get hashCode => Object.hash(id, name, rssi);

  @override
  String toString() => 'DiscoveredDevice($id, $name, $rssi dBm)';
}

/// Bluetooth adapter state, normalised across platforms.
enum BleAdapterState { unknown, unsupported, unauthorized, off, on }

/// Failure raised by the BLE layer.
class BleException implements Exception {
  const BleException(this.message);

  final String message;

  @override
  String toString() => message;
}

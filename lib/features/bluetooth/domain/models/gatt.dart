/// A characteristic of a GATT service.
class GattCharacteristic {
  const GattCharacteristic({
    required this.uuid,
    this.canRead = false,
    this.canWrite = false,
    this.canNotify = false,
    this.canIndicate = false,
  });

  final String uuid;
  final bool canRead;
  final bool canWrite;
  final bool canNotify;
  final bool canIndicate;

  /// Notify and indicate both push values to the client.
  bool get supportsNotification => canNotify || canIndicate;
}

/// A GATT service exposed by the peripheral.
class GattService {
  const GattService({
    required this.uuid,
    this.isPrimary = true,
    this.characteristics = const [],
  });

  final String uuid;
  final bool isPrimary;
  final List<GattCharacteristic> characteristics;
}

import '../models/telemetry_frame.dart';

/// Publishes decoded telemetry frames.
abstract interface class TelemetryRepository {
  /// Successfully decoded frames.
  Stream<TelemetryFrame> get frames;

  /// Packets that failed validation.
  Stream<TelemetryParseException> get failures;

  /// UUID of the characteristic the telemetry is coming from, null while idle.
  String? get sourceCharacteristic;

  /// Subscribes to the telemetry characteristic of the connected peripheral.
  ///
  /// Pass [characteristicUuid] to subscribe to exactly that characteristic,
  /// otherwise the known one is used and every notify characteristic is probed
  /// as a fallback.
  Future<void> start({String? characteristicUuid});

  /// Unsubscribes again.
  Future<void> stop();
}

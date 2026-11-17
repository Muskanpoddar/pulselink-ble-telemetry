import 'dart:async';

import '../../../../core/constants/ble_constants.dart';
import '../../domain/models/gatt.dart';
import '../../domain/models/telemetry_frame.dart';
import '../../domain/repositories/ble_repository.dart';
import '../../domain/repositories/telemetry_repository.dart';

/// Turns notification payloads into validated telemetry frames.
class TelemetryRepositoryImpl implements TelemetryRepository {
  TelemetryRepositoryImpl(this._ble);

  final BleRepository _ble;

  final StreamController<TelemetryFrame> _frames =
      StreamController<TelemetryFrame>.broadcast();
  final StreamController<TelemetryParseException> _failures =
      StreamController<TelemetryParseException>.broadcast();

  final Map<String, StreamSubscription<List<int>>> _subscriptions = {};

  /// Characteristic the telemetry is actually coming from.
  String? _activeUuid;

  @override
  Stream<TelemetryFrame> get frames => _frames.stream;

  @override
  Stream<TelemetryParseException> get failures => _failures.stream;

  @override
  String? get sourceCharacteristic => _activeUuid;

  @override
  Future<void> start() async {
    await stop();

    final services = await _ble.discoverServices();
    final candidates = _notificationCharacteristics(services);
    if (candidates.isEmpty) {
      throw StateError('The peripheral exposes no notify characteristic.');
    }

    // Prefer the characteristic of our own profile. Otherwise probe every
    // notify characteristic and keep the first one that yields valid packets.
    final known = candidates.where(
      (c) =>
          c.uuid.toLowerCase() ==
          BleConstants.telemetryCharacteristicUuid.toLowerCase(),
    ).toList();
    final selected = known.isNotEmpty ? known : candidates;
    if (known.isNotEmpty) {
      _activeUuid = known.first.uuid;
    }

    for (final candidate in selected) {
      await _ble.setNotifyEnabled(candidate.uuid, true);
      _subscriptions[candidate.uuid] = _ble
          .notifications(candidate.uuid)
          .listen((bytes) => _onPacket(candidate.uuid, bytes));
    }
  }

  @override
  Future<void> stop() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    for (final uuid in _subscriptions.keys) {
      try {
        await _ble.setNotifyEnabled(uuid, false);
      } catch (_) {
        // The peripheral may already be gone, nothing to unsubscribe from.
      }
    }
    _subscriptions.clear();
    _activeUuid = null;
  }

  void _onPacket(String uuid, List<int> bytes) {
    final active = _activeUuid;
    if (active != null && active != uuid) return;

    try {
      final frame = TelemetryFrame.decode(bytes);
      if (_activeUuid == null) {
        _activeUuid = uuid;
        _dropOtherSubscriptions(uuid);
      }
      _frames.add(frame);
    } on TelemetryParseException catch (error) {
      // While probing, a malformed packet just means "not this characteristic".
      if (_activeUuid == uuid) {
        _failures.add(error);
      }
    }
  }

  void _dropOtherSubscriptions(String keepUuid) {
    for (final entry in _subscriptions.entries.toList()) {
      if (entry.key != keepUuid) {
        entry.value.cancel();
        _subscriptions.remove(entry.key);
      }
    }
  }

  List<GattCharacteristic> _notificationCharacteristics(
    List<GattService> services,
  ) => [
    for (final service in services)
      for (final characteristic in service.characteristics)
        if (characteristic.supportsNotification) characteristic,
  ];

  /// Closes the stream controllers.
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _frames.close();
    _failures.close();
  }
}

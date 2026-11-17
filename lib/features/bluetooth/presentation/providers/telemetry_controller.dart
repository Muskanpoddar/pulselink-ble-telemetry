import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/telemetry_frame.dart';
import '../../domain/repositories/telemetry_repository.dart';
import 'ble_providers.dart';

class TelemetryState {
  const TelemetryState({
    this.latest,
    this.packetsReceived = 0,
    this.parseErrors = 0,
    this.speedHistory = const [],
    this.accelHistory = const [],
    this.isSubscribed = false,
    this.sourceCharacteristic,
    this.errorMessage,
  });

  final TelemetryFrame? latest;
  final int packetsReceived;
  final int parseErrors;
  final List<double> speedHistory;
  final List<double> accelHistory;
  final bool isSubscribed;

  /// UUID of the characteristic the packets are coming from.
  final String? sourceCharacteristic;

  final String? errorMessage;

  TelemetryState copyWith({
    TelemetryFrame? latest,
    int? packetsReceived,
    int? parseErrors,
    List<double>? speedHistory,
    List<double>? accelHistory,
    bool? isSubscribed,
    String? sourceCharacteristic,
    String? errorMessage,
    bool clearError = false,
  }) => TelemetryState(
    latest: latest ?? this.latest,
    packetsReceived: packetsReceived ?? this.packetsReceived,
    parseErrors: parseErrors ?? this.parseErrors,
    speedHistory: speedHistory ?? this.speedHistory,
    accelHistory: accelHistory ?? this.accelHistory,
    isSubscribed: isSubscribed ?? this.isSubscribed,
    sourceCharacteristic: sourceCharacteristic ?? this.sourceCharacteristic,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Collects the decoded frames and keeps the rolling history for the charts.
final telemetryControllerProvider =
    NotifierProvider<TelemetryController, TelemetryState>(
      TelemetryController.new,
    );

class TelemetryController extends Notifier<TelemetryState> {
  TelemetryRepository? _repository;

  @override
  TelemetryState build() {
    final repository = ref.watch(telemetryRepositoryProvider);
    _repository = repository;
    final frames = repository.frames.listen(_onFrame);
    final failures = repository.failures.listen(_onFailure);
    ref.onDispose(() {
      frames.cancel();
      failures.cancel();
    });
    return const TelemetryState();
  }

  Future<void> start() async {
    try {
      await ref.read(telemetryRepositoryProvider).start();
      state = state.copyWith(
        isSubscribed: true,
        clearError: true,
        sourceCharacteristic: ref
            .read(telemetryRepositoryProvider)
            .sourceCharacteristic,
      );
    } catch (error) {
      state = state.copyWith(isSubscribed: false, errorMessage: '$error');
    }
  }

  Future<void> stop() async {
    await ref.read(telemetryRepositoryProvider).stop();
    state = state.copyWith(isSubscribed: false);
  }

  void _onFrame(TelemetryFrame frame) {
    if (!ref.mounted) return;
    final magnitude = math.sqrt(
      frame.accelX * frame.accelX +
          frame.accelY * frame.accelY +
          frame.accelZ * frame.accelZ,
    );
    state = state.copyWith(
      latest: frame,
      packetsReceived: state.packetsReceived + 1,
      speedHistory: _append(state.speedHistory, frame.speedKmh),
      accelHistory: _append(state.accelHistory, magnitude),
      sourceCharacteristic: _repository?.sourceCharacteristic,
    );
  }

  /// Keeps the rolling history at a fixed length.
  List<double> _append(List<double> history, double value) {
    final next = [...history, value];
    if (next.length > AppConstants.telemetryHistoryLength) {
      next.removeRange(0, next.length - AppConstants.telemetryHistoryLength);
    }
    return next;
  }

  void _onFailure(TelemetryParseException error) {
    if (!ref.mounted) return;
    state = state.copyWith(
      parseErrors: state.parseErrors + 1,
      errorMessage: error.message,
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/ble_device.dart';
import 'ble_providers.dart';

class ScannerState {
  const ScannerState({
    this.isScanning = false,
    this.devices = const [],
    this.errorMessage,
  });

  final bool isScanning;
  final List<DiscoveredDevice> devices;
  final String? errorMessage;

  ScannerState copyWith({
    bool? isScanning,
    List<DiscoveredDevice>? devices,
    String? errorMessage,
    bool clearError = false,
  }) => ScannerState(
    isScanning: isScanning ?? this.isScanning,
    devices: devices ?? this.devices,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

final scannerControllerProvider = NotifierProvider<ScannerController, ScannerState>(
  ScannerController.new,
);

class ScannerController extends Notifier<ScannerState> {
  Timer? _scanTimer;

  @override
  ScannerState build() {
    final repository = ref.watch(bleRepositoryProvider);
    final subscription = repository.scanResults.listen((devices) {
      if (!ref.mounted) return;
      state = state.copyWith(devices: _normalize(devices));
    });
    ref.onDispose(() {
      subscription.cancel();
      _scanTimer?.cancel();
    });
    return const ScannerState();
  }

  Future<void> startScan() async {
    state = state.copyWith(isScanning: true, clearError: true);
    try {
      await ref.read(bleRepositoryProvider).startScan();
      // The scan stops by itself after the timeout; mirror that in the UI.
      _scanTimer?.cancel();
      _scanTimer = Timer(AppConstants.scanTimeout, () {
        if (ref.mounted) state = state.copyWith(isScanning: false);
      });
    } on BleException catch (error) {
      state = state.copyWith(isScanning: false, errorMessage: error.message);
    } catch (error) {
      state = state.copyWith(isScanning: false, errorMessage: '$error');
    }
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    await ref.read(bleRepositoryProvider).stopScan();
    state = state.copyWith(isScanning: false);
  }

  /// Keeps the strongest reading per device and sorts by signal strength.
  List<DiscoveredDevice> _normalize(List<DiscoveredDevice> devices) {
    final strongest = <String, DiscoveredDevice>{};
    for (final device in devices) {
      final known = strongest[device.id];
      if (known == null || device.rssi > known.rssi) {
        strongest[device.id] = device;
      }
    }
    final sorted = strongest.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return sorted;
  }
}

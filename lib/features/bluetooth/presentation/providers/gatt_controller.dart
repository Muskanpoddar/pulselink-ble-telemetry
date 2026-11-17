import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ble_device.dart';
import '../../domain/models/gatt.dart';
import 'ble_providers.dart';

class GattState {
  const GattState({
    this.isLoading = false,
    this.services = const [],
    this.values = const {},
    this.errorMessage,
  });

  final bool isLoading;
  final List<GattService> services;

  /// Last value read from a characteristic.
  final Map<String, List<int>> values;

  final String? errorMessage;

  GattState copyWith({
    bool? isLoading,
    List<GattService>? services,
    Map<String, List<int>>? values,
    String? errorMessage,
    bool clearError = false,
  }) => GattState(
    isLoading: isLoading ?? this.isLoading,
    services: services ?? this.services,
    values: values ?? this.values,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

final gattControllerProvider = NotifierProvider<GattController, GattState>(
  GattController.new,
);

class GattController extends Notifier<GattState> {
  @override
  GattState build() => const GattState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final services = await ref
          .read(bleRepositoryProvider)
          .discoverServices();
      state = state.copyWith(isLoading: false, services: services);
    } on BleException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '$error');
    }
  }

  Future<void> read(String uuid) async {
    try {
      final value = await ref
          .read(bleRepositoryProvider)
          .readCharacteristic(uuid);
      state = state.copyWith(values: {...state.values, uuid: value});
    } catch (error) {
      state = state.copyWith(errorMessage: '$error');
    }
  }

  Future<void> setNotify(String uuid, bool enabled) async {
    try {
      await ref
          .read(bleRepositoryProvider)
          .setNotifyEnabled(uuid, enabled);
    } catch (error) {
      state = state.copyWith(errorMessage: '$error');
    }
  }
}

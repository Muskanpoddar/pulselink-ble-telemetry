import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ble_device.dart';
import '../../domain/models/connection.dart';
import 'ble_providers.dart';

class ConnectionState {
  const ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.device,
    this.errorMessage,
    this.reconnectAttempt = 0,
  });

  final ConnectionStatus status;
  final DiscoveredDevice? device;
  final String? errorMessage;
  final int reconnectAttempt;

  ConnectionState copyWith({
    ConnectionStatus? status,
    DiscoveredDevice? device,
    String? errorMessage,
    int? reconnectAttempt,
    bool clearError = false,
  }) => ConnectionState(
    status: status ?? this.status,
    device: device ?? this.device,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
  );
}

/// Owns the connection lifecycle: connect, disconnect, and safe reconnection
/// after an unexpected drop.
final connectionControllerProvider =
    NotifierProvider<ConnectionController, ConnectionState>(
      ConnectionController.new,
    );

class ConnectionController extends Notifier<ConnectionState> {
  static const ReconnectPolicy _policy = ReconnectPolicy();

  Timer? _reconnectTimer;
  bool _userRequestedDisconnect = false;
  int _attempt = 0;

  @override
  ConnectionState build() {
    final repository = ref.watch(bleRepositoryProvider);
    final subscription = repository.connectionState.listen(_onConnectionState);
    ref.onDispose(() {
      subscription.cancel();
      _reconnectTimer?.cancel();
    });
    return const ConnectionState();
  }

  Future<void> connect(DiscoveredDevice device) async {
    _userRequestedDisconnect = false;
    _attempt = 0;
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      device: device,
      clearError: true,
    );
    try {
      await ref.read(bleRepositoryProvider).connect(device);
      state = state.copyWith(status: ConnectionStatus.connected);
    } on BleException catch (error) {
      state = state.copyWith(
        status: ConnectionStatus.failed,
        errorMessage: error.message,
      );
    } catch (error) {
      state = state.copyWith(
        status: ConnectionStatus.failed,
        errorMessage: '$error',
      );
    }
  }

  Future<void> disconnect() async {
    _userRequestedDisconnect = true;
    _reconnectTimer?.cancel();
    await ref.read(bleRepositoryProvider).disconnect();
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      clearError: true,
    );
  }

  void _onConnectionState(ConnectionStatus status) {
    if (!ref.mounted) return;

    if (status == ConnectionStatus.connected) {
      _attempt = 0;
      state = state.copyWith(status: ConnectionStatus.connected);
      return;
    }

    final wasConnected =
        state.status == ConnectionStatus.connected ||
        state.status == ConnectionStatus.reconnecting;
    if (!wasConnected) return;

    if (_userRequestedDisconnect) {
      state = state.copyWith(status: ConnectionStatus.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_policy.canRetry(_attempt)) {
      state = state.copyWith(
        status: ConnectionStatus.failed,
        errorMessage: 'Connection lost. No reconnect attempts left.',
      );
      return;
    }

    final delay = _policy.delayFor(_attempt);
    _attempt++;
    state = state.copyWith(
      status: ConnectionStatus.reconnecting,
      reconnectAttempt: _attempt,
      errorMessage: 'Connection lost, retrying in ${delay.inSeconds}s',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (!ref.mounted) return;
      final device = state.device;
      if (device == null) return;
      try {
        await ref.read(bleRepositoryProvider).connect(device);
      } catch (_) {
        if (ref.mounted) _scheduleReconnect();
      }
    });
  }
}

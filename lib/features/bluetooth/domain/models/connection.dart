/// Lifecycle of the currently selected peripheral.
enum ConnectionStatus { disconnected, connecting, connected, reconnecting, failed }

/// Exponential backoff policy for automatic reconnection.
///
/// Pure on purpose: the retry schedule is unit tested without a device or a timer.
class ReconnectPolicy {
  const ReconnectPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
  });

  /// How many automatic retries are allowed before giving up.
  final int maxAttempts;

  /// Delay of the first retry; every further attempt doubles it.
  final Duration baseDelay;

  /// Whether another attempt is allowed after [attempt] failed tries (0 based).
  bool canRetry(int attempt) => attempt < maxAttempts;

  /// Delay before retry [attempt] (0 based): 1s, 2s, 4s, ...
  Duration delayFor(int attempt) => baseDelay * (1 << attempt);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_link/features/bluetooth/domain/models/connection.dart';

void main() {
  group('ReconnectPolicy', () {
    test('doubles the delay on every attempt', () {
      const policy = ReconnectPolicy();
      expect(policy.delayFor(0), const Duration(seconds: 1));
      expect(policy.delayFor(1), const Duration(seconds: 2));
      expect(policy.delayFor(2), const Duration(seconds: 4));
    });

    test('allows maxAttempts retries and then gives up', () {
      const policy = ReconnectPolicy(maxAttempts: 3);
      expect(policy.canRetry(0), isTrue);
      expect(policy.canRetry(2), isTrue);
      expect(policy.canRetry(3), isFalse);
      expect(policy.canRetry(4), isFalse);
    });

    test('honours a custom base delay', () {
      const policy = ReconnectPolicy(baseDelay: Duration(milliseconds: 500));
      expect(policy.delayFor(0), const Duration(milliseconds: 500));
      expect(policy.delayFor(1), const Duration(seconds: 1));
    });
  });
}

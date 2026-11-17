/// App-wide constants that are not tied to the BLE protocol itself.
class AppConstants {
  const AppConstants._();

  static const String appName = 'PulseLink';

  /// How long a scan runs before the plugin stops it automatically.
  static const Duration scanTimeout = Duration(seconds: 10);

  /// How long a single connection attempt may take before it is aborted.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Number of samples kept for the dashboard sparkline.
  static const int telemetryHistoryLength = 60;

  /// Telemetry notification rate of the simulated peripheral (5 Hz).
  static const Duration simulatedPacketInterval = Duration(milliseconds: 200);
}

/// Maps an RSSI reading (dBm) to a coarse signal quality bucket.
class Rssi {
  const Rssi._();

  /// 0 (unusable) to 4 (excellent).
  static int bars(int rssi) {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }

  /// Human readable quality, e.g. `Excellent`, `Weak`.
  static String quality(int rssi) {
    switch (bars(rssi)) {
      case 4:
        return 'Excellent';
      case 3:
        return 'Good';
      case 2:
        return 'Fair';
      case 1:
        return 'Weak';
      default:
        return 'Poor';
    }
  }
}

import 'dart:typed_data';

/// Little-endian helpers for the binary telemetry packet.
class ByteCodec {
  const ByteCodec._();

  /// A [ByteData] view over [bytes] without copying the payload.
  static ByteData view(Uint8List bytes) => ByteData.sublistView(bytes);

  /// Sum of the first [length] bytes, truncated to 16 bits.
  static int checksum(Uint8List bytes, int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += bytes[i];
    }
    return sum & 0xFFFF;
  }

  /// Uppercase hex rendering, used by the GATT explorer.
  static String toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();
}

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Runtime permission handling for BLE.
class PermissionService {
  const PermissionService();

  /// Whether the app is allowed to scan for and connect to BLE devices.
  Future<bool> ensureBlePermissions() async {
    if (!Platform.isAndroid) {
      // iOS uses a single bluetooth permission prompt.
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }

    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) {
      return true;
    }

    // Android 11 and below have no BLUETOOTH_SCAN/BLUETOOTH_CONNECT runtime
    // permission; there, location access is what gates scanning.
    final location = await Permission.locationWhenInUse.request();
    return location.isGranted;
  }
}

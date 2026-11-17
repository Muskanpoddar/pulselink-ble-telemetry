# PulseLink

A Flutter client for Bluetooth Low Energy sensor nodes. It discovers nearby
peripherals, connects to them, explores their GATT database and renders the
telemetry stream in real time.

The reference peripheral is an **ESP32 sensor node** that publishes motion,
temperature and battery readings - the kind of data a connected scooter would
expose.

<!-- Screenshots: Scanner / GATT explorer / Telemetry dashboard -->

## What it does

| Screen | Purpose |
|---|---|
| **Device Scanner** | Finds nearby BLE peripherals, shows name, id and RSSI |
| **Device Details** | Connect / disconnect, signal quality, link to the GATT explorer |
| **GATT Explorer** | Lists services and characteristics, reads values, shows R/W/N properties |
| **Telemetry Dashboard** | Live accelerometer, gyroscope, temperature, speed and battery, packet counters, rolling charts |
| **Connection Monitor** | Status banner plus automatic reconnection with backoff |

## Running it without hardware

The app has a **Demo mode** (switch in the app bar). It swaps the real BLE
backend for a simulated peripheral that advertises two devices, exposes the same
GATT profile and streams packets in the exact wire format. The packets travel
through the real parser, so the demo exercises the whole pipeline.

```
Demo mode ON  ->  SCAN FOR DEVICES  ->  "ESP32 Sensor Node"
               ->  CONNECT  ->  START TELEMETRY on the Dashboard
```

## Setup

```bash
flutter pub get
flutter run          # Android phone or emulator with BLE support
flutter test
flutter analyze
```

Requires Flutter 3.38 / Dart 3.10, an Android device with BLE, and Android 6.0
(API 21) or newer.

### Android permissions

`android/app/src/main/AndroidManifest.xml` declares:

| Permission | Why |
|---|---|
| `BLUETOOTH_SCAN` (`neverForLocation`) | scanning on Android 12+ |
| `BLUETOOTH_CONNECT` | connecting on Android 12+ |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` (max API 30) | legacy scanning |
| `ACCESS_FINE_LOCATION` (max API 30) | location gates scanning up to Android 11 |

`permission_handler` asks for the right set at runtime, depending on the OS
version.

## Telemetry packet (v1, 41 bytes, little-endian)

```
offset size type   field
     0    1 u8    magic        0xA5
     1    1 u8    version      0x01
     2    1 u8    flags        bit0 moving, bit1 lowBattery, bit2 charging
     3    2 u16   sequence
     5    4 f32   accelX       m/s²
     9    4 f32   accelY       m/s²
    13    4 f32   accelZ       m/s²
    17    4 f32   gyroX        °/s
    21    4 f32   gyroY        °/s
    25    4 f32   gyroZ        °/s
    29    4 f32   temperature  °C
    33    4 f32   speed        km/h
    37    2 u16   battery      %
    39    2 u16   checksum     sum(bytes 0..38) & 0xFFFF
```

Packets are validated on length, magic byte, version and checksum. A malformed
packet is counted, never fatal.

The 41 byte payload does not fit into the default 23 byte BLE MTU, so the app
requests a larger MTU after connecting and the firmware sets one as well.

## GATT profile

| UUID | Properties |
|---|---|
| `f0a1c000-1a2b-4c3d-8e9f-001122334455` | service |
| `f0a1c001-1a2b-4c3d-8e9f-001122334455` | notify - telemetry packets |
| `f0a1c002-1a2b-4c3d-8e9f-001122334455` | write - commands |
| `f0a1c003-1a2b-4c3d-8e9f-001122334455` | read - device info |

If the known telemetry characteristic is missing, the app subscribes to every
notify characteristic and keeps the first one that yields valid packets.

## Hardware bring-up (Stage 2)

Two ways to get a real peripheral talking to the app.

### A. Windows PC as the BLE peripheral

`tools/ble_gatt_server/pulselink_gatt_server.py` hosts the PulseLink GATT
profile on Windows with the WinRT GATT server API - no ESP32 required. It
advertises the service, notifies the same 41 byte packet, and answers reads and
writes on the other characteristics.

```bash
pip install winrt-Windows.Devices.Bluetooth \
            winrt-Windows.Devices.Bluetooth.GenericAttributeProfile \
            winrt-Windows.Storage.Streams

python tools/ble_gatt_server/pulselink_gatt_server.py
```

The script prints `Advertising service f0a1c000-…`. Then, with **Demo mode
off** in the app:

1. Scan for the new device on the phone.
2. Connect to it and open the **GATT** tab - the service `f0a1c000-…` with the
   `f0a1c001-…` notify characteristic must be listed.
3. Open the **Dashboard** and press **START TELEMETRY**.

#### What is measured and what is simulated

The server says so on startup, so nothing is passed off as a real reading:

```
Battery  : real, from Windows (76 %)
Motion   : simulated, a laptop has no accelerometer or gyroscope
Temperature: simulated, Windows exposes no CPU temperature API
```

| Channel | Source |
|---|---|
| Battery % | **real** - `Windows.System.Power.PowerManager`, cross checked against the aggregate battery report |
| Charging and low battery flags | **real** - derived from the battery status and the signed charge rate |
| Accelerometer, gyroscope | simulated - a laptop has no IMU |
| Speed, temperature | simulated - neither a sensor nor a public Windows API |

`tools/ble_gatt_server/verify_client.py` closes the loop without a phone: it
scans, connects, subscribes and decodes the packets with the same rules as the
Dart parser.

```bash
pip install "bleak[winrt]"
python tools/ble_gatt_server/verify_client.py
```

### B. ESP32 sensor node

`hardware/esp32_sensor_node/esp32_sensor_node.ino` is a complete ESP32 sketch
using NimBLE-Arduino 2.x:

1. Install the ESP32 board package and NimBLE-Arduino in the Arduino IDE.
2. Open the sketch and flash it to a board.
3. Turn **Demo mode off** in the app, scan for `ESP32 Sensor Node`, connect and
   press **START TELEMETRY**.

The sketch builds the byte-exact packet described above, so the dashboard
values match the serial log.

The motion channels are synthetic placeholders - wire up the real IMU and fill
in the loop. The battery is read from an ADC1 pin when you define
`BATTERY_ADC_PIN` and put a 2:1 divider on the cell; without a divider the
node reports a fixed level instead of an invented one.

## Project layout

```
lib/
├── app/                     MaterialApp + theme
├── core/
│   ├── constants/           app and BLE constants
│   └── utils/               byte codec, RSSI helper
├── features/bluetooth/
│   ├── domain/
│   │   ├── models/          device, connection, GATT, telemetry frame
│   │   └── repositories/    BLE and telemetry interfaces
│   ├── data/
│   │   ├── services/        flutter_blue_plus + permission_handler wrappers
│   │   └── repositories/    live, telemetry and simulated implementations
│   └── presentation/
│       ├── providers/       Riverpod controllers
│       ├── screens/         scanner, details, GATT, dashboard
│       └── widgets/         device tile, gauges, sparkline, status banner
└── shared/widgets/          section header, empty state
```

The domain layer has no plugin imports, so the parser, the reconnection policy
and the controllers are unit tested without a radio. See
[docs/architecture.md](docs/architecture.md) for the data flow and the state
machine.

## Tests

```bash
flutter test
```

| Suite | Covers |
|---|---|
| `telemetry_frame_test.dart` | decoding, validation, little-endian order, encode round trip |
| `reconnect_policy_test.dart` | backoff schedule and attempt limit |
| `connection_controller_test.dart` | connect, failure, unexpected drop, user disconnect |
| `scanner_controller_test.dart` | strongest reading per device, sorting, scan errors |
| `demo_flow_test.dart` | the demo mode UI path end to end |

## Limitations

- The GATT profile is our own; a peripheral with a different UUID layout still
  works for scanning and GATT browsing, but telemetry needs the packet format
  above.
- The dashboard charts are hand drawn with `CustomPainter` - no charting
  dependency, and no scrubbing or zooming.
- The simulated peripheral is a demo aid, not a radio simulator: it does not
  model connection timeouts or interference.
- Stage 2 (real hardware) is verified on an ESP32; other peripherals work only
  if they follow the packet format.

## Tech stack

Flutter 3.38 · Riverpod 3 · flutter_blue_plus 1.36 · permission_handler 12

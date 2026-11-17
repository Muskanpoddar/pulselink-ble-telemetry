# Architecture

## Layers

```
┌──────────────────────────────────────────────────────────────┐
│  presentation/            widgets · screens · providers      │
│  ─ Riverpod Notifiers turn repository streams into UI state   │
├──────────────────────────────────────────────────────────────┤
│  domain/                  models · repository interfaces      │
│  ─ no plugin imports, fully unit testable                    │
├──────────────────────────────────────────────────────────────┤
│  data/                    services · repository implementations│
│  ─ flutter_blue_plus lives here, and only here               │
└──────────────────────────────────────────────────────────────┘
```

## Data flow

```
  ESP32 sensor node                Phone
 ┌───────────────┐          ┌───────────────────────────────┐
 │ 41 byte packet│──notify──▶│ BleService (flutter_blue_plus)│
 └───────────────┘          └───────────────┬───────────────┘
                                            │ raw List<int>
                                            ▼
                               TelemetryRepositoryImpl
                               ┌───────────────────────┐
                               │ TelemetryFrame.decode │  magic · version · checksum
                               └───────────┬───────────┘
                                            │ Stream<TelemetryFrame>
                                            ▼
                               TelemetryController (Riverpod)
                                            │ state
                                            ▼
                                 DashboardScreen (gauges, charts)
```

The scanner path is the same shape:

```
BleService.scanResults ─▶ ScannerController ─▶ ScannerScreen ─▶ DeviceDetailsScreen
                                                                 │
                              BleRepository.connect ─▶ ConnectionController
                                                             │
                                        ┌────────────────────┴───────────────────┐
                                        ▼                                        ▼
                             GattController (services)              TelemetryController
```

## Why the repository interfaces

`BleRepository` and `TelemetryRepository` are declared in `domain/` and have two
implementations:

| Implementation | Purpose |
|---|---|
| `BleRepositoryImpl` + `TelemetryRepositoryImpl` | real hardware, backed by `flutter_blue_plus` |
| `SimulatedBleRepository` | a fake peripheral used by Demo mode and by the tests |

Because the presentation layer only talks to the interfaces, the whole UI can be
exercised - and every controller tested - without a radio. Toggling Demo mode
swaps the provider; nothing else in the app changes.

## Connection state machine

```
                 ┌──────────────┐
   connect() ───▶│  connecting  │──error──▶ failed
                 └──────┬───────┘
                        │ connected
                        ▼
                 ┌──────────────┐
                 │  connected   │
                 └──────┬───────┘
        unexpected drop │        │ user disconnect
                        ▼        ▼
                 ┌──────────────┐  disconnected
                 │ reconnecting │──attempt──▶ (backoff 1s, 2s, 4s)
                 └──────────────┘
```

`ReconnectPolicy` holds the backoff schedule and is a pure function, so the
retry behaviour is unit tested without timers or a device.

## Packet format (v1, 41 bytes, little-endian)

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

A packet is rejected unless the length, the magic byte, the version and the
checksum are all valid. `TelemetryFrame.encode()` is the exact inverse and is
used by the simulator and mirrored in the ESP32 sketch, so there is one source
of truth for the format.

> The 41 byte payload does not fit into the default 23 byte BLE MTU. The app
> requests a 512 byte MTU after connecting (the plugin default) and the ESP32
> sketch sets an MTU of 247.

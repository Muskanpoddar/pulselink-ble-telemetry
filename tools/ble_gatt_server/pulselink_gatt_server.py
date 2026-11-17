#!/usr/bin/env python3
"""PulseLink BLE - Windows GATT server (BLE peripheral).

Hosts the PulseLink telemetry profile with the WinRT GATT server API and
notifies the very same 41 byte packet the Dart parser expects, so a phone can
run the real end to end path without an ESP32.

    pip install winrt-Windows.Devices.Bluetooth \
                winrt-Windows.Devices.Bluetooth.GenericAttributeProfile \
                winrt-Windows.Storage.Streams

    python pulselink_gatt_server.py

Requires Windows 10 1809 or newer and Bluetooth switched on.
"""

import asyncio
import math
import struct
import sys
import time
import uuid as uuid_module

from winrt.windows.devices.bluetooth import BluetoothError
from winrt.windows.devices.bluetooth.genericattributeprofile import (
    GattCharacteristicProperties,
    GattLocalCharacteristicParameters,
    GattProtectionLevel,
    GattServiceProvider,
    GattServiceProviderAdvertisingParameters,
    GattWriteOption,
)
from winrt.windows.storage.streams import DataWriter

# --- GATT profile (must match lib/core/constants/ble_constants.dart) --------
SERVICE_UUID = uuid_module.UUID("f0a1c000-1a2b-4c3d-8e9f-001122334455")
TELEMETRY_UUID = uuid_module.UUID("f0a1c001-1a2b-4c3d-8e9f-001122334455")
COMMAND_UUID = uuid_module.UUID("f0a1c002-1a2b-4c3d-8e9f-001122334455")
DEVICE_INFO_UUID = uuid_module.UUID("f0a1c003-1a2b-4c3d-8e9f-001122334455")

# --- Packet layout (must match the Dart TelemetryFrame) --------------------
PACKET_MAGIC = 0xA5
PACKET_VERSION = 1
PACKET_LENGTH = 41
CHECKSUM_OFFSET = 39
FLAG_MOVING = 0x01
FLAG_LOW_BATTERY = 0x02

PUBLISH_INTERVAL_S = 0.2  # 5 Hz

latest_packet = bytes(PACKET_LENGTH)


def build_packet(sequence, accel, gyro, temperature, speed, battery):
    """Builds the 41 byte telemetry packet, byte for byte like the Dart side."""
    flags = 0
    if speed > 1.0:
        flags |= FLAG_MOVING
    if battery < 20:
        flags |= FLAG_LOW_BATTERY

    body = struct.pack(
        "<BBBHffffffffH",
        PACKET_MAGIC,
        PACKET_VERSION,
        flags,
        sequence & 0xFFFF,
        accel[0],
        accel[1],
        accel[2],
        gyro[0],
        gyro[1],
        gyro[2],
        temperature,
        speed,
        battery,
    )
    assert len(body) == CHECKSUM_OFFSET, len(body)
    checksum = sum(body) & 0xFFFF
    return body + struct.pack("<H", checksum)


def to_buffer(data: bytes):
    writer = DataWriter()
    writer.write_bytes(data)
    return writer.detach_buffer()


def spawn(coro):
    """WinRT event handlers must be plain functions, so the work goes async."""
    return asyncio.ensure_future(coro)


async def create_characteristic(provider, characteristic_uuid, properties):
    params = GattLocalCharacteristicParameters()
    params.characteristic_properties = properties
    params.read_protection_level = GattProtectionLevel.PLAIN
    params.write_protection_level = GattProtectionLevel.PLAIN

    result = await provider.service.create_characteristic_async(
        characteristic_uuid, params
    )
    if result.error != BluetoothError.SUCCESS:
        raise RuntimeError(f"{characteristic_uuid}: {result.error}")
    return result.characteristic


async def main():
    global latest_packet

    print("Creating the PulseLink GATT service ...")
    result = await GattServiceProvider.create_async(SERVICE_UUID)
    if result.error != BluetoothError.SUCCESS:
        print(f"Could not create the service provider: {result.error}")
        return 1
    provider = result.service_provider

    notify_char = await create_characteristic(
        provider,
        TELEMETRY_UUID,
        GattCharacteristicProperties.NOTIFY | GattCharacteristicProperties.READ,
    )
    await create_characteristic(
        provider, COMMAND_UUID, GattCharacteristicProperties.WRITE
    )
    await create_characteristic(
        provider, DEVICE_INFO_UUID, GattCharacteristicProperties.READ
    )

    async def handle_read(sender, args):
        deferral = args.get_deferral()
        try:
            request = await args.get_request_async()
            request.respond_with_value(to_buffer(latest_packet))
        finally:
            deferral.complete()

    async def handle_write(sender, args):
        deferral = args.get_deferral()
        try:
            request = await args.get_request_async()
            print(f"Command received: {bytes(request.value)}")
            if request.option == GattWriteOption.WRITE_WITH_RESPONSE:
                request.respond()
        finally:
            deferral.complete()

    def on_read(sender, args):
        spawn(handle_read(sender, args))

    def on_write(sender, args):
        spawn(handle_write(sender, args))

    def on_subscribed(sender, args):
        print(f"Subscribed clients: {len(sender.subscribed_clients)}")

    notify_char.add_read_requested(on_read)
    notify_char.add_write_requested(on_write)
    notify_char.add_subscribed_clients_changed(on_subscribed)

    advertising = GattServiceProviderAdvertisingParameters()
    advertising.is_discoverable = True
    advertising.is_connectable = True
    provider.start_advertising(advertising)

    print(f"Advertising service {SERVICE_UUID}")
    print(f"Telemetry characteristic {TELEMETRY_UUID} (notify)")
    print("Press Ctrl+C to stop.\n")

    sequence = 0
    started = time.monotonic()
    try:
        while True:
            await asyncio.sleep(PUBLISH_INTERVAL_S)
            t = time.monotonic() - started
            sequence += 1

            accel = (0.42 * math.sin(t), 0.42 * math.cos(t * 0.8), 9.81)
            gyro = (
                1.24 * math.sin(t * 0.7),
                0.60 * math.cos(t * 0.5),
                0.10 * math.sin(t * 0.3),
            )
            temperature = 32.0 + 2.0 * math.sin(t / 10.0)
            speed = 18.0 + 6.0 * math.sin(t / 5.0)
            battery = max(0, 87 - sequence // 40)

            latest_packet = build_packet(
                sequence, accel, gyro, temperature, speed, battery
            )

            if notify_char.subscribed_clients:
                await notify_char.notify_value_async(to_buffer(latest_packet))
    except KeyboardInterrupt:
        print("\nStopping.")
    finally:
        provider.stop_advertising()
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))

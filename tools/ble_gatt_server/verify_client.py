#!/usr/bin/env python3
"""Verifies the Windows GATT server end to end.

Scans for the PulseLink service, connects, subscribes to the telemetry
characteristic and decodes the packets with the same rules as the Dart parser.

    pip install "bleak[winrt]"
    python verify_client.py
"""

import asyncio
import struct
import sys

from bleak import BleakClient, BleakScanner

SERVICE_UUID = "f0a1c000-1a2b-4c3d-8e9f-001122334455"
TELEMETRY_UUID = "f0a1c001-1a2b-4c3d-8e9f-001122334455"
PACKET_MAGIC = 0xA5
PACKET_VERSION = 1


def decode(raw: bytes):
    """Mirrors TelemetryFrame.decode in Dart."""
    if len(raw) < 41:
        raise ValueError(f"too short: {len(raw)}")
    magic, version, flags, sequence = struct.unpack_from("<BBBH", raw, 0)
    if magic != PACKET_MAGIC:
        raise ValueError(f"bad magic 0x{magic:02X}")
    if version != PACKET_VERSION:
        raise ValueError(f"bad version {version}")
    expected = sum(raw[:39]) & 0xFFFF
    checksum = struct.unpack_from("<H", raw, 39)[0]
    if checksum != expected:
        raise ValueError(f"bad checksum 0x{checksum:04X} != 0x{expected:04X}")

    (
        accel_x,
        accel_y,
        accel_z,
        gyro_x,
        gyro_y,
        gyro_z,
        temperature,
        speed,
    ) = struct.unpack_from("<ffffffff", raw, 5)
    battery = struct.unpack_from("<H", raw, 37)[0]
    return {
        "seq": sequence,
        "accel": (round(accel_x, 2), round(accel_y, 2), round(accel_z, 2)),
        "gyro": (round(gyro_x, 2), round(gyro_y, 2), round(gyro_z, 2)),
        "temperature": round(temperature, 1),
        "speed": round(speed, 1),
        "battery": battery,
        "moving": bool(flags & 0x01),
    }


async def main():
    print("Scanning for the PulseLink service ...")
    device = await BleakScanner.find_device_by_filter(
        lambda d, ad: SERVICE_UUID.lower()
        in [uuid.lower() for uuid in ad.service_uuids],
        timeout=25,
    )
    if device is None:
        print("Service not found. Is the GATT server running?")
        return 1

    print(f"Found {device.name} ({device.address})")
    async with BleakClient(device) as client:
        print("Services:")
        for service in client.services:
            print(f"  {service.uuid}")
            for char in service.characteristics:
                print(f"    {char.uuid} {sorted(char.properties)}")

        count = 0

        def on_notify(sender, data):
            nonlocal count
            count += 1
            try:
                frame = decode(bytes(data))
                print(f"[{count}] {frame}")
            except ValueError as error:
                print(f"[{count}] rejected: {error}")

        print("\nSubscribing to the telemetry characteristic ...")
        await client.start_notify(TELEMETRY_UUID, on_notify)
        await asyncio.sleep(6)
        await client.stop_notify(TELEMETRY_UUID)

    print(f"\nReceived {count} packets")
    return 0 if count > 0 else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))

/*
 * PulseLink - ESP32 sensor node
 *
 * Advertises the PulseLink telemetry service and streams the very same 41 byte
 * packet the Dart parser expects. Keep this file in sync with
 * lib/features/bluetooth/domain/models/telemetry_frame.dart
 * and lib/core/constants/ble_constants.dart
 *
 * Hardware : ESP32 (any 38 pin dev board)
 * Library  : NimBLE-Arduino 2.x
 * IDE      : Arduino IDE with the ESP32 board package
 */

#include <Arduino.h>
#include <NimBLEDevice.h>

// ---------------------------------------------------------------------------
// Packet layout - must match the Dart implementation
// ---------------------------------------------------------------------------
static const uint8_t PACKET_MAGIC = 0xA5;
static const uint8_t PACKET_VERSION = 0x01;
static const size_t PACKET_LENGTH = 41;
static const size_t CHECKSUM_OFFSET = 39;

static const uint8_t FLAG_MOVING = 0x01;
static const uint8_t FLAG_LOW_BATTERY = 0x02;
static const uint8_t FLAG_CHARGING = 0x04;

// ---------------------------------------------------------------------------
// GATT profile
// ---------------------------------------------------------------------------
static const char *SERVICE_UUID = "f0a1c000-1a2b-4c3d-8e9f-001122334455";
static const char *TELEMETRY_UUID = "f0a1c001-1a2b-4c3d-8e9f-001122334455";
static const char *COMMAND_UUID = "f0a1c002-1a2b-4c3d-8e9f-001122334455";
static const char *DEVICE_INFO_UUID = "f0a1c003-1a2b-4c3d-8e9f-001122334455";

static const char *DEVICE_NAME = "ESP32 Sensor Node";
static const uint32_t PUBLISH_INTERVAL_MS = 200;  // 5 Hz

NimBLEServer *gServer = nullptr;
NimBLECharacteristic *gTelemetry = nullptr;

uint16_t gSequence = 0;

// Sensor state. Replace the loop body with real readings.
float gAccelX = 0.42f, gAccelY = 0.0f, gAccelZ = 9.81f;
float gGyroX = 1.24f, gGyroY = 0.0f, gGyroZ = 0.0f;
float gTemperature = 31.5f;
float gSpeed = 18.0f;
uint16_t gBattery = 87;

// ---------------------------------------------------------------------------
// Little endian helpers
// ---------------------------------------------------------------------------
static void putUint16LE(uint8_t *buffer, size_t offset, uint16_t value) {
  buffer[offset] = (uint8_t)(value & 0xFF);
  buffer[offset + 1] = (uint8_t)((value >> 8) & 0xFF);
}

static void putFloat32LE(uint8_t *buffer, size_t offset, float value) {
  uint32_t bits;
  memcpy(&bits, &value, sizeof(bits));
  putUint16LE(buffer, offset, (uint16_t)(bits & 0xFFFF));
  putUint16LE(buffer, offset + 2, (uint16_t)(bits >> 16));
}

static uint16_t checksum(const uint8_t *buffer, size_t length) {
  uint16_t sum = 0;
  for (size_t i = 0; i < length; i++) {
    sum += buffer[i];
  }
  return sum & 0xFFFF;
}

// ---------------------------------------------------------------------------
// Packet builder
// ---------------------------------------------------------------------------
static void buildPacket(uint8_t *buffer) {
  memset(buffer, 0, PACKET_LENGTH);

  buffer[0] = PACKET_MAGIC;
  buffer[1] = PACKET_VERSION;

  uint8_t flags = 0;
  if (gSpeed > 1.0f) flags |= FLAG_MOVING;
  if (gBattery < 20) flags |= FLAG_LOW_BATTERY;
  if (gBattery > 95) flags |= FLAG_CHARGING;
  buffer[2] = flags;

  putUint16LE(buffer, 3, gSequence++);
  putFloat32LE(buffer, 5, gAccelX);
  putFloat32LE(buffer, 9, gAccelY);
  putFloat32LE(buffer, 13, gAccelZ);
  putFloat32LE(buffer, 17, gGyroX);
  putFloat32LE(buffer, 21, gGyroY);
  putFloat32LE(buffer, 25, gGyroZ);
  putFloat32LE(buffer, 29, gTemperature);
  putFloat32LE(buffer, 33, gSpeed);
  putUint16LE(buffer, 37, gBattery);

  putUint16LE(buffer, CHECKSUM_OFFSET, checksum(buffer, CHECKSUM_OFFSET));
}

// ---------------------------------------------------------------------------
// Callbacks
// ---------------------------------------------------------------------------
class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server, NimBLEConnInfo &info) override {
    Serial.println("Client connected");
  }

  void onDisconnect(NimBLEServer *server, NimBLEConnInfo &info, int reason) override {
    Serial.printf("Client disconnected (%d), advertising again\n", reason);
    NimBLEDevice::startAdvertising();
  }
};

class CommandCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *characteristic, NimBLEConnInfo &info) override {
    std::string value = characteristic->getValue();
    Serial.printf("Command received: %.*s\n", (int)value.length(), value.c_str());
  }
};

// ---------------------------------------------------------------------------
// Setup / loop
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  Serial.println("PulseLink sensor node starting");

  NimBLEDevice::init(DEVICE_NAME);
  // The 41 byte packet does not fit into the 23 byte default MTU.
  NimBLEDevice::setMTU(247);

  gServer = NimBLEDevice::createServer();
  gServer->setCallbacks(new ServerCallbacks());

  NimBLEService *service = gServer->createService(SERVICE_UUID);

  gTelemetry = service->createCharacteristic(
      TELEMETRY_UUID, NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ);

  NimBLECharacteristic *command = service->createCharacteristic(
      COMMAND_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  command->setCallbacks(new CommandCallbacks());

  NimBLECharacteristic *info = service->createCharacteristic(
      DEVICE_INFO_UUID, NIMBLE_PROPERTY::READ);
  info->setValue("PulseLink ESP32 Node");

  service->start();

  NimBLEAdvertising *advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setName(DEVICE_NAME);
  advertising->enableScanResponse(true);

  NimBLEDevice::startAdvertising();
  Serial.printf("Advertising as %s\n", DEVICE_NAME);
}

void loop() {
  static uint32_t lastPublish = 0;
  uint32_t now = millis();

  if (now - lastPublish < PUBLISH_INTERVAL_MS) {
    delay(5);
    return;
  }
  lastPublish = now;

  // --- Replace with the real sensor readings ---------------------------
  float t = now / 1000.0f;
  gAccelX = 0.42f * sinf(t);
  gAccelY = 0.42f * cosf(t * 0.8f);
  gAccelZ = 9.81f;
  gGyroX = 1.24f * sinf(t * 0.7f);
  gGyroY = 0.60f * cosf(t * 0.5f);
  gGyroZ = 0.10f * sinf(t * 0.3f);
  gTemperature = 32.0f + 2.0f * sinf(t / 10.0f);
  gSpeed = 18.0f + 6.0f * sinf(t / 5.0f);
  if (gBattery > 0) gBattery--;

  if (gServer->getConnectedCount() > 0) {
    uint8_t packet[PACKET_LENGTH];
    buildPacket(packet);
    gTelemetry->notify(packet, PACKET_LENGTH);
  }
}

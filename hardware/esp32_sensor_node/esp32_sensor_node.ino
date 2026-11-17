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
NimBLECharacteristic *gNotifyCharacteristic = nullptr;

uint16_t gSequence = 0;

// One telemetry sample.
struct Telemetry {
  uint16_t sequence;
  float accelX, accelY, accelZ;
  float gyroX, gyroY, gyroZ;
  float temperature;
  float speed;
  uint16_t battery;
  bool moving;
  bool charging;
};

// Sensor state. Replace the loop body with real readings.
Telemetry gSample = {
    /* sequence   */ 0,
    /* accelX     */ 0.42f,
    /* accelY     */ 0.0f,
    /* accelZ     */ 9.81f,
    /* gyroX      */ 1.24f,
    /* gyroY      */ 0.0f,
    /* gyroZ      */ 0.0f,
    /* temperature*/ 31.5f,
    /* speed      */ 18.0f,
    /* battery    */ 87,
    /* moving     */ true,
    /* charging   */ false,
};

// --- Battery ---------------------------------------------------------------
// Wire the cell through a 2:1 divider to an ADC1 pin (GPIO36 = ADC1_0) and
// define BATTERY_ADC_PIN below. Without a divider the node reports a fixed
// level rather than a made up one.
#ifdef BATTERY_ADC_PIN
float readBatteryPercent() {
  float volts = analogReadMilliVolts(BATTERY_ADC_PIN) / 1000.0f * 2.0f;
  float percent = (volts - 3.2f) / (4.2f - 3.2f) * 100.0f;
  return constrain(percent, 0.0f, 100.0f);
}
#else
float readBatteryPercent() { return 87.0f; }
#endif

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
static void buildPacket(uint8_t *buffer, const Telemetry &t) {
  memset(buffer, 0, PACKET_LENGTH);

  buffer[0] = PACKET_MAGIC;
  buffer[1] = PACKET_VERSION;

  uint8_t flags = 0;
  if (t.moving) flags |= FLAG_MOVING;
  if (t.battery < 20) flags |= FLAG_LOW_BATTERY;
  if (t.charging) flags |= FLAG_CHARGING;
  buffer[2] = flags;

  putUint16LE(buffer, 3, t.sequence);
  putFloat32LE(buffer, 5, t.accelX);
  putFloat32LE(buffer, 9, t.accelY);
  putFloat32LE(buffer, 13, t.accelZ);
  putFloat32LE(buffer, 17, t.gyroX);
  putFloat32LE(buffer, 21, t.gyroY);
  putFloat32LE(buffer, 25, t.gyroZ);
  putFloat32LE(buffer, 29, t.temperature);
  putFloat32LE(buffer, 33, t.speed);
  putUint16LE(buffer, 37, t.battery);

  putUint16LE(buffer, CHECKSUM_OFFSET, checksum(buffer, CHECKSUM_OFFSET));
}

// The golden packet: the same 41 bytes the Dart encoder and the Python GATT
// server produce. The sketch checks itself against it on boot, so the three
// implementations cannot drift apart unnoticed.
static const uint8_t GOLDEN_PACKET[PACKET_LENGTH] = {
    0xA5, 0x01, 0x01, 0x2A, 0x00, 0x3D, 0x0A, 0xD7, 0x3E, 0x00, 0x00, 0xA0,
    0xBF, 0xC3, 0xF5, 0x1C, 0x41, 0x52, 0xB8, 0x9E, 0x3F, 0x00, 0x00, 0x00,
    0x3F, 0x00, 0x00, 0x80, 0xBE, 0x00, 0x00, 0xFC, 0x41, 0x00, 0x00, 0x92,
    0x41, 0x57, 0x00, 0x6C, 0x0B};

static void checkPacketFormat() {
  Telemetry golden = gSample;
  golden.sequence = 42;
  golden.accelX = 0.42f;
  golden.accelY = -1.25f;
  golden.accelZ = 9.81f;
  golden.gyroX = 1.24f;
  golden.gyroY = 0.50f;
  golden.gyroZ = -0.25f;
  golden.temperature = 31.5f;
  golden.speed = 18.25f;
  golden.battery = 87;
  golden.moving = true;
  golden.charging = false;

  uint8_t packet[PACKET_LENGTH];
  buildPacket(packet, golden);

  if (memcmp(packet, GOLDEN_PACKET, PACKET_LENGTH) == 0) {
    Serial.println("Packet format matches the Dart encoder");
  } else {
    Serial.println("WARNING: packet format differs from the Dart encoder");
  }
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
  checkPacketFormat();

  NimBLEDevice::init(DEVICE_NAME);
  // The 41 byte packet does not fit into the 23 byte default MTU.
  NimBLEDevice::setMTU(247);

  gServer = NimBLEDevice::createServer();
  gServer->setCallbacks(new ServerCallbacks());

  NimBLEService *service = gServer->createService(SERVICE_UUID);

  gNotifyCharacteristic = service->createCharacteristic(
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
  gSample.sequence = gSequence++;
  gSample.accelX = 0.42f * sinf(t);
  gSample.accelY = 0.42f * cosf(t * 0.8f);
  gSample.accelZ = 9.81f;
  gSample.gyroX = 1.24f * sinf(t * 0.7f);
  gSample.gyroY = 0.60f * cosf(t * 0.5f);
  gSample.gyroZ = 0.10f * sinf(t * 0.3f);
  gSample.temperature = 32.0f + 2.0f * sinf(t / 10.0f);
  gSample.speed = 18.0f + 6.0f * sinf(t / 5.0f);
  gSample.battery = (uint16_t)readBatteryPercent();
  gSample.moving = gSample.speed > 1.0f;
  // Set this from a charger detect pin if the node has one.
  gSample.charging = false;

  if (gServer->getConnectedCount() > 0) {
    uint8_t packet[PACKET_LENGTH];
    buildPacket(packet, gSample);
    gNotifyCharacteristic->notify(packet, PACKET_LENGTH);
  }
}

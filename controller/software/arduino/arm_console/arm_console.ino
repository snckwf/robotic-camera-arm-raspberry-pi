/*
  arm_console.ino - Remote controller for the camera arm (Arduino Nano)

  Reads 2 KY-023 joysticks and 4 buttons and sends their state to the Raspberry Pi over USB (serial 115200).
  The Raspberry (controller_braccio.py program) turns the commands into arm movements.

  Wiring:
    LEFT joystick  (base / shoulder)    VRx -> A0   VRy -> A1   SW -> D2   +5V -> 5V   GND -> GND
    RIGHT joystick (elbow)              VRx -> A2   VRy -> A3   SW -> D3   +5V -> 5V   GND -> GND
    TILT UP button            D4 --[button]-- GND
    TILT DOWN button          D5 --[button]-- GND
    ROTATE LEFT button        D6 --[button]-- GND
    ROTATE RIGHT button       D7 --[button]-- GND
  (4-pin 12x12 buttons: use two pins on opposite sides, e.g. 1 and 4)

  Line sent every 40 ms (or at once when a button changes):
    J,<A0>,<A1>,<A2>,<A3>,<pulsanti>
    A0..A3 = 0..1023 (centre ~512), buttons = bit0 left SW, bit1 right SW,
             bit2 tilt up, bit3 tilt down, bit4 rotate left, bit5 rotate right (1 = pressed)
  Commands received:  "?" -> answers "ID,ARM_CONSOLE,1"
*/

const uint8_t PIN_ASSI[4] = {A0, A1, A2, A3};
const uint8_t PIN_TASTI[6] = {2, 3, 4, 5, 6, 7};
const uint8_t PIN_LED = 13;

const unsigned long PERIODO_MS = 40;     // 25 readings per second
const unsigned long ANTIRIMBALZO_MS = 20;

uint8_t statoTasti = 0;          // stable state (after debounce)
uint8_t letturaPrec = 0;
unsigned long tCambio = 0;
unsigned long tInvio = 0;
unsigned long tLed = 0;

int leggiAsse(uint8_t pin) {
  // average of 4 readings: removes the potentiometer noise
  long s = 0;
  for (uint8_t i = 0; i < 4; i++) s += analogRead(pin);
  return (int)(s / 4);
}

uint8_t leggiTasti() {
  uint8_t b = 0;
  for (uint8_t i = 0; i < 6; i++) {
    if (digitalRead(PIN_TASTI[i]) == LOW) b |= (1 << i);
  }
  return b;
}

void invia() {
  Serial.print(F("J,"));
  for (uint8_t i = 0; i < 4; i++) {
    Serial.print(leggiAsse(PIN_ASSI[i]));
    Serial.print(',');
  }
  Serial.println(statoTasti);
}

void setup() {
  Serial.begin(115200);
  for (uint8_t i = 0; i < 6; i++) pinMode(PIN_TASTI[i], INPUT_PULLUP);
  pinMode(PIN_LED, OUTPUT);
  Serial.println(F("ID,ARM_CONSOLE,1"));
}

void loop() {
  unsigned long ora = millis();

  // button debounce
  uint8_t l = leggiTasti();
  if (l != letturaPrec) {
    letturaPrec = l;
    tCambio = ora;
  }
  bool cambiato = false;
  if (ora - tCambio >= ANTIRIMBALZO_MS && l != statoTasti) {
    statoTasti = l;
    cambiato = true;
  }

  if (cambiato || ora - tInvio >= PERIODO_MS) {
    tInvio = ora;
    invia();
  }

  // identification request from the Raspberry
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '?') Serial.println(F("ID,ARM_CONSOLE,1"));
  }

  // onboard LED: slow blink = alive, steady on = button pressed
  if (statoTasti) {
    digitalWrite(PIN_LED, HIGH);
  } else if (ora - tLed >= 500) {
    tLed = ora;
    digitalWrite(PIN_LED, !digitalRead(PIN_LED));
  }
}

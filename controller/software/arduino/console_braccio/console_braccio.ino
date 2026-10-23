/*
  console_braccio.ino - Controller remoto del braccio telecamera (Arduino Nano)

  Legge 2 joystick KY-023 e 4 pulsanti e manda lo stato al Raspberry Pi via USB (seriale 115200).
  Il Raspberry (programma controller_braccio.py) trasforma i comandi in movimenti del braccio.

  Collegamenti:
    Joystick SINISTRO (base / spalla)   VRx -> A0   VRy -> A1   SW -> D2   +5V -> 5V   GND -> GND
    Joystick DESTRO   (gomito)          VRx -> A2   VRy -> A3   SW -> D3   +5V -> 5V   GND -> GND
    Pulsante TILT SU          D4 --[pulsante]-- GND
    Pulsante TILT GIU         D5 --[pulsante]-- GND
    Pulsante ROTAZIONE SX     D6 --[pulsante]-- GND
    Pulsante ROTAZIONE DX     D7 --[pulsante]-- GND
  (pulsanti 12x12 a 4 piedini: usare due piedini su lati opposti, es. 1 e 4)

  Riga inviata ogni 40 ms (o subito quando cambia un pulsante):
    J,<A0>,<A1>,<A2>,<A3>,<pulsanti>
    A0..A3 = 0..1023 (centro ~512), pulsanti = bit0 SW sinistro, bit1 SW destro,
             bit2 tilt su, bit3 tilt giu, bit4 rot sx, bit5 rot dx (1 = premuto)
  Comandi ricevuti:  "?" -> risponde "ID,CONSOLE_BRACCIO,1"
*/

const uint8_t PIN_ASSI[4] = {A0, A1, A2, A3};
const uint8_t PIN_TASTI[6] = {2, 3, 4, 5, 6, 7};
const uint8_t PIN_LED = 13;

const unsigned long PERIODO_MS = 40;     // 25 letture al secondo
const unsigned long ANTIRIMBALZO_MS = 20;

uint8_t statoTasti = 0;          // stato stabile (dopo antirimbalzo)
uint8_t letturaPrec = 0;
unsigned long tCambio = 0;
unsigned long tInvio = 0;
unsigned long tLed = 0;

int leggiAsse(uint8_t pin) {
  // media di 4 letture: toglie il rumore dei potenziometri
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
  Serial.println(F("ID,CONSOLE_BRACCIO,1"));
}

void loop() {
  unsigned long ora = millis();

  // antirimbalzo dei pulsanti
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

  // richiesta di identificazione dal Raspberry
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '?') Serial.println(F("ID,CONSOLE_BRACCIO,1"));
  }

  // LED di bordo: lampeggio lento = vivo, acceso fisso = pulsante premuto
  if (statoTasti) {
    digitalWrite(PIN_LED, HIGH);
  } else if (ora - tLed >= 500) {
    tLed = ora;
    digitalWrite(PIN_LED, !digitalRead(PIN_LED));
  }
}

#!/usr/bin/env python3
"""
controller_braccio.py - Optional remote controller for the camera arm: Arduino Nano over USB.

- Reads from the Nano serial port the lines "J,a0,a1,a2,a3,pulsanti" (arm_console.ino sketch, 115200 baud).
- Turns joysticks and buttons into commands for braccio_web.py (http://127.0.0.1:8091/api/...):
    left joystick      X -> base        Y -> spalla (shoulder)
    right joystick     Y -> gomito (elbow)   (X unused)
    buttons            tilt up / down, rotazione (rotation) left / right
    left joystick button: short = STOP, held 2 s = HOME base
    right joystick button: short = light on / off
- If the LCD display is also present (display_lcd.py, port 8092) it writes the messages there (STOP, HOME, light...);
  without the display it works all the same.
Dependencies (Raspberry Pi OS):  sudo apt install python3-serial
"""
import glob
import json
import os
import threading
import time
import urllib.parse
import urllib.request

API = os.environ.get("BRACCIO_API", "http://127.0.0.1:8091")
DISPLAY = os.environ.get("BRACCIO_DISPLAY", "http://127.0.0.1:8092")
ZONA_MORTA = 110                   # out of 512: how far to move the stick before the joint starts
RIPETI_JOG = 0.25                  # s: movement confirmation (braccio_web stops it after 0.7 s without confirmations)
HOME_TENUTO = 2.0                  # s: hold the left joystick button this long for HOME
LUCE_ACCESA = 60

# command direction: if a joint moves the wrong way, change it here (+1 / -1)
SEGNO = {"base": 1, "spalla": -1, "gomito": -1, "tilt": 1, "rotazione": 1}


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def api(percorso, timeout=3):
    try:
        with urllib.request.urlopen(API + percorso, timeout=timeout) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        try:
            return json.load(e)
        except Exception:  # noqa: BLE001
            return {"errore": str(e)}
    except Exception as e:  # noqa: BLE001
        return {"errore": str(e)}


def avviso(r1, r2, sec=3):
    """Message on the LCD display, if installed (otherwise nothing)."""
    q = urllib.parse.urlencode({"r1": r1, "r2": r2, "sec": sec})
    try:
        urllib.request.urlopen(f"{DISPLAY}/lcd?{q}", timeout=1).read()
    except Exception:  # noqa: BLE001
        pass


class Controller:
    def __init__(self):
        self.centro = None
        self.campioni = []
        self.tasti_prec = 0
        self.attivi = {}              # joint -> direction in progress
        self.ultimo_jog = {}
        self.errore_t = {}
        self.t_sw1 = None
        self.home_fatto = False

    @staticmethod
    def trova_porta():
        cand = sorted(glob.glob("/dev/serial/by-id/*"))
        cand = [c for c in cand if any(k in c for k in ("1a86", "CH340", "Arduino", "FTDI", "ch341"))] or cand
        cand += sorted(glob.glob("/dev/ttyUSB*")) + sorted(glob.glob("/dev/ttyACM*"))
        return cand[0] if cand else None

    def assi(self, v):
        # centre calibration: average of the first readings with the sticks at rest
        if self.centro is None:
            self.campioni.append(v)
            if len(self.campioni) >= 15:
                self.centro = [sum(c[i] for c in self.campioni) / len(self.campioni) for i in range(4)]
                log(f"Joystick centre: {[round(c) for c in self.centro]}")
            return [0, 0, 0, 0]
        return [x - c for x, c in zip(v, self.centro)]

    def gestisci(self, valori, tasti):
        a = self.assi(valori)
        voluti = {}

        def asse(nome, val):
            if abs(val) > ZONA_MORTA:
                voluti[nome] = (1 if val > 0 else -1) * SEGNO[nome]

        asse("base", a[0])
        asse("spalla", a[1])
        asse("gomito", a[3])
        if tasti & 0x04:
            voluti["tilt"] = SEGNO["tilt"]
        elif tasti & 0x08:
            voluti["tilt"] = -SEGNO["tilt"]
        if tasti & 0x10:
            voluti["rotazione"] = -SEGNO["rotazione"]
        elif tasti & 0x20:
            voluti["rotazione"] = SEGNO["rotazione"]

        ora = time.time()
        # released joints -> stop
        for nome in list(self.attivi):
            if voluti.get(nome) != self.attivi[nome]:
                api(f"/api/ferma?nome={nome}")
                del self.attivi[nome]
        # moving joints -> repeated jog
        for nome, verso in voluti.items():
            if ora - self.errore_t.get(nome, 0) < 1.5:      # after a refusal retry calmly
                continue
            if nome not in self.attivi or ora - self.ultimo_jog.get(nome, 0) > RIPETI_JOG:
                r = api(f"/api/jog?nome={nome}&verso={verso}")
                self.ultimo_jog[nome] = ora
                if "errore" in r:
                    self.errore_t[nome] = ora
                    if "not zeroed" in r["errore"]:
                        avviso("Base not zeroed", "Hold LEFT btn", 3)
                    continue
                self.attivi[nome] = verso

        # left joystick button: short = STOP, held = HOME
        sw1 = bool(tasti & 0x01)
        if sw1 and self.t_sw1 is None:
            self.t_sw1, self.home_fatto = ora, False
        if sw1 and not self.home_fatto and ora - self.t_sw1 >= HOME_TENUTO:
            self.home_fatto = True
            avviso("HOME base...", "please wait", 30)
            threading.Thread(target=self.home, daemon=True).start()
        if not sw1 and self.t_sw1 is not None:
            if not self.home_fatto:
                api("/api/stop")
                self.attivi.clear()
                avviso("STOP", "", 2)
            self.t_sw1 = None
        # right joystick button: light
        if (tasti & 0x02) and not (self.tasti_prec & 0x02):
            liv = api("/api/stato").get("luce", {}).get("livello", 0)
            nuovo = 0 if liv else LUCE_ACCESA
            api(f"/api/luce?livello={nuovo}")
            avviso("Light", "on" if nuovo else "off", 1.5)
        self.tasti_prec = tasti

    def home(self):
        r = api("/api/home", timeout=120)
        avviso("HOME base", "done" if r.get("home") else "FAILED", 3)

    def ferma_tutto(self):
        if self.attivi:
            api("/api/stop")
        self.attivi.clear()

    def ciclo(self):
        import serial
        segnalato = False
        while True:
            porta = self.trova_porta()
            if not porta:
                if not segnalato:
                    log("Waiting for the controller (Arduino Nano over USB)...")
                    segnalato = True
                time.sleep(2)
                continue
            try:
                with serial.Serial(porta, 115200, timeout=0.5) as s:
                    log(f"Controller connected on {porta}")
                    avviso("Controller", "connected", 2)
                    segnalato = False
                    self.centro, self.campioni = None, []
                    ultimo = time.time()
                    while True:
                        riga = s.readline().decode(errors="ignore").strip()
                        if not riga:
                            if time.time() - ultimo > 1.0:      # silent controller: stop the joints for safety
                                self.ferma_tutto()
                            continue
                        ultimo = time.time()
                        p = riga.split(",")
                        if p[0] != "J" or len(p) != 6:
                            continue
                        try:
                            v = [int(x) for x in p[1:5]]
                            t = int(p[5])
                        except ValueError:
                            continue
                        self.gestisci(v, t)
            except Exception as e:  # noqa: BLE001
                log(f"Controller disconnected ({e})")
                self.ferma_tutto()
                time.sleep(2)


if __name__ == "__main__":
    Controller().ciclo()

#!/usr/bin/env python3
"""
display_lcd.py - Optional 16x2 LCD display for the camera arm.

- Shows the joint positions and the light, read from braccio_web.py (http://127.0.0.1:8091/api/stato).
- Small HTTP server on port 8092 to write messages on the display (used by Claude, the controller and scripts):
    GET /lcd?r1=Hello&r2=World&sec=10    writes two lines for 10 seconds, then the status comes back
    GET /lcd/stato                       what is on the display now
Hardware: 16x2 LCD with PCF8574 I2C module (address 0x27 or 0x3F) powered at 5 V,
          connected to GPIO2/GPIO3 through the BSS138 level shifter.
Dependencies (Raspberry Pi OS):  sudo apt install python3-smbus2 ;  I2C enabled (sudo raspi-config)
"""
import json
import os
import threading
import time
import unicodedata
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

API = os.environ.get("BRACCIO_API", "http://127.0.0.1:8091")
PORTA_HTTP = int(os.environ.get("DISPLAY_PORTA", "8092"))
LCD_BUS = 1
LCD_INDIRIZZI = (0x27, 0x3F)       # typical addresses of the PCF8574 module


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def api(percorso, timeout=3):
    try:
        with urllib.request.urlopen(API + percorso, timeout=timeout) as r:
            return json.load(r)
    except Exception as e:  # noqa: BLE001
        return {"errore": str(e)}


# ------------------------------------------------------------------ 16x2 LCD display on PCF8574
class Lcd:
    RS, EN, BL = 0x01, 0x04, 0x08

    def __init__(self):
        self.bus = None
        self.ind = None
        self.lock = threading.Lock()
        self.righe = ["", ""]
        try:
            try:
                from smbus2 import SMBus
            except ImportError:
                from smbus import SMBus
            bus = SMBus(LCD_BUS)
            for ind in LCD_INDIRIZZI:
                try:
                    bus.write_byte(ind, self.BL)
                    self.bus, self.ind = bus, ind
                    break
                except OSError:
                    continue
            if self.bus is None:
                log("WARNING: LCD display not found on I2C (0x27 / 0x3F)")
                return
            self._init()
            log(f"LCD display on I2C 0x{self.ind:02X}")
        except Exception as e:  # noqa: BLE001
            log(f"WARNING: I2C not available ({e})")
            self.bus = None

    def _scrivi4(self, val):
        self.bus.write_byte(self.ind, val | self.BL)
        self.bus.write_byte(self.ind, val | self.EN | self.BL)
        time.sleep(0.0005)
        self.bus.write_byte(self.ind, (val & ~self.EN) | self.BL)
        time.sleep(0.0001)

    def _byte(self, val, rs=0):
        self._scrivi4((val & 0xF0) | rs)
        self._scrivi4(((val << 4) & 0xF0) | rs)

    def _init(self):
        time.sleep(0.05)
        for _ in range(3):
            self._scrivi4(0x30)
            time.sleep(0.005)
        self._scrivi4(0x20)          # 4-bit mode
        self._byte(0x28)             # 2 lines, 5x8 characters
        self._byte(0x0C)             # display on, cursor off
        self._byte(0x06)             # write to the right
        self._byte(0x01)             # clear
        time.sleep(0.003)

    @staticmethod
    def pulisci(testo):
        t = unicodedata.normalize("NFKD", str(testo)).encode("ascii", "ignore").decode()
        return t[:16].ljust(16)

    def mostra(self, r1, r2):
        r1, r2 = self.pulisci(r1), self.pulisci(r2)
        with self.lock:
            if [r1, r2] == self.righe or self.bus is None:
                self.righe = [r1, r2]
                return
            try:
                for riga, testo in ((0x80, r1), (0xC0, r2)):
                    self._byte(riga)
                    for c in testo:
                        self._byte(ord(c), self.RS)
                self.righe = [r1, r2]
            except OSError as e:
                log(f"LCD: I2C error ({e}), retrying")
                try:
                    self._init()
                except OSError:
                    pass


LCD = Lcd()
MESSAGGIO = {"r1": "", "r2": "", "fino": 0.0}


def ciclo_display():
    LCD.mostra("Camera arm", "starting...")
    while True:
        time.sleep(0.5)
        if time.time() < MESSAGGIO["fino"]:
            LCD.mostra(MESSAGGIO["r1"], MESSAGGIO["r2"])
            continue
        s = api("/api/stato", timeout=2)
        if "giunti" not in s:
            LCD.mostra("Camera arm", "server off")
            continue
        g = s["giunti"]
        base = f"{s['base']:4.0f}" if s.get("base_azzerata") else "   ?"
        r1 = f"B{base} S{g['spalla']:3.0f} E{g['gomito']:4.0f}"
        r2 = f"T{g['tilt']:4.0f} R{g['rotazione']:4.0f} L{s['luce']['livello']:3d}"
        LCD.mostra(r1, r2)


def messaggio(r1, r2, sec=3):
    MESSAGGIO.update(r1=r1, r2=r2, fino=time.time() + sec)
    LCD.mostra(r1, r2)


# ------------------------------------------------------------------ HTTP server for the messages
class Gestore(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def _json(self, dati, codice=200):
        corpo = json.dumps(dati, ensure_ascii=False).encode()
        self.send_response(codice)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self):  # noqa: N802
        u = urlparse(self.path)
        q = {k: v[-1] for k, v in parse_qs(u.query).items()}
        if u.path == "/lcd":
            try:
                sec = max(1.0, min(600.0, float(q.get("sec", 10))))
            except ValueError:
                sec = 10.0
            messaggio(q.get("r1", ""), q.get("r2", ""), sec)
            return self._json({"r1": LCD.righe[0], "r2": LCD.righe[1], "secondi": sec, "lcd": LCD.bus is not None})
        if u.path == "/lcd/stato":
            return self._json({"r1": LCD.righe[0], "r2": LCD.righe[1], "lcd": LCD.bus is not None})
        return self._json({"errore": "unknown path"}, 404)


def main():
    threading.Thread(target=ciclo_display, daemon=True).start()
    log(f"Display ready, messages on http://0.0.0.0:{PORTA_HTTP}/lcd")
    ThreadingHTTPServer(("0.0.0.0", PORTA_HTTP), Gestore).serve_forever()


if __name__ == "__main__":
    main()

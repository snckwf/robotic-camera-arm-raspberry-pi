#!/usr/bin/env python3
"""
display_lcd.py - Display LCD 16x2 (opzionale) del braccio telecamera.

- Mostra la posizione dei giunti e la luce, letti da braccio_web.py (http://127.0.0.1:8091/api/stato).
- Piccolo server HTTP sulla porta 8092 per scrivere messaggi sul display (usato da Claude, dal controller e dagli script):
    GET /lcd?r1=Ciao&r2=Mondo&sec=10     scrive due righe per 10 secondi, poi torna lo stato
    GET /lcd/stato                       cosa c'e' sul display adesso
Hardware: LCD 16x2 con modulo I2C PCF8574 (indirizzo 0x27 o 0x3F) alimentato a 5 V,
          collegato a GPIO2/GPIO3 attraverso il traslatore di livello BSS138.
Dipendenze (Raspberry Pi OS):  sudo apt install python3-smbus2 ;  I2C attivo (sudo raspi-config)
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
LCD_INDIRIZZI = (0x27, 0x3F)       # indirizzi tipici del modulo PCF8574


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def api(percorso, timeout=3):
    try:
        with urllib.request.urlopen(API + percorso, timeout=timeout) as r:
            return json.load(r)
    except Exception as e:  # noqa: BLE001
        return {"errore": str(e)}


# ------------------------------------------------------------------ display LCD 16x2 su PCF8574
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
                log("ATTENZIONE: display LCD non trovato su I2C (0x27 / 0x3F)")
                return
            self._init()
            log(f"Display LCD su I2C 0x{self.ind:02X}")
        except Exception as e:  # noqa: BLE001
            log(f"ATTENZIONE: I2C non disponibile ({e})")
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
        self._scrivi4(0x20)          # modo 4 bit
        self._byte(0x28)             # 2 righe, caratteri 5x8
        self._byte(0x0C)             # display acceso, cursore spento
        self._byte(0x06)             # scrittura verso destra
        self._byte(0x01)             # cancella
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
                log(f"LCD: errore I2C ({e}), riprovo")
                try:
                    self._init()
                except OSError:
                    pass


LCD = Lcd()
MESSAGGIO = {"r1": "", "r2": "", "fino": 0.0}


def ciclo_display():
    LCD.mostra("Braccio camera", "avvio...")
    while True:
        time.sleep(0.5)
        if time.time() < MESSAGGIO["fino"]:
            LCD.mostra(MESSAGGIO["r1"], MESSAGGIO["r2"])
            continue
        s = api("/api/stato", timeout=2)
        if "giunti" not in s:
            LCD.mostra("Braccio camera", "server spento")
            continue
        g = s["giunti"]
        base = f"{s['base']:4.0f}" if s.get("base_azzerata") else "   ?"
        r1 = f"B{base} S{g['spalla']:3.0f} G{g['gomito']:4.0f}"
        r2 = f"T{g['tilt']:4.0f} R{g['rotazione']:4.0f} L{s['luce']['livello']:3d}"
        LCD.mostra(r1, r2)


def messaggio(r1, r2, sec=3):
    MESSAGGIO.update(r1=r1, r2=r2, fino=time.time() + sec)
    LCD.mostra(r1, r2)


# ------------------------------------------------------------------ server HTTP per i messaggi
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
        return self._json({"errore": "percorso sconosciuto"}, 404)


def main():
    threading.Thread(target=ciclo_display, daemon=True).start()
    log(f"Display pronto, messaggi su http://0.0.0.0:{PORTA_HTTP}/lcd")
    ThreadingHTTPServer(("0.0.0.0", PORTA_HTTP), Gestore).serve_forever()


if __name__ == "__main__":
    main()

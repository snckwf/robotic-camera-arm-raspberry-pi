#!/usr/bin/env python3
"""
console_lcd.py - Ponte tra console remota (Arduino Nano via USB), display LCD 16x2 sul box e braccio.

- Legge dalla seriale del Nano le righe "J,a0,a1,a2,a3,pulsanti" (sketch console_braccio.ino).
- Trasforma joystick e pulsanti in comandi per braccio_web.py (http://127.0.0.1:8091/api/...):
    joystick sinistro  X -> base        Y -> spalla
    joystick destro    Y -> gomito      (X libero)
    pulsanti           tilt su / giu, rotazione sx / dx
    pulsante joystick sinistro: breve = STOP, tenuto 2 s = HOME base
    pulsante joystick destro:   breve = luce accesa / spenta
- Mostra sul display LCD 16x2 (I2C, modulo PCF8574, dietro traslatore di livello) la posizione dei giunti.
- Piccolo server HTTP sulla porta 8092 per scrivere messaggi sul display (per Claude e per gli script):
    GET /lcd?r1=Ciao&r2=Mondo&sec=10     scrive due righe per 10 secondi, poi torna lo stato
    GET /lcd/stato                       cosa c'e' sul display adesso
Dipendenze (Raspberry Pi OS):  sudo apt install python3-serial python3-smbus2 ;  I2C attivo (raspi-config)
"""
import glob
import json
import os
import threading
import time
import unicodedata
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

API = os.environ.get("BRACCIO_API", "http://127.0.0.1:8091")
PORTA_HTTP = int(os.environ.get("CONSOLE_PORTA", "8092"))
LCD_BUS = 1
LCD_INDIRIZZI = (0x27, 0x3F)       # indirizzi tipici del modulo PCF8574
ZONA_MORTA = 110                   # su 512: quanto spostare la leva prima che il giunto parta
RIPETI_JOG = 0.25                  # s: conferma del movimento (braccio_web lo ferma dopo 0,7 s senza conferme)
HOME_TENUTO = 2.0                  # s: tenere premuto il pulsante del joystick sinistro per l'HOME
LUCE_ACCESA = 60

# segno dei comandi: se un giunto va al contrario, cambiare qui (+1 / -1)
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


def avviso(r1, r2, sec=3):
    MESSAGGIO.update(r1=r1, r2=r2, fino=time.time() + sec)
    LCD.mostra(r1, r2)


# ------------------------------------------------------------------ console via seriale
class Console:
    def __init__(self):
        self.centro = None
        self.campioni = []
        self.tasti_prec = 0
        self.attivi = {}              # giunto -> verso in corso
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
        # calibrazione del centro: media delle prime letture a leve ferme
        if self.centro is None:
            self.campioni.append(v)
            if len(self.campioni) >= 15:
                self.centro = [sum(c[i] for c in self.campioni) / len(self.campioni) for i in range(4)]
                log(f"Centro joystick: {[round(c) for c in self.centro]}")
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
        # giunti rilasciati -> ferma
        for nome in list(self.attivi):
            if voluti.get(nome) != self.attivi[nome]:
                api(f"/api/ferma?nome={nome}")
                del self.attivi[nome]
        # giunti in movimento -> jog ripetuto
        for nome, verso in voluti.items():
            if ora - self.errore_t.get(nome, 0) < 1.5:      # dopo un rifiuto riprova con calma
                continue
            if nome not in self.attivi or ora - self.ultimo_jog.get(nome, 0) > RIPETI_JOG:
                r = api(f"/api/jog?nome={nome}&verso={verso}")
                self.ultimo_jog[nome] = ora
                if "errore" in r:
                    self.errore_t[nome] = ora
                    if "azzerata" in r["errore"]:
                        avviso("Base da azzerare", "Tieni premuto SX")
                    continue
                self.attivi[nome] = verso

        # pulsante joystick sinistro: breve = STOP, tenuto = HOME
        sw1 = bool(tasti & 0x01)
        if sw1 and self.t_sw1 is None:
            self.t_sw1, self.home_fatto = ora, False
        if sw1 and not self.home_fatto and ora - self.t_sw1 >= HOME_TENUTO:
            self.home_fatto = True
            avviso("HOME base...", "attendere", 30)
            threading.Thread(target=self.home, daemon=True).start()
        if not sw1 and self.t_sw1 is not None:
            if not self.home_fatto:
                api("/api/stop")
                self.attivi.clear()
                avviso("STOP", "", 2)
            self.t_sw1 = None
        # pulsante joystick destro: luce
        if (tasti & 0x02) and not (self.tasti_prec & 0x02):
            liv = api("/api/stato").get("luce", {}).get("livello", 0)
            nuovo = 0 if liv else LUCE_ACCESA
            api(f"/api/luce?livello={nuovo}")
            avviso("Luce", "accesa" if nuovo else "spenta", 1.5)
        self.tasti_prec = tasti

    def home(self):
        r = api("/api/home", timeout=120)
        avviso("HOME base", "fatto" if r.get("home") else "FALLITO", 3)

    def ferma_tutto(self):
        if self.attivi:
            api("/api/stop")
        self.attivi.clear()

    def ciclo(self):
        import serial
        while True:
            porta = self.trova_porta()
            if not porta:
                time.sleep(2)
                continue
            try:
                with serial.Serial(porta, 115200, timeout=0.5) as s:
                    log(f"Console collegata su {porta}")
                    self.centro, self.campioni = None, []
                    ultimo = time.time()
                    while True:
                        riga = s.readline().decode(errors="ignore").strip()
                        if not riga:
                            if time.time() - ultimo > 1.0:      # console muta: per sicurezza ferma i giunti
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
                log(f"Console scollegata ({e})")
                self.ferma_tutto()
                time.sleep(2)


# ------------------------------------------------------------------ server HTTP per i messaggi sul display
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
            sec = max(1.0, min(600.0, float(q.get("sec", 10))))
            avviso(q.get("r1", ""), q.get("r2", ""), sec)
            return self._json({"r1": LCD.righe[0], "r2": LCD.righe[1], "secondi": sec})
        if u.path == "/lcd/stato":
            return self._json({"r1": LCD.righe[0], "r2": LCD.righe[1], "lcd": LCD.bus is not None})
        return self._json({"errore": "percorso sconosciuto"}, 404)


def main():
    threading.Thread(target=ciclo_display, daemon=True).start()
    threading.Thread(target=Console().ciclo, daemon=True).start()
    log(f"Console/LCD pronti, messaggi su http://0.0.0.0:{PORTA_HTTP}/lcd")
    ThreadingHTTPServer(("0.0.0.0", PORTA_HTTP), Gestore).serve_forever()


if __name__ == "__main__":
    main()

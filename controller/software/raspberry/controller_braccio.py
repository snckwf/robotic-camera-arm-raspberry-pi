#!/usr/bin/env python3
"""
controller_braccio.py - Controller remoto (opzionale) del braccio telecamera: Arduino Nano via USB.

- Legge dalla seriale del Nano le righe "J,a0,a1,a2,a3,pulsanti" (sketch console_braccio.ino, 115200 baud).
- Trasforma joystick e pulsanti in comandi per braccio_web.py (http://127.0.0.1:8091/api/...):
    joystick sinistro  X -> base        Y -> spalla
    joystick destro    Y -> gomito      (X libero)
    pulsanti           tilt su / giu, rotazione sx / dx
    pulsante joystick sinistro: breve = STOP, tenuto 2 s = HOME base
    pulsante joystick destro:   breve = luce accesa / spenta
- Se c'e' anche il display LCD (display_lcd.py, porta 8092) ci scrive i messaggi (STOP, HOME, luce...);
  senza display funziona lo stesso.
Dipendenze (Raspberry Pi OS):  sudo apt install python3-serial
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
ZONA_MORTA = 110                   # su 512: quanto spostare la leva prima che il giunto parta
RIPETI_JOG = 0.25                  # s: conferma del movimento (braccio_web lo ferma dopo 0,7 s senza conferme)
HOME_TENUTO = 2.0                  # s: tenere premuto il pulsante del joystick sinistro per l'HOME
LUCE_ACCESA = 60

# verso dei comandi: se un giunto va al contrario, cambiare qui (+1 / -1)
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
    """Messaggio sul display LCD, se installato (altrimenti nulla)."""
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
        segnalato = False
        while True:
            porta = self.trova_porta()
            if not porta:
                if not segnalato:
                    log("In attesa del controller (Arduino Nano via USB)...")
                    segnalato = True
                time.sleep(2)
                continue
            try:
                with serial.Serial(porta, 115200, timeout=0.5) as s:
                    log(f"Controller collegato su {porta}")
                    avviso("Controller", "collegato", 2)
                    segnalato = False
                    self.centro, self.campioni = None, []
                    ultimo = time.time()
                    while True:
                        riga = s.readline().decode(errors="ignore").strip()
                        if not riga:
                            if time.time() - ultimo > 1.0:      # controller muto: per sicurezza ferma i giunti
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
                log(f"Controller scollegato ({e})")
                self.ferma_tutto()
                time.sleep(2)


if __name__ == "__main__":
    Controller().ciclo()

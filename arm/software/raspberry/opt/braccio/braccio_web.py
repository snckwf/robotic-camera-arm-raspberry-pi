#!/usr/bin/env python3
"""
braccio_web.py - Server with web interface for the camera arm (Raspberry Pi 4).

Interface:  http://<pi-ip>:8091/
Hardware (see the wiring diagram):
  servos    PCA9685 board on I2C (GPIO2 SDA, GPIO3 SCL, address 0x40):
            CH0 shoulder (spalla) MG996R, CH1 elbow (gomito) MG996R, CH2 tilt MG90S, CH3 rotation (rotazione) MG90S
            (alternatively, for each servo in config.json: "tipo": "hw" = hardware PWM GPIO12/13
             with dtoverlay=pwm-2chan, "tipo": "sw" = lgpio software pulses on any GPIO)
  base      28BYJ-48 + ULN2003  GPIO17, 27, 22, 23 (half step, 1:2 reduction)
  homing    KY-024 DO  GPIO24
  light     WS2812B 24-LED ring on SPI0 MOSI (GPIO10)
  camera    CamUI (port 8080): stream /video_feed_0, photos /snapshot_0

API (GET unless stated otherwise; names are kept in Italian as in the code):
  /api/stato                        status
  /api/muovi?base=&spalla=&gomito=&tilt=&rotazione=&attendi=1   move (attendi=1 waits for the end)
  /api/stop                         stops everything at once (servos stay in position)
  /api/rilascia                     switches off the servo pulses (release)
  /api/home                         base zeroing with the Hall sensor
  /api/luce?livello=0..100&colore=ffffff   light level and colour
  /api/preset/elenco | /api/preset?nome= | /api/preset/salva?nome= | /api/preset/elimina?nome=   list / go / save / delete
  /api/scatta?luce=&attesa=0.4      JPEG photo (waits for the end of the movement)
  /api/config                       GET: configuration   POST (JSON): change and save
  /api/prova?nome=spalla&gradi=90   "raw" servo angle 0..180 for calibration
/api/registra?azione=avvia|ferma|stato&max=600   MP4 video recording start|stop|status (go2rtc stream)
/api/video/elenco | /api/video/file?nome=&scarica=1 | /api/video/elimina?nome=   list / file (download) / delete
"""
import json
import mimetypes
import os
import subprocess
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

CARTELLA = os.path.dirname(os.path.abspath(__file__))
CARTELLA_UI = os.path.join(CARTELLA, "ui")
DATI = os.environ.get("BRACCIO_DATI", os.path.join(CARTELLA, "dati"))
os.makedirs(DATI, exist_ok=True)
F_CONFIG = os.path.join(DATI, "config.json")
F_STATO = os.path.join(DATI, "stato.json")
F_PRESET = os.path.join(DATI, "preset.json")

CONFIG_DEFAULT = {
    "porta": 8091,
    "camui": "http://127.0.0.1:8080",
    "servo": {
        # logical angle -> servo angle = zero_servo + segno * (angle - riferimento)
        "spalla":    {"tipo": "pca", "canale": 0, "gpio": 12, "min": 28, "max": 115,
                      "riferimento": 70, "zero_servo": 90, "segno": 1, "vel": 40,
                      "imp_min": 500, "imp_max": 2500, "rilascia_dopo": False, "partenza": 70},
        "gomito":    {"tipo": "pca", "canale": 1, "gpio": 13, "min": -90, "max": 90,
                      "riferimento": 0, "zero_servo": 90, "segno": 1, "vel": 50,
                      "imp_min": 500, "imp_max": 2500, "rilascia_dopo": False, "partenza": -60},
        "tilt":      {"tipo": "pca", "canale": 2, "gpio": 5, "min": -90, "max": 90,
                      "riferimento": 0, "zero_servo": 90, "segno": 1, "vel": 90,
                      "imp_min": 500, "imp_max": 2400, "rilascia_dopo": True, "partenza": -45},
        "rotazione": {"tipo": "pca", "canale": 3, "gpio": 6, "min": -90, "max": 90,
                      "riferimento": 0, "zero_servo": 90, "segno": 1, "vel": 90,
                      "imp_min": 500, "imp_max": 2400, "rilascia_dopo": True, "partenza": 0},
    },
    "base": {
        "pin": [17, 27, 22, 23],
        "passi_giro_motore": 4096,
        "riduzione": 2.0,
        "ritardo_passo": 0.0015,
        "min": -170, "max": 170,
        "segno": 1,
        "gpio_hall": 24, "hall_attivo": 0,
        "angolo_hall": 0,
        "ricerca_max": 400
    },
    # PCA9685 servo board (address 64 = 0x40; 50 Hz for the servos)
    "pca9685": {"bus": 1, "indirizzo": 64, "freq": 50},
    "luce": {"spi_bus": 0, "spi_dev": 0, "led": 24, "livello_max": 60, "ordine": "GRB"},
    # global speed in % (scales the servo speeds and the base step rate) and image flipping
    "interfaccia": {"velocita": 60, "flip_h": False, "flip_v": False},
    "camera": {
        "galleria_camui": "/home/YOUR_USER/CamUI/static/gallery",
        # 4:3 resolutions offered by CamUI for the video (CamUI index, width, height)
        "live": [[0, 3280, 2464], [4, 1640, 1232], [5, 1140, 856], [6, 640, 480], [7, 480, 360], [8, 320, 240]],
        "live_indice": 4,
        # resolutions offered for photos (derived from the full-sensor photo 3280x2464)
        "foto": [[3280, 2464], [2592, 1944], [1920, 1440], [1640, 1232], [1280, 960], [640, 480]],
        "foto_ris": [3280, 2464],
        "foto_hq": True,
    },
}
JOG_TIMEOUT = 0.7   # s: a press-and-hold movement stops by itself if the browser stops confirming it
# fields editable from the interface (the others stay in the file only)
MODIFICABILI = {
    "servo": ["min", "max", "riferimento", "zero_servo", "segno", "vel", "imp_min", "imp_max", "rilascia_dopo"],
    "base": ["ritardo_passo", "min", "max", "segno", "hall_attivo", "angolo_hall", "ricerca_max"],
    "luce": ["led", "livello_max", "ordine"],
}

PASSI = [(1, 0, 0, 0), (1, 1, 0, 0), (0, 1, 0, 0), (0, 1, 1, 0),
         (0, 0, 1, 0), (0, 0, 1, 1), (0, 0, 0, 1), (1, 0, 0, 1)]


def carica_json(percorso, default):
    try:
        with open(percorso, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def salva_json(percorso, dati):
    tmp = percorso + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(dati, f, indent=2, ensure_ascii=False)
    os.replace(tmp, percorso)


def unisci(base, extra):
    out = dict(base)
    for k, v in extra.items():
        out[k] = unisci(out[k], v) if isinstance(v, dict) and isinstance(out.get(k), dict) else v
    return out


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


# ------------------------------------------------------------------ GPIO
try:
    import lgpio
    GPIO = lgpio.gpiochip_open(0)
except Exception as e:  # noqa: BLE001
    lgpio = None
    GPIO = None
    log(f"WARNING: lgpio not available ({e}) - simulated GPIO")


class PwmHw:
    """Hardware PWM via sysfs (dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4)."""
    PERIODO = 20_000_000

    def __init__(self, canale):
        self.ok = False
        self.chip = self._trova_chip()
        if not self.chip:
            log(f"WARNING: hardware PWM missing - channel {canale} simulated")
            return
        self.dir = f"{self.chip}/pwm{canale}"
        try:
            if not os.path.isdir(self.dir):
                self._scrivi(f"{self.chip}/export", canale)
                for _ in range(50):
                    if os.path.isdir(self.dir):
                        break
                    time.sleep(0.02)
                time.sleep(0.1)
            self._scrivi(f"{self.dir}/period", self.PERIODO)
            self.ok = True
        except OSError as e:
            log(f"WARNING: PWM channel {canale}: {e}")

    @staticmethod
    def _trova_chip():
        radice = "/sys/class/pwm"
        if not os.path.isdir(radice):
            return None
        candidati = []
        for nome in sorted(os.listdir(radice)):
            p = os.path.join(radice, nome)
            try:
                with open(os.path.join(p, "npwm")) as f:
                    npwm = int(f.read())
            except (OSError, ValueError):
                continue
            disp = os.path.realpath(p)
            if npwm >= 2 and ("20c000.pwm" in disp):
                return p
            if npwm >= 2 and "fan" not in disp:
                candidati.append(p)
        return candidati[0] if candidati else None

    @staticmethod
    def _scrivi(percorso, valore):
        with open(percorso, "w") as f:
            f.write(str(valore))

    def impulso(self, us):
        if not self.ok:
            return
        if us <= 0:
            self._scrivi(f"{self.dir}/enable", 0)
            return
        self._scrivi(f"{self.dir}/duty_cycle", int(us * 1000))
        self._scrivi(f"{self.dir}/enable", 1)


class Pca9685:
    """PCA9685 board (16 PWM channels, I2C): generates the servo pulses in hardware, no jitter."""
    _istanze = {}

    def __init__(self, bus, indirizzo, freq):
        self.ok = False
        self.ind = int(indirizzo)
        self.lock = threading.Lock()
        self.periodo_us = 1_000_000 / float(freq)
        try:
            try:
                from smbus2 import SMBus
            except ImportError:
                from smbus import SMBus
            self.bus = SMBus(int(bus))
            prescale = int(round(25_000_000 / (4096 * float(freq)))) - 1
            self.bus.write_byte_data(self.ind, 0x00, 0x10)        # MODE1: sleep to change frequency
            self.bus.write_byte_data(self.ind, 0xFE, prescale)    # PRE_SCALE
            self.bus.write_byte_data(self.ind, 0x01, 0x04)        # MODE2: totem-pole outputs
            self.bus.write_byte_data(self.ind, 0x00, 0x20)        # MODE1: wake up + auto-increment
            time.sleep(0.005)
            self.ok = True
            log(f"PCA9685 ready (bus {bus}, address 0x{self.ind:02X}, {freq} Hz)")
        except Exception as e:  # noqa: BLE001
            log(f"WARNING: PCA9685 not found (bus {bus}, 0x{self.ind:02X}): {e} - simulated servos")

    @classmethod
    def condivisa(cls, cfg):
        chiave = (int(cfg["bus"]), int(cfg["indirizzo"]))
        if chiave not in cls._istanze:
            cls._istanze[chiave] = cls(cfg["bus"], cfg["indirizzo"], cfg["freq"])
        return cls._istanze[chiave]

    def imposta(self, canale, us):
        if not self.ok:
            return
        if us <= 0:
            dati = [0, 0, 0, 0x10]                              # channel off (FULL OFF)
        else:
            off = max(1, min(4095, int(round(us / self.periodo_us * 4096))))
            dati = [0, 0, off & 0xFF, off >> 8]
        with self.lock:
            try:
                self.bus.write_i2c_block_data(self.ind, 0x06 + 4 * int(canale), dati)
            except OSError as e:
                log(f"WARNING: PCA9685 channel {canale}: {e}")


class PwmPca:
    def __init__(self, cfg_pca, canale):
        self.pca = Pca9685.condivisa(cfg_pca)
        self.canale = int(canale)

    def impulso(self, us):
        self.pca.imposta(self.canale, us)


class PwmSw:
    def __init__(self, gpio):
        self.gpio = gpio
        if GPIO is not None:
            lgpio.gpio_claim_output(GPIO, gpio, 0)

    def impulso(self, us):
        if GPIO is None:
            return
        if us > 0:
            lgpio.tx_servo(GPIO, self.gpio, int(us), 50)
            return
        try:
            lgpio.tx_servo(GPIO, self.gpio, 0)
        except Exception:  # noqa: BLE001
            pass
        lgpio.gpio_write(GPIO, self.gpio, 0)


class Servo:
    def __init__(self, nome, cfg, angolo_iniziale, cfg_pca=None):
        self.nome, self.cfg = nome, cfg
        if cfg["tipo"] == "pca":
            self.uscita = PwmPca(cfg_pca or CONFIG_DEFAULT["pca9685"], cfg["canale"])
        elif cfg["tipo"] == "hw":
            self.uscita = PwmHw(cfg["canale"])
        else:
            self.uscita = PwmSw(cfg["gpio"])
        self.attuale = float(angolo_iniziale)
        self.obiettivo = float(angolo_iniziale)
        self.attivo = False
        self.prova = None          # raw angle during calibration
        self.fermo_da = time.time()

    def limita(self, a):
        return max(self.cfg["min"], min(self.cfg["max"], float(a)))

    def _us_grezzo(self, s):
        s = max(0.0, min(180.0, float(s)))
        return self.cfg["imp_min"] + s / 180.0 * (self.cfg["imp_max"] - self.cfg["imp_min"])

    def angolo_servo(self, angolo):
        c = self.cfg
        return c["zero_servo"] + c["segno"] * (angolo - c["riferimento"])

    def passo(self, dt, fattore=1.0):
        if self.prova is not None:
            return False
        diff = self.obiettivo - self.attuale
        if abs(diff) > 0.05:
            delta = self.cfg["vel"] * fattore * dt
            self.attuale += max(-delta, min(delta, diff))
            self.uscita.impulso(self._us_grezzo(self.angolo_servo(self.attuale)))
            self.attivo = True
            self.fermo_da = time.time()
            return True
        if self.attivo and self.cfg.get("rilascia_dopo") and time.time() - self.fermo_da > 0.6:
            self.uscita.impulso(0)
            self.attivo = False
        return False

    def tieni(self):
        self.prova = None
        self.uscita.impulso(self._us_grezzo(self.angolo_servo(self.attuale)))
        self.attivo = True
        self.fermo_da = time.time()

    def grezzo(self, gradi):
        self.prova = float(gradi)
        self.uscita.impulso(self._us_grezzo(gradi))
        self.attivo = True

    def ferma(self):
        self.obiettivo = self.attuale

    def rilascia(self):
        self.prova = None
        self.uscita.impulso(0)
        self.attivo = False


class Base:
    def __init__(self, cfg, passi_iniziali, azzerata):
        self.cfg = cfg
        self.passi = int(passi_iniziali)
        self.obiettivo = self.passi
        self.azzerata = azzerata
        self.fase = 0
        self.interrompi = False
        self.fattore = 1.0
        if GPIO is not None:
            for p in cfg["pin"]:
                lgpio.gpio_claim_output(GPIO, p, 0)
            lgpio.gpio_claim_input(GPIO, cfg["gpio_hall"], lgpio.SET_PULL_UP)

    @property
    def passi_grado(self):
        return self.cfg["passi_giro_motore"] * self.cfg["riduzione"] / 360.0

    @property
    def angolo(self):
        return self.passi / self.passi_grado

    def imposta(self, angolo):
        a = max(self.cfg["min"], min(self.cfg["max"], float(angolo)))
        self.obiettivo = int(round(a * self.passi_grado))

    def _bobine(self, valori):
        if GPIO is None:
            return
        for p, v in zip(self.cfg["pin"], valori):
            lgpio.gpio_write(GPIO, p, v)

    def _un_passo(self, verso):
        self.fase = (self.fase + verso * self.cfg["segno"]) % 8
        self._bobine(PASSI[self.fase])
        self.passi += verso
        time.sleep(self.cfg["ritardo_passo"] / max(0.1, self.fattore))

    def spegni(self):
        self._bobine((0, 0, 0, 0))

    def hall(self):
        if GPIO is None:
            return False
        return lgpio.gpio_read(GPIO, self.cfg["gpio_hall"]) == self.cfg["hall_attivo"]

    def esegui(self):
        self.interrompi = False
        while self.passi != self.obiettivo and not self.interrompi:
            self._un_passo(1 if self.obiettivo > self.passi else -1)
        self.obiettivo = self.passi
        self.spegni()

    def home(self):
        self.interrompi = False
        if GPIO is None:
            self.passi = self.obiettivo = 0
            self.azzerata = True
            return True
        limite = int(self.cfg["ricerca_max"] * self.passi_grado)
        n = 0
        while self.hall() and n < limite and not self.interrompi:
            self._un_passo(1)
            n += 1
        n = 0
        while not self.hall() and n < limite and not self.interrompi:
            self._un_passo(-1)
            n += 1
        self.spegni()
        if not self.hall():
            log("HOME FAILED: Hall sensor never triggered")
            self.obiettivo = self.passi
            return False
        self.passi = self.obiettivo = int(round(self.cfg["angolo_hall"] * self.passi_grado))
        self.azzerata = True
        log("Base home completed")
        return True


class Luce:
    def __init__(self, cfg):
        self.cfg = cfg
        self.livello = 0
        self.colore = "ffffff"
        self.spi = None
        try:
            import spidev
            self.spi = spidev.SpiDev()
            self.spi.open(cfg["spi_bus"], cfg["spi_dev"])
            self.spi.max_speed_hz = 2_400_000
            self.spi.mode = 0
        except Exception as e:  # noqa: BLE001
            log(f"WARNING: SPI not available ({e}) - simulated light")
            self.spi = None

    @staticmethod
    def _codifica(dati):
        bits = []
        for byte in dati:
            for i in range(7, -1, -1):
                bits.extend((1, 1, 0) if byte >> i & 1 else (1, 0, 0))
        out = bytearray()
        for i in range(0, len(bits), 8):
            v = 0
            for b in bits[i:i + 8]:
                v = (v << 1) | b
            out.append(v)
        return bytes(100) + bytes(out) + bytes(100)

    def imposta(self, livello, colore=None):
        self.livello = max(0, min(100, int(float(livello))))
        if colore:
            self.colore = colore.lstrip("#")[:6].ljust(6, "0")
        scala = self.livello / 100.0 * self.cfg["livello_max"] / 100.0
        r, g, b = (int(int(self.colore[i:i + 2], 16) * scala) for i in (0, 2, 4))
        mappa = {"R": r, "G": g, "B": b}
        pixel = [mappa[c] for c in self.cfg["ordine"]]
        if self.spi:
            self.spi.writebytes2(self._codifica(pixel * int(self.cfg["led"])))


class Braccio:
    def __init__(self):
        self.cfg = unisci(CONFIG_DEFAULT, carica_json(F_CONFIG, {}))
        salva_json(F_CONFIG, self.cfg)
        stato = carica_json(F_STATO, {})
        self.lock = threading.RLock()
        self.servi = {n: Servo(n, c, stato.get(n, c["partenza"]), self.cfg["pca9685"])
                      for n, c in self.cfg["servo"].items()}
        self.base = Base(self.cfg["base"], stato.get("base_passi", 0), stato.get("base_azzerata", False))
        self.luce = Luce(self.cfg["luce"])
        self.in_moto = threading.Event()
        self.base_occupata = threading.Event()
        self.jog_scadenze = {}            # joint name -> time after which the jog stops
        self.base.fattore = self.fattore
        threading.Thread(target=self._ciclo_servi, daemon=True).start()
        threading.Thread(target=self._ciclo_base, daemon=True).start()
        self.luce.imposta(0)

    def _ciclo_servi(self):
        t0 = time.time()
        while True:
            time.sleep(0.02)
            t = time.time()
            dt, t0 = t - t0, t
            with self.lock:
                for nome, scad in list(self.jog_scadenze.items()):
                    if t > scad:
                        self._ferma_giunto(nome)
                f = self.fattore
                mossi = [s.passo(dt, f) for s in self.servi.values()]
            if any(mossi):
                self.in_moto.set()
            elif self.in_moto.is_set():
                self.in_moto.clear()
                self._salva_stato()

    def _ciclo_base(self):
        while True:
            time.sleep(0.02)
            if self.base.obiettivo != self.base.passi:
                self.base_occupata.set()
                self.base.esegui()
                self._salva_stato()
                self.base_occupata.clear()

    def _salva_stato(self):
        with self.lock:
            dati = {n: round(s.attuale, 2) for n, s in self.servi.items()}
            dati["base_passi"] = self.base.passi
            dati["base_azzerata"] = self.base.azzerata
        salva_json(F_STATO, dati)

    def stato(self):
        with self.lock:
            return {
                "giunti": {n: round(s.attuale, 1) for n, s in self.servi.items()},
                "obiettivi": {n: round(s.obiettivo, 1) for n, s in self.servi.items()},
                "attivi": {n: s.attivo for n, s in self.servi.items()},
                "base": round(self.base.angolo, 1),
                "base_obiettivo": round(self.base.obiettivo / self.base.passi_grado, 1),
                "base_azzerata": self.base.azzerata,
                "hall": self.base.hall(),
                "in_movimento": self.in_moto.is_set() or self.base_occupata.is_set(),
                "luce": {"livello": self.luce.livello, "colore": self.luce.colore},
                "limiti": {**{n: [s.cfg["min"], s.cfg["max"]] for n, s in self.servi.items()},
                           "base": [self.base.cfg["min"], self.base.cfg["max"]]},
                "simulazione": GPIO is None,
                "interfaccia": self.cfg["interfaccia"],
                "camera": self.cfg["camera"],
                "jog": list(self.jog_scadenze),
            }

    def muovi(self, valori):
        with self.lock:
            for n, v in valori.items():
                if n == "base":
                    if not self.base.azzerata:
                        raise ValueError("base not zeroed: press Home")
                    self.base.imposta(v)
                elif n in self.servi:
                    s = self.servi[n]
                    if not s.attivo or s.prova is not None:
                        s.tieni()
                    s.obiettivo = s.limita(v)

    def attendi(self, timeout=30):
        t = time.time() + timeout
        time.sleep(0.05)
        while time.time() < t:
            with self.lock:
                fermi = all(abs(s.obiettivo - s.attuale) <= 0.05 for s in self.servi.values())
            if fermi and not self.base_occupata.is_set() and self.base.obiettivo == self.base.passi:
                return True
            time.sleep(0.05)
        return False

    # ---- speed, flipping, press-and-hold movement
    @property
    def fattore(self):
        return max(5, min(100, float(self.cfg["interfaccia"]["velocita"]))) / 100.0

    def impostazioni(self, q):
        ui = self.cfg["interfaccia"]
        if "velocita" in q:
            ui["velocita"] = max(5, min(100, int(float(q["velocita"]))))
        for k in ("flip_h", "flip_v"):
            if k in q:
                ui[k] = str(q[k]).lower() in ("1", "true", "si", "on")
        self.base.fattore = self.fattore
        salva_json(F_CONFIG, self.cfg)
        return ui

    def jog(self, nome, verso):
        """Moves the joint towards its limit as long as confirmations arrive (every < JOG_TIMEOUT)."""
        verso = 1 if float(verso) > 0 else -1
        with self.lock:
            if nome == "base":
                if not self.base.azzerata:
                    raise ValueError("base not zeroed: press Home")
                lim = self.base.cfg["max"] if verso > 0 else self.base.cfg["min"]
                self.base.imposta(lim)
            elif nome in self.servi:
                s = self.servi[nome]
                if not s.attivo or s.prova is not None:
                    s.tieni()
                s.obiettivo = s.cfg["max"] if verso > 0 else s.cfg["min"]
            else:
                raise KeyError(nome)
            self.jog_scadenze[nome] = time.time() + JOG_TIMEOUT

    def _ferma_giunto(self, nome):
        self.jog_scadenze.pop(nome, None)
        if nome == "base":
            self.base.interrompi = True
            self.base.obiettivo = self.base.passi
        elif nome in self.servi:
            self.servi[nome].ferma()

    def ferma(self, nome):
        with self.lock:
            self._ferma_giunto(nome)

    def stop(self):
        with self.lock:
            self.jog_scadenze.clear()
            for s in self.servi.values():
                s.ferma()
        self.base.interrompi = True

    def rilascia(self):
        self.stop()
        with self.lock:
            for s in self.servi.values():
                s.rilascia()
        self.base.spegni()

    def home(self):
        while self.base_occupata.is_set():
            time.sleep(0.05)
        self.base_occupata.set()
        try:
            ok = self.base.home()
        finally:
            self.base_occupata.clear()
        self._salva_stato()
        return ok

    def preset(self, nome):
        p = carica_json(F_PRESET, {})
        if nome not in p:
            raise KeyError(f"preset '{nome}' does not exist")
        valori = dict(p[nome])
        if not self.base.azzerata:
            valori.pop("base", None)
        self.muovi(valori)

    def salva_preset(self, nome):
        nome = nome.strip()[:40]
        if not nome:
            raise ValueError("empty name")
        p = carica_json(F_PRESET, {})
        with self.lock:
            p[nome] = {n: round(s.obiettivo, 1) for n, s in self.servi.items()}
            p[nome]["base"] = round(self.base.obiettivo / self.base.passi_grado, 1)
        salva_json(F_PRESET, p)
        return p[nome]

    def elimina_preset(self, nome):
        p = carica_json(F_PRESET, {})
        p.pop(nome, None)
        salva_json(F_PRESET, p)

    def aggiorna_config(self, nuova):
        with self.lock:
            for nome, valori in nuova.get("servo", {}).items():
                if nome in self.cfg["servo"]:
                    for k in MODIFICABILI["servo"]:
                        if k in valori:
                            self.cfg["servo"][nome][k] = valori[k]
            for sez in ("base", "luce"):
                for k in MODIFICABILI[sez]:
                    if k in nuova.get(sez, {}):
                        self.cfg[sez][k] = nuova[sez][k]
            for s in self.servi.values():
                s.obiettivo = s.limita(s.obiettivo)
            salva_json(F_CONFIG, self.cfg)
        self.luce.imposta(self.luce.livello)
        return self.cfg

    # ---- camera (CamUI keeps ownership of the sensor)
    def _camui_post(self, percorso, dati=None, timeout=30):
        req = urllib.request.Request(self.cfg["camui"] + percorso, json.dumps(dati or {}).encode(),
                                     {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.load(r)

    def imposta_live(self, indice):
        indice = int(indice)
        if indice not in [x[0] for x in self.cfg["camera"]["live"]]:
            raise ValueError("video resolution not supported")
        self._camui_post("/update_setting", {"camera_num": 0, "id": "LiveFeedResolution", "value": indice})
        self.cfg["camera"]["live_indice"] = indice
        salva_json(F_CONFIG, self.cfg)
        return self.cfg["camera"]

    def imposta_foto(self, q):
        c = self.cfg["camera"]
        if "ris" in q:
            w, h = (int(v) for v in str(q["ris"]).lower().split("x"))
            if [w, h] not in c["foto"]:
                raise ValueError("photo resolution not supported")
            c["foto_ris"] = [w, h]
        if "hq" in q:
            c["foto_hq"] = str(q["hq"]).lower() in ("1", "true", "si", "on")
        salva_json(F_CONFIG, self.cfg)
        return c

    def _jpeg_sensore(self, hq):
        """Full-sensor photo (CamUI capture_still, ~2 s video pause) or a frame of the video."""
        if hq:
            r = self._camui_post("/capture_still_0", timeout=40)
            if not r.get("success"):
                raise RuntimeError("CamUI: " + str(r.get("message")))
            base = os.path.join(self.cfg["camera"]["galleria_camui"], r["image"])
            with open(base + ".jpg", "rb") as f:
                dati = f.read()
            for est in (".jpg", ".dng"):   # leaves no duplicates in the CamUI gallery
                try:
                    os.remove(base + est)
                except OSError:
                    pass
            return dati
        with urllib.request.urlopen(self.cfg["camui"] + "/snapshot_0", timeout=20) as r:
            return r.read()

    def foto(self, zoom=1.0, cx=0.5, cy=0.5, hq=None, ris=None):
        """Takes the shot, then applies digital zoom (crop centred on cx, cy in sensor coordinates),
        flipping and output resolution."""
        c, ui = self.cfg["camera"], self.cfg["interfaccia"]
        hq = c["foto_hq"] if hq is None else hq
        w_out, h_out = ris or c["foto_ris"]
        jpg = self._jpeg_sensore(hq)
        import io
        from PIL import Image
        im = Image.open(io.BytesIO(jpg))
        W, H = im.size
        z = max(1.0, min(8.0, float(zoom)))
        if z > 1.001:
            w, h = W / z, H / z
            x0 = min(max(float(cx) * W - w / 2, 0), W - w)
            y0 = min(max(float(cy) * H - h / 2, 0), H - h)
            im = im.crop((int(x0), int(y0), int(x0 + w), int(y0 + h)))
        if ui["flip_h"]:
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if ui["flip_v"]:
            im = im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        if im.size != (w_out, h_out):
            im = im.resize((w_out, h_out), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        im.save(out, "JPEG", quality=92)
        return out.getvalue()

    def applica_live_avvio(self):
        """At startup brings CamUI back to the chosen video resolution (CamUI may start later)."""
        def lavoro():
            for _ in range(30):
                try:
                    self.imposta_live(self.cfg["camera"]["live_indice"])
                    log(f"CamUI video set (index {self.cfg['camera']['live_indice']})")
                    return
                except Exception:  # noqa: BLE001
                    time.sleep(5)
            log("WARNING: CamUI not reachable, video resolution not applied")
        threading.Thread(target=lavoro, daemon=True).start()


BRACCIO = None


# ------------------------------------------------------------------ video recording
CARTELLA_VIDEO = os.path.join(DATI, "video")
RTSP_VIDEO = os.environ.get("BRACCIO_RTSP", "rtsp://127.0.0.1:8554/braccio")


class Registratore:
    """Records the go2rtc stream to MP4 (H.264) by copying it without re-encoding: almost no CPU."""

    def __init__(self):
        os.makedirs(CARTELLA_VIDEO, exist_ok=True)
        self.proc = None
        self.file = None
        self.inizio = 0.0
        self.lock = threading.Lock()

    def attiva(self):
        return self.proc is not None and self.proc.poll() is None

    def avvia(self, max_sec=600):
        with self.lock:
            if self.attiva():
                return self.stato()
            max_sec = max(1, min(int(float(max_sec)), 3600))
            nome = time.strftime("braccio_%Y%m%d_%H%M%S.mp4")
            self.file = os.path.join(CARTELLA_VIDEO, nome)
            cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-rtsp_transport", "tcp", "-i", RTSP_VIDEO,
                   "-t", str(max_sec), "-c", "copy", "-movflags", "+faststart", "-y", self.file]
            self.proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                         stderr=subprocess.PIPE)
            self.inizio = time.time()
            log(f"recording started: {nome} (max {max_sec} s)")
        # go2rtc starts the conversion only when needed: wait until the first frames really arrive
        limite = time.time() + 15
        while time.time() < limite and self.attiva():
            if os.path.exists(self.file) and os.path.getsize(self.file) > 100_000:
                break
            time.sleep(0.3)
        if not self.attiva():
            err = self.proc.stderr.read().decode(errors="ignore").strip()[-300:]
            raise RuntimeError("recording did not start: " + (err or "go2rtc stream not reachable"))
        self.inizio = time.time()
        return self.stato()

    def ferma(self):
        with self.lock:
            if self.attiva():
                try:
                    self.proc.stdin.write(b"q")
                    self.proc.stdin.flush()
                    self.proc.wait(timeout=15)
                except Exception:  # noqa: BLE001
                    self.proc.terminate()
                log(f"recording stopped: {os.path.basename(self.file)}")
        return self.stato()

    def stato(self):
        return {"attiva": self.attiva(), "file": os.path.basename(self.file) if self.file else None,
                "secondi": round(time.time() - self.inizio) if self.attiva() else 0}

    def elenco(self):
        out = []
        for n in sorted(os.listdir(CARTELLA_VIDEO), reverse=True):
            if n.endswith(".mp4"):
                out.append({"nome": n, "mb": round(os.path.getsize(os.path.join(CARTELLA_VIDEO, n)) / 1048576, 1)})
        return out

    def percorso(self, nome):
        f = os.path.realpath(os.path.join(CARTELLA_VIDEO, os.path.basename(nome)))
        if not f.startswith(os.path.realpath(CARTELLA_VIDEO) + os.sep) or not os.path.isfile(f):
            raise KeyError("video not found")
        return f

    def elimina(self, nome):
        f = self.percorso(nome)
        if self.attiva() and self.file and os.path.basename(f) == os.path.basename(self.file):
            raise ValueError("recording in progress on this file")
        os.remove(f)
        log(f"video deleted: {os.path.basename(f)}")
        return self.elenco()


REG = None


class Gestore(BaseHTTPRequestHandler):
    server_version = "BraccioWeb/2.0"

    def log_message(self, fmt, *args):
        riga = str(args[0]) if args else ""
        if "/api/stato" not in riga and "/api/jog" not in riga:
            log("HTTP " + fmt % args)

    def _invia(self, corpo, tipo, codice=200, cache=False):
        self.send_response(codice)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(corpo)))
        if not cache:
            self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(corpo)

    def _file(self, f, tipo, scarica=False):
        self.send_response(200)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(os.path.getsize(f)))
        if scarica:
            self.send_header("Content-Disposition", f'attachment; filename="{os.path.basename(f)}"')
        self.end_headers()
        with open(f, "rb") as fh:
            while True:
                blocco = fh.read(1 << 20)
                if not blocco:
                    break
                self.wfile.write(blocco)

    def _json(self, dati, codice=200):
        self._invia(json.dumps(dati, ensure_ascii=False).encode(), "application/json; charset=utf-8", codice)

    def _statico(self, percorso):
        rel = "index.html" if percorso in ("/", "") else percorso.lstrip("/")
        f = os.path.realpath(os.path.join(CARTELLA_UI, rel))
        if not f.startswith(os.path.realpath(CARTELLA_UI)) or not os.path.isfile(f):
            return self._json({"errore": "not found"}, 404)
        tipo = mimetypes.guess_type(f)[0] or "application/octet-stream"
        with open(f, "rb") as fh:
            self._invia(fh.read(), tipo + ("; charset=utf-8" if tipo.startswith("text/") else ""))
        return None

    def do_POST(self):  # noqa: N802
        u = urlparse(self.path)
        try:
            n = int(self.headers.get("Content-Length", 0))
            dati = json.loads(self.rfile.read(n) or b"{}")
            if u.path == "/api/config":
                return self._json(BRACCIO.aggiorna_config(dati))
            return self._json({"errore": "unknown path"}, 404)
        except (ValueError, KeyError) as e:
            return self._json({"errore": str(e)}, 400)

    def do_GET(self):  # noqa: N802
        u = urlparse(self.path)
        q = {k: v[-1] for k, v in parse_qs(u.query).items()}
        b = BRACCIO
        if not u.path.startswith("/api/"):
            return self._statico(u.path)
        try:
            p = u.path[4:]
            if p == "/stato":
                return self._json(b.stato())
            if p == "/muovi":
                b.muovi({k: float(v) for k, v in q.items() if k in list(b.servi) + ["base"]})
                if q.get("attendi") == "1":
                    b.attendi()
                return self._json(b.stato())
            if p == "/stop":
                b.stop()
                return self._json(b.stato())
            if p == "/jog":
                b.jog(q["nome"], q.get("verso", 1))
                return self._json({"jog": q["nome"]})
            if p == "/ferma":
                b.ferma(q["nome"])
                return self._json({"fermo": q["nome"]})
            if p == "/impostazioni":
                return self._json(b.impostazioni(q))
            if p == "/rilascia":
                b.rilascia()
                return self._json(b.stato())
            if p == "/home":
                return self._json({"home": b.home(), **b.stato()})
            if p == "/luce":
                b.luce.imposta(q.get("livello", b.luce.livello), q.get("colore"))
                return self._json(b.stato()["luce"])
            if p == "/preset/elenco":
                return self._json(carica_json(F_PRESET, {}))
            if p == "/preset":
                b.preset(q["nome"])
                if q.get("attendi") == "1":
                    b.attendi()
                return self._json(b.stato())
            if p == "/preset/salva":
                return self._json({"salvato": q["nome"], "valori": b.salva_preset(q["nome"])})
            if p == "/preset/elimina":
                b.elimina_preset(q["nome"])
                return self._json(carica_json(F_PRESET, {}))
            if p == "/config":
                return self._json({"config": b.cfg, "modificabili": MODIFICABILI})
            if p == "/prova":
                s = b.servi[q["nome"]]
                with b.lock:
                    s.grezzo(float(q["gradi"]))
                return self._json({"nome": q["nome"], "gradi": float(q["gradi"])})
            if p == "/registra":
                azione = q.get("azione", "stato")
                if azione == "avvia":
                    return self._json(REG.avvia(q.get("max", 600)))
                if azione == "ferma":
                    return self._json(REG.ferma())
                return self._json(REG.stato())
            if p == "/video/elenco":
                return self._json(REG.elenco())
            if p == "/video/elimina":
                return self._json(REG.elimina(q["nome"]))
            if p == "/video/file":
                return self._file(REG.percorso(q["nome"]), "video/mp4", q.get("scarica") == "1")
            if p == "/camera/live":
                return self._json(b.imposta_live(q["indice"]))
            if p == "/camera/foto":
                return self._json(b.imposta_foto(q))
            if p == "/scatta":
                if "luce" in q:
                    b.luce.imposta(q["luce"], q.get("colore"))
                b.attendi()
                time.sleep(float(q.get("attesa", 0.4)))
                ris = [int(v) for v in q["ris"].lower().split("x")] if "ris" in q else None
                hq = (q["hq"] in ("1", "true")) if "hq" in q else None
                jpg = b.foto(q.get("zoom", 1), q.get("cx", 0.5), q.get("cy", 0.5), hq, ris)
                return self._invia(jpg, "image/jpeg")
            return self._json({"errore": "unknown path"}, 404)
        except (KeyError, ValueError) as e:
            return self._json({"errore": str(e)}, 400)
        except Exception as e:  # noqa: BLE001
            log(f"ERROR {u.path}: {e!r}")
            return self._json({"errore": repr(e)}, 500)


def main():
    global BRACCIO, REG
    BRACCIO = Braccio()
    REG = Registratore()
    BRACCIO.applica_live_avvio()
    porta = int(BRACCIO.cfg["porta"])
    log(f"Arm web server ready on http://0.0.0.0:{porta}/")
    ThreadingHTTPServer(("0.0.0.0", porta), Gestore).serve_forever()


if __name__ == "__main__":
    main()

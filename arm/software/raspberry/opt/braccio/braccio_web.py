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
  /api/stop                         stops everything at once (servos stay in position, base and HOME stop)
  /api/rilascia                     switches off the servo pulses (position then treated as "unknown")
  /api/home                         base zeroing with the Hall sensor (409 if already running)
  /api/luce?livello=0..100&colore=ffffff   light level and colour (colour: 6 hex digits, otherwise error 400)
  /api/preset/elenco | /api/preset?nome= | /api/preset/salva?nome= | /api/preset/elimina?nome=   list / go / save / delete
  /api/scatta?luce=&attesa=0.4&ris=WxH   JPEG photo (waits for the end of the movement; ris limited to the sensor)
  /api/config                       GET: configuration   POST (JSON): change and save (values checked)
  /api/prova?nome=spalla&gradi=90   "raw" servo angle 0..180 for calibration, within limits and box zone
/api/registra?azione=avvia|ferma|stato&max=600   MP4 video recording start|stop|status (go2rtc stream)
/api/video/elenco | /api/video/file?nome=&scarica=1 | /api/video/elimina?nome=   list / file (download) / delete
/api/sistema?azione=riavvia|spegni   reboot or shut down the Raspberry

Idle mode (optional "riposo" section in config.json, minutes without commands):
  luce_min (default 5) light off, casa_min (default 60) arm to the "casa" preset,
  spegni_min (default 120) the Raspberry shuts down. Not while recording.

Safety (last modified 15/11/2026):
  - STOP really stops the base, the lift for the box zone and HOME;
  - box zone checked at every step of the base, even if the destination changes while it turns;
  - released servos = unknown position: before entering the zone they are powered again and lifted;
  - a single owner of the base motor (lock): HOME and movements never overlap;
  - servo thread protected by try/except; /api/config validated; light colour validated;
  - unreadable config.json: the last valid backup (config.json.bak) is used, never the factory values;
  - stato.json saved also while the base turns (every 2 s), atomic write with fsync;
  - /api/prova within limits and zone; /api/scatta with resolution limited to the sensor.
"""
import copy
import glob
import json
import math
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
F_CONFIG_BAK = F_CONFIG + ".bak"
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
    # PCA9685 servo board (address 64 = 0x40; 50 Hz for servos)
    "pca9685": {"bus": 1, "indirizzo": 64, "freq": 50},
    "luce": {"spi_bus": 0, "spi_dev": 0, "led": 24, "livello_max": 60, "ordine": "GRB"},
    # global speed in % (scales the servo vel and the base step rate) and image flip
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
JOG_TIMEOUT = 0.7      # s: a press-and-hold movement stops by itself if the browser stops confirming it
ASSESTAMENTO = 1.5     # s: after powering again a servo with unknown position, time to reach it
SALVA_OGNI = 2.0       # s: while the base turns stato.json is saved at this rate
# fields that can be changed from the interface (the others stay only in the file)
MODIFICABILI = {
    "servo": ["min", "max", "riferimento", "zero_servo", "segno", "vel", "imp_min", "imp_max", "rilascia_dopo"],
    "base": ["ritardo_passo", "min", "max", "segno", "hall_attivo", "angolo_hall", "ricerca_max"],
    "luce": ["led", "livello_max", "ordine"],
}
# validation rules: ("num", minimum, maximum) | ("int", minimum, maximum) | ("segno",) | ("bool",) | ("ordine",)
REGOLE = {
    "servo": {"min": ("num", -180, 180), "max": ("num", -180, 180), "riferimento": ("num", -180, 180),
              "zero_servo": ("num", 0, 180), "segno": ("segno",), "vel": ("num", 1, 360),
              "imp_min": ("num", 300, 2700), "imp_max": ("num", 300, 2700), "rilascia_dopo": ("bool",),
              "partenza": ("num", -180, 180)},
    "base": {"ritardo_passo": ("num", 0.001, 0.02), "min": ("num", -360, 360), "max": ("num", -360, 360),
             "segno": ("segno",), "hall_attivo": ("int", 0, 1), "angolo_hall": ("num", -360, 360),
             "ricerca_max": ("num", 10, 400)},
    "luce": {"led": ("int", 1, 300), "livello_max": ("num", 0, 100), "ordine": ("ordine",)},
    "interfaccia": {"velocita": ("num", 0, 100)},
}

PASSI = [(1, 0, 0, 0), (1, 1, 0, 0), (0, 1, 0, 0), (0, 1, 1, 0),
         (0, 0, 1, 0), (0, 0, 1, 1), (0, 0, 0, 1), (1, 0, 0, 1)]


class Occupato(Exception):
    """Command refused because the resource is busy (e.g. HOME already running) -> HTTP 409."""


def carica_json(percorso, default):
    try:
        with open(percorso, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


_LOCK_JSON = threading.Lock()


def salva_json(percorso, dati):
    """Atomic write: temporary file + fsync + os.replace (never a half-written file)."""
    testo = json.dumps(dati, indent=2, ensure_ascii=False)
    with _LOCK_JSON:
        tmp = f"{percorso}.{os.getpid()}.{threading.get_ident()}.tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(testo)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, percorso)
        finally:
            if os.path.exists(tmp):
                try:
                    os.remove(tmp)
                except OSError:
                    pass


def unisci(base, extra):
    out = dict(base)
    for k, v in extra.items():
        out[k] = unisci(out[k], v) if isinstance(v, dict) and isinstance(out.get(k), dict) else v
    return out


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


# ------------------------------------------------------------------ configuration validation
def valore_valido(nome, v, regola):
    """Checks and converts a value according to the rule; ValueError with a clear message if it is not valid."""
    tipo = regola[0]
    if tipo == "bool":
        if isinstance(v, bool):
            return v
        if isinstance(v, (int, float)) and v in (0, 1):
            return bool(v)
        if isinstance(v, str) and v.strip().lower() in ("true", "false", "1", "0", "si", "no"):
            return v.strip().lower() in ("true", "1", "si")
        raise ValueError(f"{nome}: expected true/false, received {v!r}")
    if tipo == "ordine":
        if not isinstance(v, str) or sorted(v.strip().upper()) != ["B", "G", "R"]:
            raise ValueError(f"{nome}: expected an order of the letters R, G, B (e.g. GRB), received {v!r}")
        return v.strip().upper()
    if isinstance(v, bool) or v is None:
        raise ValueError(f"{nome}: expected a number, received {v!r}")
    try:
        x = float(v)
    except (TypeError, ValueError):
        raise ValueError(f"{nome}: expected a number, received {v!r}") from None
    if not math.isfinite(x):
        raise ValueError(f"{nome}: invalid number ({v!r})")
    if tipo == "segno":
        if x not in (1.0, -1.0):
            raise ValueError(f"{nome}: must be 1 or -1, received {v!r}")
        return int(x)
    lo, hi = regola[1], regola[2]
    if not lo <= x <= hi:
        raise ValueError(f"{nome}: {v!r} outside the allowed range {lo}..{hi}")
    if tipo == "int":
        if not x.is_integer():
            raise ValueError(f"{nome}: expected an integer, received {v!r}")
        return int(x)
    return int(x) if x.is_integer() and nome.split(".")[-1] != "ritardo_passo" else x


def controlla_coerenza(cfg):
    for nome, c in cfg["servo"].items():
        if not c["min"] < c["max"]:
            raise ValueError(f"servo.{nome}: min ({c['min']}) must be lower than max ({c['max']})")
        if not c["imp_min"] < c["imp_max"]:
            raise ValueError(f"servo.{nome}: imp_min ({c['imp_min']}) must be lower than imp_max ({c['imp_max']})")
    b = cfg["base"]
    if not b["min"] < b["max"]:
        raise ValueError(f"base: min ({b['min']}) must be lower than max ({b['max']})")


def controlla_config(cfg):
    """Full check of a configuration read from file (at startup)."""
    if not isinstance(cfg.get("servo"), dict) or not cfg["servo"]:
        raise ValueError("'servo' section missing")
    for nome, c in cfg["servo"].items():
        if not isinstance(c, dict):
            raise ValueError(f"servo.{nome}: not an object")
        for k, regola in REGOLE["servo"].items():
            valore_valido(f"servo.{nome}.{k}", c.get(k), regola)
    for sez in ("base", "luce", "interfaccia"):
        if not isinstance(cfg.get(sez), dict):
            raise ValueError(f"invalid '{sez}' section")
        for k, regola in REGOLE[sez].items():
            valore_valido(f"{sez}.{k}", cfg[sez].get(k), regola)
    z = cfg.get("zona_scatola")
    if z is not None:
        if not isinstance(z, dict) or "base" not in z:
            raise ValueError("invalid zona_scatola")
        for k, v in z.items():
            valore_valido(f"zona_scatola.{k}", v, ("num", -360, 360))
    controlla_coerenza(cfg)


def carica_config():
    """Reads config.json. If it is unreadable or invalid it is NOT overwritten with the factory values:
    it is renamed to .corrotto_<date> and the last valid backup is used (config.json.bak, then config.json.bak_*).
    If there is no valid configuration the service does not start (better stopped than with wrong limits)."""
    altri = sorted(glob.glob(F_CONFIG + ".bak_*"), key=os.path.getmtime, reverse=True)
    candidati = [F_CONFIG, F_CONFIG_BAK] + altri
    esiste_qualcosa = False
    for f in candidati:
        if not os.path.exists(f):
            continue
        esiste_qualcosa = True
        try:
            with open(f, encoding="utf-8") as fh:
                dati = json.load(fh)
            if not isinstance(dati, dict):
                raise ValueError("the file does not contain a JSON object")
            cfg = unisci(CONFIG_DEFAULT, dati)
            controlla_config(cfg)
        except (OSError, ValueError, TypeError, KeyError) as e:
            log(f"WARNING: configuration {os.path.basename(f)} not valid: {e}")
            if f == F_CONFIG:
                dest = F_CONFIG + time.strftime(".corrotto_%Y%m%d_%H%M%S")
                try:
                    os.replace(F_CONFIG, dest)
                    log(f"WARNING: config.json renamed to {os.path.basename(dest)} (not overwritten)")
                except OSError as e2:
                    log(f"WARNING: cannot rename config.json: {e2}")
            continue
        if f != F_CONFIG:
            log(f"WARNING: config.json RESTORED from the backup {os.path.basename(f)} - check the calibration")
        return cfg
    if esiste_qualcosa:
        log("SERIOUS ERROR: no valid configuration (config.json and backups unreadable). Service stopped.")
        raise SystemExit(2)
    log("config.json missing: first installation, using the factory values")
    return copy.deepcopy(CONFIG_DEFAULT)


def scrivi_se_diverso(percorso, dati):
    """Writes the file only if the content changes (at startup an identical config.json is not rewritten)."""
    nuovo = json.dumps(dati, indent=2, ensure_ascii=False)
    try:
        with open(percorso, encoding="utf-8") as f:
            if f.read() == nuovo:
                return False
    except OSError:
        pass
    salva_json(percorso, dati)
    return True


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
    """PCA9685 board (16 PWM channels, I2C): generates the servo pulses in hardware, without jitter."""
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
        self.fermo_da = time.time()
        self.voluto = None             # user target suspended while the box zone keeps the arm up
        # without pulses the real position is unknown (the shoulder drops by gravity): NOT safe for the zone
        self.sconosciuto = True
        self.assestato_da = 0.0        # time from which the position after tieni() is considered reached
        self.bloccato_stop = False     # after STOP the zone does not move it until a new command arrives

    def limita(self, a):
        return max(self.cfg["min"], min(self.cfg["max"], float(a)))

    def _us_grezzo(self, s):
        s = max(0.0, min(180.0, float(s)))
        return self.cfg["imp_min"] + s / 180.0 * (self.cfg["imp_max"] - self.cfg["imp_min"])

    def angolo_servo(self, angolo):
        c = self.cfg
        return c["zero_servo"] + c["segno"] * (angolo - c["riferimento"])

    def angolo_logico(self, gradi_servo):
        c = self.cfg
        return c["riferimento"] + (float(gradi_servo) - c["zero_servo"]) / c["segno"]

    def passo(self, dt, fattore=1.0):
        if self.sconosciuto:
            return False                # does not drive a servo with unknown position: tieni() first
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
            self.sconosciuto = True
        return False

    def tieni(self):
        """Powers the servo again at the last known angle."""
        if self.sconosciuto or not self.attivo:
            self.assestato_da = time.time() + ASSESTAMENTO
        self.sconosciuto = False
        self.uscita.impulso(self._us_grezzo(self.angolo_servo(self.attuale)))
        self.attivo = True
        self.fermo_da = time.time()

    def ferma(self):
        self.obiettivo = self.attuale

    def rilascia(self):
        self.uscita.impulso(0)
        self.attivo = False
        self.sconosciuto = True
        self.voluto = None
        self.obiettivo = self.attuale


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
        """New target: it is a new command, so it cancels a previous STOP."""
        a = max(self.cfg["min"], min(self.cfg["max"], float(angolo)))
        self.interrompi = False
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
        """True only if the sensor sees the magnet in 5 readings in a row (filters noise)."""
        if GPIO is None:
            return False
        for i in range(5):
            if lgpio.gpio_read(GPIO, self.cfg["gpio_hall"]) != self.cfg["hall_attivo"]:
                return False
            if i < 4:
                time.sleep(0.0005)
        return True

    def esegui(self, guardia=None, periodico=None):
        """Moves towards the target (which can change during the movement).
        guardia(next_step) -> False = stop here (box zone with the arm low).
        periodico() is called every SALVA_OGNI seconds (saving stato.json).
        Does NOT reset 'interrompi': only imposta() does it when a new command arrives.
        Returns 'arrivato' (reached), 'interrotto' (stopped) or 'zona' (zone)."""
        esito = "arrivato"
        ultimo = time.time()
        try:
            while self.passi != self.obiettivo:
                if self.interrompi:
                    esito = "interrotto"
                    break
                verso = 1 if self.obiettivo > self.passi else -1
                if guardia is not None and not guardia(self.passi + verso):
                    esito = "zona"
                    break
                self._un_passo(verso)
                if periodico is not None and time.time() - ultimo >= SALVA_OGNI:
                    ultimo = time.time()
                    periodico()
        finally:
            self.spegni()
        if esito == "interrotto":
            self.obiettivo = self.passi
        return esito

    def _hall_maggioranza(self, letture=20, minimo=15):
        if GPIO is None:
            return False
        att = 0
        for _ in range(letture):
            if lgpio.gpio_read(GPIO, self.cfg["gpio_hall"]) == self.cfg["hall_attivo"]:
                att += 1
            time.sleep(0.002)
        return att >= minimo

    def home(self):
        """Magnet search. Must be called only by Braccio.home() (which owns the motor and
        handles 'interrompi'): a STOP during the search makes it fail."""
        if GPIO is None:
            self.passi = self.obiettivo = 0
            self.azzerata = True
            return True
        pg = self.passi_grado
        lim = int(self.cfg["ricerca_max"] * pg)       # never beyond +-ricerca_max degrees from the estimated magnet
        extra = int(40 * pg)                           # the magnet field does not exceed 40 degrees
        self.obiettivo = self.passi                    # the base loop must not bring it back

        def passo(verso):
            if self.interrompi or not (-lim <= self.passi + verso <= lim):
                return False
            self._un_passo(verso)
            self.obiettivo = self.passi
            return True

        def cerca(verso):
            """Turns until it sees the magnet. True if found."""
            while True:
                if self.hall():
                    return True
                if not passo(verso):
                    return False

        def attraversa(verso):
            """Moves on until the magnet disappears for 15 steps in a row; returns the last step with the magnet."""
            ultimo, fuori, fatti = self.passi, 0, 0
            while fuori < 15 and fatti < extra and passo(verso):
                fatti += 1
                if self.hall():
                    ultimo, fuori = self.passi, 0
                else:
                    fuori += 1
            return ultimo

        if self._hall_maggioranza():
            attraversa(-1)                             # already on the magnet: leaves on one side
            for _ in range(5):
                passo(-1)
            primo = 1
        else:
            primo = -1 if self.passi > 0 else 1        # first towards the estimated zero
        trovato, verso = False, primo
        bordo1 = bordo2 = self.passi
        if cerca(primo):
            trovato = True
        elif not self.interrompi and cerca(-primo):    # then the other side, always within +-lim
            trovato, verso = True, -primo
        if trovato and not self.interrompi:
            bordo1 = self.passi
            bordo2 = attraversa(verso)
            centro = (bordo1 + bordo2) // 2
            while self.passi != centro and passo(1 if centro > self.passi else -1):
                pass
            time.sleep(0.05)
        self.spegni()
        if self.interrompi:
            log("HOME STOPPED by STOP")
            self.obiettivo = self.passi
            return False
        if not trovato or not self._hall_maggioranza():
            log(f"HOME FAILED: magnet not found (found={trovato})")
            self.obiettivo = self.passi
            return False
        log(f"Base home: magnet width {abs(bordo2 - bordo1) / pg:.1f} degrees")
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

    @staticmethod
    def valida_colore(colore):
        c = str(colore).strip().lstrip("#").lower()
        if len(c) != 6 or any(ch not in "0123456789abcdef" for ch in c):
            raise ValueError(f"invalid colour {colore!r}: use 6 hex digits, e.g. ffffff")
        return c

    def imposta(self, livello, colore=None):
        """Validates level and colour first; if they are not valid, error and the light stays as it was."""
        try:
            liv = float(livello)
        except (TypeError, ValueError):
            raise ValueError(f"invalid light level: {livello!r}") from None
        if not math.isfinite(liv):
            raise ValueError(f"invalid light level: {livello!r}")
        liv = max(0, min(100, int(liv)))
        col = self.valida_colore(colore) if colore else self.colore
        self.livello, self.colore = liv, col
        scala = liv / 100.0 * self.cfg["livello_max"] / 100.0
        r, g, b = (int(int(col[i:i + 2], 16) * scala) for i in (0, 2, 4))
        mappa = {"R": r, "G": g, "B": b}
        pixel = [mappa[c] for c in self.cfg["ordine"]]
        if self.spi:
            self.spi.writebytes2(self._codifica(pixel * int(self.cfg["led"])))


class Braccio:
    def __init__(self):
        self.cfg = carica_config()
        if scrivi_se_diverso(F_CONFIG, self.cfg):
            log("config.json written (completed with the missing fields or restored)")
        scrivi_se_diverso(F_CONFIG_BAK, self.cfg)        # last valid backup
        stato = carica_json(F_STATO, {})
        if not isinstance(stato, dict):
            stato = {}
        self.lock = threading.RLock()
        self.servi = {n: Servo(n, c, stato.get(n, c["partenza"]), self.cfg["pca9685"])
                      for n, c in self.cfg["servo"].items()}
        self.base = Base(self.cfg["base"], stato.get("base_passi", 0), stato.get("base_azzerata", False))
        self.luce = Luce(self.cfg["luce"])
        self.in_moto = threading.Event()
        self.base_occupata = threading.Event()
        self.motore_base = threading.Lock()  # SINGLE owner of the stepper: base loop or HOME
        self.homing = False
        self.n_stop = 0                       # grows at every STOP: cancels the waits in progress
        self.jog_scadenze = {}                # joint name -> time after which the jog stops
        self._da_salvare = threading.Event()
        self.base.fattore = self.fattore
        self.ultimo_uso = time.time()
        self.riposo_luce_fatto = False
        self.riposo_casa_fatto = False
        threading.Thread(target=self._ciclo_servi, daemon=True).start()
        threading.Thread(target=self._ciclo_base, daemon=True).start()
        threading.Thread(target=self._ciclo_salvataggio, daemon=True).start()
        threading.Thread(target=self._ciclo_riposo, daemon=True).start()
        self.luce.imposta(0)

    # ---- electronics box zone (base near zero: arm up)
    def _zona(self):
        return self.cfg.get("zona_scatola") or {"base": 25, "spalla": 70, "gomito": 60}

    def _base_in_zona(self, verso_gradi=None):
        """True if the base is in the zone or its movement crosses it."""
        z = self._zona()["base"]
        pg = self.base.passi_grado
        a = self.base.passi / pg
        t = (self.base.obiettivo if verso_gradi is None else verso_gradi * pg) / pg
        return min(a, t) <= z and max(a, t) >= -z

    def _min_zona(self, nome):
        z = self._zona()
        if nome in z and nome != "base" and (self.homing or self._base_in_zona()):
            return float(z[nome])
        return None

    def _braccio_alto(self):
        """True only if shoulder and elbow are powered, in a known position and above the zone minimums."""
        z = self._zona()
        ora = time.time()
        for n in ("spalla", "gomito"):
            sv = self.servi.get(n)
            if sv is None or n not in z:
                continue
            if not sv.attivo or sv.sconosciuto or ora < sv.assestato_da or sv.attuale < float(z[n]) - 0.5:
                return False
        return True

    def _guardia_zona(self, prossimo):
        """Step-by-step check of the base: it does not enter the zone if the arm is not up."""
        zb = float(self._zona()["base"]) * self.base.passi_grado
        if -zb <= prossimo <= zb:
            return self._braccio_alto()
        return True

    def _alza_per_zona(self, annulla=None, timeout=15):
        """Powers again and lifts shoulder and elbow to the zone minimums, and waits until they get there.
        annulla() -> True stops the wait (STOP, HOME...)."""
        z = self._zona()
        with self.lock:
            for n in ("spalla", "gomito"):
                sv = self.servi.get(n)
                if sv is None or n not in z:
                    continue
                sv.bloccato_stop = False
                if not sv.attivo or sv.sconosciuto:
                    sv.tieni()                               # unknown position: powered first
                if sv.obiettivo < float(z[n]):
                    if sv.voluto is None:
                        sv.voluto = sv.obiettivo            # goes back there when the base leaves the zone
                    sv.obiettivo = float(z[n])
        fine = time.time() + timeout
        while time.time() < fine:
            if annulla is not None and annulla():
                log("Lift for the box zone cancelled")
                return False
            if self._braccio_alto():
                return True
            time.sleep(0.05)
        log("WARNING: shoulder/elbow not raised in time for the box zone")
        return False

    # ---- idle mode (light off after 5 min, "casa" position after 60 min without commands)
    def uso(self):
        self.ultimo_uso = time.time()
        self.riposo_luce_fatto = False
        self.riposo_casa_fatto = False

    def _ciclo_riposo(self):
        r = self.cfg.get("riposo") or {}
        min_luce = float(r.get("luce_min", 5))
        min_casa = float(r.get("casa_min", 60))
        min_spegni = float(r.get("spegni_min", 120))
        while True:
            time.sleep(10)
            try:
                if REG is not None and REG.attiva():
                    self.uso()                         # recording: not idle
                    continue
                fermo = time.time() - self.ultimo_uso
                if not self.riposo_luce_fatto and fermo >= min_luce * 60:
                    self.riposo_luce_fatto = True
                    if self.luce.livello > 0:
                        self.luce.imposta(0)
                        log(f"Idle: light off after {min_luce:g} minutes without commands")
                if not self.riposo_casa_fatto and fermo >= min_casa * 60:
                    self.riposo_casa_fatto = True
                    p = carica_json(F_PRESET, {}).get("casa")
                    if not p:
                        log("Idle: 'casa' position not found")
                        continue
                    if "base" in p and self.base.azzerata:
                        self.muovi({"base": p["base"]})    # base first, then shoulder, elbow and head
                        self.attendi(180)
                    self.preset("casa")
                    self.attendi(60)
                    log(f"Idle: arm in 'casa' position after {min_casa:g} minutes without commands")
                if fermo >= min_spegni * 60:
                    log(f"Idle: {min_spegni:g} minutes without commands, shutting down the Raspberry")
                    for azione in (self.stop, lambda: self.luce.imposta(0), self._salva_stato):
                        try:
                            azione()
                        except Exception as e:  # noqa: BLE001
                            log(f"WARNING: idle before shutdown: {e!r}")
                    time.sleep(2)
                    subprocess.Popen(["systemctl", "poweroff"])
                    return
            except Exception as e:  # noqa: BLE001
                log(f"WARNING: idle mode: {e!r}")

    def _ciclo_servi(self):
        t0 = time.time()
        ultimo_err, t_err = None, 0.0
        while True:
            time.sleep(0.02)
            try:
                t = time.time()
                dt, t0 = min(t - t0, 0.2), t
                with self.lock:
                    for nome, scad in list(self.jog_scadenze.items()):
                        if t > scad:
                            self._ferma_giunto(nome)
                    f = self.fattore
                    for nome, sv in self.servi.items():
                        m = self._min_zona(nome)
                        if m is not None:
                            if sv.attivo and not sv.sconosciuto and not sv.bloccato_stop and sv.obiettivo < m:
                                if sv.voluto is None:
                                    sv.voluto = sv.obiettivo          # remembers where it had to go
                                sv.obiettivo = m
                        elif sv.voluto is not None:
                            sv.obiettivo = sv.limita(sv.voluto)       # base out of the zone: back to the wanted position
                            sv.voluto = None
                    mossi = [s.passo(dt, f) for s in self.servi.values()]
                if any(mossi):
                    self.in_moto.set()
                elif self.in_moto.is_set():
                    self.in_moto.clear()
                    self._salva_stato()
            except Exception as e:  # noqa: BLE001
                msg = repr(e)
                if msg != ultimo_err or time.time() - t_err > 30:
                    log(f"ERROR servo loop (resuming): {msg}")
                    ultimo_err, t_err = msg, time.time()
                time.sleep(0.5)
                t0 = time.time()

    def _ciclo_base(self):
        while True:
            time.sleep(0.02)
            if self.base.obiettivo == self.base.passi:
                continue
            if not self.motore_base.acquire(blocking=False):
                continue                                   # the motor belongs to HOME: hands off
            try:
                self.base_occupata.set()
                self._muovi_base()
            except Exception as e:  # noqa: BLE001
                log(f"WARNING: base loop: {e!r}")
                self.base.spegni()
                self.base.obiettivo = self.base.passi
                time.sleep(0.5)
            finally:
                self.base_occupata.clear()
                self.motore_base.release()

    def _muovi_base(self):
        """Moves the base (motor already owned). The zone check is repeated step by step:
        if the destination changes halfway the base stops at the zone edge and lifts the arm first."""
        with self.lock:
            gen = self.n_stop

        def annullato():
            return self.n_stop != gen or self.base.interrompi or self.homing

        tentativi = 0
        try:
            while self.base.obiettivo != self.base.passi and not annullato():
                if self._base_in_zona() and not self._braccio_alto():
                    tentativi += 1
                    if tentativi > 3 or not self._alza_per_zona(annullato):
                        with self.lock:
                            self.base.obiettivo = self.base.passi    # cannot pass: movement cancelled
                        log("Base stopped: arm not raised for the box zone")
                        break
                esito = self.base.esegui(self._guardia_zona, self._da_salvare.set)
                if esito != "zona":
                    break
        finally:
            self._salva_stato()

    def _ciclo_salvataggio(self):
        """Saves requested while the base turns (outside the base thread: no pauses between steps)."""
        while True:
            self._da_salvare.wait()
            self._da_salvare.clear()
            try:
                self._salva_stato()
            except Exception as e:  # noqa: BLE001
                log(f"WARNING: saving state: {e!r}")
            time.sleep(0.5)

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
                "posizione_nota": {n: not s.sconosciuto for n, s in self.servi.items()},
                "base": round(self.base.angolo, 1),
                "base_obiettivo": round(self.base.obiettivo / self.base.passi_grado, 1),
                "base_azzerata": self.base.azzerata,
                "home_in_corso": self.homing,
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

    def _controlla_base(self):
        if self.homing:
            raise Occupato("HOME in progress: base busy")
        if not self.base.azzerata:
            raise ValueError("base not zeroed: press Home")

    def _comanda_servo(self, s):
        """Prepares a servo for a new user command."""
        if not s.attivo or s.sconosciuto:
            s.tieni()
        s.voluto = None
        s.bloccato_stop = False

    def muovi(self, valori):
        with self.lock:
            if "base" in valori:
                self._controlla_base()
            for n, v in valori.items():
                if n == "base":
                    self.base.imposta(v)
                elif n in self.servi:
                    s = self.servi[n]
                    self._comanda_servo(s)
                    s.obiettivo = s.limita(v)

    def attendi(self, timeout=30):
        t = time.time() + timeout
        time.sleep(0.05)
        while time.time() < t:
            with self.lock:
                fermi = all(abs(s.obiettivo - s.attuale) <= 0.05 for s in self.servi.values() if not s.sconosciuto)
            if fermi and not self.base_occupata.is_set() and self.base.obiettivo == self.base.passi:
                return True
            time.sleep(0.05)
        return False

    # ---- speed, flip, press-and-hold movement
    @property
    def fattore(self):
        return max(5, min(100, float(self.cfg["interfaccia"]["velocita"]))) / 100.0

    def _salva_config(self):
        with self.lock:
            cfg = copy.deepcopy(self.cfg)
        salva_json(F_CONFIG, cfg)
        salva_json(F_CONFIG_BAK, cfg)

    def impostazioni(self, q):
        with self.lock:
            ui = self.cfg["interfaccia"]
            if "velocita" in q:
                v = float(q["velocita"])
                if not math.isfinite(v):
                    raise ValueError("invalid speed")
                ui["velocita"] = max(5, min(100, int(v)))
            for k in ("flip_h", "flip_v"):
                if k in q:
                    ui[k] = str(q[k]).lower() in ("1", "true", "si", "on")
            self.base.fattore = self.fattore
        self._salva_config()
        return ui

    def jog(self, nome, verso):
        """Moves the joint towards its limit while confirmations keep arriving (every < JOG_TIMEOUT)."""
        verso = 1 if float(verso) > 0 else -1
        with self.lock:
            if nome == "base":
                self._controlla_base()
                lim = self.base.cfg["max"] if verso > 0 else self.base.cfg["min"]
                self.base.imposta(lim)
            elif nome in self.servi:
                s = self.servi[nome]
                self._comanda_servo(s)
                s.obiettivo = s.cfg["max"] if verso > 0 else s.cfg["min"]
            else:
                raise KeyError(nome)
            self.jog_scadenze[nome] = time.time() + JOG_TIMEOUT

    def _ferma_giunto(self, nome):
        self.jog_scadenze.pop(nome, None)
        if nome == "base":
            if self.homing:
                return                      # releasing a button does not stop HOME (only STOP does)
            self.base.interrompi = True
            self.base.obiettivo = self.base.passi
        elif nome in self.servi:
            self.servi[nome].ferma()

    def ferma(self, nome):
        with self.lock:
            self._ferma_giunto(nome)

    def stop(self):
        """Stops everything at once: base (even while waiting for the lift), servos, lift for the zone and HOME."""
        with self.lock:
            self.n_stop += 1
            self.jog_scadenze.clear()
            for s in self.servi.values():
                s.ferma()
                s.voluto = None
                s.bloccato_stop = True
            self.base.interrompi = True
            self.base.obiettivo = self.base.passi
        log("STOP")

    def rilascia(self):
        self.stop()
        with self.lock:
            for s in self.servi.values():
                s.rilascia()
        if not self.motore_base.locked():
            self.base.spegni()
        log("Servos released: shoulder/elbow position treated as unknown")

    def home(self):
        """HOME with exclusive ownership of the base motor. If already running it is refused (409)."""
        with self.lock:
            if self.homing:
                raise Occupato("HOME already in progress")
            self.homing = True
            gen = self.n_stop
            self.jog_scadenze.pop("base", None)
            self.base.interrompi = True                    # stops a normal movement, if any
            self.base.obiettivo = self.base.passi
        preso, ok = False, False
        try:
            preso = self.motore_base.acquire(timeout=10)
            if not preso:
                raise Occupato("base motor busy, try again")
            self.base_occupata.set()
            with self.lock:
                if self.n_stop != gen:
                    log("HOME cancelled by STOP")
                    return False
                self.base.interrompi = False
                self.base.obiettivo = self.base.passi
                self.base.azzerata = False                 # during HOME the base cannot be used
            self._salva_stato()
            log("Base HOME started")
            if not self._alza_per_zona(lambda: self.n_stop != gen):
                log("HOME cancelled: arm not raised (STOP or timeout)")
                return False
            ok = self.base.home()
            return ok
        finally:
            if preso:
                self.base.spegni()
                self.base_occupata.clear()
                self.motore_base.release()
            with self.lock:
                self.homing = False
            self._salva_stato()

    def preset(self, nome):
        p = carica_json(F_PRESET, {})
        if nome not in p:
            raise KeyError(f"preset '{nome}' does not exist")
        valori = dict(p[nome])
        if not self.base.azzerata or self.homing:
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
        """Validates ALL the fields on a copy; only if everything is valid it changes the configuration in use."""
        if not isinstance(nuova, dict):
            raise ValueError("configuration: expected a JSON object")
        with self.lock:
            if self.homing:
                raise Occupato("HOME in progress: save the calibration again afterwards")
            cand = copy.deepcopy(self.cfg)
            servo_n = nuova.get("servo", {})
            if not isinstance(servo_n, dict):
                raise ValueError("servo: expected an object")
            for nome, valori in servo_n.items():
                if nome not in cand["servo"]:
                    raise ValueError(f"unknown servo: {nome}")
                if not isinstance(valori, dict):
                    raise ValueError(f"servo.{nome}: expected an object")
                for k in MODIFICABILI["servo"]:
                    if k in valori:
                        cand["servo"][nome][k] = valore_valido(f"servo.{nome}.{k}", valori[k], REGOLE["servo"][k])
            for sez in ("base", "luce"):
                parte = nuova.get(sez, {})
                if not isinstance(parte, dict):
                    raise ValueError(f"{sez}: expected an object")
                for k in MODIFICABILI[sez]:
                    if k in parte:
                        cand[sez][k] = valore_valido(f"{sez}.{k}", parte[k], REGOLE[sez][k])
            controlla_coerenza(cand)
            # all valid: applied to the same dictionaries used by Servo, Base and Luce
            segno_cambiato = cand["base"]["segno"] != self.cfg["base"]["segno"]
            for nome in self.cfg["servo"]:
                self.cfg["servo"][nome].update(cand["servo"][nome])
            for sez in ("base", "luce"):
                self.cfg[sez].update(cand[sez])
            for s in self.servi.values():
                s.obiettivo = s.limita(s.obiettivo)
                if s.voluto is not None:
                    s.voluto = s.limita(s.voluto)
            pg = self.base.passi_grado
            lo, hi = int(round(self.base.cfg["min"] * pg)), int(round(self.base.cfg["max"] * pg))
            if not lo <= self.base.obiettivo <= hi:
                self.base.obiettivo = max(lo, min(hi, self.base.obiettivo))   # limits the movement in progress again
            if segno_cambiato:
                self.base.interrompi = True
                self.base.obiettivo = self.base.passi
                if self.base.azzerata:
                    self.base.azzerata = False
                    log("Base direction changed: base must be zeroed again (Home)")
        self._salva_config()
        self._salva_stato()
        try:
            self.luce.imposta(self.luce.livello)
        except Exception as e:  # noqa: BLE001
            log(f"WARNING: light after calibration: {e!r}")
        return self.cfg

    def prova(self, nome, gradi):
        """Calibration: 'raw' servo angle 0..180, but always within min/max and box zone (with ramp)."""
        s = self.servi[nome]
        g = float(gradi)
        if not math.isfinite(g):
            raise ValueError("invalid degrees")
        g = max(0.0, min(180.0, g))
        with self.lock:
            ang = s.limita(s.angolo_logico(g))
            m = self._min_zona(nome)
            if m is not None:
                ang = max(ang, m)
            self._comanda_servo(s)
            s.obiettivo = ang
            applicato = s.angolo_servo(ang)
        limitato = abs(applicato - g) > 0.05
        if limitato:
            log(f"Test {nome}: {g:g} servo degrees limited to {applicato:.1f} (limits/zone)")
        return {"nome": nome, "gradi": round(applicato, 1), "richiesti": g,
                "angolo": round(ang, 1), "limitato": limitato}

    # ---- camera (CamUI keeps ownership of the sensor)
    def _camui_post(self, percorso, dati=None, timeout=30):
        req = urllib.request.Request(self.cfg["camui"] + percorso, json.dumps(dati or {}).encode(),
                                     {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.load(r)

    def imposta_live(self, indice):
        indice = int(indice)
        if indice not in [x[0] for x in self.cfg["camera"]["live"]]:
            raise ValueError("video resolution not available")
        self._camui_post("/update_setting", {"camera_num": 0, "id": "LiveFeedResolution", "value": indice})
        if self.cfg["camera"]["live_indice"] != indice:
            self.cfg["camera"]["live_indice"] = indice
            self._salva_config()
        return self.cfg["camera"]

    def imposta_foto(self, q):
        c = self.cfg["camera"]
        if "ris" in q:
            w, h = (int(v) for v in str(q["ris"]).lower().split("x"))
            if [w, h] not in c["foto"]:
                raise ValueError("photo resolution not available")
            c["foto_ris"] = [w, h]
        if "hq" in q:
            c["foto_hq"] = str(q["hq"]).lower() in ("1", "true", "si", "on")
        self._salva_config()
        return c

    def limita_ris(self, ris):
        """Output resolution: never beyond the sensor (the largest in camera.foto), aspect ratio kept."""
        w, h = (int(v) for v in ris)
        if w < 16 or h < 16:
            raise ValueError("resolution too small (minimum 16x16)")
        foto = self.cfg["camera"]["foto"]
        w_max = max(int(x[0]) for x in foto)
        h_max = max(int(x[1]) for x in foto)
        k = min(1.0, w_max / w, h_max / h)
        if k < 1.0:
            w2, h2 = max(16, int(w * k)), max(16, int(h * k))
            log(f"Photo: resolution {w}x{h} limited to {w2}x{h2} (sensor {w_max}x{h_max})")
            w, h = w2, h2
        return [w, h]

    def _jpeg_sensore(self, hq):
        """Full-sensor photo (CamUI capture_still, ~2 s video pause) or a frame of the video."""
        if hq:
            r = self._camui_post("/capture_still_0", timeout=40)
            if not r.get("success"):
                raise RuntimeError("CamUI: " + str(r.get("message")))
            base = os.path.join(self.cfg["camera"]["galleria_camui"], r["image"])
            with open(base + ".jpg", "rb") as f:
                dati = f.read()
            for est in (".jpg", ".dng"):   # does not leave duplicates in the CamUI gallery
                try:
                    os.remove(base + est)
                except OSError:
                    pass
            return dati
        with urllib.request.urlopen(self.cfg["camui"] + "/snapshot_0", timeout=20) as r:
            return r.read()

    def foto(self, zoom=1.0, cx=0.5, cy=0.5, hq=None, ris=None):
        """Takes the photo, then applies digital zoom (crop centred on cx, cy in sensor coordinates),
        flip and output resolution."""
        c, ui = self.cfg["camera"], self.cfg["interfaccia"]
        hq = c["foto_hq"] if hq is None else hq
        w_out, h_out = self.limita_ris(ris or c["foto_ris"])
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
            raise RuntimeError("recording not started: " + (err or "go2rtc stream not reachable"))
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
    server_version = "BraccioWeb/2.1"

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
        BRACCIO.uso()
        u = urlparse(self.path)
        try:
            n = int(self.headers.get("Content-Length", 0))
            dati = json.loads(self.rfile.read(n) or b"{}")
            if u.path == "/api/config":
                return self._json(BRACCIO.aggiorna_config(dati))
            return self._json({"errore": "unknown path"}, 404)
        except Occupato as e:
            return self._json({"errore": str(e)}, 409)
        except (ValueError, KeyError, TypeError) as e:
            return self._json({"errore": str(e)}, 400)
        except Exception as e:  # noqa: BLE001
            log(f"ERROR POST {u.path}: {e!r}")
            return self._json({"errore": repr(e)}, 500)

    def do_GET(self):  # noqa: N802
        u = urlparse(self.path)
        q = {k: v[-1] for k, v in parse_qs(u.query).items()}
        b = BRACCIO
        if not u.path.startswith("/api/"):
            return self._statico(u.path)
        try:
            p = u.path[4:]
            if not (p == "/stato" or p.startswith("/video") or
                    (p == "/registra" and q.get("azione", "stato") == "stato")):
                b.uso()
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
                return self._json(b.prova(q["nome"], q["gradi"]))
            if p == "/sistema":
                azione = q.get("azione", "")
                if azione not in ("riavvia", "spegni"):
                    raise ValueError("azione: riavvia (reboot) or spegni (shut down)")
                if REG is not None:
                    REG.ferma()
                b.stop()
                cmd = ["systemctl", "reboot" if azione == "riavvia" else "poweroff"]
                threading.Timer(1.5, lambda: subprocess.Popen(cmd)).start()
                log(f"SYSTEM: {azione} requested from the web page")
                return self._json({"sistema": azione})
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
                ris = None
                if "ris" in q:
                    parti = q["ris"].lower().split("x")
                    if len(parti) != 2:
                        raise ValueError("ris: format WIDTHxHEIGHT, e.g. 1280x960")
                    ris = b.limita_ris(parti)
                if "luce" in q:
                    b.luce.imposta(q["luce"], q.get("colore"))
                b.attendi()
                time.sleep(float(q.get("attesa", 0.4)))
                hq = (q["hq"] in ("1", "true")) if "hq" in q else None
                jpg = b.foto(q.get("zoom", 1), q.get("cx", 0.5), q.get("cy", 0.5), hq, ris)
                return self._invia(jpg, "image/jpeg")
            return self._json({"errore": "unknown path"}, 404)
        except Occupato as e:
            return self._json({"errore": str(e)}, 409)
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

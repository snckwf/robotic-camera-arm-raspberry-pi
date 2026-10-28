#!/usr/bin/env python3
"""
mcp_braccio.py - MCP server (stdio) that lets Claude use the bench camera arm.

It runs on the Raspberry Pi; Claude Desktop starts it over SSH:
    ssh -i <key> YOUR_USER@PI_IP python3 /home/YOUR_USER/braccio_mcp/mcp_braccio.py
It talks to braccio_web.py (http://127.0.0.1:8091) and, if installed, to display_lcd.py (port 8092).
No external dependencies (Python 3 standard library only).

Safety: the joints listed in mcp.json (same folder) -> "bloccati" (locked) are not moved
(e.g. spalla/shoulder and gomito/elbow during calibration). Tool and joint names are kept in Italian.
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = os.environ.get("BRACCIO_API", "http://127.0.0.1:8091")
LCD = os.environ.get("BRACCIO_LCD", "http://127.0.0.1:8092")
F_CONF = os.environ.get("BRACCIO_MCP_CONF", os.path.join(os.path.dirname(os.path.abspath(__file__)), "mcp.json"))
VERSIONE = "1.0"
GIUNTI = ["base", "spalla", "gomito", "tilt", "rotazione"]


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def bloccati():
    try:
        with open(F_CONF, encoding="utf-8") as f:
            return list(json.load(f).get("bloccati", []))
    except (OSError, ValueError):
        return ["spalla", "gomito"]


def http(url, timeout=40, binario=False):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            dati = r.read()
            return dati if binario else json.loads(dati)
    except urllib.error.HTTPError as e:
        try:
            msg = json.loads(e.read()).get("errore", str(e))
        except Exception:  # noqa: BLE001
            msg = str(e)
        raise RuntimeError(msg) from None
    except urllib.error.URLError as e:
        raise RuntimeError(f"service not reachable ({url.split('/api')[0]}): {e.reason}") from None


def api(percorso, **par):
    q = urllib.parse.urlencode({k: v for k, v in par.items() if v is not None})
    return http(f"{API}{percorso}" + (f"?{q}" if q else ""))


def riassunto(s):
    g = s["giunti"]
    righe = [
        f"spalla (shoulder) {g['spalla']:.1f}, gomito (elbow) {g['gomito']:.1f}, tilt {g['tilt']:.1f}, rotazione (rotation) {g['rotazione']:.1f}",
        f"base {s['base']:.1f}" + ("" if s["base_azzerata"] else " (NOT zeroed: use home_base before moving it)"),
        f"limits: " + ", ".join(f"{n} {a}..{b}" for n, (a, b) in s["limiti"].items()),
        f"light {s['luce']['livello']}% #{s['luce']['colore']}, moving: {'yes' if s['in_movimento'] else 'no'}",
        f"joints locked for safety: {', '.join(bloccati()) or 'none'}",
    ]
    return "\n".join(righe)


# ------------------------------------------------------------------ tools
def t_stato(_):
    return riassunto(api("/api/stato"))


def _controlla(valori):
    b = [n for n in valori if n in bloccati()]
    if b:
        raise RuntimeError(f"joints locked for safety: {', '.join(b)} (unlock them in {F_CONF})")


def t_muovi(a):
    valori = {n: float(a[n]) for n in GIUNTI if a.get(n) is not None}
    if not valori:
        raise RuntimeError("specify at least one joint")
    _controlla(valori)
    s = api("/api/muovi", attendi=1 if a.get("attendi", True) else None, **valori)
    return "Done.\n" + riassunto(s)


def t_sposta(a):
    s = api("/api/stato")
    att = dict(s["giunti"], base=s["base"])
    valori = {n: att[n] + float(a[n]) for n in GIUNTI if a.get(n) not in (None, 0)}
    if not valori:
        raise RuntimeError("specify at least one non-zero offset")
    _controlla(valori)
    s = api("/api/muovi", attendi=1, **valori)
    return "Done.\n" + riassunto(s)


def t_stop(_):
    return "Stopped.\n" + riassunto(api("/api/stop"))


def t_rilascia(_):
    return "Servos released (no torque).\n" + riassunto(api("/api/rilascia"))


def t_home(_):
    if "base" in bloccati():
        raise RuntimeError("base locked for safety")
    r = http(f"{API}/api/home", timeout=180)
    return ("Base home completed.\n" if r.get("home") else "HOME FAILED: Hall sensor never triggered.\n") + riassunto(r)


def t_luce(a):
    r = api("/api/luce", livello=int(a.get("livello", 60)), colore=a.get("colore"))
    return f"Light {r['livello']}% #{r['colore']}"


def t_foto(a):
    larg = int(a.get("larghezza", 1280))
    larg = max(320, min(3280, larg))
    alt = round(larg * 3 / 4)
    par = {"ris": f"{larg}x{alt}", "zoom": a.get("zoom", 1), "cx": a.get("cx"), "cy": a.get("cy"),
           "hq": 1 if a.get("alta_qualita") else 0, "luce": a.get("luce")}
    q = urllib.parse.urlencode({k: v for k, v in par.items() if v is not None})
    jpg = http(f"{API}/api/scatta?{q}", timeout=60, binario=True)
    return [{"type": "image", "data": base64.b64encode(jpg).decode(), "mimeType": "image/jpeg"},
            {"type": "text", "text": f"Photo {larg}x{alt}, zoom {par['zoom']}, {len(jpg) // 1024} KB"}]


def t_preset_elenco(_):
    p = api("/api/preset/elenco")
    return "\n".join(f"{n}: " + ", ".join(f"{k} {v}" for k, v in v.items()) for n, v in p.items()) or "no saved positions"


def t_preset_vai(a):
    nome = a["nome"]
    p = api("/api/preset/elenco")
    if nome not in p:
        raise RuntimeError(f"position '{nome}' does not exist")
    _controlla([n for n in p[nome] if n in GIUNTI])
    return f"Reached '{nome}'.\n" + riassunto(api("/api/preset", nome=nome, attendi=1))


def t_preset_salva(a):
    r = api("/api/preset/salva", nome=a["nome"])
    return f"Saved '{r['salvato']}': {r['valori']}"


def t_display(a):
    try:
        r = http(f"{LCD}/lcd?" + urllib.parse.urlencode({"r1": a.get("riga1", ""), "r2": a.get("riga2", ""),
                                                         "sec": a.get("secondi", 15)}), timeout=5)
    except RuntimeError:
        return "LCD display not installed (optional) or display-lcd service stopped."
    if r.get("lcd") is False:
        return "The display service answers but the LCD is not connected (I2C 0x27/0x3F not found)."
    return f"Display: [{r['r1']}] [{r['r2']}]"


def t_registra(a):
    az = a.get("azione", "stato")
    if az not in ("avvia", "ferma", "stato"):
        raise RuntimeError("azione: avvia (start), ferma (stop) or stato (status)")
    s = api("/api/registra", azione=az, max=a.get("max_secondi") if az == "avvia" else None)
    if s["attiva"]:
        return f"Recording in progress: {s['file']} ({s['secondi']} s)"
    return (f"No recording in progress. Last file: {s['file'] or '-'} "
            "(the videos are opened and downloaded from the arm web page)")


NUM = {"type": "number"}
STRUMENTI = {
    "stato": (t_stato, "Current position of the camera arm joints, limits, light and locked joints.", {}),
    "muovi": (t_muovi, "Moves the joints to absolute angles (degrees). Joints: base, spalla (shoulder), gomito (elbow), tilt, rotazione (rotation); give only the ones to move. "
              "Respect the limits given by 'stato'. The base must be zeroed (home_base) before moving it.",
              {"base": NUM, "spalla": NUM, "gomito": NUM, "tilt": NUM, "rotazione": NUM,
               "attendi": {"type": "boolean", "description": "waits for the end of the movement (default yes)"}}),
    "sposta": (t_sposta, "Moves the joints by a relative angle (degrees, + or -) from the current position.",
               {"base": NUM, "spalla": NUM, "gomito": NUM, "tilt": NUM, "rotazione": NUM}),
    "stop": (t_stop, "Stops all movements at once (the servos stay in position).", {}),
    "rilascia": (t_rilascia, "Removes torque from the servos (the arm can be moved by hand).", {}),
    "home_base": (t_home, "Zeroes the rotating base with the Hall sensor (required before moving the base).", {}),
    "luce": (t_luce, "Turns the LED ring around the camera on/off (livello = level, colore = colour).",
             {"livello": {"type": "integer", "minimum": 0, "maximum": 100},
              "colore": {"type": "string", "description": "hexadecimal RRGGBB, e.g. ffffff"}}),
    "foto": (t_foto, "Takes a photo with the arm camera (waits for movements to end) and returns it. "
             "zoom 1..8 crops around cx, cy (0..1 on the sensor).",
             {"zoom": NUM, "cx": NUM, "cy": NUM,
              "larghezza": {"type": "integer", "description": "width in pixels, 320..3280 (default 1280, 4:3 format)"},
              "alta_qualita": {"type": "boolean", "description": "full-sensor shot, sharper but ~2 s"},
              "luce": {"type": "integer", "description": "turns the light on at this level before the shot"}}),
    "posizioni": (t_preset_elenco, "List of saved positions.", {}),
    "vai_posizione": (t_preset_vai, "Moves the arm to a saved position.", {"nome": {"type": "string"}}),
    "salva_posizione": (t_preset_salva, "Saves the current position with a name.", {"nome": {"type": "string"}}),
    "scrivi_display": (t_display, "Writes two lines (max 16 characters, no accents) on the arm LCD display (if installed) for a few seconds.",
                       {"riga1": {"type": "string"}, "riga2": {"type": "string"}, "secondi": NUM}),
    "registra": (t_registra, "Records an MP4 video of what the camera frames: azione avvia (start), ferma (stop) or stato (status).",
                 {"azione": {"type": "string", "enum": ["avvia", "ferma", "stato"]},
                  "max_secondi": {"type": "integer", "description": "maximum duration in seconds (default 600, max 3600)"}}),
}
OBBLIGATORI = {"vai_posizione": ["nome"], "salva_posizione": ["nome"], "registra": ["azione"]}


def elenco_strumenti():
    out = []
    for nome, (_, desc, props) in STRUMENTI.items():
        out.append({"name": nome, "description": desc,
                    "inputSchema": {"type": "object", "properties": props, "required": OBBLIGATORI.get(nome, [])}})
    return out


# ------------------------------------------------------------------ MCP protocol (JSON-RPC over stdin/stdout)
def rispondi(id_, risultato=None, errore=None):
    msg = {"jsonrpc": "2.0", "id": id_}
    if errore:
        msg["error"] = errore
    else:
        msg["result"] = risultato
    sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def gestisci(m):
    metodo, id_ = m.get("method"), m.get("id")
    if id_ is None:                       # notifications: no reply
        return
    if metodo == "initialize":
        ver = m.get("params", {}).get("protocolVersion", "2024-11-05")
        rispondi(id_, {"protocolVersion": ver, "capabilities": {"tools": {}},
                       "serverInfo": {"name": "braccio-telecamera", "version": VERSIONE},
                       "instructions": "Motorised arm with camera on the workbench. Use 'stato' before moving, "
                                       "'foto' to look. Move in small steps and check with a photo."})
    elif metodo == "ping":
        rispondi(id_, {})
    elif metodo == "tools/list":
        rispondi(id_, {"tools": elenco_strumenti()})
    elif metodo == "tools/call":
        p = m.get("params", {})
        nome, arg = p.get("name"), p.get("arguments") or {}
        if nome not in STRUMENTI:
            return rispondi(id_, errore={"code": -32602, "message": f"unknown tool: {nome}"})
        try:
            r = STRUMENTI[nome][0](arg)
            contenuto = r if isinstance(r, list) else [{"type": "text", "text": str(r)}]
            rispondi(id_, {"content": contenuto, "isError": False})
        except Exception as e:  # noqa: BLE001
            rispondi(id_, {"content": [{"type": "text", "text": f"Error: {e}"}], "isError": True})
    else:
        rispondi(id_, errore={"code": -32601, "message": f"method not supported: {metodo}"})


def main():
    log(f"mcp_braccio {VERSIONE} ready (API {API})")
    for riga in sys.stdin:
        riga = riga.strip()
        if not riga:
            continue
        try:
            m = json.loads(riga)
        except ValueError:
            continue
        for x in (m if isinstance(m, list) else [m]):
            gestisci(x)


if __name__ == "__main__":
    main()

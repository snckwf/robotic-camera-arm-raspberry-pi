#!/usr/bin/env python3
"""
mcp_braccio.py - Server MCP (stdio) per far usare a Claude il braccio telecamera del banco.

Gira sul Raspberry Pi; Claude Desktop lo avvia via SSH:
    ssh -i <chiave> TUO_UTENTE@IP_DEL_PI python3 /home/TUO_UTENTE/braccio_mcp/mcp_braccio.py
Parla con braccio_web.py (http://127.0.0.1:8091) e, se installato, con display_lcd.py (porta 8092).
Nessuna dipendenza esterna (solo libreria standard Python 3).

Sicurezza: i giunti elencati in mcp.json (stessa cartella) -> "bloccati" non vengono mossi
(es. spalla e gomito durante la taratura).
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
        raise RuntimeError(f"servizio non raggiungibile ({url.split('/api')[0]}): {e.reason}") from None


def api(percorso, **par):
    q = urllib.parse.urlencode({k: v for k, v in par.items() if v is not None})
    return http(f"{API}{percorso}" + (f"?{q}" if q else ""))


def riassunto(s):
    g = s["giunti"]
    righe = [
        f"spalla {g['spalla']:.1f}, gomito {g['gomito']:.1f}, tilt {g['tilt']:.1f}, rotazione {g['rotazione']:.1f}",
        f"base {s['base']:.1f}" + ("" if s["base_azzerata"] else " (NON azzerata: usa home_base prima di muoverla)"),
        f"limiti: " + ", ".join(f"{n} {a}..{b}" for n, (a, b) in s["limiti"].items()),
        f"luce {s['luce']['livello']}% #{s['luce']['colore']}, in movimento: {'si' if s['in_movimento'] else 'no'}",
        f"giunti bloccati per sicurezza: {', '.join(bloccati()) or 'nessuno'}",
    ]
    return "\n".join(righe)


# ------------------------------------------------------------------ strumenti
def t_stato(_):
    return riassunto(api("/api/stato"))


def _controlla(valori):
    b = [n for n in valori if n in bloccati()]
    if b:
        raise RuntimeError(f"giunti bloccati per sicurezza: {', '.join(b)} (si sbloccano in {F_CONF})")


def t_muovi(a):
    valori = {n: float(a[n]) for n in GIUNTI if a.get(n) is not None}
    if not valori:
        raise RuntimeError("indica almeno un giunto")
    _controlla(valori)
    s = api("/api/muovi", attendi=1 if a.get("attendi", True) else None, **valori)
    return "Fatto.\n" + riassunto(s)


def t_sposta(a):
    s = api("/api/stato")
    att = dict(s["giunti"], base=s["base"])
    valori = {n: att[n] + float(a[n]) for n in GIUNTI if a.get(n) not in (None, 0)}
    if not valori:
        raise RuntimeError("indica almeno uno spostamento diverso da zero")
    _controlla(valori)
    s = api("/api/muovi", attendi=1, **valori)
    return "Fatto.\n" + riassunto(s)


def t_stop(_):
    return "Fermato.\n" + riassunto(api("/api/stop"))


def t_rilascia(_):
    return "Servo rilasciati (senza forza).\n" + riassunto(api("/api/rilascia"))


def t_home(_):
    if "base" in bloccati():
        raise RuntimeError("base bloccata per sicurezza")
    r = http(f"{API}/api/home", timeout=180)
    return ("Home base completato.\n" if r.get("home") else "HOME FALLITO: sensore Hall mai attivato.\n") + riassunto(r)


def t_luce(a):
    r = api("/api/luce", livello=int(a.get("livello", 60)), colore=a.get("colore"))
    return f"Luce {r['livello']}% #{r['colore']}"


def t_foto(a):
    larg = int(a.get("larghezza", 1280))
    larg = max(320, min(3280, larg))
    alt = round(larg * 3 / 4)
    par = {"ris": f"{larg}x{alt}", "zoom": a.get("zoom", 1), "cx": a.get("cx"), "cy": a.get("cy"),
           "hq": 1 if a.get("alta_qualita") else 0, "luce": a.get("luce")}
    q = urllib.parse.urlencode({k: v for k, v in par.items() if v is not None})
    jpg = http(f"{API}/api/scatta?{q}", timeout=60, binario=True)
    return [{"type": "image", "data": base64.b64encode(jpg).decode(), "mimeType": "image/jpeg"},
            {"type": "text", "text": f"Foto {larg}x{alt}, zoom {par['zoom']}, {len(jpg) // 1024} KB"}]


def t_preset_elenco(_):
    p = api("/api/preset/elenco")
    return "\n".join(f"{n}: " + ", ".join(f"{k} {v}" for k, v in v.items()) for n, v in p.items()) or "nessuna posizione salvata"


def t_preset_vai(a):
    nome = a["nome"]
    p = api("/api/preset/elenco")
    if nome not in p:
        raise RuntimeError(f"posizione '{nome}' inesistente")
    _controlla([n for n in p[nome] if n in GIUNTI])
    return f"Raggiunta '{nome}'.\n" + riassunto(api("/api/preset", nome=nome, attendi=1))


def t_preset_salva(a):
    r = api("/api/preset/salva", nome=a["nome"])
    return f"Salvata '{r['salvato']}': {r['valori']}"


def t_display(a):
    try:
        r = http(f"{LCD}/lcd?" + urllib.parse.urlencode({"r1": a.get("riga1", ""), "r2": a.get("riga2", ""),
                                                         "sec": a.get("secondi", 15)}), timeout=5)
    except RuntimeError:
        return "Display LCD non installato (opzionale) o servizio display-lcd spento."
    if r.get("lcd") is False:
        return "Il servizio del display risponde ma l'LCD non e' collegato (I2C 0x27/0x3F non trovato)."
    return f"Display: [{r['r1']}] [{r['r2']}]"


def t_registra(a):
    az = a.get("azione", "stato")
    if az not in ("avvia", "ferma", "stato"):
        raise RuntimeError("azione: avvia, ferma o stato")
    s = api("/api/registra", azione=az, max=a.get("max_secondi") if az == "avvia" else None)
    if s["attiva"]:
        return f"Registrazione in corso: {s['file']} ({s['secondi']} s)"
    return (f"Nessuna registrazione in corso. Ultimo file: {s['file'] or '-'} "
            "(i video si aprono e si scaricano dalla pagina web del braccio)")


NUM = {"type": "number"}
STRUMENTI = {
    "stato": (t_stato, "Posizione attuale dei giunti del braccio telecamera, limiti, luce e giunti bloccati.", {}),
    "muovi": (t_muovi, "Porta i giunti ad angoli assoluti (gradi). Indicare solo i giunti da muovere. "
              "Rispettare i limiti dati da 'stato'. La base va azzerata (home_base) prima di muoverla.",
              {"base": NUM, "spalla": NUM, "gomito": NUM, "tilt": NUM, "rotazione": NUM,
               "attendi": {"type": "boolean", "description": "attende la fine del movimento (predefinito si)"}}),
    "sposta": (t_sposta, "Sposta i giunti di un angolo relativo (gradi, + o -) rispetto alla posizione attuale.",
               {"base": NUM, "spalla": NUM, "gomito": NUM, "tilt": NUM, "rotazione": NUM}),
    "stop": (t_stop, "Ferma subito tutti i movimenti (i servo restano in posizione).", {}),
    "rilascia": (t_rilascia, "Toglie la forza ai servo (il braccio si puo' muovere a mano).", {}),
    "home_base": (t_home, "Azzera la base rotante con il sensore Hall (necessario prima di muovere la base).", {}),
    "luce": (t_luce, "Accende/spegne l'anello LED attorno alla camera.",
             {"livello": {"type": "integer", "minimum": 0, "maximum": 100},
              "colore": {"type": "string", "description": "esadecimale RRGGBB, es. ffffff"}}),
    "foto": (t_foto, "Scatta una foto con la camera del braccio (attende la fine dei movimenti) e la restituisce. "
             "zoom 1..8 ritaglia attorno a cx, cy (0..1 sul sensore).",
             {"zoom": NUM, "cx": NUM, "cy": NUM,
              "larghezza": {"type": "integer", "description": "pixel, 320..3280 (predefinito 1280, formato 4:3)"},
              "alta_qualita": {"type": "boolean", "description": "scatto a sensore pieno, piu' nitido ma ~2 s"},
              "luce": {"type": "integer", "description": "accende la luce a questo livello prima dello scatto"}}),
    "posizioni": (t_preset_elenco, "Elenco delle posizioni salvate.", {}),
    "vai_posizione": (t_preset_vai, "Porta il braccio a una posizione salvata.", {"nome": {"type": "string"}}),
    "salva_posizione": (t_preset_salva, "Salva la posizione attuale con un nome.", {"nome": {"type": "string"}}),
    "scrivi_display": (t_display, "Scrive due righe (max 16 caratteri, senza accenti) sul display LCD del braccio (se installato) per qualche secondo.",
                       {"riga1": {"type": "string"}, "riga2": {"type": "string"}, "secondi": NUM}),
    "registra": (t_registra, "Registra un video MP4 di quello che inquadra la camera: azione avvia, ferma o stato.",
                 {"azione": {"type": "string", "enum": ["avvia", "ferma", "stato"]},
                  "max_secondi": {"type": "integer", "description": "durata massima (predefinito 600, max 3600)"}}),
}
OBBLIGATORI = {"vai_posizione": ["nome"], "salva_posizione": ["nome"], "registra": ["azione"]}


def elenco_strumenti():
    out = []
    for nome, (_, desc, props) in STRUMENTI.items():
        out.append({"name": nome, "description": desc,
                    "inputSchema": {"type": "object", "properties": props, "required": OBBLIGATORI.get(nome, [])}})
    return out


# ------------------------------------------------------------------ protocollo MCP (JSON-RPC su stdin/stdout)
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
    if id_ is None:                       # notifiche: nessuna risposta
        return
    if metodo == "initialize":
        ver = m.get("params", {}).get("protocolVersion", "2024-11-05")
        rispondi(id_, {"protocolVersion": ver, "capabilities": {"tools": {}},
                       "serverInfo": {"name": "braccio-telecamera", "version": VERSIONE},
                       "instructions": "Braccio motorizzato con camera sul banco di lavoro. Usa 'stato' prima di muovere, "
                                       "'foto' per guardare. Muovi a piccoli passi e controlla con una foto."})
    elif metodo == "ping":
        rispondi(id_, {})
    elif metodo == "tools/list":
        rispondi(id_, {"tools": elenco_strumenti()})
    elif metodo == "tools/call":
        p = m.get("params", {})
        nome, arg = p.get("name"), p.get("arguments") or {}
        if nome not in STRUMENTI:
            return rispondi(id_, errore={"code": -32602, "message": f"strumento sconosciuto: {nome}"})
        try:
            r = STRUMENTI[nome][0](arg)
            contenuto = r if isinstance(r, list) else [{"type": "text", "text": str(r)}]
            rispondi(id_, {"content": contenuto, "isError": False})
        except Exception as e:  # noqa: BLE001
            rispondi(id_, {"content": [{"type": "text", "text": f"Errore: {e}"}], "isError": True})
    else:
        rispondi(id_, errore={"code": -32601, "message": f"metodo non supportato: {metodo}"})


def main():
    log(f"mcp_braccio {VERSIONE} pronto (API {API})")
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

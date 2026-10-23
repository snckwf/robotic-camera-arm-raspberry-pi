#!/usr/bin/env python3
"""
avvio_braccio.py - avvio "silenzioso" del server MCP del braccio per Claude Desktop (Windows).

Claude Desktop avvia questo programma al posto di ssh. Lui risponde subito a Claude con l'elenco degli
strumenti (salvato in cache), quindi Claude Desktop non segnala errori se il Raspberry e' spento.
La connessione SSH al Raspberry si apre solo quando Claude usa davvero uno strumento: se il Pi non
risponde, lo strumento restituisce un messaggio "braccio non raggiungibile" e basta.
Solo libreria standard.
"""
import json
import os
import queue
import socket
import subprocess
import sys
import threading
import time

PI_HOST = os.environ.get("BRACCIO_PI_HOST", "IP_DEL_PI")
PI_UTENTE = "TUO_UTENTE"
CHIAVE = os.path.join(os.environ.get("USERPROFILE", ""), ".ssh", "id_ed25519_pi")
COMANDO_REMOTO = "python3 /home/TUO_UTENTE/braccio_mcp/mcp_braccio.py"
SSH = r"C:\Windows\System32\OpenSSH\ssh.exe"
CARTELLA = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(CARTELLA, "strumenti_cache.json")
TIMEOUT_CHIAMATA = 200      # home_base puo' durare fino a 180 s
MSG_SPENTO = ("Il braccio non e' raggiungibile: il Raspberry e' spento o fuori rete. "
              "Riprova quando e' acceso.")


def log(msg):
    print(f"[avvio_braccio] {msg}", file=sys.stderr, flush=True)


LOCK_OUT = threading.Lock()


def scrivi(msg):
    with LOCK_OUT:
        sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
        sys.stdout.flush()


def pi_acceso(timeout=3):
    try:
        with socket.create_connection((PI_HOST, 22), timeout=timeout):
            return True
    except OSError:
        return False


class Remoto:
    """Sessione MCP verso il Raspberry via SSH, aperta su richiesta e riaperta se cade."""

    def __init__(self):
        self.proc = None
        self.coda = queue.Queue()
        self.id_interno = 0
        self.lock = threading.Lock()

    def _lettore(self, proc):
        for riga in proc.stdout:
            riga = riga.strip()
            if riga:
                try:
                    self.coda.put(json.loads(riga))
                except ValueError:
                    pass
        self.coda.put(None)          # fine flusso

    def _attendi(self, id_, timeout):
        limite = time.time() + timeout
        while True:
            resto = limite - time.time()
            if resto <= 0:
                raise TimeoutError("nessuna risposta dal braccio")
            m = self.coda.get(timeout=resto)
            if m is None:
                raise ConnectionError("connessione al braccio chiusa")
            if m.get("id") == id_:
                return m

    def _invia(self, msg):
        self.proc.stdin.write(json.dumps(msg, ensure_ascii=False) + "\n")
        self.proc.stdin.flush()

    def connetti(self):
        if self.proc and self.proc.poll() is None:
            return
        if not pi_acceso():
            raise ConnectionError("Raspberry spento")
        self.coda = queue.Queue()
        self.proc = subprocess.Popen(
            [SSH, "-i", CHIAVE, "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "-o", "ServerAliveInterval=30",
             f"{PI_UTENTE}@{PI_HOST}", COMANDO_REMOTO],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, encoding="utf-8", bufsize=1, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        threading.Thread(target=self._lettore, args=(self.proc,), daemon=True).start()
        self.id_interno += 1
        iid = f"init-{self.id_interno}"
        self._invia({"jsonrpc": "2.0", "id": iid, "method": "initialize",
                     "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                                "clientInfo": {"name": "avvio_braccio", "version": "1"}}})
        self._attendi(iid, 20)
        self._invia({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def richiesta(self, metodo, params, timeout=TIMEOUT_CHIAMATA):
        with self.lock:
            for tentativo in (1, 2):
                try:
                    self.connetti()
                    self.id_interno += 1
                    iid = f"r-{self.id_interno}"
                    self._invia({"jsonrpc": "2.0", "id": iid, "method": metodo, "params": params})
                    return self._attendi(iid, timeout)
                except (ConnectionError, OSError, BrokenPipeError, queue.Empty, TimeoutError) as e:
                    log(f"tentativo {tentativo}: {e!r}")
                    self.chiudi()
                    if tentativo == 2 or not pi_acceso():
                        raise ConnectionError(str(e)) from None

    def chiudi(self):
        if self.proc:
            try:
                self.proc.kill()
            except Exception:  # noqa: BLE001
                pass
        self.proc = None


REMOTO = Remoto()


def carica_strumenti():
    try:
        with open(CACHE, encoding="utf-8") as f:
            return json.load(f)
    except Exception:  # noqa: BLE001
        return None


def aggiorna_cache():
    """Se il Pi e' acceso, rilegge l'elenco strumenti e lo salva (in background, senza bloccare Claude)."""
    try:
        r = REMOTO.richiesta("tools/list", {}, timeout=30)
        strumenti = r.get("result", {}).get("tools")
        if strumenti:
            with open(CACHE, "w", encoding="utf-8") as f:
                json.dump(strumenti, f, ensure_ascii=False, indent=1)
    except Exception as e:  # noqa: BLE001
        log(f"cache non aggiornata: {e!r}")


def gestisci(m):
    metodo, id_ = m.get("method"), m.get("id")
    if id_ is None:
        return
    if metodo == "initialize":
        ver = m.get("params", {}).get("protocolVersion", "2024-11-05")
        scrivi({"jsonrpc": "2.0", "id": id_, "result": {
            "protocolVersion": ver, "capabilities": {"tools": {}},
            "serverInfo": {"name": "braccio-telecamera", "version": "1.0"},
            "instructions": "Braccio motorizzato con camera sul banco di lavoro. Usa 'stato' prima di muovere, "
                            "'foto' per guardare. Muovi a piccoli passi e controlla con una foto. "
                            "Se il Raspberry e' spento gli strumenti rispondono che il braccio non e' raggiungibile."}})
        if pi_acceso(timeout=1):
            threading.Thread(target=aggiorna_cache, daemon=True).start()
    elif metodo == "ping":
        scrivi({"jsonrpc": "2.0", "id": id_, "result": {}})
    elif metodo == "tools/list":
        strumenti = carica_strumenti()
        if strumenti is None:
            try:
                strumenti = REMOTO.richiesta("tools/list", {}, timeout=30)["result"]["tools"]
            except Exception:  # noqa: BLE001
                strumenti = [{"name": "stato", "description": "Stato del braccio telecamera.",
                              "inputSchema": {"type": "object", "properties": {}}}]
        scrivi({"jsonrpc": "2.0", "id": id_, "result": {"tools": strumenti}})
    elif metodo == "tools/call":
        try:
            r = REMOTO.richiesta("tools/call", m.get("params", {}))
            r["id"] = id_
            scrivi(r)
        except Exception:  # noqa: BLE001
            scrivi({"jsonrpc": "2.0", "id": id_, "result": {
                "content": [{"type": "text", "text": MSG_SPENTO}], "isError": True}})
    else:
        scrivi({"jsonrpc": "2.0", "id": id_, "error": {"code": -32601, "message": f"metodo sconosciuto: {metodo}"}})


def main():
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    for riga in sys.stdin:
        riga = riga.strip()
        if not riga:
            continue
        try:
            m = json.loads(riga)
        except ValueError:
            continue
        # le chiamate agli strumenti in un thread: un home_base lungo non blocca ping e altre richieste
        if m.get("method") == "tools/call":
            threading.Thread(target=gestisci, args=(m,), daemon=True).start()
        else:
            gestisci(m)
    REMOTO.chiudi()


if __name__ == "__main__":
    main()

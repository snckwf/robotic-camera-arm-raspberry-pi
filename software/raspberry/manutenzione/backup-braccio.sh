#!/bin/bash
# Backup impostazioni braccio: una copia al giorno (al primo avvio)
# Raspberry: ultime 30 copie - NAS: ultime 7 copie
# Nome file: braccio_AAAA-MM-GG_giorno.tar.gz (es. braccio_2026-10-19_lunedi.tar.gz)
DEST=/home/TUO_UTENTE/backup_braccio
NAS=//IP_DEL_NAS/NOME_CONDIVISIONE
NAS_DIR="NOME_CARTELLA_SUL_NAS"
CRED=/etc/braccio-nas.cred
TIENI_LOCALE=30
TIENI_NAS=7
GIORNI=(x lunedi martedi mercoledi giovedi venerdi sabato domenica)
mkdir -p "$DEST"
OGGI=$(date +%Y-%m-%d)
F="$DEST/braccio_${OGGI}_${GIORNI[$(date +%u)]}.tar.gz"
if ! ls "$DEST"/braccio_${OGGI}*.tar.gz >/dev/null 2>&1; then
  tar -czf "$F" --ignore-failed-read --exclude='/opt/braccio/dati/video' --exclude='CamUI/static/gallery' --exclude='CamUI/venv' --exclude='CamUI/.venv' --exclude='*/__pycache__' --exclude='CamUI/.git' /opt/braccio /home/TUO_UTENTE/braccio_mcp /home/TUO_UTENTE/CamUI /etc/systemd/system/braccio-web.service /etc/systemd/system/console-lcd.service /etc/systemd/system/backup-braccio.service /etc/systemd/system/backup-braccio.timer /usr/local/bin/backup-braccio.sh /boot/firmware/config.txt /etc/sudoers.d/claude-braccio /etc/systemd/system.conf.d 2>/dev/null
  chown -R TUO_UTENTE:TUO_UTENTE "$DEST"
  ls -1 "$DEST"/braccio_*.tar.gz | sort | head -n -$TIENI_LOCALE | xargs -r rm -f
  echo "Copia locale creata: $F"
else
  echo "Copia di oggi gia presente"
fi
# --- NAS ---
if [ ! -f "$CRED" ]; then echo "NAS: manca $CRED, salto"; exit 0; fi
ELENCO=$(smbclient "$NAS" -A "$CRED" -c "cd \"$NAS_DIR\"; ls" 2>/dev/null) || { echo "NAS non raggiungibile, riprovo piu tardi"; exit 0; }
for f in $(ls -1 "$DEST"/braccio_*.tar.gz | sort | tail -n $TIENI_NAS); do
  b=$(basename "$f")
  echo "$ELENCO" | grep -q " $b " && continue
  smbclient "$NAS" -A "$CRED" -c "cd \"$NAS_DIR\"; lcd $DEST; put $b" >/dev/null 2>&1 && echo "NAS: caricato $b" || echo "NAS: errore su $b"
done
ELENCO=$(smbclient "$NAS" -A "$CRED" -c "cd \"$NAS_DIR\"; ls" 2>/dev/null)
for b in $(echo "$ELENCO" | grep -o 'braccio_[0-9-]*[_a-z]*\.tar\.gz' | sort -u | head -n -$TIENI_NAS); do
  smbclient "$NAS" -A "$CRED" -c "cd \"$NAS_DIR\"; del $b" >/dev/null 2>&1 && echo "NAS: tolto $b"
done

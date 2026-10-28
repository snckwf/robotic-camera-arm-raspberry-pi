#!/bin/bash
# Arm settings backup: one copy per day (at first boot)
# Raspberry: last 30 copies - NAS: last 7 copies
# File name: braccio_YYYY-MM-DD_day.tar.gz (e.g. braccio_2026-10-19_monday.tar.gz)
DEST=/home/YOUR_USER/backup_braccio
NAS=//NAS_IP/SHARE_NAME
NAS_DIR="NAS_FOLDER_NAME"
CRED=/etc/braccio-nas.cred
TIENI_LOCALE=30
TIENI_NAS=7
GIORNI=(x monday tuesday wednesday thursday friday saturday sunday)
mkdir -p "$DEST"
OGGI=$(date +%Y-%m-%d)
F="$DEST/braccio_${OGGI}_${GIORNI[$(date +%u)]}.tar.gz"
if ! ls "$DEST"/braccio_${OGGI}*.tar.gz >/dev/null 2>&1; then
  tar -czf "$F" --ignore-failed-read --exclude='/opt/braccio/dati/video' --exclude='CamUI/static/gallery' --exclude='CamUI/venv' --exclude='CamUI/.venv' --exclude='*/__pycache__' --exclude='CamUI/.git' /opt/braccio /home/YOUR_USER/braccio_mcp /home/YOUR_USER/CamUI /etc/systemd/system/braccio-web.service /etc/systemd/system/backup-braccio.service /etc/systemd/system/backup-braccio.timer /usr/local/bin/backup-braccio.sh /boot/firmware/config.txt /etc/sudoers.d/claude-braccio /etc/systemd/system.conf.d 2>/dev/null
  chown -R YOUR_USER:YOUR_USER "$DEST"
  ls -1 "$DEST"/braccio_*.tar.gz | sort | head -n -$TIENI_LOCALE | xargs -r rm -f
  echo "Local copy created: $F"
else
  echo "Today's copy already present"
fi
# --- NAS ---
if [ ! -f "$CRED" ]; then echo "NAS: $CRED missing, skipping"; exit 0; fi
ELENCO=$(smbclient "$NAS" -A "$CRED" -c "cd \"$NAS_DIR\"; ls" 2>/dev/null) || { echo "NAS not reachable, will retry later"; exit 0; }
for f in $(ls -1 "$DEST"/braccio_*.tar.gz | sort | tail -n $TIENI_NAS); do
  b=$(basename "$f")
  echo "$ELENCO" | grep -q " $b " && continue
  smbclient "$NAS" -A "$CRED" -c "cd \"$NAS_DIR\"; lcd $DEST; put $b" >/dev/null 2>&1 && echo "NAS: uploaded $b" || echo "NAS: error on $b"
done
ELENCO=$(smbclient "$NAS" -A "$CRED" -c "cd \"$NAS_DIR\"; ls" 2>/dev/null)
for b in $(echo "$ELENCO" | grep -o 'braccio_[0-9-]*[_a-z]*\.tar\.gz' | sort -u | head -n -$TIENI_NAS); do
  smbclient "$NAS" -A "$CRED" -c "cd \"$NAS_DIR\"; del $b" >/dev/null 2>&1 && echo "NAS: removed $b"
done

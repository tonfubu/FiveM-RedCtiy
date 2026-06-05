#!/bin/bash
# ============================================================
#   FiveM RedCity - backup script
#   Backs up: server.cfg, secrets.cfg, systemd unit, and a DB dump.
#   Usage: bash /opt/fivem-redcity/scripts/backup.sh
# ============================================================
set -euo pipefail

BASE=/opt/fivem-redcity
DATA=$BASE/server-data
DEST=$BASE/backups
STAMP=$(date +%F_%H%M%S)
OUT=$DEST/backup_$STAMP
mkdir -p "$OUT"

# --- DB credentials are read from secrets.cfg (kept off git) ---
DB_HOST=10.10.10.205
DB_USER=redpotiondb
DB_NAME=redcity_esx
# Pull password out of secrets.cfg connection string (semicolon format)
DB_PASS=$(grep mysql_connection_string "$DATA/secrets.cfg" | sed -n 's/.*password=\([^;\"]*\).*/\1/p')

echo "[backup] config files ..."
cp -a "$DATA/server.cfg"        "$OUT/" 2>/dev/null || true
cp -a "$DATA/secrets.cfg"       "$OUT/" 2>/dev/null || true
cp -a /etc/systemd/system/fivem-redcity.service "$OUT/" 2>/dev/null || true

echo "[backup] database dump ($DB_NAME) ..."
MYSQL_PWD="$DB_PASS" mysqldump -h "$DB_HOST" -u "$DB_USER" \
  --single-transaction --quick --routines "$DB_NAME" \
  | gzip > "$OUT/${DB_NAME}_${STAMP}.sql.gz"

echo "[backup] done -> $OUT"
# keep only the last 14 backups
ls -1dt "$DEST"/backup_* | tail -n +15 | xargs -r rm -rf
echo "[backup] retention applied (keep 14)"

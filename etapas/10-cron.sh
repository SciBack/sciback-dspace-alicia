#!/bin/bash
# SciBack — Etapa 10: Cron jobs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_CRON:-yes}" == "skip" ]] && exit 99
set -euo pipefail

DSPACE_DIR="${DSPACE_DIR:-/dspace}"

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 10 — Cron jobs\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"

mkdir -p "${DSPACE_DIR}/log"
chown dspace:dspace "${DSPACE_DIR}/log"

CRON_TMP=$(mktemp)
crontab -l -u dspace 2>/dev/null > "$CRON_TMP" || true

if grep -q 'sciback' "$CRON_TMP" 2>/dev/null; then
  echo -e "\033[1;33m[!]\033[0m Cron jobs de SciBack ya existen — omitiendo"
else
  cat >> "$CRON_TMP" <<CRON
# ─── SciBack DSpace — cron jobs (${SCIBACK_CLIENT}) ──────────────
# Zona horaria EC2: UTC. Lima = UTC-5.

0 * * * * ${DSPACE_DIR}/bin/dspace index-discovery -b > ${DSPACE_DIR}/log/cron-index.log 2>&1
0 6 * * * ${DSPACE_DIR}/bin/dspace oai import -c > ${DSPACE_DIR}/log/cron-oai.log 2>&1
0 7 * * * ${DSPACE_DIR}/bin/dspace filter-media > ${DSPACE_DIR}/log/cron-media.log 2>&1
0 11 * * * ${DSPACE_DIR}/bin/dspace subscription-send > ${DSPACE_DIR}/log/cron-subs.log 2>&1
0 8 * * * ${DSPACE_DIR}/bin/dspace stats-util -o > ${DSPACE_DIR}/log/cron-stats.log 2>&1
0 9 1 * * ${DSPACE_DIR}/bin/dspace cleanup > ${DSPACE_DIR}/log/cron-cleanup.log 2>&1
CRON

  crontab -u dspace "$CRON_TMP"
  echo -e "\033[0;32m[✓]\033[0m Cron jobs instalados"
fi
rm -f "$CRON_TMP"

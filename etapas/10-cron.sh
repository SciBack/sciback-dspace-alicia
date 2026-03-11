#!/usr/bin/env bash
# SciBack — Etapa 10: Cron jobs

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"

[[ -f "${ENV_FILE}" ]] || { echo "[✗] No se encontró: ${ENV_FILE}"; exit 1; }

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

[[ "${INSTALL_CRON:-yes}" == "skip" ]] && exit 99

ETAPA_INICIO=$(date +%s)

RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
RUN_GROUP="${DSPACE_RUN_AS_GROUP:-dspace}"
DSPACE_DIR="${DSPACE_DIR:-/dspace}"
DSPACE_BIN="${DSPACE_DIR}/bin/dspace"
DSPACE_LOG_DIR="${DSPACE_DIR}/log"
CRON_TIMEZONE="${CRON_TIMEZONE:-America/Lima}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[✗] Falta comando requerido: $1"
    exit 1
  }
}

require_command crontab
require_command install
require_command grep
require_command mktemp

[[ -x "${DSPACE_BIN}" ]] || { echo "[✗] No existe ejecutable DSpace: ${DSPACE_BIN}"; exit 1; }

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 10 — Cron jobs\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~1 min\033[0m"

echo -e "\n\033[0;34m--- 10.1 Preparando directorio de logs ---\033[0m"
install -d -o "${RUN_USER}" -g "${RUN_GROUP}" "${DSPACE_LOG_DIR}"
echo -e "\033[0;32m[✓]\033[0m Directorio de logs listo: ${DSPACE_LOG_DIR}"

echo -e "\n\033[0;34m--- 10.2 Registrando cron jobs ---\033[0m"
CRON_TMP="$(mktemp)"
trap 'rm -f "${CRON_TMP}"' EXIT

crontab -l -u "${RUN_USER}" 2>/dev/null > "${CRON_TMP}" || true

if grep -Fq "# ─── SciBack DSpace — cron jobs (${SCIBACK_CLIENT}) ──────────────" "${CRON_TMP}"; then
  echo -e "\033[1;33m[!]\033[0m Cron jobs de SciBack ya existen para ${SCIBACK_CLIENT} — omitiendo"
else
  {
    echo ""
    echo "# ─── SciBack DSpace — cron jobs (${SCIBACK_CLIENT}) ──────────────"
    echo "SHELL=/bin/bash"
    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    echo "CRON_TZ=${CRON_TIMEZONE}"
    echo ""
    echo "0 * * * * ${DSPACE_BIN} index-discovery -b > ${DSPACE_LOG_DIR}/cron-index.log 2>&1"
    echo "0 6 * * * ${DSPACE_BIN} oai import -c > ${DSPACE_LOG_DIR}/cron-oai.log 2>&1"
    echo "0 7 * * * ${DSPACE_BIN} filter-media > ${DSPACE_LOG_DIR}/cron-media.log 2>&1"
    echo "0 11 * * * ${DSPACE_BIN} subscription-send > ${DSPACE_LOG_DIR}/cron-subs.log 2>&1"
    echo "0 8 * * * ${DSPACE_BIN} stats-util -o > ${DSPACE_LOG_DIR}/cron-stats.log 2>&1"
    echo "0 9 1 * * ${DSPACE_BIN} cleanup > ${DSPACE_LOG_DIR}/cron-cleanup.log 2>&1"
  } >> "${CRON_TMP}"

  crontab -u "${RUN_USER}" "${CRON_TMP}"
  echo -e "\033[0;32m[✓]\033[0m Cron jobs instalados para ${RUN_USER}"
fi

rm -f "${CRON_TMP}"
trap - EXIT

echo -e "\n\033[0;34m--- 10.3 Verificación final ---\033[0m"
if crontab -l -u "${RUN_USER}" 2>/dev/null | grep -Fq "# ─── SciBack DSpace — cron jobs (${SCIBACK_CLIENT}) ──────────────"; then
  echo -e "\033[0;32m[✓]\033[0m Cron jobs verificados correctamente"
else
  echo "[✗] No se pudieron verificar los cron jobs"
  exit 1
fi

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

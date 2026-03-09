#!/bin/bash
# SciBack — Etapa 02: Java 17
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_JAVA:-yes}" == "skip" ]] && exit 99
set -euo pipefail

ETAPA_INICIO=$(date +%s)

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 02 — Java 17\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~1 min\033[0m"

apt-get install -y -q openjdk-17-jdk
JAVA_VER=$(java -version 2>&1 | head -1)
echo -e "\033[0;32m[✓]\033[0m Java instalado: ${JAVA_VER}"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

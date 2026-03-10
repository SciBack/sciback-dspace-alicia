#!/bin/bash
# =============================================================================
# SciBack — install.sh v3.1
# Disparador modular: DSpace 7.6.6 + ALICIA/RENATI
# Código base: deploy-dspace.sh v2.2 (probado y funcional)
# =============================================================================
set -euo pipefail

INSTALL_INICIO=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETAPAS_DIR="${SCRIPT_DIR}/etapas"

# ─── Cargar .env ─────────────────────────────────────────────
ENV_FILE="${SCRIPT_DIR}/.env.dspace.deploy"
if [[ "${1:-}" == "--env" ]]; then ENV_FILE="${2:-${ENV_FILE}}"; fi
[[ -f "$ENV_FILE" ]] || { echo -e "\033[0;31m[✗] No se encontró: $ENV_FILE\033[0m"; exit 1; }
export ENV_FILE
source "$ENV_FILE"

# ─── Validaciones ────────────────────────────────────────────
[[ "$(id -u)" -eq 0 ]] || { echo -e "\033[0;31m[✗] Ejecutar con sudo\033[0m"; exit 1; }
[[ -d "$ETAPAS_DIR" ]] || { echo -e "\033[0;31m[✗] No se encontró: ${ETAPAS_DIR}/\033[0m"; exit 1; }
[[ -n "${SCIBACK_CLIENT:-}" ]] || { echo -e "\033[0;31m[✗] SCIBACK_CLIENT no definido\033[0m"; exit 1; }
[[ -n "${DB_PASSWORD:-}" ]] || { echo -e "\033[0;31m[✗] DB_PASSWORD no definido\033[0m"; exit 1; }
[[ -n "${DSPACE_HOSTNAME:-}" ]] || { echo -e "\033[0;31m[✗] DSPACE_HOSTNAME no definido\033[0m"; exit 1; }
[[ "$DB_PASSWORD" != *"CAMBIAR"* ]] || { echo -e "\033[0;31m[✗] DB_PASSWORD tiene placeholder\033[0m"; exit 1; }

# ─── Log ─────────────────────────────────────────────────────
LOG_FILE="/var/log/sciback-install-$(date +%Y%m%d-%H%M%S).log"
export LOG_FILE
exec > >(tee -a "$LOG_FILE") 2>&1

# ─── Banner ──────────────────────────────────────────────────
echo ""
echo -e "\033[0;34m╔══════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[0;36m║  SciBack — DSpace ${DSPACE_VERSION} + ALICIA/RENATI     ║\033[0m"
echo -e "\033[0;36m║  Instalación modular v3.1                               ║\033[0m"
echo -e "\033[0;34m╚══════════════════════════════════════════════════════════╝\033[0m"
echo ""
echo -e "  Cliente:   \033[0;32m${SCIBACK_CLIENT}\033[0m"
echo -e "  Hostname:  \033[0;32m${DSPACE_HOSTNAME}\033[0m"
echo -e "  Entorno:   \033[0;32m${SCIBACK_ENV:-prod}\033[0m"
echo -e "  Log:       \033[0;32m${LOG_FILE}\033[0m"
echo -e "  Fecha:     $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
echo ""
echo -e "[0;34mSe ejecutarán 14 etapas (tiempo estimado):[0m"
echo "  01. Sistema (paquetes, swap, usuario)     ~3 min"
echo "  02. Java 17                               ~1 min"
echo "  03. PostgreSQL 14                         ~2 min"
echo "  04. Solr 8.11.4                           ~5 min"
echo "  05. Tomcat 9                              ~1 min"
echo "  06. DSpace Backend                        ~15 min"
echo "  07. Frontend Angular + PM2                ~12 min"
echo "  08. Nginx + SSL                           ~2 min"
echo "  09. Handle Server                         ~1 min"
echo "  10. Cron jobs                             ~1 min"
echo "  11. Schemas ALICIA                        ~1 min"
echo "  12. Vocabularios CONCYTEC                 ~1 min"
echo "  13. Formularios depósito                  ~1 min"
echo "  14. Estructura SciBack Lab                ~1 min"
echo -e "[0;36m  Total estimado: ~46 min[0m"
echo ""
# ─── Etapas ──────────────────────────────────────────────────
ETAPAS=(
  "01-sistema.sh"
  "02-java.sh"
  "03-postgresql.sh"
  "04-solr.sh"
  "05-tomcat.sh"
  "06-dspace-backend.sh"
  "07-frontend.sh"
  "08-nginx.sh"
  "09-handle.sh"
  "10-cron.sh"
  "11-schemas-alicia.sh"
  "12-vocabularios.sh"
  "13-formularios.sh"
  "14-lab-structure.sh"
)

TOTAL=${#ETAPAS[@]}
EXITOSAS=0; OMITIDAS=0; FALLIDAS=0

for i in "${!ETAPAS[@]}"; do
  ETAPA="${ETAPAS[$i]}"
  NUM=$((i + 1))
  ETAPA_PATH="${ETAPAS_DIR}/${ETAPA}"

  if [[ ! -f "$ETAPA_PATH" ]]; then
    echo -e "\033[0;31m[✗] No se encontró: ${ETAPA_PATH}\033[0m"
    ((FALLIDAS++)) || true
    continue
  fi

  echo ""
  echo -e "\033[0;34m╔══════════════════════════════════════════════════════════╗\033[0m"
  echo -e "\033[0;36m║  ETAPA ${NUM}/${TOTAL} — ${ETAPA%.sh}\033[0m"
  echo -e "\033[0;34m╚══════════════════════════════════════════════════════════╝\033[0m"

  if bash "${ETAPA_PATH}" 2>&1; then
    echo -e "\n\033[0;32m[✓] Etapa ${NUM}/${TOTAL} completada\033[0m"
    ((EXITOSAS++)) || true
  else
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 99 ]]; then
      echo -e "\n\033[1;33m[!] Etapa ${NUM}/${TOTAL} omitida (skip)\033[0m"
      ((OMITIDAS++)) || true
    else
      echo -e "\n\033[0;31m[✗] Etapa ${NUM}/${TOTAL} falló (exit: ${EXIT_CODE})\033[0m"
      echo -e "    Re-ejecutar: sudo bash etapas/${ETAPA}"
      ((FALLIDAS++)) || true
      read -p "    ¿Continuar con la siguiente etapa? (s/N): " -n 1 -r
      echo ""
      [[ $REPLY =~ ^[Ss]$ ]] || break
    fi
  fi
done

# ─── Resumen ─────────────────────────────────────────────────
DSPACE_BASEURL="https://${DSPACE_HOSTNAME}"
INSTALL_FIN=$(date +%s)
TOTAL_MIN=$(( (INSTALL_FIN - INSTALL_INICIO + 59) / 60 ))

echo ""
echo -e "[0;34m╔══════════════════════════════════════════════════════════╗[0m"
if [[ "$FALLIDAS" -eq 0 ]]; then
  echo -e "[0;36m║  ✅ INSTALACIÓN COMPLETADA                              ║[0m"
else
  echo -e "[1;33m║  ⚠️  INSTALACIÓN COMPLETADA CON ERRORES                ║[0m"
fi
echo -e "[0;34m╠══════════════════════════════════════════════════════════╣[0m"
echo -e "[0;36m║  Tiempo total: ${TOTAL_MIN} minuto(s)                                  ║[0m"
echo -e "[0;36m║  Etapas: ${EXITOSAS}/${TOTAL} exitosas | Omitidas: ${OMITIDAS} | Fallidas: ${FALLIDAS}               ║[0m"
echo -e "[0;34m╠══════════════════════════════════════════════════════════╣[0m"
echo -e "[0;36m║  Frontend:  ${DSPACE_BASEURL}[0m"
echo -e "[0;36m║  REST API:  ${DSPACE_BASEURL}/server[0m"
echo -e "[0;36m║  OAI-PMH:   ${DSPACE_BASEURL}/oai/request[0m"
echo -e "[0;34m╠══════════════════════════════════════════════════════════╣[0m"
echo -e "[0;36m║  Verificar:                                              ║[0m"
echo -e "[0;36m║    systemctl status tomcat9 solr nginx                   ║[0m"
echo -e "[0;36m║    su - dspace -c 'pm2 list'                           ║[0m"
echo -e "[0;34m╚══════════════════════════════════════════════════════════╝[0m"
echo ""
echo "  Log: ${LOG_FILE}"
echo ""
[[ "$FALLIDAS" -eq 0 ]] && echo -e "[0;32m[✓] Todo listo ✓[0m" || echo -e "[1;33m[!] ${FALLIDAS} error(es)[0m"

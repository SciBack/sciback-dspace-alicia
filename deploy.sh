#!/bin/bash
# =============================================================================
# SciBack — deploy.sh v3.2
# Disparador modular: DSpace 7.6.6 + ALICIA/RENATI
# Incluye indicadores de progreso y tiempo restante estimado
# =============================================================================
set -euo pipefail

INSTALL_INICIO=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETAPAS_DIR="${SCRIPT_DIR}/etapas"

# ─── Cargar .env ─────────────────────────────────────────────
ENV_FILE="${SCRIPT_DIR}/.env.deploy"
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

# ─── Tiempos estimados por etapa (en segundos) ──────────────
# Usados para calcular progreso y tiempo restante estimado
declare -A TIEMPOS_EST=(
  ["01-sistema"]=180
  ["02-java"]=60
  ["03-postgresql"]=120
  ["04-solr"]=300
  ["05-tomcat"]=60
  ["06-dspace-backend"]=900
  ["07-frontend"]=720
  ["08-nginx"]=120
  ["09-handle"]=60
  ["10-cron"]=60
  ["11-schemas-alicia"]=60
  ["12-vocabularios"]=60
  ["13-formularios"]=60
  ["14-lab-structure"]=60
)

TIEMPO_TOTAL_EST=0
for t in "${TIEMPOS_EST[@]}"; do TIEMPO_TOTAL_EST=$((TIEMPO_TOTAL_EST + t)); done

# ─── Funciones de progreso ───────────────────────────────────

format_time() {
  local secs=$1
  if (( secs >= 3600 )); then
    printf "%dh %02dm %02ds" $((secs/3600)) $(((secs%3600)/60)) $((secs%60))
  elif (( secs >= 60 )); then
    printf "%dm %02ds" $((secs/60)) $((secs%60))
  else
    printf "%ds" "$secs"
  fi
}

progress_bar() {
  local pct=$1
  local width=30
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""

  local i
  for ((i=0; i<filled; i++)); do bar+="#"; done
  for ((i=0; i<empty; i++)); do bar+="-"; done

  printf '\033[0;36m[%s] %3d%%\033[0m' "$bar" "$pct"
}

# ─── Banner ──────────────────────────────────────────────────
echo ""
echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  SciBack — DSpace ${DSPACE_VERSION} + ALICIA/RENATI     \033[0m"
echo -e "\033[0;36m  Instalación modular v3.2                               \033[0m"
echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"
echo ""
echo -e "  Cliente:   \033[0;32m${SCIBACK_CLIENT}\033[0m"
echo -e "  Hostname:  \033[0;32m${DSPACE_HOSTNAME}\033[0m"
echo -e "  Entorno:   \033[0;32m${SCIBACK_ENV:-prod}\033[0m"
echo -e "  Log:       \033[0;32m${LOG_FILE}\033[0m"
echo -e "  Fecha:     $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
echo ""
echo -e "\033[0;34mSe ejecutarán 14 etapas (tiempo estimado):\033[0m"
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
echo -e "\033[0;36m  Total estimado: ~46 min\033[0m"
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
TIEMPO_ACUM_EST=0   # Tiempo estimado acumulado de etapas completadas

for i in "${!ETAPAS[@]}"; do
  ETAPA="${ETAPAS[$i]}"
  NUM=$((i + 1))
  ETAPA_PATH="${ETAPAS_DIR}/${ETAPA}"
  ETAPA_KEY="${ETAPA%.sh}"

  if [[ ! -f "$ETAPA_PATH" ]]; then
    echo -e "\033[0;31m[✗] No se encontró: ${ETAPA_PATH}\033[0m"
    ((FALLIDAS++)) || true
    continue
  fi

  # ── Calcular progreso y tiempo restante ──
  PCT=$(( TIEMPO_ACUM_EST * 100 / TIEMPO_TOTAL_EST ))
  ELAPSED_TOTAL=$(( $(date +%s) - INSTALL_INICIO ))
  RESTANTE_EST=$(( TIEMPO_TOTAL_EST - TIEMPO_ACUM_EST ))

  echo ""
  echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"
  echo -e "\033[0;36m  ETAPA ${NUM}/${TOTAL} — ${ETAPA_KEY}\033[0m"
  echo -e "\033[0;34m──────────────────────────────────────────────────────────\033[0m"
  echo -ne "  $(progress_bar $PCT)"
  printf "  Transcurrido: \033[0;33m%s\033[0m" "$(format_time $ELAPSED_TOTAL)"
  printf "  Restante: \033[0;33m~%s\033[0m\n" "$(format_time $RESTANTE_EST)"
  echo -e "  Estimado para esta etapa: \033[0;33m~$(format_time ${TIEMPOS_EST[$ETAPA_KEY]:-60})\033[0m"
  echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"

  ETAPA_INICIO=$(date +%s)

  if bash "${ETAPA_PATH}" 2>&1; then
    ETAPA_FIN=$(date +%s)
    ETAPA_DURACION=$(( ETAPA_FIN - ETAPA_INICIO ))
    echo -e "\n\033[0;32m[✓] Etapa ${NUM}/${TOTAL} completada en $(format_time $ETAPA_DURACION)\033[0m"
    ((EXITOSAS++)) || true
  else
    EXIT_CODE=$?
    ETAPA_FIN=$(date +%s)
    ETAPA_DURACION=$(( ETAPA_FIN - ETAPA_INICIO ))
    if [[ $EXIT_CODE -eq 99 ]]; then
      echo -e "\n\033[1;33m[!] Etapa ${NUM}/${TOTAL} omitida (skip) — $(format_time $ETAPA_DURACION)\033[0m"
      ((OMITIDAS++)) || true
    else
      echo -e "\n\033[0;31m[✗] Etapa ${NUM}/${TOTAL} falló (exit: ${EXIT_CODE}) — $(format_time $ETAPA_DURACION)\033[0m"
      echo -e "    Re-ejecutar: sudo bash etapas/${ETAPA}"
      ((FALLIDAS++)) || true
      read -p "    ¿Continuar con la siguiente etapa? (s/N): " -n 1 -r
      echo ""
      [[ $REPLY =~ ^[Ss]$ ]] || break
    fi
  fi

  # Actualizar progreso acumulado
  TIEMPO_ACUM_EST=$(( TIEMPO_ACUM_EST + ${TIEMPOS_EST[$ETAPA_KEY]:-60} ))
done

# ─── Resumen ─────────────────────────────────────────────────
DSPACE_BASEURL="https://${DSPACE_HOSTNAME}"
INSTALL_FIN=$(date +%s)
TOTAL_SEG=$(( INSTALL_FIN - INSTALL_INICIO ))
TOTAL_MIN=$(( (TOTAL_SEG + 59) / 60 ))

echo ""
echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"
if [[ "$FALLIDAS" -eq 0 ]]; then
  echo -e "\033[0;36m  ✅ INSTALACIÓN COMPLETADA                              \033[0m"
else
  echo -e "\033[1;33m  ⚠️  INSTALACIÓN COMPLETADA CON ERRORES                \033[0m"
fi
echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo total: $(format_time $TOTAL_SEG) (${TOTAL_MIN} min)\033[0m"
echo -e "\033[0;36m  Etapas: ${EXITOSAS}/${TOTAL} exitosas | Omitidas: ${OMITIDAS} | Fallidas: ${FALLIDAS}\033[0m"
echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Frontend:  ${DSPACE_BASEURL}\033[0m"
echo -e "\033[0;36m  REST API:  ${DSPACE_BASEURL}/server\033[0m"
echo -e "\033[0;36m  OAI-PMH:   ${DSPACE_BASEURL}/oai/request\033[0m"
echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Verificar:\033[0m"
echo -e "\033[0;36m    systemctl status tomcat9 solr nginx\033[0m"
echo -e "\033[0;36m    su - dspace -c 'pm2 list'\033[0m"
echo -e "\033[0;34m══════════════════════════════════════════════════════════\033[0m"
echo ""
echo "  Log: ${LOG_FILE}"
echo ""
[[ "$FALLIDAS" -eq 0 ]] && echo -e "\033[0;32m[✓] Todo listo ✓\033[0m" || echo -e "\033[1;33m[!] ${FALLIDAS} error(es)\033[0m"

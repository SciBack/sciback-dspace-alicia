#!/usr/bin/env bash
# =============================================================================
# SciBack — Etapa 14: Estructura inicial Lab (comunidades y colecciones)
# Crea jerarquía desde variables LAB_* definidas en .env.deploy
# Usa DSpace CLI: structure-builder
# =============================================================================

set -Eeuo pipefail

ETAPA_INICIO=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"

[[ -f "${ENV_FILE}" ]] || { echo "[✗] No se encontró: ${ENV_FILE}"; exit 1; }

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

[[ "${LAB_STRUCTURE:-false}" == "true" ]] || {
  echo "[!] LAB_STRUCTURE no está en true. Etapa 14 omitida."
  exit 99
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()   { echo -e "${CYAN}[→]${NC} $1"; }
header() {
  echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || error "Falta comando requerido: $1"
}

require_command sudo
require_command python3
require_command systemctl
require_command grep
require_command sed
require_command tee
require_command mktemp

RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
RUN_GROUP="${DSPACE_RUN_AS_GROUP:-dspace}"
DSPACE_DIR="${DSPACE_DIR:-/dspace}"
DSPACE_BIN="${DSPACE_DIR}/bin/dspace"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"

WORK_DIR="/tmp/sciback-lab-structure"
EXPORT_XML="${WORK_DIR}/existing-structure.xml"
IMPORT_XML="${WORK_DIR}/import-structure.xml"
RESULT_XML="${WORK_DIR}/import-result.xml"
LOG_FILE="/tmp/sciback-lab-structure-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "${WORK_DIR}"
chown -R "${RUN_USER}:${RUN_GROUP}" "${WORK_DIR}" 2>/dev/null || true
chmod 775 "${WORK_DIR}" 2>/dev/null || true

exec > >(tee -a "${LOG_FILE}") 2>&1

TOTAL_STEPS=6

progress_bar() {
  local current="$1"
  local total="$2"
  local width=32
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local percent=$(( current * 100 / total ))

  printf "\n["
  if (( filled > 0 )); then
    printf "%0.s#" $(seq 1 "${filled}")
  fi
  if (( empty > 0 )); then
    printf "%0.s-" $(seq 1 "${empty}")
  fi
  printf "] %d%% (%d/%d)\n" "${percent}" "${current}" "${total}"
}

step() {
  local n="$1"
  local msg="$2"
  echo ""
  echo -e "${BLUE}── ${n}. ${msg} ─────────────────────────────${NC}"
  progress_bar "${n}" "${TOTAL_STEPS}"
}

run_dspace() {
  sudo -u "${RUN_USER}" "${DSPACE_BIN}" "$@"
}

xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//\'/&apos;}"
  printf '%s' "${s}"
}

normalize_name() {
  local input="$1"
  echo "${input}" \
    | tr '[:lower:]' '[:upper:]' \
    | sed -E 's/[^A-Z0-9]+/_/g; s/_+/_/g; s/^_+|_+$//g'
}

trim() {
  echo "$1" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

generate_subcommunity_xml() {
  local subcommunity_name="$1"
  local norm var_name collections
  local col col_trimmed

  norm="$(normalize_name "${subcommunity_name}")"
  var_name="LAB_COLLECTIONS__${norm}"
  collections="${!var_name:-}"

  echo "    <community>"
  echo "      <name>$(xml_escape "${subcommunity_name}")</name>"

  if [[ -n "${collections}" ]]; then
    IFS='|' read -r -a cols <<< "${collections}"
    for col in "${cols[@]}"; do
      col_trimmed="$(trim "${col}")"
      [[ -n "${col_trimmed}" ]] || continue
      echo "      <collection>"
      echo "        <name>$(xml_escape "${col_trimmed}")</name>"
      echo "      </collection>"
    done
  else
    echo "      <!-- Sin colecciones definidas para ${var_name} -->"
  fi

  echo "    </community>"
}

header "Etapa 14 — Estructura inicial SciBack Lab"
echo -e "${CYAN}  Tiempo estimado: ~1-2 min${NC}"

step 1 "Validando prerrequisitos"
[[ -x "${DSPACE_BIN}" ]] || error "No ejecutable: ${DSPACE_BIN}"
[[ -n "${ADMIN_EMAIL}" ]] || error "ADMIN_EMAIL vacío"
[[ -n "${LAB_ROOT_COMMUNITY:-}" ]] || error "LAB_ROOT_COMMUNITY vacío"
[[ -n "${LAB_SUBCOMMUNITIES:-}" ]] || error "LAB_SUBCOMMUNITIES vacío"
log "Prerrequisitos OK"

step 2 "Exportando estructura actual"
run_dspace structure-builder -x -e "${ADMIN_EMAIL}" -o "${EXPORT_XML}"
log "Export generado: ${EXPORT_XML}"

step 3 "Comprobando idempotencia"
if grep -Fq "<name>${LAB_ROOT_COMMUNITY}</name>" "${EXPORT_XML}"; then
  warn "La comunidad raíz '${LAB_ROOT_COMMUNITY}' ya existe. Etapa omitida de forma segura."
  ETAPA_FIN=$(date +%s)
  DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
  echo -e "${GREEN}[✓]${NC} Etapa completada en ${DURACION_MIN} minuto(s)"
  exit 0
fi
log "La comunidad raíz no existe aún"

step 4 "Generando XML de importación"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<import_structure>'
  echo '  <community>'
  echo "    <name>$(xml_escape "${LAB_ROOT_COMMUNITY}")</name>"

  if [[ -n "${LAB_REPOSITORY_DESCRIPTION:-}" ]]; then
    echo "    <metadata>"
    echo "      <field>"
    echo "        <dc-schema>dc</dc-schema>"
    echo "        <dc-element>description</dc-element>"
    echo "        <value>$(xml_escape "${LAB_REPOSITORY_DESCRIPTION}")</value>"
    echo "      </field>"
    echo "    </metadata>"
  fi

  IFS='|' read -r -a subs <<< "${LAB_SUBCOMMUNITIES}"
  for sub in "${subs[@]}"; do
    sub_trimmed="$(trim "${sub}")"
    [[ -n "${sub_trimmed}" ]] || continue
    generate_subcommunity_xml "${sub_trimmed}"
  done

  echo '  </community>'
  echo '</import_structure>'
} > "${IMPORT_XML}"

log "XML de importación generado: ${IMPORT_XML}"
echo ""
echo "Contenido generado:"
sed 's/^/  /' "${IMPORT_XML}"

step 5 "Importando estructura con structure-builder"
run_dspace structure-builder -f "${IMPORT_XML}" -e "${ADMIN_EMAIL}" -o "${RESULT_XML}"
log "Importación completada"
log "Resultado: ${RESULT_XML}"

step 6 "Reiniciando Tomcat"
systemctl restart tomcat9
sleep 5
log "Tomcat reiniciado"

echo ""
log "Estructura Lab procesada correctamente"
echo "    Comunidad raíz: ${LAB_ROOT_COMMUNITY}"
echo "    Log: ${LOG_FILE}"
echo "    XML importación: ${IMPORT_XML}"
echo "    XML resultado:   ${RESULT_XML}"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "${GREEN}[✓]${NC} Etapa completada en ${DURACION_MIN} minuto(s)"

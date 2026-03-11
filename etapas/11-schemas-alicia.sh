#!/usr/bin/env bash
# =============================================================================
# SciBack — Etapa 11: Schemas ALICIA/RENATI vía REST API (DSpace 7.6.6)
# Enfoque: DSpace 7.6.6 + Guía ALICIA 2.1.0 + RENATI (sin CRIS)
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

[[ "${INSTALL_SCHEMAS_ALICIA:-yes}" == "skip" ]] && exit 99

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
  command -v "$1" >/dev/null 2>&1 || {
    info "Instalando dependencia faltante: $1"
    apt-get install -y -q "$1"
  }
}

require_command curl
require_command jq
require_command awk
require_command grep
require_command tee
require_command tr
require_command head

API_BASE="${DSPACE_REST_API_BASE:-http://localhost:8080/server/api}"
ADMIN_EMAIL="${ADMIN_EMAIL:?ADMIN_EMAIL no definido en .env.deploy}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:?ADMIN_PASSWORD no definido en .env.deploy}"

CREATED=0
SKIPPED=0
ERRORS=0
CSRF=""
TOKEN=""

LOG_FILE="/tmp/sciback-alicia-schema-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

header "Etapa 11 — Schemas ALICIA/RENATI"
log "API: ${API_BASE}"
log "Admin: ${ADMIN_EMAIL}"
log "Log: ${LOG_FILE}"
echo -e "${CYAN}  Tiempo estimado: ~1-3 min${NC}"

http_get() {
  local url="$1"
  curl -fsS -H "Authorization: ${TOKEN}" "${url}"
}

authenticate() {
  info "Autenticando contra REST API..."

  CSRF="$(
    curl -sS "${API_BASE}" -D - -o /dev/null \
      | awk '/DSPACE-XSRF-TOKEN/ {print $2}' \
      | tr -d '\r\n'
  )"

  [[ -n "${CSRF}" ]] || error "No se pudo obtener CSRF — ¿Tomcat/REST activos?"

  TOKEN="$(
    curl -sS -X POST "${API_BASE}/authn/login" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -H "X-XSRF-TOKEN: ${CSRF}" \
      -H "Cookie: DSPACE-XSRF-COOKIE=${CSRF}" \
      -d "user=${ADMIN_EMAIL}&password=${ADMIN_PASSWORD}" \
      -D - -o /dev/null \
      | awk '/^Authorization:/ {print $2" "$3}' \
      | tr -d '\r\n'
  )"

  [[ -n "${TOKEN}" ]] || error "Login fallido — verificar credenciales de administrador"

  log "Autenticación exitosa"
}

refresh_csrf() {
  local new_csrf
  new_csrf="$(
    curl -sS "${API_BASE}" -D - -o /dev/null \
      | awk '/DSPACE-XSRF-TOKEN/ {print $2}' \
      | tr -d '\r\n'
  )"
  [[ -n "${new_csrf}" ]] && CSRF="${new_csrf}" || true
}

get_schema_id() {
  local prefix="$1"
  http_get "${API_BASE}/core/metadataschemas?size=100" \
    | jq -r --arg p "${prefix}" '._embedded.metadataschemas[]? | select(.prefix == $p) | .id' 2>/dev/null || true
}

schema_exists() {
  local prefix="$1"
  http_get "${API_BASE}/core/metadataschemas?size=100" \
    | jq -r --arg p "${prefix}" '._embedded.metadataschemas[]? | select(.prefix == $p) | .prefix' 2>/dev/null || true
}

create_schema() {
  local name="$1"
  local namespace="$2"

  info "Schema: ${name}"

  local existing
  existing="$(schema_exists "${name}")"

  if [[ "${existing}" == "${name}" ]]; then
    warn "'${name}' ya existe"
    ((SKIPPED++)) || true
    return 0
  fi

  refresh_csrf

  local response
  response="$(
    curl -sS -X POST "${API_BASE}/core/metadataschemas" \
      -H "Content-Type: application/json" \
      -H "Authorization: ${TOKEN}" \
      -H "X-XSRF-TOKEN: ${CSRF}" \
      -H "Cookie: DSPACE-XSRF-COOKIE=${CSRF}" \
      -d "{\"prefix\":\"${name}\",\"namespace\":\"${namespace}\"}"
  )"

  if echo "${response}" | jq -e '.prefix' >/dev/null 2>&1; then
    log "Creado: ${name} → ${namespace}"
    ((CREATED++)) || true
  else
    warn "Error creando schema '${name}': $(echo "${response}" | jq -r '.message // .' 2>/dev/null | head -1)"
    ((ERRORS++)) || true
  fi
}

field_exists() {
  local schema="$1"
  local element="$2"
  local qualifier="${3:-}"
  local url="${API_BASE}/core/metadatafields/search/byFieldName?schema=${schema}&element=${element}&size=10"

  [[ -n "${qualifier}" ]] && url="${url}&qualifier=${qualifier}"

  local result
  result="$(
    http_get "${url}" \
      | jq -r --arg e "${element}" --arg q "${qualifier}" \
        '._embedded.metadatafields[]? | select(.element == $e and .qualifier == (if $q == "" then null else $q end)) | .element' \
      2>/dev/null || true
  )"

  [[ -n "${result}" ]]
}

create_field() {
  local schema="$1"
  local element="$2"
  local qualifier="${3:-}"
  local note="$4"

  local display_name="${schema}.${element}${qualifier:+.${qualifier}}"

  info "Campo: ${display_name}"

  if field_exists "${schema}" "${element}" "${qualifier}"; then
    warn "'${display_name}' ya existe"
    ((SKIPPED++)) || true
    return 0
  fi

  local schema_id
  schema_id="$(get_schema_id "${schema}")"

  if [[ -z "${schema_id}" ]]; then
    warn "Schema '${schema}' no encontrado"
    ((ERRORS++)) || true
    return 1
  fi

  refresh_csrf

  local payload
  if [[ -z "${qualifier}" ]]; then
    payload="{\"element\":\"${element}\",\"qualifier\":null,\"scopeNote\":\"${note}\"}"
  else
    payload="{\"element\":\"${element}\",\"qualifier\":\"${qualifier}\",\"scopeNote\":\"${note}\"}"
  fi

  local response
  response="$(
    curl -sS -X POST "${API_BASE}/core/metadatafields?schemaId=${schema_id}" \
      -H "Content-Type: application/json" \
      -H "Authorization: ${TOKEN}" \
      -H "X-XSRF-TOKEN: ${CSRF}" \
      -H "Cookie: DSPACE-XSRF-COOKIE=${CSRF}" \
      -d "${payload}"
  )"

  if echo "${response}" | jq -e '.element' >/dev/null 2>&1; then
    log "Creado: ${display_name}"
    ((CREATED++)) || true
  else
    warn "Error en '${display_name}': $(echo "${response}" | jq -r '.message // .' 2>/dev/null | head -1)"
    ((ERRORS++)) || true
  fi
}

logout() {
  [[ -n "${TOKEN}" && -n "${CSRF}" ]] || return 0

  curl -sS -X POST "${API_BASE}/authn/logout" \
    -H "Authorization: ${TOKEN}" \
    -H "X-XSRF-TOKEN: ${CSRF}" \
    -H "Cookie: DSPACE-XSRF-COOKIE=${CSRF}" >/dev/null 2>&1 || true
}

trap logout EXIT

header "Paso 1 — Autenticación"
authenticate

header "Paso 2 — Schemas"
create_schema "renati" "http://purl.org/pe-repo/renati#"
create_schema "thesis" "http://purl.org/pe-repo/thesis#"
sleep 1

header "Paso 3 — Campos renati.*"
create_field "renati" "author"     "dni"       "Número de documento DNI del autor."
create_field "renati" "author"     "cext"      "Número de carné de extranjería del autor."
create_field "renati" "author"     "pasaporte" "Número de pasaporte del autor."
create_field "renati" "author"     "cedula"    "Número de cédula del autor."

create_field "renati" "advisor"    "orcid"     "ORCID del asesor."
create_field "renati" "advisor"    "dni"       "Número de documento DNI del asesor."
create_field "renati" "advisor"    "cext"      "Número de carné de extranjería del asesor."
create_field "renati" "advisor"    "pasaporte" "Número de pasaporte del asesor."
create_field "renati" "advisor"    "cedula"    "Número de cédula del asesor."

create_field "renati" "type"       ""          "Tipo de trabajo de investigación."
create_field "renati" "level"      ""          "Grado académico o título profesional."
create_field "renati" "discipline" ""          "Código del programa."
create_field "renati" "juror"      ""          "Jurado."

header "Paso 4 — Campos thesis.*"
create_field "thesis" "degree" "name"       "Nombre del grado."
create_field "thesis" "degree" "discipline" "Nombre del programa."
create_field "thesis" "degree" "grantor"    "Institución otorgante del grado."

header "Paso 5 — Campos dc.* adicionales mínimos ALICIA"
create_field "dc" "contributor" "advisor"        "Asesor."
create_field "dc" "contributor" "editor"         "Editor."
create_field "dc" "publisher"   "country"        "País de publicación."
create_field "dc" "type"        "version"        "Versión de la publicación."
create_field "dc" "date"        "embargoEnd"     "Fecha de fin de embargo."
create_field "dc" "identifier"  "citation"       "Referencia bibliográfica."
create_field "dc" "identifier"  "doi"            "DOI."
create_field "dc" "identifier"  "isbn"           "ISBN."
create_field "dc" "relation"    "uri"            "Recurso relacionado."
create_field "dc" "relation"    "isPartOf"       "Recurso del cual forma parte."
create_field "dc" "subject"     "ocde"           "Campo del conocimiento OCDE."
create_field "dc" "rights"      "uri"            "Condición de licencia."
create_field "dc" "description" "sponsorship"    "Patrocinio."

header "Paso 6 — Verificación"
for schema in renati thesis dc; do
  existing="$(schema_exists "${schema}")"
  if [[ "${schema}" == "dc" ]]; then
    log "Schema base esperado: dc"
  elif [[ "${existing}" == "${schema}" ]]; then
    log "Schema: ${schema}"
  else
    warn "Schema: ${schema} no verificado"
  fi
done

for schema in renati thesis dc; do
  field_count="$(
    http_get "${API_BASE}/core/metadatafields/search/byFieldName?schema=${schema}&size=100" \
      | jq '._embedded.metadatafields | length' 2>/dev/null || echo "0"
  )"
  log "${schema}: ${field_count} campo(s)"
done

header "Etapa 11 — Completada"
echo "  Creados: ${CREATED} | Omitidos: ${SKIPPED} | Errores: ${ERRORS}"
echo "  Siguiente etapa: 12-vocabularios.sh"
echo "  Log: ${LOG_FILE}"

if [[ "${ERRORS}" -eq 0 ]]; then
  log "Listo"
else
  warn "${ERRORS} error(es)"
fi

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

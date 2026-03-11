#!/bin/bash
# =============================================================================
# SciBack — setup-alicia-schema.sh v2.0
# Registra schemas y campos ALICIA/RENATI via REST API (DSpace 7.6.6)
# Cambios v2.0: Fix namespace thesis → http://purl.org/pe-repo/thesis#
# =============================================================================
set -euo pipefail

ETAPA_INICIO=$(date +%s)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()   { echo -e "${CYAN}[→]${NC} $1"; }
header() {
  echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
}

ENV_FILE=".env.deploy"
if [[ "${1:-}" == "--env" ]]; then ENV_FILE="${2:-.env.deploy}"
elif [[ -n "${1:-}" && "${1}" != --* ]]; then ENV_FILE="$1"; fi
[[ -f "$ENV_FILE" ]] || error "No se encontró: $ENV_FILE"
source "$ENV_FILE"

for PKG in curl jq; do
  command -v "$PKG" &>/dev/null || { info "Instalando ${PKG}..."; apt-get install -y -q "$PKG"; }
done

API_BASE="http://localhost:8080/server/api"
ADMIN_EMAIL="${ADMIN_EMAIL:-repositorio@uniq.edu.pe}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Repo2026Test!}"
CREATED=0; SKIPPED=0; ERRORS=0; CSRF=""; TOKEN=""

LOG_FILE="/tmp/sciback-alicia-schema-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

header "SciBack — Setup Schema ALICIA/RENATI v2.0"
log "API: ${API_BASE} | Admin: ${ADMIN_EMAIL} | Log: ${LOG_FILE}"

authenticate() {
  info "Autenticando..."
  CSRF=$(curl -s "${API_BASE}" -D - | grep "DSPACE-XSRF-TOKEN" | awk '{print $2}' | tr -d '\r\n')
  [[ -n "$CSRF" ]] || error "No se pudo obtener CSRF — ¿Tomcat activo?"
  TOKEN=$(curl -s -X POST "${API_BASE}/authn/login" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "X-XSRF-TOKEN: ${CSRF}" -H "Cookie: DSPACE-XSRF-COOKIE=${CSRF}" \
    -d "user=${ADMIN_EMAIL}&password=${ADMIN_PASSWORD}" -D - \
    | grep -i "^Authorization:" | awk '{print $2" "$3}' | tr -d '\r\n')
  [[ -n "$TOKEN" ]] || error "Login fallido — verificar credenciales"
  log "Autenticación exitosa ✓"
}

refresh_csrf() {
  local N; N=$(curl -s "${API_BASE}" -D - | grep "DSPACE-XSRF-TOKEN" | awk '{print $2}' | tr -d '\r\n')
  [[ -n "$N" ]] && CSRF="$N" || true
}

get_schema_id() {
  curl -s -H "Authorization: ${TOKEN}" "${API_BASE}/core/metadataschemas?size=100" \
    | jq -r --arg p "$1" '._embedded.metadataschemas[] | select(.prefix == $p) | .id' 2>/dev/null || true
}

create_schema() {
  local NAME="$1" NS="$2"
  info "Schema: ${NAME}"
  local E; E=$(curl -s -H "Authorization: ${TOKEN}" "${API_BASE}/core/metadataschemas?size=100" \
    | jq -r --arg p "$NAME" '._embedded.metadataschemas[] | select(.prefix == $p) | .prefix' 2>/dev/null || true)
  if [[ "$E" == "$NAME" ]]; then warn "'${NAME}' ya existe"; ((SKIPPED++)) || true; return 0; fi
  refresh_csrf
  local R; R=$(curl -s -X POST "${API_BASE}/core/metadataschemas" \
    -H "Content-Type: application/json" -H "Authorization: ${TOKEN}" \
    -H "X-XSRF-TOKEN: ${CSRF}" -H "Cookie: DSPACE-XSRF-COOKIE=${CSRF}" \
    -d "{\"prefix\":\"${NAME}\",\"namespace\":\"${NS}\"}")
  if echo "$R" | jq -e '.prefix' &>/dev/null; then log "Creado: ${NAME} → ${NS}"; ((CREATED++)) || true
  else warn "Error: $(echo "$R" | jq -r '.message // .' 2>/dev/null | head -1)"; ((ERRORS++)) || true; fi
}

field_exists() {
  local S="$1" E="$2" Q="${3:-}"
  local U="${API_BASE}/core/metadatafields/search/byFieldName?schema=${S}&element=${E}&size=10"
  [[ -n "$Q" ]] && U="${U}&qualifier=${Q}"
  local R; R=$(curl -s -H "Authorization: ${TOKEN}" "$U" \
    | jq -r --arg e "$E" --arg q "${Q}" \
      '._embedded.metadatafields[] | select(.element == $e and .qualifier == (if $q == "" then null else $q end)) | .element' \
    2>/dev/null || true)
  [[ -n "$R" ]]
}

create_field() {
  local S="$1" E="$2" Q="${3:-}" NOTE="$4"
  local DISP="${S}.${E}${Q:+.${Q}}"
  info "Campo: ${DISP}"
  if field_exists "$S" "$E" "$Q"; then warn "'${DISP}' ya existe"; ((SKIPPED++)) || true; return 0; fi
  local SID; SID=$(get_schema_id "$S")
  [[ -n "$SID" ]] || { warn "Schema '${S}' no encontrado"; ((ERRORS++)) || true; return 1; }
  refresh_csrf
  local JSON
  [[ -z "$Q" ]] && JSON="{\"element\":\"${E}\",\"qualifier\":null,\"scopeNote\":\"${NOTE}\"}" \
                 || JSON="{\"element\":\"${E}\",\"qualifier\":\"${Q}\",\"scopeNote\":\"${NOTE}\"}"
  local R; R=$(curl -s -X POST "${API_BASE}/core/metadatafields?schemaId=${SID}" \
    -H "Content-Type: application/json" -H "Authorization: ${TOKEN}" \
    -H "X-XSRF-TOKEN: ${CSRF}" -H "Cookie: DSPACE-XSRF-COOKIE=${CSRF}" -d "$JSON")
  if echo "$R" | jq -e '.element' &>/dev/null; then log "Creado: ${DISP}"; ((CREATED++)) || true
  else warn "Error en '${DISP}': $(echo "$R" | jq -r '.message // .' 2>/dev/null | head -1)"; ((ERRORS++)) || true; fi
}

# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\033[0;36m  Tiempo estimado: ~1-2 min\033[0m"

header "Paso 1 — Autenticación"
authenticate

header "Paso 2 — Schemas"
create_schema "renati" "http://purl.org/pe-repo/renati#"
create_schema "thesis" "http://purl.org/pe-repo/thesis#"
sleep 1

header "Paso 3 — Campos renati.* (12)"
create_field "renati" "type"       ""                 "Tipo de recurso RENATI (purl.org/pe-repo/renati/type). Obligatorio ALICIA."
create_field "renati" "level"      ""                 "Nivel grado académico SUNEDU. Obligatorio ALICIA."
create_field "renati" "discipline" ""                 "Disciplina OCDE (purl.org/pe-repo/ocde/ford)."
create_field "renati" "advisor"    ""                 "Asesor de tesis. Formato: Apellidos, Nombres."
create_field "renati" "advisor"    "dni"              "DNI asesor (8 dígitos). Obligatorio ALICIA."
create_field "renati" "advisor"    "orcid"            "ORCID asesor (0000-0000-0000-0000)."
create_field "renati" "author"     "dni"              "DNI autor (8 dígitos). Obligatorio ALICIA."
create_field "renati" "author"     "orcid"            "ORCID autor (0000-0000-0000-0000)."
create_field "renati" "juror"      ""                 "Miembro del jurado. Repetible."
create_field "renati" "juror"      "dni"              "DNI jurado (8 dígitos)."
create_field "renati" "publisher"  "country"          "País editor ISO 3166. Perú: PE."
create_field "renati" "identifier" "orcidinstitution" "ORCID institucional."

header "Paso 4 — Campos thesis.* (4)"
create_field "thesis" "degree" "name"       "Nombre del grado académico."
create_field "thesis" "degree" "level"      "Nivel: Bachiller, Título, Segunda Esp., Maestría, Doctorado."
create_field "thesis" "degree" "discipline" "Especialidad académica."
create_field "thesis" "degree" "grantor"    "Institución otorgante."

header "Paso 5 — Campos dc.* adicionales (4)"
create_field "dc" "subject"     "ocde"       "Clasificación OCDE/FORD. Obligatorio ALICIA."
create_field "dc" "rights"      "uri"        "URI licencia CC. Obligatorio ALICIA."
create_field "dc" "description" "provenance" "Procedencia del depósito."
create_field "dc" "relation"    "uri"        "URI recurso relacionado."

header "Paso 6 — Verificación"
for S in "renati" "thesis"; do
  E=$(curl -s -H "Authorization: ${TOKEN}" "${API_BASE}/core/metadataschemas?size=100" \
    | jq -r --arg p "$S" '._embedded.metadataschemas[] | select(.prefix == $p) | .prefix' 2>/dev/null || true)
  [[ "$E" == "$S" ]] && log "Schema: ${S} ✓" || warn "Schema: ${S} ✗"
done
for SC in "renati" "thesis"; do
  FC=$(curl -s -H "Authorization: ${TOKEN}" \
    "${API_BASE}/core/metadatafields/search/byFieldName?schema=${SC}&size=100" \
    | jq '._embedded.metadatafields | length' 2>/dev/null || echo "0")
  log "${SC}: ${FC} campo(s)"
done

curl -s -X POST "${API_BASE}/authn/logout" \
  -H "Authorization: ${TOKEN}" -H "X-XSRF-TOKEN: ${CSRF}" \
  -H "Cookie: DSPACE-XSRF-COOKIE=${CSRF}" > /dev/null 2>&1 || true

header "✅ Schema ALICIA/RENATI v2.0 — Completado"
echo "  Creados: ${CREATED} | Omitidos: ${SKIPPED} | Errores: ${ERRORS}"
echo "  Próximo: sudo bash setup-vocabularies.sh"
echo "  Log: ${LOG_FILE}"
[[ "$ERRORS" -eq 0 ]] && log "Listo ✓" || warn "${ERRORS} error(es)"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

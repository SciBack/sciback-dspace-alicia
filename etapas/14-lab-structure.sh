#!/bin/bash
# =============================================================================
# SciBack — Etapa 14: Estructura inicial Lab (comunidades/colecciones)
# Crea jerarquía desde variables LAB_* definidas en .env.dspace.deploy
# =============================================================================
set -euo pipefail

ETAPA_INICIO=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"

if [[ -z "${LAB_STRUCTURE:-}" || -z "${LAB_ROOT_COMMUNITY:-}" || -z "${LAB_SUBCOMMUNITIES:-}" ]]; then
  [[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }
fi

[[ "${LAB_STRUCTURE:-false}" == "true" ]] || exit 99

DSPACE_DIR="${DSPACE_DIR:-/dspace}"
DSPACE_BIN="${DSPACE_DIR}/bin/dspace"
LOG_FILE="/tmp/sciback-lab-structure.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo ""
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 14 — Estructura inicial SciBack Lab\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~1-2 min\033[0m"

echo -e "\n\033[0;34m── 14.1 Validando prerrequisitos ─────────────────────────────\033[0m"
[[ -x "$DSPACE_BIN" ]] || { echo "[✗] No ejecutable: ${DSPACE_BIN}"; exit 1; }
[[ -n "${LAB_ROOT_COMMUNITY:-}" ]] || { echo "[✗] LAB_ROOT_COMMUNITY vacío"; exit 1; }
[[ -n "${LAB_SUBCOMMUNITIES:-}" ]] || { echo "[✗] LAB_SUBCOMMUNITIES vacío"; exit 1; }

normalize_name() {
  local input="$1"
  echo "$input" \
    | tr '[:lower:]' '[:upper:]' \
    | sed -E 's/[^A-Z0-9]+/_/g; s/_+/_/g; s/^_+|_+$//g'
}

run_dspace_try() {
  local output
  output=$(su - dspace -c "$1" 2>&1) && { echo "$output"; return 0; }
  echo "$output"
  return 1
}

find_handle_in_output() {
  local txt="$1"
  local h
  h=$(echo "$txt" | grep -Eo "${HANDLE_PREFIX:-20\\.500\\.[0-9A-Z]+}/[0-9]+" | head -1 || true)
  echo "$h"
}

create_community() {
  local name="$1"
  local parent_handle="${2:-}"
  local output=""
  local handle=""

  echo -e "\033[0;36m[→]\033[0m Comunidad: ${name}"

  if [[ -n "$parent_handle" ]]; then
    output=$(run_dspace_try "'${DSPACE_BIN}' create-community --parent '${parent_handle}' --name '${name}'") || \
    output=$(run_dspace_try "'${DSPACE_BIN}' create-community -p '${parent_handle}' -n '${name}'") || \
    output=$(run_dspace_try "printf '%s\n' '${name}' | '${DSPACE_BIN}' create-community -p '${parent_handle}'") || true
  else
    output=$(run_dspace_try "'${DSPACE_BIN}' create-community --name '${name}'") || \
    output=$(run_dspace_try "'${DSPACE_BIN}' create-community -n '${name}'") || \
    output=$(run_dspace_try "printf '%s\n' '${name}' | '${DSPACE_BIN}' create-community") || true
  fi

  if echo "$output" | grep -Eiq 'already exists|ya existe|duplicate|duplicado'; then
    echo -e "\033[1;33m[!]\033[0m Comunidad ya existe: ${name}"
    echo ""
    return 0
  fi

  handle=$(find_handle_in_output "$output")
  if [[ -n "$handle" ]]; then
    echo -e "\033[0;32m[✓]\033[0m Comunidad creada: ${name} (${handle})"
    echo "$handle"
    return 0
  fi

  echo "$output" | grep -Eiq 'created|creado|success|éxito' && {
    echo -e "\033[0;32m[✓]\033[0m Comunidad creada: ${name}"
    echo ""
    return 0
  }

  echo -e "\033[1;33m[!]\033[0m No se pudo confirmar creación de comunidad '${name}'. Continuando de forma idempotente."
  echo ""
  return 0
}

create_collection() {
  local name="$1"
  local parent_handle="$2"
  local output=""

  echo -e "\033[0;36m[→]\033[0m Colección: ${name}"

  output=$(run_dspace_try "'${DSPACE_BIN}' create-collection --parent '${parent_handle}' --name '${name}'") || \
  output=$(run_dspace_try "'${DSPACE_BIN}' create-collection -p '${parent_handle}' -n '${name}'") || \
  output=$(run_dspace_try "printf '%s\n' '${name}' | '${DSPACE_BIN}' create-collection -p '${parent_handle}'") || true

  if echo "$output" | grep -Eiq 'already exists|ya existe|duplicate|duplicado'; then
    echo -e "\033[1;33m[!]\033[0m Colección ya existe: ${name}"
    return 0
  fi

  if echo "$output" | grep -Eiq 'created|creado|success|éxito'; then
    echo -e "\033[0;32m[✓]\033[0m Colección creada: ${name}"
    return 0
  fi

  echo -e "\033[1;33m[!]\033[0m No se pudo confirmar creación de colección '${name}'. Continuando de forma idempotente."
  return 0
}

echo -e "\n\033[0;34m── 14.2 Creando comunidad raíz ─────────────────────────────\033[0m"
ROOT_HANDLE="$(create_community "${LAB_ROOT_COMMUNITY}" | tail -1)"

echo -e "\n\033[0;34m── 14.3 Creando subcomunidades y colecciones ──────────────\033[0m"
IFS='|' read -r -a SUBS <<< "${LAB_SUBCOMMUNITIES}"

for SUB in "${SUBS[@]}"; do
  SUB_TRIMMED="$(echo "$SUB" | sed -E 's/^\s+|\s+$//g')"
  [[ -n "$SUB_TRIMMED" ]] || continue

  NORM="$(normalize_name "$SUB_TRIMMED")"
  VAR_NAME="LAB_COLLECTIONS__${NORM}"
  COLLECTIONS="${!VAR_NAME:-}"

  SUB_HANDLE=""
  if [[ -n "$ROOT_HANDLE" ]]; then
    SUB_HANDLE="$(create_community "$SUB_TRIMMED" "$ROOT_HANDLE" | tail -1)"
  else
    create_community "$SUB_TRIMMED" >/dev/null || true
  fi

  if [[ -z "$COLLECTIONS" ]]; then
    echo -e "\033[1;33m[!]\033[0m ${VAR_NAME} no definido; subcomunidad sin colecciones."
    continue
  fi

  IFS='|' read -r -a COLS <<< "$COLLECTIONS"
  for COL in "${COLS[@]}"; do
    COL_TRIMMED="$(echo "$COL" | sed -E 's/^\s+|\s+$//g')"
    [[ -n "$COL_TRIMMED" ]] || continue

    if [[ -n "$SUB_HANDLE" ]]; then
      create_collection "$COL_TRIMMED" "$SUB_HANDLE"
    else
      echo -e "\033[1;33m[!]\033[0m Sin handle de subcomunidad '${SUB_TRIMMED}'. Colección '${COL_TRIMMED}' omitida de forma segura."
    fi
  done
done

echo -e "\n\033[0;34m── 14.4 Reiniciando Tomcat ─────────────────────────────────\033[0m"
systemctl restart tomcat9
sleep 3

echo -e "\033[0;32m[✓]\033[0m Estructura Lab procesada. Log: ${LOG_FILE}"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

#!/usr/bin/env bash
# =============================================================================
# SciBack — theme-manager.sh
# Dispatcher modular para personalización de theme en DSpace 7.6.6
# Ejecuta etapas del theme-manager de forma completa o parcial
# =============================================================================

set -Eeuo pipefail

readonly TM_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly THEME_DIR="${TM_PROJECT_DIR}/theme-manager"
readonly COMMON_LIB="${THEME_DIR}/lib/common.sh"

ENV_FILE="${ENV_FILE:-${TM_PROJECT_DIR}/.env.theme-manager}"

if [[ ! -f "${COMMON_LIB}" ]]; then
  echo "[ERROR] No se encontró ${COMMON_LIB}"
  exit 1
fi

# shellcheck disable=SC1091
source "${COMMON_LIB}"

register_error_trap

readonly STAGES=(
  "01-load-config"
  "02-create-theme-copy"
  "03-register-theme"
  "04-validate-paths"
  "05-apply-colors"
  "06-apply-logo"
  "07-apply-banner"
  "08-apply-footer"
  "09-apply-menus"
  "10-apply-policies"
  "11-build-frontend"
  "12-restart-pm2"
  "13-summary"
)

usage() {
  cat <<USAGE
Uso:
  bash theme-manager.sh [--env /ruta/.env.theme-manager]
                        [--stage 03-register-theme]
                        [--from-stage 05-apply-colors]
                        [--list-stages]

Opciones:
  --env <path>         Ruta del archivo de entorno
                       (default: ${TM_PROJECT_DIR}/.env.theme-manager)

  --stage <name>       Ejecuta solo una etapa
                       Ej: --stage 03-register-theme
                           --stage 03

  --from-stage <name>  Ejecuta desde una etapa hasta el final
                       Ej: --from-stage 05-apply-colors
                           --from-stage 05

  --list-stages        Lista etapas disponibles
  -h, --help           Muestra esta ayuda
USAGE
}

resolve_stage() {
  local input="$1"
  local stage

  for stage in "${STAGES[@]}"; do
    if [[ "${stage}" == "${input}" || "${stage}" == "${input}-"* ]]; then
      printf '%s\n' "${stage}"
      return 0
    fi
  done

  return 1
}

run_stage() {
  local stage_name="$1"
  local stage_script="${THEME_DIR}/stages/${stage_name}.sh"

  [[ -f "${stage_script}" ]] || die "No existe etapa: ${stage_name}"

  log_info "Ejecutando etapa ${stage_name}"
  ENV_FILE="${ENV_FILE}" bash "${stage_script}"
}

list_stages() {
  printf '%s\n' "${STAGES[@]}"
}

SELECTED_STAGE=""
FROM_STAGE=""

while (($#)); do
  case "$1" in
    --env)
      shift
      ENV_FILE="${1:-}"
      [[ -n "${ENV_FILE}" ]] || die "Debes indicar una ruta tras --env"
      ;;
    --stage)
      shift
      SELECTED_STAGE="${1:-}"
      [[ -n "${SELECTED_STAGE}" ]] || die "Debes indicar una etapa tras --stage"
      ;;
    --from-stage)
      shift
      FROM_STAGE="${1:-}"
      [[ -n "${FROM_STAGE}" ]] || die "Debes indicar una etapa tras --from-stage"
      ;;
    --list-stages)
      list_stages
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Argumento no reconocido: $1"
      ;;
  esac
  shift
done

[[ -z "${SELECTED_STAGE}" || -z "${FROM_STAGE}" ]] || die "No puedes usar --stage y --from-stage al mismo tiempo"
[[ -f "${ENV_FILE}" ]] || die "No existe el archivo de entorno: ${ENV_FILE}"

export ENV_FILE
export TM_PROJECT_DIR
export THEME_DIR

ensure_dir "${THEME_DIR}/logs"
ensure_dir "${THEME_DIR}/backups"

log_info "══════════════════════════════════════════════════════════"
log_info "SciBack — Theme Manager DSpace 7.6.6"
log_info "Archivo de entorno: ${ENV_FILE}"
log_info "Directorio base: ${THEME_DIR}"
log_info "══════════════════════════════════════════════════════════"

if [[ -n "${SELECTED_STAGE}" ]]; then
  resolved="$(resolve_stage "${SELECTED_STAGE}")" || die "Etapa inválida: ${SELECTED_STAGE}"
  run_stage "${resolved}"
elif [[ -n "${FROM_STAGE}" ]]; then
  resolved_from="$(resolve_stage "${FROM_STAGE}")" || die "Etapa inválida: ${FROM_STAGE}"

  start_running=false
  total=${#STAGES[@]}
  current=0

  for stage in "${STAGES[@]}"; do
    ((current+=1)) || true

    if [[ "${stage}" == "${resolved_from}" ]]; then
      start_running=true
    fi

    if [[ "${start_running}" == "true" ]]; then
      log_info "──────────────────────────────────────────────────────────"
      log_info "Etapa ${current}/${total}: ${stage}"
      log_info "──────────────────────────────────────────────────────────"
      run_stage "${stage}"
    fi
  done
else
  total=${#STAGES[@]}
  current=0

  for stage in "${STAGES[@]}"; do
    ((current+=1)) || true
    log_info "──────────────────────────────────────────────────────────"
    log_info "Etapa ${current}/${total}: ${stage}"
    log_info "──────────────────────────────────────────────────────────"
    run_stage "${stage}"
  done
fi

log_info "Ejecución theme-manager completada"

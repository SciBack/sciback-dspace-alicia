#!/usr/bin/env bash
set -Eeuo pipefail

TM_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="${TM_PROJECT_DIR}/theme-manager"

ENV_FILE="${ENV_FILE:-${TM_PROJECT_DIR}/.env.theme-manager}"

source "${THEME_DIR}/lib/common.sh"

register_error_trap

STAGES=(
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
  bash theme-manager.sh [--env /ruta/.env] [--stage 03-register-theme]

Opciones:
  --env <path>       Ruta del archivo de entorno (default: ${TM_PROJECT_DIR}/.env.theme-manager)
  --stage <name>     Ejecuta una etapa individual (por nombre o prefijo numérico)
  --list-stages      Lista etapas disponibles
USAGE
}

run_stage() {
  local stage_name="$1"
  local stage_script="${THEME_DIR}/stages/${stage_name}.sh"
  [[ -f "${stage_script}" ]] || die "No existe etapa: ${stage_name}"
  log_info "Ejecutando etapa ${stage_name}"
  ENV_FILE="${ENV_FILE}" bash "${stage_script}"
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

SELECTED_STAGE=""
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
    --list-stages)
      printf '%s\n' "${STAGES[@]}"
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

ensure_dir "${THEME_DIR}/logs"
ensure_dir "${THEME_DIR}/backups"

if [[ -n "${SELECTED_STAGE}" ]]; then
  resolved="$(resolve_stage "${SELECTED_STAGE}")" || die "Etapa inválida: ${SELECTED_STAGE}"
  run_stage "${resolved}"
else
  for stage in "${STAGES[@]}"; do
    run_stage "${stage}"
  done
fi

log_info "Ejecución theme-manager completada"

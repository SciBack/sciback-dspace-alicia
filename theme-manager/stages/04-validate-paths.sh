#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 04: Validación de rutas
# =============================================================================

set -Eeuo pipefail

readonly STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/fs.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/dspace-theme.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/ui.sh"

register_error_trap

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"

print_header "Etapa 04 — Validación de rutas"

load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths

if bool_true "${STRICT_PATH_VALIDATION:-true}"; then
  require_path_exists "${DSPACE_TARGET_THEME_DIR}" "DSPACE_TARGET_THEME_DIR"
  log_info "Validación estricta activa: theme destino encontrado"
else
  log_warn "STRICT_PATH_VALIDATION=false; se omite validación estricta de DSPACE_TARGET_THEME_DIR"
fi

log_info "Frontend: ${DSPACE_FRONTEND_DIR}"
log_info "Theme base: ${DSPACE_BASE_THEME_DIR}"
log_info "Theme destino: ${DSPACE_TARGET_THEME_DIR}"
log_info "Config app: ${DSPACE_DEFAULT_APP_CONFIG_FILE}"

log_info "Validación de rutas completada correctamente"

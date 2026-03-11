#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 01: Carga y validación de configuración
# =============================================================================

set -Eeuo pipefail

readonly STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/dspace-theme.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/ui.sh"

register_error_trap

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"

print_header "Etapa 01 — Carga de configuración"

load_env_file "${ENV_FILE}"
validate_config_vars

log_info "Configuración cargada correctamente desde ${ENV_FILE}"
log_info "Theme base: ${DSPACE_BASE_THEME_NAME}"
log_info "Theme destino: ${DSPACE_TARGET_THEME_NAME}"
log_info "Frontend: ${DSPACE_FRONTEND_DIR}"

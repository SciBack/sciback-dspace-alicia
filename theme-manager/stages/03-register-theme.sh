#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 03: Registrar theme en default-app-config.ts
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

print_header "Etapa 03 — Registrar theme"

load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths

log_info "Archivo de configuración: ${DSPACE_DEFAULT_APP_CONFIG_FILE}"
log_info "Theme destino: ${DSPACE_TARGET_THEME_NAME}"
log_info "Extiende de: ${DSPACE_THEME_EXTENDS}"

register_theme_in_config

log_info "Registro de theme completado correctamente"

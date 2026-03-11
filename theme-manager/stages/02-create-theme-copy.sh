#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 02: Crear copia del theme base
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

print_header "Etapa 02 — Crear copia del theme base"

load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths

log_info "Theme base: ${DSPACE_BASE_THEME_DIR}"
log_info "Theme destino: ${DSPACE_TARGET_THEME_DIR}"

create_theme_copy

log_info "Copia de theme completada correctamente"

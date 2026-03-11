#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/dspace-theme.sh"
source "${ROOT_DIR}/lib/fs.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"
load_env_file "${ENV_FILE}"
validate_config_vars

validate_dspace_paths
if bool_true "${STRICT_PATH_VALIDATION:-true}"; then
  require_path_exists "${DSPACE_TARGET_THEME_DIR}" "DSPACE_TARGET_THEME_DIR"
fi

log_info "Validación de rutas completada"

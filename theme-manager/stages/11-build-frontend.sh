#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/dspace-theme.sh"
source "${ROOT_DIR}/lib/ui.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.dspace.theme-manager}"
load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths
require_commands yarn

cd "${DSPACE_FRONTEND_DIR}"
run_with_spinner "Compilando frontend (${DSPACE_YARN_BUILD_COMMAND})" bash -lc "${DSPACE_YARN_BUILD_COMMAND}"
log_info "Build frontend completado"

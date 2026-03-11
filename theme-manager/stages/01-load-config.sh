#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${ROOT_DIR}/lib/common.sh"
# shellcheck source=lib/dspace-theme.sh
source "${ROOT_DIR}/lib/dspace-theme.sh"

register_error_trap

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.dspace.theme-manager}"
load_env_file "${ENV_FILE}"
validate_config_vars

log_info "Configuración cargada correctamente desde ${ENV_FILE}"

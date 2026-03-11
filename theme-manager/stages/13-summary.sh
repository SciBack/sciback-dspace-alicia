#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.dspace.theme-manager}"
load_env_file "${ENV_FILE}"

cat <<MSG
Theme manager finalizado.
Perfil: ${DSPACE_THEME_PROFILE:-n/a}
Theme destino: ${DSPACE_TARGET_THEME_NAME}
Ruta theme: ${DSPACE_TARGET_THEME_DIR}
Config: ${DSPACE_DEFAULT_APP_CONFIG_FILE}
Log: ${LOG_FILE}
MSG

log_info "Resumen emitido"

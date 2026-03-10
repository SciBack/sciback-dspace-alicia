#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/fs.sh"
init_trap

require_dir "${DSPACE_FRONTEND_DIR}"
require_dir "${DSPACE_BASE_THEME_DIR}"
require_dir "${DSPACE_TARGET_THEME_DIR}"
require_file "${DSPACE_DEFAULT_APP_CONFIG_FILE}"

[[ -f "${DSPACE_THEME_LOGO_SOURCE}" ]] || log_warn "Logo fuente no encontrado: ${DSPACE_THEME_LOGO_SOURCE}"
[[ -f "${DSPACE_THEME_BANNER_SOURCE}" ]] || log_warn "Banner fuente no encontrado: ${DSPACE_THEME_BANNER_SOURCE}"

require_command yarn
if [[ "${AUTO_RESTART_ON_FULL_RUN}" == "true" ]]; then
  require_command pm2
fi
log_info "Validación de rutas/dependencias completada"

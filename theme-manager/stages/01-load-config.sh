#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=theme-manager/lib/fs.sh
source "${ROOT_DIR}/lib/fs.sh"
init_trap

ensure_dir "${DSPACE_THEME_WORKDIR}"
ensure_dir "${DSPACE_THEME_LOG_DIR}"
ensure_dir "${DSPACE_THEME_BACKUP_DIR}"
log_info "Configuración cargada desde: ${THEME_MANAGER_ENV_FILE:-desconocido}"
log_info "Perfil: ${DSPACE_THEME_PROFILE}"
log_info "Directorio frontend: ${DSPACE_FRONTEND_DIR}"

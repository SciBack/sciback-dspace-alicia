#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/fs.sh"
init_trap

require_dir "${DSPACE_BASE_THEME_DIR}"
log_info "Theme base: ${DSPACE_BASE_THEME_DIR}"
log_info "Theme destino: ${DSPACE_TARGET_THEME_DIR}"

if [[ -d "${DSPACE_TARGET_THEME_DIR}" ]]; then
  if [[ "${OVERWRITE_EXISTING_THEME}" == "true" ]]; then
    log_warn "Theme destino existe. OVERWRITE_EXISTING_THEME=true, recreando."
    [[ "${CREATE_BACKUPS}" == "true" ]] && backup_dir "${DSPACE_TARGET_THEME_DIR}"
    rm -rf "${DSPACE_TARGET_THEME_DIR}"
    cp -a "${DSPACE_BASE_THEME_DIR}" "${DSPACE_TARGET_THEME_DIR}"
    log_info "Theme recreado desde base."
  else
    log_warn "Theme destino ya existe. Se reutiliza sin cambios."
  fi
else
  cp -a "${DSPACE_BASE_THEME_DIR}" "${DSPACE_TARGET_THEME_DIR}"
  log_info "Theme creado correctamente."
fi

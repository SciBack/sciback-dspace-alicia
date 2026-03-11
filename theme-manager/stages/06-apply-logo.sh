#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/fs.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"
load_env_file "${ENV_FILE}"

ensure_dir "$(dirname "${DSPACE_THEME_LOGO_SOURCE}")"
ensure_dir "$(dirname "${DSPACE_THEME_LOGO_TARGET}")"

if [[ -f "${DSPACE_THEME_LOGO_SOURCE}" ]]; then
  copy_file_safe "${DSPACE_THEME_LOGO_SOURCE}" "${DSPACE_THEME_LOGO_TARGET}"
else
  log_warn "Logo no encontrado en ${DSPACE_THEME_LOGO_SOURCE} — omitiendo. Colocar el archivo y re-ejecutar esta etapa."
fi

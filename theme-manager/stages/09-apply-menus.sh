#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/fs.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"
load_env_file "${ENV_FILE}"

MENU_FILE="${DSPACE_TARGET_THEME_DIR}/components/menu/theme-menu-flags.ts"
ensure_dir "$(dirname "${MENU_FILE}")"

cat > "${MENU_FILE}" <<TS
// Generado por theme-manager para toggles de menú
export const THEME_MENU_FLAGS = {
  aliciaPolicy: ${ENABLE_ALICIA_POLICY_MENU:-true},
  privacy: ${ENABLE_PRIVACY_MENU:-true},
  terms: ${ENABLE_TERMS_MENU:-true},
};
TS

log_info "Configuración de menú aplicada en ${MENU_FILE}"

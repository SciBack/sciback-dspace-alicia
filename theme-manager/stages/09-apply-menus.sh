#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 09: Aplicar flags de menú
# =============================================================================

set -Eeuo pipefail

readonly STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/fs.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/dspace-theme.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/ui.sh"

register_error_trap

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"

print_header "Etapa 09 — Aplicar flags de menú"

load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths

MENU_FILE="${DSPACE_TARGET_THEME_DIR}/components/menu/theme-menu-flags.ts"
BACKUP_DIR="${ROOT_DIR}/backups"

ensure_dir "$(dirname "${MENU_FILE}")"
ensure_dir "${BACKUP_DIR}"

if bool_true "${CREATE_BACKUPS:-true}" && [[ -f "${MENU_FILE}" ]]; then
  backup_file "${MENU_FILE}" "${BACKUP_DIR}"
fi

cat > "${MENU_FILE}" <<TS
// Generado por SciBack theme-manager para toggles de menú
export const THEME_MENU_FLAGS = {
  aliciaPolicy: ${ENABLE_ALICIA_POLICY_MENU:-true},
  privacy: ${ENABLE_PRIVACY_MENU:-true},
  terms: ${ENABLE_TERMS_MENU:-true},
};
TS

log_info "Configuración de menú aplicada correctamente"
log_info "Archivo: ${MENU_FILE}"
log_info "aliciaPolicy: ${ENABLE_ALICIA_POLICY_MENU:-true}"
log_info "privacy: ${ENABLE_PRIVACY_MENU:-true}"
log_info "terms: ${ENABLE_TERMS_MENU:-true}"

#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 10: Aplicar configuración de políticas
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

print_header "Etapa 10 — Aplicar políticas"

load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths

POLICY_FILE="${DSPACE_TARGET_THEME_DIR}/assets/policies.json"
BACKUP_DIR="${ROOT_DIR}/backups"

ensure_dir "$(dirname "${POLICY_FILE}")"
ensure_dir "${BACKUP_DIR}"

if bool_true "${CREATE_BACKUPS:-true}" && [[ -f "${POLICY_FILE}" ]]; then
  backup_file "${POLICY_FILE}" "${BACKUP_DIR}"
fi

cat > "${POLICY_FILE}" <<JSON
{
  "aliciaPolicyEnabled": ${ENABLE_ALICIA_POLICY_MENU:-true},
  "privacyEnabled": ${ENABLE_PRIVACY_MENU:-true},
  "termsEnabled": ${ENABLE_TERMS_MENU:-true}
}
JSON

log_info "Políticas aplicadas correctamente"
log_info "Archivo: ${POLICY_FILE}"
log_info "aliciaPolicyEnabled: ${ENABLE_ALICIA_POLICY_MENU:-true}"
log_info "privacyEnabled: ${ENABLE_PRIVACY_MENU:-true}"
log_info "termsEnabled: ${ENABLE_TERMS_MENU:-true}"

#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/fs.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.dspace.theme-manager}"
load_env_file "${ENV_FILE}"

POLICY_FILE="${DSPACE_TARGET_THEME_DIR}/assets/policies.json"
ensure_dir "$(dirname "${POLICY_FILE}")"

cat > "${POLICY_FILE}" <<JSON
{
  "aliciaPolicyEnabled": ${ENABLE_ALICIA_POLICY_MENU:-true},
  "privacyEnabled": ${ENABLE_PRIVACY_MENU:-true},
  "termsEnabled": ${ENABLE_TERMS_MENU:-true}
}
JSON

log_info "Políticas configuradas en ${POLICY_FILE}"

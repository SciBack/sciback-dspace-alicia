#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/dspace-theme.sh"
init_trap

require_file "${DSPACE_DEFAULT_APP_CONFIG_FILE}"
ensure_theme_registered "${DSPACE_DEFAULT_APP_CONFIG_FILE}"
log_info "Activación finalizada para ${DSPACE_TARGET_THEME_NAME}"

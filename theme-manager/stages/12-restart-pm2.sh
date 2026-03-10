#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/fs.sh"
init_trap

require_command pm2
if [[ "${DSPACE_PM2_APP_NAME}" == "all" ]]; then
  run_as_configured_user "pm2 restart all"
else
  run_as_configured_user "pm2 restart ${DSPACE_PM2_APP_NAME}"
fi
log_info "PM2 reiniciado (${DSPACE_PM2_APP_NAME})"

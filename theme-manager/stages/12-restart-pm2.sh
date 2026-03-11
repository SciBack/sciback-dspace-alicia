#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.dspace.theme-manager}"
load_env_file "${ENV_FILE}"
require_commands pm2 sudo

sudo -u "${DSPACE_RUN_AS_USER}" pm2 restart "${DSPACE_PM2_APP_NAME}"
log_info "PM2 reiniciado para app ${DSPACE_PM2_APP_NAME} como ${DSPACE_RUN_AS_USER}"

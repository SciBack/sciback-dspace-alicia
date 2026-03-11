#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"

register_error_trap

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"
load_env_file "${ENV_FILE}"

require_commands sudo

RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
PM2_APP_NAME="${DSPACE_PM2_APP_NAME:-dspace}"

log_info "Reiniciando PM2 para app ${PM2_APP_NAME} como ${RUN_USER}"

sudo -u "${RUN_USER}" bash -lc "
  set -Eeuo pipefail

  export NVM_DIR=\"\$HOME/.nvm\"
  if [[ -s \"\$NVM_DIR/nvm.sh\" ]]; then
    # shellcheck disable=SC1090
    source \"\$NVM_DIR/nvm.sh\"
  else
    echo '[ERROR] No se encontró nvm.sh en \$NVM_DIR'
    exit 1
  fi

  if ! command -v pm2 >/dev/null 2>&1; then
    echo '[ERROR] pm2 no está disponible en el entorno de ${RUN_USER}'
    exit 1
  fi

  pm2 restart '${PM2_APP_NAME}'
  pm2 save
"

log_info "PM2 reiniciado correctamente para app ${PM2_APP_NAME} como ${RUN_USER}"

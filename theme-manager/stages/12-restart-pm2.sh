#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 12: Reiniciar PM2
# =============================================================================

set -Eeuo pipefail

readonly STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/ui.sh"

register_error_trap

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"

print_header "Etapa 12 — Reiniciar PM2"

load_env_file "${ENV_FILE}"

require_commands sudo bash

RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
PM2_APP_NAME="${DSPACE_PM2_APP_NAME:-all}"

log_info "Usuario PM2 : ${RUN_USER}"
log_info "App PM2     : ${PM2_APP_NAME}"

run_as_dspace_user "
  set -Eeuo pipefail

  export NVM_DIR=\"\$HOME/.nvm\"

  if [[ -s \"\$NVM_DIR/nvm.sh\" ]]; then
    # shellcheck disable=SC1090
    source \"\$NVM_DIR/nvm.sh\"
  else
    echo '[ERROR] No se encontró nvm.sh en '\$NVM_DIR
    exit 1
  fi

  if ! command -v pm2 >/dev/null 2>&1; then
    echo '[ERROR] pm2 no está disponible en el entorno del usuario'
    exit 1
  fi

  echo '[INFO] Estado previo de PM2:'
  pm2 list

  echo '[INFO] Reiniciando aplicación PM2...'
  pm2 restart '${PM2_APP_NAME}'

  echo '[INFO] Guardando estado PM2...'
  pm2 save

  echo '[INFO] Estado final de PM2:'
  pm2 list
"

log_info "PM2 reiniciado correctamente para app ${PM2_APP_NAME}"

#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 11: Compilar frontend Angular SSR
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

print_header "Etapa 11 — Compilar frontend"

load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths

require_commands sudo bash

BUILD_CMD="${DSPACE_YARN_BUILD_COMMAND:-yarn build:ssr}"
NODE_OPTS="${DSPACE_NODE_OPTIONS:---max-old-space-size=6144}"
RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
FRONTEND_DIR="${DSPACE_FRONTEND_DIR:-/home/dspace/frontend}"
THEME_NAME="${DSPACE_TARGET_THEME_NAME:-sciback_theme_dspace7}"
DIST_DIR="${FRONTEND_DIR}/dist/browser"

require_dir_exists "${FRONTEND_DIR}" "DSPACE_FRONTEND_DIR"

log_info "Usuario       : ${RUN_USER}"
log_info "Frontend dir  : ${FRONTEND_DIR}"
log_info "Build command : ${BUILD_CMD}"
log_info "NODE_OPTIONS  : ${NODE_OPTS}"
log_info "Theme name    : ${THEME_NAME}"

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

  cd '${FRONTEND_DIR}'
  export NODE_OPTIONS='${NODE_OPTS}'

  echo '[INFO] Node version:'
  node -v

  echo '[INFO] Yarn version:'
  yarn -v

  echo '[INFO] Ejecutando build del frontend...'
  ${BUILD_CMD}
"

log_info "Build frontend completado"

print_step "Verificando artefactos de salida"

require_dir_exists "${DIST_DIR}" "directorio de salida del build"

run_as_dspace_user "
  set -Eeuo pipefail

  if [[ -f '${DIST_DIR}/dspace-theme.css' && ! -f '${DIST_DIR}/${THEME_NAME}-theme.css' ]]; then
    cp '${DIST_DIR}/dspace-theme.css' '${DIST_DIR}/${THEME_NAME}-theme.css'
    echo '[INFO] CSS del theme copiado: ${THEME_NAME}-theme.css'
  elif [[ -f '${DIST_DIR}/${THEME_NAME}-theme.css' ]]; then
    echo '[INFO] CSS del theme ya existe: ${THEME_NAME}-theme.css'
  else
    echo '[WARN] No se encontró dspace-theme.css en ${DIST_DIR}'
  fi

  if [[ -f '${FRONTEND_DIR}/dist/server/main.js' ]]; then
    echo '[INFO] SSR server generado correctamente: dist/server/main.js'
  else
    echo '[ERROR] No se encontró dist/server/main.js'
    exit 1
  fi
"

log_info "Etapa 11 finalizada correctamente"

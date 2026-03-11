#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.dspace.theme-manager}"

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

BUILD_CMD="${DSPACE_YARN_BUILD_COMMAND:-yarn build}"
NODE_OPTS="${DSPACE_NODE_OPTIONS:---max-old-space-size=6144}"
RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
FRONTEND_DIR="${DSPACE_FRONTEND_DIR:-/home/dspace/frontend}"
THEME_NAME="${DSPACE_TARGET_THEME_NAME:-sciback_theme_dspace7}"
DIST_DIR="${FRONTEND_DIR}/dist/browser"

echo "[INFO] Compilando frontend (${BUILD_CMD}) con NODE_OPTIONS=${NODE_OPTS}"

sudo -u "${RUN_USER}" bash -lc "
  cd '${FRONTEND_DIR}' &&
  export NODE_OPTIONS='${NODE_OPTS}' &&
  ${BUILD_CMD}
"

echo "[INFO] Build frontend completado"

echo "[INFO] Verificando CSS del theme..."

sudo -u "${RUN_USER}" bash -lc "
  if [[ -f '${DIST_DIR}/dspace-theme.css' && ! -f '${DIST_DIR}/${THEME_NAME}-theme.css' ]]; then
    cp '${DIST_DIR}/dspace-theme.css' '${DIST_DIR}/${THEME_NAME}-theme.css'
    echo '[INFO] CSS del theme copiado: ${THEME_NAME}-theme.css'
  else
    echo '[INFO] CSS del theme ya existe'
  fi
"

echo "[INFO] Etapa 11 finalizada correctamente"

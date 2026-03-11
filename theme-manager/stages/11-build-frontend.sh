#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Cargar utilidades comunes del theme-manager
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"

# Si no viene ENV_FILE definido externamente, usar el esperado por el proyecto
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[ERROR] No se encontró el archivo de entorno: ${ENV_FILE}"
  exit 1
fi

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

if [[ ! -d "${FRONTEND_DIR}" ]]; then
  echo "[ERROR] No existe el directorio del frontend: ${FRONTEND_DIR}"
  exit 1
fi

echo "[INFO] Iniciando compilación del frontend"
echo "[INFO] Usuario       : ${RUN_USER}"
echo "[INFO] Frontend dir  : ${FRONTEND_DIR}"
echo "[INFO] Build command : ${BUILD_CMD}"
echo "[INFO] NODE_OPTIONS  : ${NODE_OPTS}"
echo "[INFO] Theme name    : ${THEME_NAME}"

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

  cd '${FRONTEND_DIR}'
  export NODE_OPTIONS='${NODE_OPTS}'

  echo '[INFO] Node version:'
  node -v

  echo '[INFO] Yarn version:'
  yarn -v

  echo '[INFO] Ejecutando build...'
  ${BUILD_CMD}
"

echo "[INFO] Build frontend completado"

echo "[INFO] Verificando CSS del theme..."

sudo -u "${RUN_USER}" bash -lc "
  set -Eeuo pipefail

  if [[ ! -d '${DIST_DIR}' ]]; then
    echo '[ERROR] No existe el directorio de salida del build: ${DIST_DIR}'
    exit 1
  fi

  if [[ -f '${DIST_DIR}/dspace-theme.css' && ! -f '${DIST_DIR}/${THEME_NAME}-theme.css' ]]; then
    cp '${DIST_DIR}/dspace-theme.css' '${DIST_DIR}/${THEME_NAME}-theme.css'
    echo '[INFO] CSS del theme copiado: ${THEME_NAME}-theme.css'
  elif [[ -f '${DIST_DIR}/${THEME_NAME}-theme.css' ]]; then
    echo '[INFO] CSS del theme ya existe: ${THEME_NAME}-theme.css'
  else
    echo '[WARN] No se encontró dspace-theme.css en ${DIST_DIR}'
  fi
"

echo "[INFO] Etapa 11 finalizada correctamente"

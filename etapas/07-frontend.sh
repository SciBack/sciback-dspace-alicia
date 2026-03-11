#!/usr/bin/env bash
# SciBack — Etapa 07: Node.js + Frontend Angular + PM2
# FIX CRÍTICO: PM2/Yarn con NVM en usuario dspace para evitar spawn node EACCES

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"

[[ -f "${ENV_FILE}" ]] || { echo "[✗] No se encontró: ${ENV_FILE}"; exit 1; }

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

[[ "${INSTALL_FRONTEND:-yes}" == "skip" ]] && exit 99

ETAPA_INICIO=$(date +%s)

DSPACE_VERSION="${DSPACE_VERSION:-7.6.6}"
RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
RUN_GROUP="${DSPACE_RUN_AS_GROUP:-dspace}"
FRONTEND_DIR="${DSPACE_FRONTEND_DIR:-/home/dspace/frontend}"
NVM_DIR="/home/${RUN_USER}/.nvm"
NODE_MAJOR="${NODE_MAJOR:-20}"
PM2_APP_NAME="${DSPACE_PM2_APP_NAME:-dspace-${SCIBACK_CLIENT}}"
PM2_PORT_VALUE="${PM2_PORT:-4000}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[✗] Falta comando requerido: $1"
    exit 1
  }
}

require_command curl
require_command git
require_command sudo
require_command apt-get

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 07 — Node.js ${NODE_MAJOR} + Frontend Angular\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~12 min\033[0m"

echo -e "\n\033[0;34m--- 7.1 Instalando Node.js ${NODE_MAJOR} (base sistema) ---\033[0m"
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
  apt-get install -y -q nodejs
fi

echo -e "\n\033[0;34m--- 7.2 Instalando NVM + Node.js + PM2 + Yarn para usuario ${RUN_USER} ---\033[0m"
if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
  sudo -u "${RUN_USER}" bash -lc 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
fi

sudo -u "${RUN_USER}" bash -lc "
  set -Eeuo pipefail
  export NVM_DIR='${NVM_DIR}'
  source \"\$NVM_DIR/nvm.sh\"
  nvm install '${NODE_MAJOR}'
  nvm alias default '${NODE_MAJOR}'
  npm install -g pm2 yarn
"

DSPACE_NODE_VERSION="$(sudo -u "${RUN_USER}" bash -lc "
  export NVM_DIR='${NVM_DIR}'
  source \"\$NVM_DIR/nvm.sh\"
  node -v
")"

DSPACE_PM2_VERSION="$(sudo -u "${RUN_USER}" bash -lc "
  export NVM_DIR='${NVM_DIR}'
  source \"\$NVM_DIR/nvm.sh\"
  pm2 --version | tail -1
")"

DSPACE_YARN_VERSION="$(sudo -u "${RUN_USER}" bash -lc "
  export NVM_DIR='${NVM_DIR}'
  source \"\$NVM_DIR/nvm.sh\"
  yarn --version
")"

echo -e "\033[0;32m[✓]\033[0m Node.js ${DSPACE_NODE_VERSION}, PM2 ${DSPACE_PM2_VERSION}, Yarn ${DSPACE_YARN_VERSION} (usuario ${RUN_USER})"

echo -e "\n\033[0;34m--- 7.3 Clonando dspace-angular ---\033[0m"
if [[ ! -d "${FRONTEND_DIR}" ]]; then
  sudo -u "${RUN_USER}" bash -lc "git clone --depth 1 --branch 'dspace-${DSPACE_VERSION}' https://github.com/DSpace/dspace-angular.git '${FRONTEND_DIR}'"
  echo -e "\033[0;32m[✓]\033[0m dspace-angular ${DSPACE_VERSION} clonado"
else
  echo -e "\033[1;33m[!]\033[0m Directorio ${FRONTEND_DIR} ya existe — omitiendo clone"
fi

echo -e "\n\033[0;34m--- 7.4 Configurando config.yml ---\033[0m"
mkdir -p "${FRONTEND_DIR}/config"

cat > "${FRONTEND_DIR}/config/config.yml" <<CONFIGYML
ui:
  ssl: false
  host: 0.0.0.0
  port: ${PM2_PORT_VALUE}
  nameSpace: /

rest:
  ssl: true
  host: ${DSPACE_HOSTNAME}
  port: 443
  nameSpace: /server

defaultLanguage: 'es'
languages:
  - code: es
    label: Español
  - code: en
    label: English
CONFIGYML

cp "${FRONTEND_DIR}/config/config.yml" "${FRONTEND_DIR}/config/config.production.yaml"
chown -R "${RUN_USER}:${RUN_GROUP}" "${FRONTEND_DIR}"

echo -e "\033[0;32m[✓]\033[0m config.yml generado (ui.host=0.0.0.0, rest.host=${DSPACE_HOSTNAME})"

echo -e "\n\033[0;34m── 7.5 Instalando dependencias y compilando (~8-12 min) ───────────────\033[0m"
echo -e "\033[0;36m[→]\033[0m Ejecutando yarn install + yarn build:ssr"

sudo -u "${RUN_USER}" bash -lc "
  set -Eeuo pipefail
  export NVM_DIR='${NVM_DIR}'
  source \"\$NVM_DIR/nvm.sh\"
  cd '${FRONTEND_DIR}'
  yarn install --frozen-lockfile
  yarn build:ssr
"

echo -e "\033[0;32m[✓]\033[0m Frontend Angular compilado"

echo -e "\n\033[0;34m--- 7.6 Configurando PM2 ---\033[0m"
cat > "/home/${RUN_USER}/ecosystem.config.js" <<PM2EOF
module.exports = {
  apps: [{
    name: '${PM2_APP_NAME}',
    script: 'dist/server/main.js',
    cwd: '${FRONTEND_DIR}',
    instances: ${PM2_INSTANCES:-3},
    exec_mode: 'cluster',
    max_memory_restart: '${PM2_MAX_MEMORY:-1500M}',
    env: {
      NODE_ENV: 'production',
      PORT: ${PM2_PORT_VALUE},
      NODE_TLS_REJECT_UNAUTHORIZED: '${DSPACE_NODE_TLS_REJECT_UNAUTHORIZED:-1}',
      NGSSR_TIMEOUT: '60000',
      DSPACE_REST_SSL: 'true',
      DSPACE_REST_HOST: '${DSPACE_HOSTNAME}',
      DSPACE_REST_PORT: '443',
      DSPACE_REST_NAMESPACE: '/server'
    }
  }]
}
PM2EOF

chown "${RUN_USER}:${RUN_GROUP}" "/home/${RUN_USER}/ecosystem.config.js"

sudo -u "${RUN_USER}" bash -lc "
  set -Eeuo pipefail
  export NVM_DIR='${NVM_DIR}'
  source \"\$NVM_DIR/nvm.sh\"
  pm2 delete '${PM2_APP_NAME}' >/dev/null 2>&1 || true
  pm2 start /home/${RUN_USER}/ecosystem.config.js
  pm2 save
"

NODE_BIN_DIR="$(sudo -u "${RUN_USER}" bash -lc "
  export NVM_DIR='${NVM_DIR}'
  source \"\$NVM_DIR/nvm.sh\"
  dirname \"\$(nvm which default)\"
")"

env PATH="${PATH}:${NODE_BIN_DIR}" pm2 startup systemd -u "${RUN_USER}" --hp "/home/${RUN_USER}"

echo -e "\033[0;32m[✓]\033[0m PM2 configurado: ${PM2_INSTANCES:-3} instancias en puerto ${PM2_PORT_VALUE}"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

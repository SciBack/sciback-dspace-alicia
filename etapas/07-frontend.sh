#!/bin/bash
# SciBack — Etapa 07: Node.js + Frontend Angular + PM2
# EXACTO del deploy-dspace.sh v2.2 que funcionó
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_FRONTEND:-yes}" == "skip" ]] && exit 99
set -euo pipefail

DSPACE_VERSION="${DSPACE_VERSION:-7.6.6}"
FRONTEND_DIR="/home/dspace/frontend"

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 07 — Node.js ${NODE_MAJOR} + Frontend Angular\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"

echo -e "\n\033[0;34m--- 7.1 Instalando Node.js ${NODE_MAJOR} ---\033[0m"
if ! command -v node &>/dev/null; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR:-18}.x" | bash -
  apt-get install -y -qq nodejs
fi

npm install -g pm2 yarn
echo -e "\033[0;32m[✓]\033[0m Node.js $(node -v), PM2 $(pm2 --version), Yarn $(yarn --version)"

echo -e "\n\033[0;34m--- 7.2 Clonando dspace-angular ---\033[0m"
if [[ ! -d "${FRONTEND_DIR}" ]]; then
  sudo -u dspace git clone --depth 1 --branch "dspace-${DSPACE_VERSION}" \
    https://github.com/DSpace/dspace-angular.git "${FRONTEND_DIR}"
  echo -e "\033[0;32m[✓]\033[0m dspace-angular ${DSPACE_VERSION} clonado"
else
  echo -e "\033[1;33m[!]\033[0m Directorio ${FRONTEND_DIR} ya existe — omitiendo clone"
fi

echo -e "\n\033[0;34m--- 7.3 Configurando config.yml ---\033[0m"
sudo -u dspace bash -c "cat > ${FRONTEND_DIR}/config/config.yml" <<CONFIGYML
ui:
  ssl: false
  host: 0.0.0.0
  port: ${PM2_PORT:-4000}
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

sudo -u dspace cp "${FRONTEND_DIR}/config/config.yml" \
                  "${FRONTEND_DIR}/config/config.production.yaml"
echo -e "\033[0;32m[✓]\033[0m config.yml generado (ui.host=0.0.0.0, rest.host=${DSPACE_HOSTNAME})"

echo -e "\n\033[0;34m--- 7.4 Instalando dependencias y compilando (puede tardar 5-10 min) ---\033[0m"
sudo -u dspace bash -c "
  cd ${FRONTEND_DIR}
  yarn install --frozen-lockfile
  yarn build:ssr
"
echo -e "\033[0;32m[✓]\033[0m Frontend Angular compilado"

echo -e "\n\033[0;34m--- 7.5 Configurando PM2 ---\033[0m"
cat > /home/dspace/ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'dspace-${SCIBACK_CLIENT}',
    script: 'dist/server/main.js',
    cwd: '${FRONTEND_DIR}',
    instances: ${PM2_INSTANCES:-2},
    exec_mode: 'cluster',
    max_memory_restart: '${PM2_MAX_MEMORY:-900M}',
    env: {
      NODE_ENV: 'production',
      PORT: ${PM2_PORT:-4000},
      NODE_TLS_REJECT_UNAUTHORIZED: '0',
      NGSSR_TIMEOUT: '60000',
      DSPACE_REST_SSL: 'true',
      DSPACE_REST_HOST: '${DSPACE_HOSTNAME}',
      DSPACE_REST_PORT: '443',
      DSPACE_REST_NAMESPACE: '/server'
    }
  }]
}
EOF
chown dspace:dspace /home/dspace/ecosystem.config.js

sudo -u dspace bash -c "
  pm2 start /home/dspace/ecosystem.config.js
  pm2 save
"

env PATH=$PATH:/usr/bin pm2 startup systemd -u dspace --hp /home/dspace
echo -e "\033[0;32m[✓]\033[0m PM2 configurado: ${PM2_INSTANCES:-2} instancias en puerto ${PM2_PORT:-4000}"

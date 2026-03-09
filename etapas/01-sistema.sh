#!/bin/bash
# SciBack — Etapa 01: Preparación del sistema
# Extraído de deploy-dspace.sh v2.2 (código probado y funcional)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_SYSTEM:-yes}" == "skip" ]] && exit 99
set -euo pipefail

DSPACE_DIR="${DSPACE_DIR:-/dspace}"

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 01 — Preparación del sistema\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"

echo -e "\n\033[0;34m--- 1.1 Configurando timezone ---\033[0m"
timedatectl set-timezone "${TIMEZONE:-America/Lima}"
echo -e "\033[0;32m[✓]\033[0m Timezone: $(timedatectl show --property=Timezone --value)"

echo -e "\n\033[0;34m--- 1.2 Actualizando paquetes ---\033[0m"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get upgrade -y -q

echo -e "\n\033[0;34m--- 1.3 Instalando paquetes base ---\033[0m"
apt-get install -y -q \
  curl wget git unzip htop nano \
  build-essential maven ant \
  postgresql-client \
  fontconfig \
  software-properties-common \
  apt-transport-https \
  ca-certificates \
  gnupg \
  openssl \
  jq libxml2-utils

echo -e "\n\033[0;34m--- 1.4 Configurando locale ${DB_LOCALE:-es_PE.UTF-8} ---\033[0m"
locale-gen "${DB_LOCALE:-es_PE.UTF-8}" || true
update-locale || true

echo -e "\n\033[0;34m--- 1.5 Creando swap ${SWAP_SIZE:-4G} ---\033[0m"
if [[ ! -f /swapfile ]]; then
  fallocate -l "${SWAP_SIZE:-4G}" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo -e "\033[0;32m[✓]\033[0m Swap de ${SWAP_SIZE:-4G} activado"
else
  echo -e "\033[1;33m[!]\033[0m Swap ya existe — omitiendo"
fi

echo -e "\n\033[0;34m--- 1.6 Creando usuario dspace ---\033[0m"
if ! id -u dspace &>/dev/null; then
  useradd -m -s /bin/bash dspace
  echo -e "\033[0;32m[✓]\033[0m Usuario dspace creado"
else
  echo -e "\033[1;33m[!]\033[0m Usuario dspace ya existe — omitiendo"
fi

mkdir -p /home/dspace
chown -R dspace:dspace /home/dspace
mkdir -p "${DSPACE_DIR}"
chown dspace:dspace "${DSPACE_DIR}"
echo -e "\033[0;32m[✓]\033[0m Paso 1 completado ✓"

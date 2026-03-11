#!/bin/bash
# SciBack — Etapa 03: PostgreSQL 14
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_POSTGRES:-yes}" == "skip" ]] && exit 99
set -euo pipefail

ETAPA_INICIO=$(date +%s)

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 03 — PostgreSQL 14\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~2 min\033[0m"

echo -e "\n\033[0;34m--- Instalando PostgreSQL 14 (nativo Ubuntu 22.04) ---\033[0m"
apt-get install -y -q postgresql postgresql-contrib

if [[ -d /run/systemd/system ]]; then
  systemctl enable --now postgresql
else
  echo -e "\033[1;33m[!]\033[0m systemd no disponible — iniciando cluster con pg_ctlcluster"
  pg_ctlcluster --skip-systemctl-redirect 16 main start || true
fi

echo -e "\n\033[0;34m--- Verificando que PostgreSQL responde ---\033[0m"
sleep 3
sudo -u postgres pg_isready || { echo "[✗] PostgreSQL no responde"; exit 1; }

echo -e "\n\033[0;34m--- Creando base de datos y usuario DSpace ---\033[0m"
cd /tmp
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' LC_COLLATE '${DB_LOCALE:-es_PE.UTF-8}' LC_CTYPE '${DB_LOCALE:-es_PE.UTF-8}' TEMPLATE template0;"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

PG_VER=$(sudo -u postgres psql -tc "SHOW server_version;" | xargs)
echo -e "\033[0;32m[✓]\033[0m PostgreSQL ${PG_VER} listo — DB: ${DB_NAME}, User: ${DB_USER}"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

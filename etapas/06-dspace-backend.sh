#!/bin/bash
# SciBack — Etapa 06: DSpace Backend
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_DSPACE:-yes}" == "skip" ]] && exit 99
set -euo pipefail

DSPACE_DIR="${DSPACE_DIR:-/dspace}"
DSPACE_SRC="/home/dspace/dspace-src"
DSPACE_BASEURL="https://${DSPACE_HOSTNAME}"
DSPACE_REST_URL="https://${DSPACE_HOSTNAME}/server"

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 06 — DSpace ${DSPACE_VERSION} (backend)\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"

echo -e "\n\033[0;34m--- 6.1 Clonando repositorio ---\033[0m"
if [[ ! -d "${DSPACE_SRC}" ]]; then
  su - dspace -c "git clone --depth 1 --branch 'dspace-${DSPACE_VERSION}' https://github.com/DSpace/DSpace.git '${DSPACE_SRC}'"
  echo -e "\033[0;32m[✓]\033[0m DSpace ${DSPACE_VERSION} clonado en ${DSPACE_SRC}"
else
  echo -e "\033[1;33m[!]\033[0m Directorio ${DSPACE_SRC} ya existe — omitiendo clone"
fi

echo -e "\n\033[0;34m--- 6.2 Generando local.cfg desde .env ---\033[0m"
cat > "${DSPACE_SRC}/dspace/config/local.cfg" <<CFGEOF
# Generado por SciBack — $(date '+%Y-%m-%d %H:%M:%S')
dspace.dir = ${DSPACE_DIR}
dspace.server.url = ${DSPACE_REST_URL}
dspace.ui.url = ${DSPACE_BASEURL}
dspace.name = ${DSPACE_NAME}
db.url = jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
db.username = ${DB_USER}
db.password = ${DB_PASSWORD}
mail.server = ${MAIL_SERVER}
mail.server.port = ${MAIL_PORT}
mail.from.address = ${MAIL_FROM}
mail.admin = ${MAIL_ADMIN}
handle.prefix = ${HANDLE_PREFIX}
oai.url = ${DSPACE_BASEURL}/oai
solr.server = http://localhost:8983/solr
CFGEOF
chown dspace:dspace "${DSPACE_SRC}/dspace/config/local.cfg"
echo -e "\033[0;32m[✓]\033[0m local.cfg generado"

echo -e "\n\033[0;34m--- 6.3 Compilando DSpace (esto puede tardar 10-15 min) ---\033[0m"
su - dspace -c "cd '${DSPACE_SRC}' && mvn clean package -DskipTests"
echo -e "\033[0;32m[✓]\033[0m Compilación completada"

echo -e "\n\033[0;34m--- 6.4 Instalando en ${DSPACE_DIR} ---\033[0m"
su - dspace -c "cd '${DSPACE_SRC}/dspace/target/dspace-installer' && ant fresh_install"
echo -e "\033[0;32m[✓]\033[0m DSpace instalado en ${DSPACE_DIR}"

echo -e "\n\033[0;34m--- 6.5 Creando cores Solr ---\033[0m"
for CORE in search oai statistics authority; do
  if sudo -u solr /opt/solr/bin/solr create_core -c "$CORE" -d "${DSPACE_DIR}/solr/${CORE}/conf" 2>/dev/null; then
    echo -e "\033[0;32m[✓]\033[0m Core Solr creado: ${CORE}"
  else
    echo -e "\033[1;33m[!]\033[0m Core Solr '${CORE}' ya existe o falló"
  fi
done

echo -e "\n\033[0;34m--- 6.6 Desplegando webapps en Tomcat ---\033[0m"
for WEBAPP in server oai; do
  if [[ -d "${DSPACE_DIR}/webapps/${WEBAPP}" ]]; then
    cp -r "${DSPACE_DIR}/webapps/${WEBAPP}" /opt/tomcat9/webapps/${WEBAPP}
    chown -R dspace:dspace /opt/tomcat9/webapps/${WEBAPP}
    echo -e "\033[0;32m[✓]\033[0m Webapp ${WEBAPP} desplegada en Tomcat"
  else
    echo -e "\033[1;33m[!]\033[0m Webapp ${WEBAPP} no encontrada (OAI integrado en /server desde DSpace 7.x)"
  fi
done

echo -e "\n\033[0;34m--- 6.7 Migrando base de datos ---\033[0m"
su - dspace -c "'${DSPACE_DIR}/bin/dspace' database migrate"

echo -e "\n\033[0;34m--- 6.8 Creando administrador ---\033[0m"
su - dspace -c "'${DSPACE_DIR}/bin/dspace' create-administrator -e '${ADMIN_EMAIL}' -f '${ADMIN_FIRSTNAME:-Admin}' -l '${ADMIN_LASTNAME:-SciBack}' -p '${ADMIN_PASSWORD}' -c '${ADMIN_LANGUAGE:-es}'" || echo -e "\033[1;33m[!]\033[0m Admin ya existe o falló"

echo -e "\n\033[0;34m--- 6.9 Iniciando Tomcat ---\033[0m"
systemctl start tomcat9

echo -e "\n\033[0;34m--- 6.10 Esperando que Tomcat responda (puede tardar 30-60 seg) ---\033[0m"
TOMCAT_READY=false
for i in $(seq 1 12); do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/server/api 2>/dev/null | grep -q "200"; then
    echo -e "\033[0;32m[✓]\033[0m Tomcat respondiendo en puerto 8080 ✓"
    TOMCAT_READY=true
    break
  fi
  echo "  Esperando... (${i}/12)"
  sleep 10
done
[[ "$TOMCAT_READY" == "true" ]] || { echo "[✗] Tomcat no respondió"; exit 1; }

echo -e "\033[0;32m[✓]\033[0m DSpace backend desplegado ✓"

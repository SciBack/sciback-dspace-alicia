#!/usr/bin/env bash
# SciBack — Etapa 06: DSpace Backend
# FIX: forward-headers-strategy en local.cfg (CSRF/CORS detrás de Nginx)
# FIX: HOME explícito en bloques sudo -u para evitar EACCES

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"

[[ -f "${ENV_FILE}" ]] || { echo "[✗] No se encontró: ${ENV_FILE}"; exit 1; }

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

[[ "${INSTALL_DSPACE:-yes}" == "skip" ]] && exit 99

ETAPA_INICIO=$(date +%s)

RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
RUN_GROUP="${DSPACE_RUN_AS_GROUP:-dspace}"
RUN_HOME="/home/${RUN_USER}"
DSPACE_DIR="${DSPACE_DIR:-/dspace}"
DSPACE_SRC="${DSPACE_SRC_DIR:-${RUN_HOME}/dspace-src}"
DSPACE_BASEURL="https://${DSPACE_HOSTNAME}"
DSPACE_REST_URL="https://${DSPACE_HOSTNAME}/server"
DSPACE_INSTALL_MODE="${DSPACE_INSTALL_MODE:-fresh_install}"
DSPACE_MAVEN_BUILD_ARGS="${DSPACE_MAVEN_BUILD_ARGS:--DskipTests}"
TOMCAT_WEBAPPS_DIR="${TOMCAT_WEBAPPS_DIR:-/opt/tomcat9/webapps}"
SOLR_BIN="${SOLR_BIN:-/opt/solr/bin/solr}"
SOLR_URL="${SOLR_URL:-http://localhost:8983/solr}"
LOCAL_CFG_PATH="${DSPACE_SRC}/dspace/config/local.cfg"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[✗] Falta comando requerido: $1"
    exit 1
  }
}

# ── Helper: ejecutar comando como RUN_USER con HOME correcto ────────
run_as_dspace() {
  sudo -u "${RUN_USER}" HOME="${RUN_HOME}" bash -lc "
    set -Eeuo pipefail
    export HOME='${RUN_HOME}'
    $1
  "
}

require_command git
require_command sudo
require_command curl
require_command systemctl
require_command rm
require_command cp
require_command chown
require_command mvn
require_command ant

[[ -x "${SOLR_BIN}" ]] || { echo "[✗] No existe binario Solr: ${SOLR_BIN}"; exit 1; }
[[ -d "${TOMCAT_WEBAPPS_DIR}" ]] || { echo "[✗] No existe directorio Tomcat webapps: ${TOMCAT_WEBAPPS_DIR}"; exit 1; }

if [[ "${DSPACE_INSTALL_MODE}" != "fresh_install" && "${DSPACE_INSTALL_MODE}" != "update" ]]; then
  echo "[✗] DSPACE_INSTALL_MODE debe ser fresh_install o update"
  exit 1
fi

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 06 — DSpace ${DSPACE_VERSION} (backend)\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~15-20 min\033[0m"

echo -e "\n\033[0;34m--- 6.1 Clonando repositorio ---\033[0m"
if [[ ! -d "${DSPACE_SRC}" ]]; then
  run_as_dspace "git clone --depth 1 --branch 'dspace-${DSPACE_VERSION}' https://github.com/DSpace/DSpace.git '${DSPACE_SRC}'"
  echo -e "\033[0;32m[✓]\033[0m DSpace ${DSPACE_VERSION} clonado en ${DSPACE_SRC}"
else
  echo -e "\033[1;33m[!]\033[0m Directorio ${DSPACE_SRC} ya existe — omitiendo clone"
fi

echo -e "\n\033[0;34m--- 6.2 Generando local.cfg desde .env ---\033[0m"
mkdir -p "$(dirname "${LOCAL_CFG_PATH}")"

cat > "${LOCAL_CFG_PATH}" <<CFGEOF
# Generado por SciBack — $(date '+%Y-%m-%d %H:%M:%S')
dspace.dir = ${DSPACE_DIR}
dspace.server.url = ${DSPACE_REST_URL}
dspace.ui.url = ${DSPACE_BASEURL}
dspace.name = ${DSPACE_NAME}

# ── Base de datos ────────────────────────────────────────
db.url = jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
db.username = ${DB_USER}
db.password = ${DB_PASSWORD}

# ── Email ────────────────────────────────────────────────
mail.server = ${MAIL_SERVER}
mail.server.port = ${MAIL_PORT}
mail.from.address = ${MAIL_FROM}
mail.admin = ${MAIL_ADMIN}

# ── Handle / OAI / Solr ─────────────────────────────────
handle.prefix = ${HANDLE_PREFIX}
oai.url = ${DSPACE_BASEURL}/server/oai
solr.server = ${SOLR_URL}

# ── Locale ───────────────────────────────────────────────
default.locale = ${ADMIN_LANGUAGE:-es}

# ── Proxy headers — CRÍTICO para Nginx reverse proxy ────
# Sin esto, Spring Boot ignora X-Forwarded-Proto/Host y
# genera URLs http:// rompiendo CSRF/CORS tras Nginx SSL
server.forward-headers-strategy = FRAMEWORK
CFGEOF

chown "${RUN_USER}:${RUN_GROUP}" "${LOCAL_CFG_PATH}"
echo -e "\033[0;32m[✓]\033[0m local.cfg generado (con forward-headers-strategy)"

echo -e "\n\033[0;34m--- 6.3 Verificando conectividad base ---\033[0m"
if curl -fsS "${SOLR_URL}/admin/info/system" >/dev/null 2>&1; then
  echo -e "\033[0;32m[✓]\033[0m Solr responde en ${SOLR_URL}"
else
  echo -e "\033[1;33m[!]\033[0m Solr no respondió a tiempo; la creación de cores podría fallar"
fi

echo -e "\n\033[0;34m── 6.4 Compilando DSpace (~10-15 min) ──────────────────\033[0m"
echo -e "\033[0;36m[→]\033[0m Compilando DSpace backend..."
run_as_dspace "
  cd '${DSPACE_SRC}'
  mvn clean package ${DSPACE_MAVEN_BUILD_ARGS}
"
echo -e "\033[0;32m[✓]\033[0m Compilación completada"

echo -e "\n\033[0;34m── 6.5 Instalando en ${DSPACE_DIR} (~3-5 min) ───────────\033[0m"
echo -e "\033[0;36m[→]\033[0m Ejecutando ant ${DSPACE_INSTALL_MODE}..."
run_as_dspace "
  cd '${DSPACE_SRC}/dspace/target/dspace-installer'
  ant '${DSPACE_INSTALL_MODE}'
"
echo -e "\033[0;32m[✓]\033[0m DSpace instalado en ${DSPACE_DIR}"

echo -e "\n\033[0;34m--- 6.6 Creando cores Solr ---\033[0m"
for CORE in search oai statistics authority; do
  CORE_CONF_DIR="${DSPACE_DIR}/solr/${CORE}/conf"
  if [[ ! -d "${CORE_CONF_DIR}" ]]; then
    echo -e "\033[1;33m[!]\033[0m No existe configuración para core ${CORE}: ${CORE_CONF_DIR}"
    continue
  fi

  if curl -fsS "${SOLR_URL}/${CORE}/admin/ping" >/dev/null 2>&1; then
    echo -e "\033[1;33m[!]\033[0m Core Solr ya existe: ${CORE}"
    continue
  fi

  if sudo -u solr "${SOLR_BIN}" create_core -c "${CORE}" -d "${CORE_CONF_DIR}" >/dev/null 2>&1; then
    echo -e "\033[0;32m[✓]\033[0m Core Solr creado: ${CORE}"
  else
    echo -e "\033[1;33m[!]\033[0m No se pudo crear core Solr: ${CORE}"
  fi
done

echo -e "\n\033[0;34m--- 6.7 Desplegando webapps en Tomcat ---\033[0m"
for WEBAPP in server oai; do
  SOURCE_WEBAPP="${DSPACE_DIR}/webapps/${WEBAPP}"
  TARGET_WEBAPP="${TOMCAT_WEBAPPS_DIR}/${WEBAPP}"

  if [[ -d "${SOURCE_WEBAPP}" ]]; then
    rm -rf "${TARGET_WEBAPP}" "${TARGET_WEBAPP}.war"
    cp -a "${SOURCE_WEBAPP}" "${TARGET_WEBAPP}"
    chown -R "${RUN_USER}:${RUN_GROUP}" "${TARGET_WEBAPP}"
    echo -e "\033[0;32m[✓]\033[0m Webapp ${WEBAPP} desplegada en Tomcat"
  else
    echo -e "\033[1;33m[!]\033[0m Webapp ${WEBAPP} no encontrada"
  fi
done

echo -e "\n\033[0;34m--- 6.8 Migrando base de datos ---\033[0m"
run_as_dspace "'${DSPACE_DIR}/bin/dspace' database migrate"
echo -e "\033[0;32m[✓]\033[0m Migración de base de datos completada"

echo -e "\n\033[0;34m--- 6.9 Creando administrador ---\033[0m"
if run_as_dspace "
  '${DSPACE_DIR}/bin/dspace' create-administrator \
    -e '${ADMIN_EMAIL}' \
    -f '${ADMIN_FIRSTNAME:-Admin}' \
    -l '${ADMIN_LASTNAME:-SciBack}' \
    -p '${ADMIN_PASSWORD}' \
    -c '${ADMIN_LANGUAGE:-es}'
"; then
  echo -e "\033[0;32m[✓]\033[0m Administrador creado"
else
  echo -e "\033[1;33m[!]\033[0m Administrador ya existe o no pudo crearse"
fi

echo -e "\n\033[0;34m--- 6.10 Reiniciando Tomcat ---\033[0m"
systemctl restart tomcat9

echo -e "\n\033[0;34m--- 6.11 Esperando que Tomcat responda (puede tardar 30-120 seg) ---\033[0m"
TOMCAT_READY=false
for i in $(seq 1 18); do
  HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/server/api 2>/dev/null || true)"
  if [[ "${HTTP_CODE}" == "200" || "${HTTP_CODE}" == "301" || "${HTTP_CODE}" == "302" ]]; then
    echo -e "\033[0;32m[✓]\033[0m Tomcat respondiendo en puerto 8080 (HTTP ${HTTP_CODE})"
    TOMCAT_READY=true
    break
  fi
  echo "  Esperando... (${i}/18)"
  sleep 10
done

[[ "${TOMCAT_READY}" == "true" ]] || { echo "[✗] Tomcat no respondió correctamente"; exit 1; }

echo -e "\n\033[0;34m--- 6.12 Verificación final backend ---\033[0m"
echo -e "\033[0;32m[✓]\033[0m DSpace backend desplegado"
echo -e "\033[0;36m[→]\033[0m URL backend: ${DSPACE_REST_URL}"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

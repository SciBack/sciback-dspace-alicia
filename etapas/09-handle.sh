#!/usr/bin/env bash
# SciBack — Etapa 09: Handle Server (solo descarga)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"

[[ -f "${ENV_FILE}" ]] || { echo "[✗] No se encontró: ${ENV_FILE}"; exit 1; }

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

[[ "${INSTALL_HANDLE:-yes}" == "skip" ]] && exit 99

ETAPA_INICIO=$(date +%s)

HANDLE_VER="${HANDLE_VERSION:-9.3.1}"
RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
RUN_GROUP="${DSPACE_RUN_AS_GROUP:-dspace}"
HANDLE_DIR="${HANDLE_INSTALL_DIR:-/opt/handle}"
HANDLE_PARENT_DIR="$(dirname "${HANDLE_DIR}")"
HANDLE_ARCHIVE="handle-${HANDLE_VER}-distribution.tar.gz"
HANDLE_SRC_DIR="handle-${HANDLE_VER}"
HANDLE_URL="https://www.handle.net/hnr-source/${HANDLE_ARCHIVE}"
HANDLE_SERVICE_FILE="/etc/systemd/system/handle.service"
HANDLE_SERVER_DIR="${HANDLE_DIR}/svr_1"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[✗] Falta comando requerido: $1"
    exit 1
  }
}

require_command wget
require_command tar
require_command chown
require_command systemctl

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 09 — Handle Server ${HANDLE_VER} (solo descarga)\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~1 min\033[0m"

echo -e "\n\033[0;34m--- 9.1 Descargando Handle Server ---\033[0m"
mkdir -p "${HANDLE_PARENT_DIR}"
cd "${HANDLE_PARENT_DIR}"

if [[ ! -d "${HANDLE_DIR}" ]]; then
  rm -f "${HANDLE_ARCHIVE}"
  wget --progress=bar:force "${HANDLE_URL}"
  tar xzf "${HANDLE_ARCHIVE}"

  [[ -d "${HANDLE_SRC_DIR}" ]] || { echo "[✗] No se extrajo correctamente ${HANDLE_SRC_DIR}"; exit 1; }

  mv "${HANDLE_SRC_DIR}" "${HANDLE_DIR}"
  chown -R "${RUN_USER}:${RUN_GROUP}" "${HANDLE_DIR}"
  rm -f "${HANDLE_ARCHIVE}"

  echo -e "\033[0;32m[✓]\033[0m Handle Server ${HANDLE_VER} descargado en ${HANDLE_DIR}"
else
  echo -e "\033[1;33m[!]\033[0m Handle Server ya existe en ${HANDLE_DIR} — omitiendo descarga"
fi

echo -e "\n\033[0;34m--- 9.2 Registrando servicio systemd ---\033[0m"
cat > "${HANDLE_SERVICE_FILE}" <<EOF
[Unit]
Description=Handle.net Server — DSpace (${SCIBACK_CLIENT})
After=network.target tomcat9.service
Wants=network.target

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_GROUP}
WorkingDirectory=${HANDLE_DIR}
ExecStart=${HANDLE_DIR}/bin/hdl-server ${HANDLE_SERVER_DIR}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo -e "\033[0;32m[✓]\033[0m Servicio systemd registrado: ${HANDLE_SERVICE_FILE}"

echo -e "\n\033[0;34m--- 9.3 Estado de configuración ---\033[0m"
if [[ -d "${HANDLE_SERVER_DIR}" ]]; then
  echo -e "\033[0;32m[✓]\033[0m Directorio Handle ya inicializado: ${HANDLE_SERVER_DIR}"
  echo -e "\033[0;36m[→]\033[0m Puedes habilitar el servicio con:"
  echo -e "    sudo systemctl enable --now handle"
else
  echo -e "\033[1;33m[!]\033[0m Handle descargado pero aún no inicializado"
  echo -e "\033[1;33m[!]\033[0m Ejecuta manualmente:"
  echo -e "    sudo -u ${RUN_USER} ${HANDLE_DIR}/bin/hdl-setup-server ${HANDLE_SERVER_DIR}"
  echo -e "    sudo systemctl enable --now handle"
fi

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

#!/bin/bash
# SciBack — Etapa 09: Handle Server (solo descarga)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_HANDLE:-yes}" == "skip" ]] && exit 99
set -euo pipefail

ETAPA_INICIO=$(date +%s)

HANDLE_VER="${HANDLE_VERSION:-9.3.1}"

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 09 — Handle Server ${HANDLE_VER} (solo descarga)\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~1 min\033[0m"

if [[ ! -d /opt/handle ]]; then
  cd /opt
  wget --progress=bar:force "https://www.handle.net/hnr-source/handle-${HANDLE_VER}-distribution.tar.gz"
  tar xzf "handle-${HANDLE_VER}-distribution.tar.gz"
  mv "handle-${HANDLE_VER}" /opt/handle
  chown -R dspace:dspace /opt/handle
  rm -f "handle-${HANDLE_VER}-distribution.tar.gz"
  echo -e "\033[0;32m[✓]\033[0m Handle Server ${HANDLE_VER} descargado en /opt/handle"
else
  echo -e "\033[1;33m[!]\033[0m Handle Server ya existe — omitiendo"
fi

cat > /etc/systemd/system/handle.service <<EOF
[Unit]
Description=Handle.net Server — DSpace (${SCIBACK_CLIENT})
After=tomcat9.service

[Service]
Type=simple
User=dspace
ExecStart=/opt/handle/bin/hdl-server /opt/handle/svr_1
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo -e "\033[1;33m[!]\033[0m Handle descargado pero NO configurado — ejecutar manualmente:"
echo -e "\033[1;33m[!]\033[0m   sudo -u dspace /opt/handle/bin/hdl-setup-server /opt/handle/svr_1"
echo -e "\033[1;33m[!]\033[0m   sudo systemctl enable --now handle"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

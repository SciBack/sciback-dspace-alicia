#!/bin/bash
# SciBack — Etapa 05: Apache Tomcat 9
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_TOMCAT:-yes}" == "skip" ]] && exit 99
set -euo pipefail

DSPACE_DIR="${DSPACE_DIR:-/dspace}"

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 05 — Apache Tomcat ${TOMCAT_VERSION}\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"

if [[ ! -d /opt/tomcat9 ]]; then
  cd /opt
  wget --progress=bar:force "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
  tar xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz"
  mv "apache-tomcat-${TOMCAT_VERSION}" /opt/tomcat9
  chown -R dspace:dspace /opt/tomcat9
  rm -f "apache-tomcat-${TOMCAT_VERSION}.tar.gz"
  echo -e "\033[0;32m[✓]\033[0m Tomcat ${TOMCAT_VERSION} instalado en /opt/tomcat9"
else
  echo -e "\033[1;33m[!]\033[0m Tomcat ya existe en /opt/tomcat9 — omitiendo descarga"
fi

echo -e "\n\033[0;34m--- Configurando JVM y servicio systemd ---\033[0m"
cat > /opt/tomcat9/bin/setenv.sh <<EOF
export JAVA_OPTS="-Xms${TOMCAT_HEAP_MIN:-1024m} -Xmx${TOMCAT_HEAP_MAX:-2048m} -XX:+UseG1GC -Dfile.encoding=UTF-8 -Djava.awt.headless=true"
export CATALINA_OPTS="-Dsolr.solr.home=${DSPACE_DIR}/solr -Ddspace.dir=${DSPACE_DIR}"
EOF
chmod +x /opt/tomcat9/bin/setenv.sh

cat > /etc/systemd/system/tomcat9.service <<EOF
[Unit]
Description=Apache Tomcat 9 — DSpace backend (${SCIBACK_CLIENT})
After=network.target postgresql.service

[Service]
Type=forking
User=dspace
Group=dspace
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
ExecStart=/opt/tomcat9/bin/startup.sh
ExecStop=/opt/tomcat9/bin/shutdown.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tomcat9
echo -e "\033[0;32m[✓]\033[0m Tomcat configurado: heap ${TOMCAT_HEAP_MIN:-1024m}-${TOMCAT_HEAP_MAX:-2048m}"

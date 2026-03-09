#!/bin/bash
# SciBack — Etapa 04: Apache Solr
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_SOLR:-yes}" == "skip" ]] && exit 99
set -euo pipefail

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 04 — Apache Solr ${SOLR_VERSION}\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"

if [[ ! -d /opt/solr ]] && [[ ! -f /etc/init.d/solr ]]; then
  cd /opt
  wget --progress=bar:force "https://archive.apache.org/dist/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz"
  tar xzf "solr-${SOLR_VERSION}.tgz" "solr-${SOLR_VERSION}/bin/install_solr_service.sh" --strip-components=2
  bash install_solr_service.sh "solr-${SOLR_VERSION}.tgz"
  rm -f "solr-${SOLR_VERSION}.tgz" install_solr_service.sh
  echo -e "\033[0;32m[✓]\033[0m Solr ${SOLR_VERSION} instalado"
else
  echo -e "\033[1;33m[!]\033[0m Solr ya instalado — omitiendo descarga"
fi

echo -e "\n\033[0;34m--- Configurando heap y bind de Solr ---\033[0m"
grep -q 'SOLR_JAVA_MEM.*sciback' /etc/default/solr.in.sh 2>/dev/null || \
  cat >> /etc/default/solr.in.sh <<EOF
# --- SciBack: Limitar heap y bind a localhost ---
SOLR_JAVA_MEM="-Xms${SOLR_HEAP_MIN:-512m} -Xmx${SOLR_HEAP_MAX:-1024m}"  # sciback
SOLR_HOST="127.0.0.1"   # Solr escucha solo en localhost — nunca expuesto
# --- fin SciBack ---
EOF

systemctl restart solr
echo -e "\033[0;32m[✓]\033[0m Solr configurado: heap ${SOLR_HEAP_MIN:-512m}-${SOLR_HEAP_MAX:-1024m}, bind 127.0.0.1"

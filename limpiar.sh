#!/bin/bash
# SciBack — limpiar.sh — Limpieza total para reinstalación desde cero
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚠️  Esto borrará TODA la instalación DSpace. Ctrl+C para cancelar."
read -p "¿Continuar? (s/N): " -n 1 -r
echo ""
[[ $REPLY =~ ^[Ss]$ ]] || exit 0

# ── Parar servicios ──────────────────────────────────────────────────
echo "→ Parando servicios..."
sudo systemctl stop tomcat9 2>/dev/null || true
sudo systemctl stop solr 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop handle 2>/dev/null || true
sudo -u dspace bash -lc '
  export HOME="/home/dspace"
  export NVM_DIR="/home/dspace/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  pm2 kill 2>/dev/null || true
' 2>/dev/null || true

# ── PostgreSQL ───────────────────────────────────────────────────────
echo "→ Limpiando PostgreSQL..."
sudo pg_dropcluster 14 main --stop 2>/dev/null || true
sudo apt-get remove --purge -y postgresql* 2>/dev/null || true

# ── Solr ─────────────────────────────────────────────────────────────
echo "→ Limpiando Solr..."
sudo rm -rf /opt/solr /opt/solr-* /var/solr
sudo rm -f /etc/init.d/solr /etc/default/solr.in.sh
sudo userdel -r solr 2>/dev/null || true

# ── Nginx ────────────────────────────────────────────────────────────
echo "→ Limpiando Nginx..."
sudo apt-get remove --purge -y nginx nginx-common nginx-core certbot python3-certbot-nginx 2>/dev/null || true
sudo rm -f /etc/nginx/sites-available/dspace-*
sudo rm -f /etc/nginx/sites-enabled/dspace-*
sudo rm -f /var/www/html/robots.txt

# ── Node.js global (del sistema, instalado en etapa 07 paso 7.1) ────
echo "→ Limpiando Node.js global..."
sudo apt-get remove --purge -y nodejs 2>/dev/null || true
sudo rm -f /etc/apt/sources.list.d/nodesource.list
sudo rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null || true

# ── Residuos de Yarn/Node en usuario que ejecuta el deploy (ubuntu) ─
# Yarn busca .yarnrc subiendo directorios, incluyendo $HOME del invocador
echo "→ Limpiando residuos Node/Yarn/PM2 del usuario invocador..."
INVOKER_HOME="$(eval echo ~"${SUDO_USER:-$(whoami)}")"
sudo rm -f "${INVOKER_HOME}/.yarnrc" 2>/dev/null || true
sudo rm -rf "${INVOKER_HOME}/.yarn" 2>/dev/null || true
sudo rm -rf "${INVOKER_HOME}/.npm" 2>/dev/null || true
sudo rm -rf "${INVOKER_HOME}/.pm2" 2>/dev/null || true
sudo rm -rf "${INVOKER_HOME}/.node-gyp" 2>/dev/null || true

# ── Usuario dspace — borrar de passwd Y el home ─────────────────────
echo "→ Eliminando usuario dspace..."
sudo userdel -r dspace 2>/dev/null || true
sudo rm -rf /home/dspace
sudo sed -i '/^dspace:/d' /etc/passwd 2>/dev/null || true
sudo sed -i '/^dspace:/d' /etc/shadow 2>/dev/null || true
sudo sed -i '/^dspace:/d' /etc/group 2>/dev/null || true

# ── Directorios DSpace ──────────────────────────────────────────────
echo "→ Eliminando directorios DSpace..."
sudo rm -rf /dspace /opt/tomcat9 /opt/handle

# ── Swap ─────────────────────────────────────────────────────────────
echo "→ Limpiando swap..."
sudo swapoff -a 2>/dev/null || true
sudo rm -f /swapfile
sudo sed -i '/swapfile/d' /etc/fstab

# ── Servicios systemd ───────────────────────────────────────────────
echo "→ Eliminando servicios systemd..."
sudo rm -f /etc/systemd/system/tomcat9.service
sudo rm -f /etc/systemd/system/handle.service
sudo rm -f /etc/systemd/system/pm2-dspace.service

# ── SSL — autofirmados + Let's Encrypt ───────────────────────────────
echo "→ Limpiando certificados SSL..."
sudo rm -f /etc/ssl/certs/dspace-selfsigned.crt
sudo rm -f /etc/ssl/private/dspace-selfsigned.key
# Let's Encrypt — se regeneran con certbot en etapa 08
sudo systemctl stop certbot.timer 2>/dev/null || true
sudo systemctl disable certbot.timer 2>/dev/null || true
if [[ -f "${SCRIPT_DIR}/.env.deploy" ]]; then
  # shellcheck disable=SC1090
  source "${SCRIPT_DIR}/.env.deploy" 2>/dev/null || true
  if [[ -n "${DSPACE_HOSTNAME:-}" ]]; then
    sudo certbot delete --cert-name "${DSPACE_HOSTNAME}" --non-interactive 2>/dev/null || true
  fi
fi
sudo rm -rf /etc/letsencrypt/live/dspace-*
sudo rm -rf /etc/letsencrypt/archive/dspace-*
sudo rm -rf /etc/letsencrypt/renewal/dspace-*

# ── /etc/hosts — limpiar hostname dinámico ──────────────────────────
echo "→ Limpiando /etc/hosts..."
if [[ -n "${DSPACE_HOSTNAME:-}" ]]; then
  sudo sed -i "/${DSPACE_HOSTNAME}/d" /etc/hosts 2>/dev/null || true
fi
sudo sed -i '/# SciBack/d' /etc/hosts 2>/dev/null || true
sudo sed -i '/repositorio\./d' /etc/hosts 2>/dev/null || true

# ── Cron de dspace ──────────────────────────────────────────────────
sudo crontab -r -u dspace 2>/dev/null || true

# ── Logs y temporales ───────────────────────────────────────────────
echo "→ Limpiando logs y temporales..."
sudo rm -f /var/log/sciback-*.log
sudo rm -f /tmp/sciback-*.log
sudo rm -f /tmp/sciback-*.xml
sudo rm -rf /tmp/sciback-lab-structure

# ── Reload systemd y autoremove ─────────────────────────────────────
sudo systemctl daemon-reload
sudo apt-get autoremove -y -q 2>/dev/null || true

# Paquetes npm globales del sistema (yarn, pm2 residuales en /usr/lib)
sudo rm -rf /usr/lib/node_modules
sudo rm -f /usr/bin/yarn /usr/bin/pm2 /bin/yarn /bin/pm2

echo ""
echo "✓ Limpieza completada. Listo para: sudo bash deploy.sh"

#!/bin/bash
# SciBack — limpiar.sh — Limpieza total para reinstalación desde cero
set -euo pipefail
echo "⚠️  Esto borrará TODA la instalación DSpace. Ctrl+C para cancelar."
read -p "¿Continuar? (s/N): " -n 1 -r
echo ""
[[ $REPLY =~ ^[Ss]$ ]] || exit 0

# Parar servicios
sudo systemctl stop tomcat9 2>/dev/null || true
sudo systemctl stop solr 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true
sudo -u dspace pm2 kill 2>/dev/null || true

# PostgreSQL
sudo pg_dropcluster 14 main --stop 2>/dev/null || true
sudo apt-get remove --purge -y postgresql* 2>/dev/null || true

# Solr
sudo rm -rf /opt/solr /opt/solr-* /var/solr
sudo rm -f /etc/init.d/solr /etc/default/solr.in.sh
sudo userdel -r solr 2>/dev/null || true

# Nginx
sudo apt-get remove --purge -y nginx nginx-common nginx-core certbot python3-certbot-nginx 2>/dev/null || true

# Usuario dspace — borrar de passwd Y el home
sudo userdel -r dspace 2>/dev/null || true
sudo rm -rf /home/dspace
# Asegurar que no quede en passwd
sudo sed -i '/^dspace:/d' /etc/passwd 2>/dev/null || true
sudo sed -i '/^dspace:/d' /etc/shadow 2>/dev/null || true
sudo sed -i '/^dspace:/d' /etc/group 2>/dev/null || true

# Directorios DSpace
sudo rm -rf /dspace /opt/tomcat9 /opt/handle

# Swap
sudo swapoff -a 2>/dev/null || true
sudo rm -f /swapfile
sudo sed -i '/swapfile/d' /etc/fstab

# Servicios systemd
sudo rm -f /etc/systemd/system/tomcat9.service
sudo rm -f /etc/systemd/system/handle.service
sudo rm -f /etc/systemd/system/pm2-dspace.service

# SSL
sudo rm -f /etc/ssl/certs/dspace-selfsigned.crt
sudo rm -f /etc/ssl/private/dspace-selfsigned.key

# Nginx configs
sudo rm -f /etc/nginx/sites-available/dspace-*
sudo rm -f /etc/nginx/sites-enabled/dspace-*
sudo rm -f /var/www/html/robots.txt

# Hosts (ambos hostnames posibles)
sudo sed -i '/repositorio\./d' /etc/hosts

# Cron de dspace
sudo crontab -r -u dspace 2>/dev/null || true

# Logs
sudo rm -f /var/log/sciback-*.log

# Limpiar
sudo systemctl daemon-reload
sudo apt-get autoremove -y -q 2>/dev/null || true

echo ""
echo "✓ Limpieza completada. Listo para: sudo bash deploy.sh"

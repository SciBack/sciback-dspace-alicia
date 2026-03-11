#!/bin/bash
# SciBack — Etapa 08: Nginx + SSL + robots.txt
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || { echo "[✗] No se encontró: $ENV_FILE"; exit 1; }

[[ "${INSTALL_NGINX:-yes}" == "skip" ]] && exit 99
set -euo pipefail

ETAPA_INICIO=$(date +%s)

FRONTEND_DIR="/home/dspace/frontend"

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 08 — Nginx (reverse proxy + protección)\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~2-3 min\033[0m"

echo -e "\n\033[0;34m--- 8.1 Instalando Nginx ---\033[0m"
apt-get remove --purge -y nginx nginx-common nginx-core 2>/dev/null || true
apt-get install -y nginx
apt-get install -y -q certbot python3-certbot-nginx
[[ -f /etc/nginx/nginx.conf ]] || { echo "[✗] nginx.conf no existe"; exit 1; }
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
if ! grep -q 'sites-enabled' /etc/nginx/nginx.conf 2>/dev/null; then
  sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi
echo -e "\033[0;32m[✓]\033[0m Nginx instalado"

echo -e "\n\033[0;34m--- 8.2 Generando certificado SSL autofirmado temporal ---\033[0m"
if [[ ! -f /etc/ssl/certs/dspace-selfsigned.crt ]]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/dspace-selfsigned.key \
    -out /etc/ssl/certs/dspace-selfsigned.crt \
    -subj "/CN=${DSPACE_HOSTNAME}" 2>/dev/null
  echo -e "\033[0;32m[✓]\033[0m Certificado SSL autofirmado generado"
else
  echo -e "\033[1;33m[!]\033[0m Certificado autofirmado ya existe"
fi

echo -e "\n\033[0;34m--- 8.3 Permisos para Nginx en assets del frontend ---\033[0m"
chmod o+x /home/dspace
chmod o+x /home/dspace/frontend
chmod o+x /home/dspace/frontend/dist
chmod o+x /home/dspace/frontend/dist/browser
chmod -R o+r /home/dspace/frontend/dist/browser/assets
echo -e "\033[0;32m[✓]\033[0m Permisos o+x aplicados"

echo -e "\n\033[0;34m--- 8.4 Generando configuración Nginx ---\033[0m"
GEO_BLOCK=""
for IP_RANGE in ${HARVESTER_IPS:-}; do
  GEO_BLOCK="${GEO_BLOCK}    ${IP_RANGE}  1;\n"
done

NGINX_CONF="/etc/nginx/sites-available/dspace-${SCIBACK_CLIENT}"
cat > "${NGINX_CONF}" <<NGINX
limit_req_zone \$binary_remote_addr zone=frontend:10m   rate=10r/s;
limit_req_zone \$binary_remote_addr zone=api:10m        rate=5r/s;
limit_req_zone \$binary_remote_addr zone=oai_public:10m rate=2r/s;

geo \$is_institutional_harvester {
    default         0;
$(echo -e "$GEO_BLOCK")}

server {
    listen 80;
    server_name ${DSPACE_HOSTNAME};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DSPACE_HOSTNAME};

    ssl_certificate     /etc/ssl/certs/dspace-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/dspace-selfsigned.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy strict-origin-when-cross-origin;
    add_header X-Robots-Tag "index, follow";

    location ~ ^/assets/i18n/([a-z-]+)(\.[a-f0-9]+)?\.json\$ {
        root ${FRONTEND_DIR}/dist/browser;
        try_files /assets/i18n/\$1.json =404;
        expires 1h;
        add_header Cache-Control "public";
    }

    location /assets {
        root ${FRONTEND_DIR}/dist/browser;
        expires 1h;
        add_header Cache-Control "public";
        try_files \$uri \$uri/ =404;
    }

    location / {
        limit_req zone=frontend burst=20 nodelay;
        proxy_pass         http://localhost:${PM2_PORT:-4000};
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location /server {
        limit_req zone=api burst=10 nodelay;
        proxy_pass         http://localhost:8080/server;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }

    location /oai {
        limit_req zone=oai_public burst=5 nodelay;
        proxy_pass         http://localhost:8080/server/oai;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600s;
    }

    location /handle {
        limit_req zone=frontend burst=30 nodelay;
        proxy_pass         http://localhost:${PM2_PORT:-4000}/handle;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location /bitstream {
        limit_req zone=api burst=5 nodelay;
        proxy_pass         http://localhost:8080/bitstream;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
    }

    location /sitemap {
        proxy_pass         http://localhost:8080/sitemap;
        proxy_set_header   Host \$host;
    }

    location /solr         { return 403; }
    location /manager      { return 403; }
    location /host-manager { return 403; }

    location = /robots.txt {
        root /var/www/html;
        add_header Content-Type text/plain;
    }
}
NGINX

ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo -e "\n\033[0;34m--- 8.5 Generando robots.txt ---\033[0m"
mkdir -p /var/www/html
cat > /var/www/html/robots.txt <<'ROBOTS'
User-agent: GPTBot
User-agent: ClaudeBot
User-agent: anthropic-ai
User-agent: Google-Extended
User-agent: CCBot
User-agent: Bytespider
User-agent: FacebookBot
User-agent: Applebot-Extended
User-agent: cohere-ai
User-agent: PerplexityBot
Disallow: /server/
Disallow: /bitstream/
Disallow: /statistics/
Disallow: /browse
Disallow: /search
Allow: /handle/
Allow: /oai/

User-agent: *
Disallow: /server/api/
Disallow: /statistics/
Disallow: /browse
Disallow: /search
Allow: /handle/
Allow: /oai/
Allow: /sitemap*
ROBOTS

echo -e "\n\033[0;34m--- 8.6 Verificando y activando Nginx ---\033[0m"
nginx -t || { echo "[✗] nginx -t falló"; exit 1; }
systemctl enable nginx
systemctl restart nginx
echo -e "\033[0;32m[✓]\033[0m Nginx configurado para ${DSPACE_HOSTNAME}"

if [[ "${CERTBOT_AUTO:-false}" == "true" ]]; then
  echo -e "\n\033[0;34m--- 8.7 Generando certificado SSL con Certbot ---\033[0m"
  certbot --nginx -d "${DSPACE_HOSTNAME}" \
    --email "${CERTBOT_EMAIL:-soporte@sciback.pe}" \
    --agree-tos --non-interactive
  systemctl enable certbot.timer
  systemctl start certbot.timer
  echo -e "\033[0;32m[✓]\033[0m SSL activo y renovación automática configurada"
else
  echo -e "\033[1;33m[!]\033[0m Certbot no ejecutado (CERTBOT_AUTO=false)"
fi

# Resolución local
if ! grep -q "${DSPACE_HOSTNAME}" /etc/hosts 2>/dev/null; then
  echo "127.0.0.1 ${DSPACE_HOSTNAME}" >> /etc/hosts
  echo -e "\033[0;32m[✓]\033[0m ${DSPACE_HOSTNAME} agregado a /etc/hosts"
fi

# Reiniciar PM2
if command -v pm2 &>/dev/null; then
  sudo -u dspace pm2 restart all 2>/dev/null || true
  sleep 5
fi

echo -e "\033[0;32m[✓]\033[0m Nginx + SSL configurado ✓"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

#!/usr/bin/env bash
# SciBack — Etapa 08: Nginx + SSL + robots.txt

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"

[[ -f "${ENV_FILE}" ]] || { echo "[✗] No se encontró: ${ENV_FILE}"; exit 1; }

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

[[ "${INSTALL_NGINX:-yes}" == "skip" ]] && exit 99

ETAPA_INICIO=$(date +%s)

RUN_USER="${DSPACE_RUN_AS_USER:-dspace}"
RUN_GROUP="${DSPACE_RUN_AS_GROUP:-dspace}"
FRONTEND_DIR="${DSPACE_FRONTEND_DIR:-/home/dspace/frontend}"
DIST_BROWSER_DIR="${FRONTEND_DIR}/dist/browser"
PM2_PORT_VALUE="${PM2_PORT:-4000}"
PM2_APP_NAME="${DSPACE_PM2_APP_NAME:-dspace-${SCIBACK_CLIENT}}"
NVM_DIR="/home/${RUN_USER}/.nvm"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[✗] Falta comando requerido: $1"
    exit 1
  }
}

require_command apt-get
require_command nginx
require_command openssl
require_command grep
require_command sed
require_command systemctl
require_command sudo

echo -e "\n\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 08 — Nginx (reverse proxy + protección)\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~2-3 min\033[0m"

echo -e "\n\033[0;34m--- 8.1 Instalando Nginx ---\033[0m"
apt-get remove --purge -y nginx nginx-common nginx-core 2>/dev/null || true
apt-get install -y -q nginx certbot python3-certbot-nginx

[[ -f /etc/nginx/nginx.conf ]] || { echo "[✗] nginx.conf no existe"; exit 1; }

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

if ! grep -q 'sites-enabled' /etc/nginx/nginx.conf 2>/dev/null; then
  sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi

echo -e "\033[0;32m[✓]\033[0m Nginx instalado"

echo -e "\n\033[0;34m--- 8.2 Configurando SSL ---\033[0m"
LE_CERT="/etc/letsencrypt/live/${DSPACE_HOSTNAME}/fullchain.pem"
LE_KEY="/etc/letsencrypt/live/${DSPACE_HOSTNAME}/privkey.pem"
SS_CERT="/etc/ssl/certs/dspace-selfsigned.crt"
SS_KEY="/etc/ssl/private/dspace-selfsigned.key"

if [[ -f "${LE_CERT}" && -f "${LE_KEY}" ]]; then
  SSL_CERT="${LE_CERT}"
  SSL_KEY="${LE_KEY}"
  echo -e "\033[0;32m[✓]\033[0m Usando certificado Let's Encrypt existente"
else
  SSL_CERT="${SS_CERT}"
  SSL_KEY="${SS_KEY}"

  if [[ ! -f "${SS_CERT}" || ! -f "${SS_KEY}" ]]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "${SS_KEY}" \
      -out "${SS_CERT}" \
      -subj "/CN=${DSPACE_HOSTNAME}" >/dev/null 2>&1
    chmod 600 "${SS_KEY}"
    chmod 644 "${SS_CERT}"
    echo -e "\033[0;32m[✓]\033[0m Certificado SSL autofirmado generado"
  else
    echo -e "\033[1;33m[!]\033[0m Certificado autofirmado ya existe"
  fi
fi

echo -e "\n\033[0;34m--- 8.3 Validando build y permisos para assets del frontend ---\033[0m"
[[ -d "${DIST_BROWSER_DIR}" ]] || { echo "[✗] No existe ${DIST_BROWSER_DIR}. Ejecuta primero la etapa 07"; exit 1; }

chmod o+x "/home/${RUN_USER}"
chmod o+x "${FRONTEND_DIR}"
chmod o+x "${FRONTEND_DIR}/dist"
chmod o+x "${DIST_BROWSER_DIR}"

if [[ -d "${DIST_BROWSER_DIR}/assets" ]]; then
  chmod -R o+r "${DIST_BROWSER_DIR}/assets"
fi

echo -e "\033[0;32m[✓]\033[0m Permisos de lectura aplicados al frontend compilado"

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
$(echo -e "${GEO_BLOCK}")}

server {
    listen 80;
    listen [::]:80;
    server_name ${DSPACE_HOSTNAME};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DSPACE_HOSTNAME};

    ssl_certificate     ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_timeout 1d;
    ssl_session_cache   shared:SSL:10m;
    ssl_prefer_server_ciphers off;

    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header X-Robots-Tag "index, follow" always;

    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE:-1024m};

    location ~ ^/assets/i18n/([a-z-]+)(\.[a-f0-9]+)?\.json\$ {
        root ${DIST_BROWSER_DIR};
        try_files /assets/i18n/\$1.json =404;
        expires 1h;
        add_header Cache-Control "public";
    }

    location /assets {
        root ${DIST_BROWSER_DIR};
        expires 1h;
        add_header Cache-Control "public";
        try_files \$uri \$uri/ =404;
    }

    location ~* \.(css|js|woff2?|ttf|eot|svg|ico|map)$ {
        root ${DIST_BROWSER_DIR};
        expires 1h;
        add_header Cache-Control "public";
        try_files \$uri @frontend;
    }

    location @frontend {
        proxy_pass         http://127.0.0.1:${PM2_PORT_VALUE};
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Forwarded-Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_read_timeout 300s;
    }

    location / {
        limit_req zone=frontend burst=20 nodelay;
        proxy_pass         http://127.0.0.1:${PM2_PORT_VALUE};
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Forwarded-Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_read_timeout 300s;
    }

    location /server {
        limit_req zone=api burst=10 nodelay;
        proxy_pass         http://127.0.0.1:8080/server;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }

    location /oai {
        limit_req zone=oai_public burst=5 nodelay;
        proxy_pass         http://127.0.0.1:8080/server/oai;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600s;
    }

    location /handle {
        limit_req zone=frontend burst=30 nodelay;
        proxy_pass         http://127.0.0.1:${PM2_PORT_VALUE}/handle;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Forwarded-Host \$host;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /bitstream {
        limit_req zone=api burst=5 nodelay;
        proxy_pass         http://127.0.0.1:8080/bitstream;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 120s;
    }

    location /sitemap {
        proxy_pass         http://127.0.0.1:8080/sitemap;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location /solr         { return 403; }
    location /manager      { return 403; }
    location /host-manager { return 403; }

    location = /robots.txt {
        root /var/www/html;
        default_type text/plain;
    }
}
NGINX

ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo -e "\033[0;32m[✓]\033[0m Configuración Nginx generada"

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

chmod 644 /var/www/html/robots.txt

echo -e "\033[0;32m[✓]\033[0m robots.txt generado"

echo -e "\n\033[0;34m--- 8.6 Verificando y activando Nginx ---\033[0m"
nginx -t
systemctl enable nginx
systemctl restart nginx

echo -e "\033[0;32m[✓]\033[0m Nginx configurado para ${DSPACE_HOSTNAME}"

if [[ -f "${LE_CERT}" && -f "${LE_KEY}" ]]; then
  echo -e "\n\033[0;32m[✓]\033[0m Certificado Let's Encrypt ya existe — Certbot omitido"
elif [[ "${CERTBOT_AUTO:-false}" == "true" ]]; then
  echo -e "\n\033[0;34m--- 8.7 Generando certificado SSL con Certbot ---\033[0m"
  certbot --nginx \
    -d "${DSPACE_HOSTNAME}" \
    --email "${CERTBOT_EMAIL:-soporte@sciback.pe}" \
    --agree-tos \
    --non-interactive

  systemctl enable certbot.timer
  systemctl start certbot.timer

  nginx -t
  systemctl reload nginx

  echo -e "\033[0;32m[✓]\033[0m SSL activo y renovación automática configurada"
else
  echo -e "\033[1;33m[!]\033[0m Certbot no ejecutado (CERTBOT_AUTO=false)"
fi

echo -e "\n\033[0;34m--- 8.8 Resolución local y reinicio PM2 ---\033[0m"
if ! grep -q "${DSPACE_HOSTNAME}" /etc/hosts 2>/dev/null; then
  echo "127.0.0.1 ${DSPACE_HOSTNAME}" >> /etc/hosts
  echo -e "\033[0;32m[✓]\033[0m ${DSPACE_HOSTNAME} agregado a /etc/hosts"
fi

if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
  sudo -u "${RUN_USER}" bash -lc "
    set -Eeuo pipefail
    export NVM_DIR='${NVM_DIR}'
    source \"\$NVM_DIR/nvm.sh\"
    if command -v pm2 >/dev/null 2>&1; then
      pm2 restart '${PM2_APP_NAME}' || pm2 restart all || true
      pm2 save || true
    fi
  "
  sleep 5
fi

echo -e "\033[0;32m[✓]\033[0m Nginx + SSL configurado ✓"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

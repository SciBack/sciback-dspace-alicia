#!/bin/bash
# SciBack — patch-nginx-css.sh
# Agrega el bloque de servir CSS/JS estáticos directo desde dist/browser
# SIN tocar la config SSL/Certbot existente
set -euo pipefail

NGINX_CONF="/etc/nginx/sites-available/dspace-sciback-lab"

if grep -q 'location @frontend' "$NGINX_CONF" 2>/dev/null; then
  echo "[!] El bloque @frontend ya existe en la config. No se necesita parche."
  exit 0
fi

echo "[→] Parcheando $NGINX_CONF..."

# Insertar el bloque CSS justo antes de "location / {"
sed -i '/    location \/ {/{
i\    location ~* \\.(css|js|woff2?|ttf|eot|svg|ico|map)$ {\
        root /home/dspace/frontend/dist/browser;\
        expires 1h;\
        add_header Cache-Control "public";\
        try_files $uri @frontend;\
    }\
\
    location @frontend {\
        proxy_pass         http://localhost:4000;\
        proxy_set_header   Host localhost;\
        proxy_set_header   X-Forwarded-Host $host;\
        proxy_set_header   X-Real-IP $remote_addr;\
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header   X-Forwarded-Proto $scheme;\
    }\

}' "$NGINX_CONF"

echo "[→] Verificando config..."
nginx -t || { echo "[✗] nginx -t falló. Revisa la config."; exit 1; }

echo "[→] Reiniciando Nginx..."
systemctl restart nginx

echo "[✓] Parche aplicado. CSS/JS ahora se sirven directo desde dist/browser."
echo ""
echo "Verificar:"
echo "  curl -sk -I https://dspace.lab.sciback.com/sciback_theme_dspace7-theme.css | head -3"

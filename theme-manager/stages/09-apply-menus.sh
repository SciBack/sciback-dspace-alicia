#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/dspace-theme.sh"
init_trap

menu_block=$(cat <<'EOB'
<nav class="sciback-policy-menu">
  <a href="/">Inicio</a>
  <a href="/communities">Comunidades</a>
</nav>
EOB
)
replace_or_append_managed_block "${DSPACE_THEME_NAVBAR_HTML_FILE}" "menus" "$menu_block"
replace_or_append_managed_block "${DSPACE_THEME_NAVBAR_SCSS_FILE}" "menus" ".sciback-policy-menu { display:flex; gap:1rem; }"
log_info "Hooks de menús aplicados"

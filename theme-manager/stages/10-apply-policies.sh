#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/dspace-theme.sh"
init_trap

links=()
[[ "${ENABLE_ALICIA_POLICY_MENU}" == "true" ]] && links+=("<a href=\"${DSPACE_POLICY_ALICIA_URL}\">Alicia</a>")
[[ "${ENABLE_PRIVACY_MENU}" == "true" ]] && links+=("<a href=\"${DSPACE_POLICY_PRIVACY_URL}\">Privacidad</a>")
[[ "${ENABLE_TERMS_MENU}" == "true" ]] && links+=("<a href=\"${DSPACE_POLICY_TERMS_URL}\">Términos</a>")

policy_html="<div class=\"sciback-policies\">${links[*]}</div>"
replace_or_append_managed_block "${DSPACE_THEME_FOOTER_HTML_FILE}" "policies" "$policy_html"
replace_or_append_managed_block "${DSPACE_THEME_FOOTER_SCSS_FILE}" "policies" ".sciback-policies { display:flex; gap:1rem; justify-content:center; }"
log_info "Políticas aplicadas"

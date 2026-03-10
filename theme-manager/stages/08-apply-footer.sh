#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/dspace-theme.sh"
init_trap

if [[ ! -f "${DSPACE_THEME_FOOTER_HTML_FILE}" ]]; then
  if [[ "${DSPACE_THEME_CREATE_FOOTER_IF_MISSING}" == "true" ]]; then
    ensure_dir "$(dirname "${DSPACE_THEME_FOOTER_HTML_FILE}")"
    : > "${DSPACE_THEME_FOOTER_HTML_FILE}"
  else
    die "Footer HTML no existe y DSPACE_THEME_CREATE_FOOTER_IF_MISSING=false"
  fi
fi
[[ -f "${DSPACE_THEME_FOOTER_SCSS_FILE}" ]] || { ensure_dir "$(dirname "${DSPACE_THEME_FOOTER_SCSS_FILE}")"; : > "${DSPACE_THEME_FOOTER_SCSS_FILE}"; }

footer_html="${DSPACE_THEME_FOOTER_HTML}"
if [[ -z "$footer_html" ]]; then
  footer_html="<div class=\"sciback-footer\">${DSPACE_THEME_FOOTER_TEXT}</div>"
fi
replace_or_append_managed_block "${DSPACE_THEME_FOOTER_HTML_FILE}" "footer" "$footer_html"
replace_or_append_managed_block "${DSPACE_THEME_FOOTER_SCSS_FILE}" "footer" ".sciback-footer { text-align:center; padding:1rem; }"
log_info "Footer aplicado"

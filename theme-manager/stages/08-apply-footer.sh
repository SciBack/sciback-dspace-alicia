#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 08: Aplicar footer
# =============================================================================

set -Eeuo pipefail

readonly STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/fs.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/dspace-theme.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/ui.sh"

register_error_trap

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"

print_header "Etapa 08 — Aplicar footer"

load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths

[[ -n "${DSPACE_THEME_FOOTER_TEXT:-}" ]] || die "DSPACE_THEME_FOOTER_TEXT no está definido"

FOOTER_FILE="${DSPACE_TARGET_THEME_DIR}/components/footer/footer.component.html"
BACKUP_DIR="${ROOT_DIR}/backups"

ensure_dir "$(dirname "${FOOTER_FILE}")"
ensure_dir "${BACKUP_DIR}"

if bool_true "${CREATE_BACKUPS:-true}" && [[ -f "${FOOTER_FILE}" ]]; then
  backup_file "${FOOTER_FILE}" "${BACKUP_DIR}"
fi

cat > "${FOOTER_FILE}" <<HTML
<footer class="footer sciback-footer">
  <div class="container text-center py-3">
    ${DSPACE_THEME_FOOTER_TEXT}
  </div>
</footer>
HTML

log_info "Footer personalizado aplicado correctamente"
log_info "Archivo: ${FOOTER_FILE}"
log_info "Texto: ${DSPACE_THEME_FOOTER_TEXT}"

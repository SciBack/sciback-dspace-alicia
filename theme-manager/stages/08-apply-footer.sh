#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/fs.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.dspace.theme-manager}"
load_env_file "${ENV_FILE}"

FOOTER_FILE="${DSPACE_TARGET_THEME_DIR}/components/footer/footer.component.html"
ensure_dir "$(dirname "${FOOTER_FILE}")"

cat > "${FOOTER_FILE}" <<HTML
<footer class="footer sciback-footer">
  <div class="container text-center py-3">
    ${DSPACE_THEME_FOOTER_TEXT}
  </div>
</footer>
HTML

log_info "Footer personalizado en ${FOOTER_FILE}"

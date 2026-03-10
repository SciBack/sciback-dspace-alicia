#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/fs.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.dspace.theme-manager}"
load_env_file "${ENV_FILE}"

require_path_exists "${DSPACE_TARGET_THEME_DIR}" "theme destino"

SCSS_FILE="${DSPACE_TARGET_THEME_DIR}/styles/_variables.scss"
ensure_dir "$(dirname "${SCSS_FILE}")"

cat > "${SCSS_FILE}" <<SCSS
// Generado por theme-manager
$primary: ${DSPACE_THEME_PRIMARY};
$secondary: ${DSPACE_THEME_SECONDARY};
$accent: ${DSPACE_THEME_ACCENT};

:root {
  --sciback-primary: ${DSPACE_THEME_PRIMARY};
  --sciback-secondary: ${DSPACE_THEME_SECONDARY};
  --sciback-accent: ${DSPACE_THEME_ACCENT};
}
SCSS

log_info "Colores aplicados en ${SCSS_FILE}"

#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 05: Aplicar colores del theme
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

print_header "Etapa 05 — Aplicar colores"

load_env_file "${ENV_FILE}"
validate_config_vars
validate_dspace_paths

SCSS_FILE="${DSPACE_THEME_SCSS_VARIABLE_OVERRIDES_FILE:-}"
CSS_FILE="${DSPACE_THEME_CSS_VARIABLE_OVERRIDES_FILE:-}"
BACKUP_DIR="${DSPACE_THEME_BACKUP_DIR:-${ROOT_DIR}/backups}"

[[ -n "${SCSS_FILE}" ]] || die "DSPACE_THEME_SCSS_VARIABLE_OVERRIDES_FILE no está definido"
[[ -n "${CSS_FILE}" ]] || die "DSPACE_THEME_CSS_VARIABLE_OVERRIDES_FILE no está definido"

ensure_dir "$(dirname "${SCSS_FILE}")"
ensure_dir "$(dirname "${CSS_FILE}")"
ensure_dir "${BACKUP_DIR}"

if bool_true "${CREATE_BACKUPS:-true}"; then
  [[ -f "${SCSS_FILE}" ]] && backup_file "${SCSS_FILE}" "${BACKUP_DIR}"
  [[ -f "${CSS_FILE}" ]] && backup_file "${CSS_FILE}" "${BACKUP_DIR}"
fi

cat > "${SCSS_FILE}" <<SCSS
// BEGIN THEME MANAGER COLORS
// Generado por SciBack theme-manager
\$primary: ${DSPACE_THEME_PRIMARY};
\$secondary: ${DSPACE_THEME_SECONDARY};
\$accent: ${DSPACE_THEME_ACCENT};
// END THEME MANAGER COLORS
SCSS

cat > "${CSS_FILE}" <<CSS
/* BEGIN THEME MANAGER COLORS */
/* Generado por SciBack theme-manager */
:root {
  --sciback-primary: ${DSPACE_THEME_PRIMARY};
  --sciback-secondary: ${DSPACE_THEME_SECONDARY};
  --sciback-accent: ${DSPACE_THEME_ACCENT};
}
/* END THEME MANAGER COLORS */
CSS

log_info "Colores aplicados correctamente"
log_info "SCSS: ${SCSS_FILE}"
log_info "CSS : ${CSS_FILE}"
log_info "Primary  : ${DSPACE_THEME_PRIMARY}"
log_info "Secondary: ${DSPACE_THEME_SECONDARY}"
log_info "Accent   : ${DSPACE_THEME_ACCENT}"

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "${ROOT_DIR}/lib/common.sh" ]] && source "${ROOT_DIR}/lib/common.sh"
[[ -f "${ROOT_DIR}/lib/fs.sh" ]] && source "${ROOT_DIR}/lib/fs.sh"

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
die() { log_error "$*"; exit 1; }

require_file() {
  local f="$1"
  [[ -f "$f" ]] || die "Archivo requerido no encontrado: $f"
}

ensure_dir() {
  local d="$1"
  mkdir -p "$d"
}

backup_file() {
  local src="$1"
  local backup_dir="$2"
  ensure_dir "$backup_dir"
  local ts
  ts="$(date +%Y%m%d%H%M%S)"
  local dst="${backup_dir}/$(basename "$src").${ts}.bak"
  [[ -f "$src" ]] && cp "$src" "$dst"
  log_info "Backup creado: $dst"
}

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.dspace.theme-manager}"
[[ -f "${ENV_FILE}" ]] || die "No existe ENV_FILE: ${ENV_FILE}"

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

SCSS_FILE="${DSPACE_THEME_SCSS_VARIABLE_OVERRIDES_FILE:-}"
CSS_FILE="${DSPACE_THEME_CSS_VARIABLE_OVERRIDES_FILE:-}"
BACKUP_DIR="${DSPACE_THEME_BACKUP_DIR:-${ROOT_DIR}/backups}"

[[ -n "${SCSS_FILE}" ]] || die "DSPACE_THEME_SCSS_VARIABLE_OVERRIDES_FILE no está definido"
[[ -n "${CSS_FILE}" ]] || die "DSPACE_THEME_CSS_VARIABLE_OVERRIDES_FILE no está definido"

ensure_dir "$(dirname "${SCSS_FILE}")"
ensure_dir "$(dirname "${CSS_FILE}")"

[[ -f "${SCSS_FILE}" ]] && backup_file "${SCSS_FILE}" "${BACKUP_DIR}"
[[ -f "${CSS_FILE}" ]] && backup_file "${CSS_FILE}" "${BACKUP_DIR}"

cat > "${SCSS_FILE}" <<SCSS
// BEGIN THEME MANAGER COLORS
// Generado por theme-manager
\$primary: ${DSPACE_THEME_PRIMARY};
\$secondary: ${DSPACE_THEME_SECONDARY};
\$accent: ${DSPACE_THEME_ACCENT};
// END THEME MANAGER COLORS
SCSS

cat > "${CSS_FILE}" <<CSS
/* BEGIN THEME MANAGER COLORS */
/* Generado por theme-manager */
:root {
  --sciback-primary: ${DSPACE_THEME_PRIMARY};
  --sciback-secondary: ${DSPACE_THEME_SECONDARY};
  --sciback-accent: ${DSPACE_THEME_ACCENT};
}
/* END THEME MANAGER COLORS */
CSS

log_info "Colores aplicados en:"
log_info "  SCSS: ${SCSS_FILE}"
log_info "  CSS : ${CSS_FILE}"

#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 07: Aplicar banner
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

print_header "Etapa 07 — Aplicar banner"

load_env_file "${ENV_FILE}"
validate_config_vars

[[ -n "${DSPACE_THEME_BANNER_SOURCE:-}" ]] || die "DSPACE_THEME_BANNER_SOURCE no está definido"
[[ -n "${DSPACE_THEME_BANNER_TARGET:-}" ]] || die "DSPACE_THEME_BANNER_TARGET no está definido"

ensure_dir "$(dirname "${DSPACE_THEME_BANNER_SOURCE}")"
ensure_dir "$(dirname "${DSPACE_THEME_BANNER_TARGET}")"

log_info "Banner origen : ${DSPACE_THEME_BANNER_SOURCE}"
log_info "Banner destino: ${DSPACE_THEME_BANNER_TARGET}"

if [[ -f "${DSPACE_THEME_BANNER_SOURCE}" ]]; then
  if bool_true "${CREATE_BACKUPS:-true}" && [[ -f "${DSPACE_THEME_BANNER_TARGET}" ]]; then
    backup_file "${DSPACE_THEME_BANNER_TARGET}" "${ROOT_DIR}/backups"
  fi

  copy_file_safe "${DSPACE_THEME_BANNER_SOURCE}" "${DSPACE_THEME_BANNER_TARGET}"
  log_info "Banner aplicado correctamente"
else
  log_warn "Banner no encontrado en ${DSPACE_THEME_BANNER_SOURCE}"
  log_warn "Etapa omitida. Coloca el archivo y vuelve a ejecutar esta etapa."
fi

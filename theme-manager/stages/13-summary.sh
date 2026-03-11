#!/usr/bin/env bash
# =============================================================================
# SciBack — Theme Manager — Etapa 13: Resumen final
# =============================================================================

set -Eeuo pipefail

readonly STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/ui.sh"

register_error_trap

ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.theme-manager}"

print_header "Etapa 13 — Resumen final"

load_env_file "${ENV_FILE}"

cat <<MSG
Theme manager finalizado correctamente.

Perfil: ${DSPACE_THEME_PROFILE:-n/a}
Theme base: ${DSPACE_BASE_THEME_NAME:-n/a}
Theme destino: ${DSPACE_TARGET_THEME_NAME:-n/a}
Ruta theme: ${DSPACE_TARGET_THEME_DIR:-n/a}
Frontend: ${DSPACE_FRONTEND_DIR:-n/a}
Config app: ${DSPACE_DEFAULT_APP_CONFIG_FILE:-n/a}
Build command: ${DSPACE_YARN_BUILD_COMMAND:-n/a}
PM2 app: ${DSPACE_PM2_APP_NAME:-n/a}
Log: ${LOG_FILE}
MSG

log_info "Resumen emitido correctamente"

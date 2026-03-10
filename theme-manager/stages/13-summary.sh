#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
init_trap

print_summary_box "Theme Manager Summary" \
  "Theme base: ${DSPACE_BASE_THEME_NAME} (${DSPACE_BASE_THEME_DIR})" \
  "Theme target: ${DSPACE_TARGET_THEME_NAME} (${DSPACE_TARGET_THEME_DIR})" \
  "Config: ${DSPACE_DEFAULT_APP_CONFIG_FILE}" \
  "Build ejecutado: ${THEME_MANAGER_BUILD_EXECUTED:-false}" \
  "Restart ejecutado: ${THEME_MANAGER_RESTART_EXECUTED:-false}" \
  "Log: ${LOG_FILE}" \
  "Backups: ${DSPACE_THEME_BACKUP_DIR}"

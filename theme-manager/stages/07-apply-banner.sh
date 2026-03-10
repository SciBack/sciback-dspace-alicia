#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/fs.sh"
init_trap

copy_with_backup "${DSPACE_THEME_BANNER_SOURCE}" "${DSPACE_THEME_BANNER_TARGET}"
log_info "Banner aplicado"

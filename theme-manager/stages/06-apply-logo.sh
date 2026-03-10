#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/fs.sh"
init_trap

copy_with_backup "${DSPACE_THEME_LOGO_SOURCE}" "${DSPACE_THEME_LOGO_TARGET}"
copy_with_backup "${DSPACE_THEME_FAVICON_ICO_SOURCE}" "${DSPACE_THEME_FAVICON_ICO_TARGET}"
copy_with_backup "${DSPACE_THEME_FAVICON_SVG_SOURCE}" "${DSPACE_THEME_FAVICON_SVG_TARGET}"
copy_with_backup "${DSPACE_THEME_APPLE_TOUCH_ICON_SOURCE}" "${DSPACE_THEME_APPLE_TOUCH_ICON_TARGET}"
copy_with_backup "${DSPACE_THEME_WEBMANIFEST_SOURCE}" "${DSPACE_THEME_WEBMANIFEST_TARGET}"
log_info "Logo y favicons aplicados"

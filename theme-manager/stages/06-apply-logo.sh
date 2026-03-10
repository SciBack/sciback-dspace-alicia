#!/usr/bin/env bash
set -Eeuo pipefail

STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${STAGE_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/fs.sh"

register_error_trap
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.dspace.theme-manager}"
load_env_file "${ENV_FILE}"

copy_file_safe "${DSPACE_THEME_LOGO_SOURCE}" "${DSPACE_THEME_LOGO_TARGET}"

#!/usr/bin/env bash
set -Eeuo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

backup_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || die "No se puede respaldar; archivo no existe: ${file_path}"

  if ! bool_true "${CREATE_BACKUPS:-true}"; then
    log_info "Backups desactivados, omitido: ${file_path}"
    return 0
  fi

  local backup_dir="${ROOT_DIR}/backups"
  ensure_dir "${backup_dir}"
  local base_name
  base_name="$(basename "${file_path}")"
  local backup_path="${backup_dir}/${base_name}.$(date '+%Y%m%d%H%M%S').bak"

  cp -a "${file_path}" "${backup_path}"
  log_info "Backup creado: ${backup_path}"
}

require_path_exists() {
  local path="$1"
  local label="${2:-ruta}"
  [[ -e "${path}" ]] || die "No existe ${label}: ${path}"
}

require_file_exists() {
  local path="$1"
  local label="${2:-archivo}"
  [[ -f "${path}" ]] || die "No existe ${label}: ${path}"
}

copy_file_safe() {
  local src="$1"
  local dst="$2"
  require_file_exists "${src}" "origen"
  ensure_dir "$(dirname "${dst}")"
  cp -f "${src}" "${dst}"
  log_info "Copiado: ${src} -> ${dst}"
}

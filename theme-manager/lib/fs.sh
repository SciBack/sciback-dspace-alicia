#!/usr/bin/env bash
set -Eeuo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=theme-manager/lib/common.sh
source "${LIB_DIR}/common.sh"

ensure_dir() {
  mkdir -p "$1"
}

timestamp() {
  date '+%Y%m%d_%H%M%S'
}

backup_file() {
  local src="$1"
  [[ -e "$src" ]] || return 0
  ensure_dir "${DSPACE_THEME_BACKUP_DIR}"
  local base
  base="$(basename "$src")"
  local dst="${DSPACE_THEME_BACKUP_DIR}/${base}.$(timestamp).bak"
  cp -a "$src" "$dst"
  log_info "Backup creado: $dst"
}

backup_dir() {
  local src="$1"
  [[ -d "$src" ]] || return 0
  ensure_dir "${DSPACE_THEME_BACKUP_DIR}"
  local base
  base="$(basename "$src")"
  local dst="${DSPACE_THEME_BACKUP_DIR}/${base}.$(timestamp).bak"
  cp -a "$src" "$dst"
  log_info "Backup directorio creado: $dst"
}

run_as_configured_user() {
  local cmd="$*"
  if [[ -n "${DSPACE_RUN_AS_USER:-}" ]] && [[ "$(id -un)" != "$DSPACE_RUN_AS_USER" ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo -u "$DSPACE_RUN_AS_USER" bash -lc "$cmd"
    else
      su - "$DSPACE_RUN_AS_USER" -c "$cmd"
    fi
  else
    bash -lc "$cmd"
  fi
}

copy_with_backup() {
  local src="$1" dst="$2"
  require_file "$src"
  ensure_dir "$(dirname "$dst")"
  if [[ -f "$dst" && "${CREATE_BACKUPS:-true}" == "true" ]]; then
    backup_file "$dst"
  fi
  cp -a "$src" "$dst"
  log_info "Copiado: $src -> $dst"
}

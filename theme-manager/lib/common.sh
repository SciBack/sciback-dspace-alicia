#!/usr/bin/env bash
set -Eeuo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=theme-manager/lib/ui.sh
source "${LIB_DIR}/ui.sh"

now_ts() { date '+%Y-%m-%d %H:%M:%S'; }

log_raw() {
  local level="$1"; shift
  local msg="$*"
  local line="[$(now_ts)] [$level] ${msg}"
  printf '%s\n' "$line"
  if [[ -n "${LOG_FILE:-}" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s\n' "$line" >> "$LOG_FILE"
  fi
}

log_info() { log_raw INFO "$*"; }
log_warn() { log_raw WARN "$*"; }
log_error() { log_raw ERROR "$*"; }

die() {
  log_error "$*"
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Comando requerido no encontrado: $cmd"
}

require_file() { [[ -f "$1" ]] || die "Archivo requerido no existe: $1"; }
require_dir() { [[ -d "$1" ]] || die "Directorio requerido no existe: $1"; }

load_env_file() {
  local env_file="$1"
  require_file "$env_file"
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

on_error() {
  local ec=$?
  local line="${BASH_LINENO[0]:-unknown}"
  local cmd="${BASH_COMMAND:-unknown}"
  log_error "Fallo en línea ${line}. Comando: ${cmd}. Exit code: ${ec}"
  log_error "Revisar log: ${LOG_FILE:-N/A}"
  exit "$ec"
}

init_trap() {
  trap on_error ERR
}

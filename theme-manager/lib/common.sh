#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

: "${LOG_FILE:=${ROOT_DIR}/logs/theme-manager.log}"

mkdir -p "$(dirname "${LOG_FILE}")"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

_log() {
  local level="$1"
  shift
  local msg="$*"
  printf '[%s] [%s] %s\n' "$(timestamp)" "${level}" "${msg}" | tee -a "${LOG_FILE}"
}

log_info() { _log "INFO" "$*"; }
log_warn() { _log "WARN" "$*"; }
log_error() { _log "ERROR" "$*"; }

die() {
  log_error "$*"
  exit 1
}

on_error() {
  local exit_code="$?"
  local line_no="${1:-unknown}"
  local cmd="${2:-unknown}"
  log_error "Fallo en línea ${line_no}: ${cmd} (exit ${exit_code})"
  exit "${exit_code}"
}

register_error_trap() {
  trap 'on_error "${LINENO}" "${BASH_COMMAND}"' ERR
}

require_commands() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done
  if ((${#missing[@]} > 0)); then
    die "Faltan dependencias de sistema: ${missing[*]}"
  fi
}

load_env_file() {
  local env_file="$1"
  [[ -f "${env_file}" ]] || die "No existe archivo de entorno: ${env_file}"

  set -a
  # shellcheck disable=SC1090
  source "${env_file}"
  set +a

  : "${CREATE_BACKUPS:=true}"
  : "${STRICT_PATH_VALIDATION:=true}"
  : "${OVERWRITE_EXISTING_THEME:=false}"
  : "${DSPACE_THEME_USE_REGEX:=false}"
  : "${DSPACE_PM2_APP_NAME:=all}"
  : "${DSPACE_RUN_AS_USER:=dspace}"
}

bool_true() {
  local value="${1:-false}"
  [[ "${value}" == "true" || "${value}" == "1" || "${value}" == "yes" || "${value}" == "on" ]]
}

ensure_dir() {
  local dir="$1"
  mkdir -p "${dir}"
}

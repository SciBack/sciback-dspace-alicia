#!/usr/bin/env bash
# =============================================================================
# SciBack — theme-manager/lib/common.sh
# Utilidades compartidas para theme-manager
# =============================================================================

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_DIR="$(cd "${ROOT_DIR}/.." && pwd)"

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

log_info()  { _log "INFO" "$*"; }
log_warn()  { _log "WARN" "$*"; }
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

ensure_dir() {
  local dir="$1"
  mkdir -p "${dir}"
}

bool_true() {
  local value="${1:-false}"
  [[ "${value}" == "true" || "${value}" == "1" || "${value}" == "yes" || "${value}" == "on" ]]
}

bool_false() {
  local value="${1:-false}"
  [[ "${value}" == "false" || "${value}" == "0" || "${value}" == "no" || "${value}" == "off" ]]
}

require_file() {
  local path="$1"
  local label="${2:-archivo}"
  [[ -f "${path}" ]] || die "No existe ${label}: ${path}"
}

require_dir() {
  local path="$1"
  local label="${2:-directorio}"
  [[ -d "${path}" ]] || die "No existe ${label}: ${path}"
}

load_env_file() {
  local env_file="$1"
  require_file "${env_file}" "archivo de entorno"

  set -a
  # shellcheck disable=SC1090
  source "${env_file}"
  set +a

  # ─── Defaults generales ──────────────────────────────────
  : "${CREATE_BACKUPS:=true}"
  : "${STRICT_PATH_VALIDATION:=true}"
  : "${OVERWRITE_EXISTING_THEME:=false}"

  # ─── Defaults DSpace Theme ───────────────────────────────
  : "${DSPACE_THEME_USE_REGEX:=false}"
  : "${DSPACE_PM2_APP_NAME:=all}"
  : "${DSPACE_RUN_AS_USER:=dspace}"
  : "${DSPACE_FRONTEND_DIR:=/home/dspace/frontend}"

  # ─── Defaults operativos ─────────────────────────────────
  : "${LOG_FILE:=${ROOT_DIR}/logs/theme-manager.log}"
  ensure_dir "$(dirname "${LOG_FILE}")"
}

print_banner() {
  local title="$1"
  log_info "══════════════════════════════════════════════════════════"
  log_info "${title}"
  log_info "══════════════════════════════════════════════════════════"
}

run_as_dspace_user() {
  local user="${DSPACE_RUN_AS_USER:-dspace}"
  sudo -u "${user}" bash -lc "$*"
}

safe_cp() {
  local src="$1"
  local dst="$2"

  require_file "${src}" "archivo origen"
  cp "${src}" "${dst}"
}

backup_file() {
  local file_path="$1"
  local backup_dir="$2"

  require_file "${file_path}" "archivo a respaldar"
  ensure_dir "${backup_dir}"

  local base_name
  base_name="$(basename "${file_path}")"

  local backup_path="${backup_dir}/${base_name}.$(date +%Y%m%d-%H%M%S).bak"
  cp "${file_path}" "${backup_path}"
  log_info "Backup creado: ${backup_path}"
}

trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

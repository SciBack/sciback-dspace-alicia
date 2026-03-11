#!/usr/bin/env bash
# =============================================================================
# SciBack — theme-manager/lib/ui.sh
# Utilidades de salida visual (UI) para theme-manager
# =============================================================================

set -Eeuo pipefail

readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${LIB_DIR}/common.sh"

print_header() {
  local title="$1"

  printf '\n' | tee -a "${LOG_FILE}"
  printf '══════════════════════════════════════════════\n' | tee -a "${LOG_FILE}"
  printf '  %s\n' "${title}" | tee -a "${LOG_FILE}"
  printf '══════════════════════════════════════════════\n' | tee -a "${LOG_FILE}"
}

print_step() {
  local msg="$1"
  log_info "→ ${msg}"
}

run_with_spinner() {
  local message="$1"
  shift

  local tmp_out
  tmp_out="$(mktemp)"

  (
    "$@"
  ) >"${tmp_out}" 2>&1 &
  local cmd_pid=$!

  local spin='|/-\\'
  local i=0

  while kill -0 "${cmd_pid}" >/dev/null 2>&1; do
    i=$(( (i + 1) % 4 ))
    printf '\r[%c] %s' "${spin:$i:1}" "${message}"
    sleep 0.2
  done

  wait "${cmd_pid}" || {
    printf '\r[✗] %s\n' "${message}"
    cat "${tmp_out}" | tee -a "${LOG_FILE}"
    rm -f "${tmp_out}"
    return 1
  }

  printf '\r[✓] %s\n' "${message}"
  cat "${tmp_out}" >>"${LOG_FILE}"
  rm -f "${tmp_out}"
}

run_logged() {
  local message="$1"
  shift

  log_info "${message}"

  if "$@" >>"${LOG_FILE}" 2>&1; then
    log_info "✓ ${message}"
  else
    log_error "✗ ${message}"
    return 1
  fi
}

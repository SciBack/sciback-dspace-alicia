#!/usr/bin/env bash
set -Eeuo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

print_header() {
  local title="$1"
  printf '\n==== %s ====\n' "${title}" | tee -a "${LOG_FILE}"
}

run_with_spinner() {
  local message="$1"
  shift

  local tmp_out
  tmp_out="$(mktemp)"
  log_info "${message}"

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

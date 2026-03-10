#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_RED='\033[0;31m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_BLUE='\033[0;34m'
  C_BOLD='\033[1m'
else
  C_RESET=''
  C_RED=''
  C_GREEN=''
  C_YELLOW=''
  C_BLUE=''
  C_BOLD=''
fi

print_banner() {
  local msg="$1"
  printf '%b\n' "${C_BOLD}${C_BLUE}==> ${msg}${C_RESET}"
}

print_summary_box() {
  local title="$1"
  shift
  printf '%b\n' "${C_BOLD}${C_BLUE}================ ${title} ================${C_RESET}"
  for line in "$@"; do
    printf '  - %s\n' "$line"
  done
  printf '%b\n' "${C_BOLD}${C_BLUE}=============================================${C_RESET}"
}

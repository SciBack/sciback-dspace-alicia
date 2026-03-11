#!/usr/bin/env bash
# =============================================================================
# SciBack — theme-manager/lib/fs.sh
# Utilidades de sistema de archivos para theme-manager
# =============================================================================

set -Eeuo pipefail

readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${LIB_DIR}/common.sh"

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

require_dir_exists() {
  local path="$1"
  local label="${2:-directorio}"
  [[ -d "${path}" ]] || die "No existe ${label}: ${path}"
}

copy_file_safe() {
  local src="$1"
  local dst="$2"

  require_file_exists "${src}" "archivo origen"
  ensure_dir "$(dirname "${dst}")"

  cp -f "${src}" "${dst}"
  log_info "Copiado: ${src} -> ${dst}"
}

copy_dir_safe() {
  local src="$1"
  local dst="$2"

  require_dir_exists "${src}" "directorio origen"
  ensure_dir "$(dirname "${dst}")"

  cp -a "${src}" "${dst}"
  log_info "Directorio copiado: ${src} -> ${dst}"
}

remove_path_safe() {
  local path="$1"

  if [[ -e "${path}" ]]; then
    rm -rf "${path}"
    log_info "Eliminado: ${path}"
  else
    log_info "Ruta no existe, sin cambios: ${path}"
  fi
}

replace_in_file() {
  local file_path="$1"
  local search_pattern="$2"
  local replacement="$3"

  require_file_exists "${file_path}" "archivo"

  python3 - "${file_path}" "${search_pattern}" "${replacement}" <<'PY'
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
search = sys.argv[2]
replacement = sys.argv[3]

text = file_path.read_text(encoding="utf-8")
new_text = text.replace(search, replacement)

if text == new_text:
    print("Sin cambios")
else:
    file_path.write_text(new_text, encoding="utf-8")
    print("Reemplazo aplicado")
PY

  log_info "Reemplazo procesado en ${file_path}"
}

append_if_missing() {
  local file_path="$1"
  local needle="$2"
  local content_to_append="$3"

  require_file_exists "${file_path}" "archivo"

  if grep -Fq "${needle}" "${file_path}"; then
    log_info "Contenido ya presente en ${file_path}, sin cambios"
    return 0
  fi

  printf '\n%s\n' "${content_to_append}" >> "${file_path}"
  log_info "Contenido agregado en ${file_path}"
}

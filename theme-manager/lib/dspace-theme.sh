#!/usr/bin/env bash
set -Eeuo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"
# shellcheck source=lib/fs.sh
source "${LIB_DIR}/fs.sh"

validate_config_vars() {
  local required=(
    DSPACE_FRONTEND_DIR
    DSPACE_BASE_THEME_NAME
    DSPACE_TARGET_THEME_NAME
    DSPACE_BASE_THEME_DIR
    DSPACE_TARGET_THEME_DIR
    DSPACE_DEFAULT_APP_CONFIG_FILE
    DSPACE_THEME_EXTENDS
    DSPACE_YARN_BUILD_COMMAND
    DSPACE_PM2_APP_NAME
    DSPACE_RUN_AS_USER
  )

  local missing=()
  local var
  for var in "${required[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("${var}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    die "Variables requeridas faltantes en .env: ${missing[*]}"
  fi
}

validate_dspace_paths() {
  require_path_exists "${DSPACE_FRONTEND_DIR}" "DSPACE_FRONTEND_DIR"
  require_path_exists "${DSPACE_BASE_THEME_DIR}" "DSPACE_BASE_THEME_DIR"
  require_file_exists "${DSPACE_DEFAULT_APP_CONFIG_FILE}" "DSPACE_DEFAULT_APP_CONFIG_FILE"
}

create_theme_copy() {
  validate_dspace_paths

  if [[ -d "${DSPACE_TARGET_THEME_DIR}" ]]; then
    if bool_true "${OVERWRITE_EXISTING_THEME:-false}"; then
      log_warn "Theme destino existe. Se sobrescribirá: ${DSPACE_TARGET_THEME_DIR}"
      rm -rf "${DSPACE_TARGET_THEME_DIR}"
    else
      log_info "Theme destino ya existe y OVERWRITE_EXISTING_THEME=false. Sin cambios."
      return 0
    fi
  fi

  cp -a "${DSPACE_BASE_THEME_DIR}" "${DSPACE_TARGET_THEME_DIR}"
  log_info "Theme creado desde base: ${DSPACE_TARGET_THEME_DIR}"
}

theme_entry_exists() {
  rg -n "name:\s*'${DSPACE_TARGET_THEME_NAME}'" "${DSPACE_DEFAULT_APP_CONFIG_FILE}" >/dev/null 2>&1
}

register_theme_in_config() {
  require_commands python3
  require_file_exists "${DSPACE_DEFAULT_APP_CONFIG_FILE}" "archivo de config"

  if theme_entry_exists; then
    log_info "El theme ya está registrado: ${DSPACE_TARGET_THEME_NAME}"
    return 0
  fi

  backup_file "${DSPACE_DEFAULT_APP_CONFIG_FILE}"

  local regex_enabled="false"
  if bool_true "${DSPACE_THEME_USE_REGEX:-false}"; then
    regex_enabled="true"
  fi

  python3 - "$DSPACE_DEFAULT_APP_CONFIG_FILE" "$DSPACE_TARGET_THEME_NAME" "$DSPACE_THEME_EXTENDS" "$regex_enabled" "${DSPACE_THEME_REGEX:-.*}" <<'PY'
import sys
from pathlib import Path

cfg = Path(sys.argv[1])
name = sys.argv[2]
extends = sys.argv[3]
use_regex = sys.argv[4] == "true"
regex = sys.argv[5]

text = cfg.read_text(encoding="utf-8")

if f"name: '{name}'" in text:
    print("Theme ya registrado")
    sys.exit(0)

anchor = "themes: ThemeConfig[] = ["
idx = text.find(anchor)
if idx == -1:
    raise SystemExit("No se encontró bloque themes: ThemeConfig[]")

arr_start = text.find('[', idx)
if arr_start == -1:
    raise SystemExit("No se encontró inicio del arreglo de themes")

pos = arr_start
depth = 0
end = -1
while pos < len(text):
    ch = text[pos]
    if ch == '[':
        depth += 1
    elif ch == ']':
        depth -= 1
        if depth == 0:
            end = pos
            break
    pos += 1

if end == -1:
    raise SystemExit("No se pudo localizar cierre del arreglo themes")

block_lines = [
    "  {",
    f"    name: '{name}',",
    f"    extends: '{extends}'" + ("," if use_regex else ""),
]
if use_regex:
    block_lines.append(f"    regex: '{regex}'")
block_lines.append("  },")
block = "\n" + "\n".join(block_lines) + "\n"

new_text = text[:end] + block + text[end:]
cfg.write_text(new_text, encoding="utf-8")
print("Theme registrado correctamente")
PY

  log_info "Registro de theme actualizado en ${DSPACE_DEFAULT_APP_CONFIG_FILE}"
}

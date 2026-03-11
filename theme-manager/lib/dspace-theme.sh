#!/usr/bin/env bash
# =============================================================================
# SciBack — theme-manager/lib/dspace-theme.sh
# Utilidades de theme para DSpace 7.6.6
# =============================================================================

set -Eeuo pipefail

readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${LIB_DIR}/common.sh"
# shellcheck disable=SC1091
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
    die "Variables requeridas faltantes en .env.theme-manager: ${missing[*]}"
  fi

  if [[ "${DSPACE_BASE_THEME_NAME}" == "${DSPACE_TARGET_THEME_NAME}" ]]; then
    die "DSPACE_BASE_THEME_NAME y DSPACE_TARGET_THEME_NAME no deben ser iguales"
  fi

  log_info "Variables de configuración validadas correctamente"
}

validate_dspace_paths() {
  require_dir "${DSPACE_FRONTEND_DIR}" "DSPACE_FRONTEND_DIR"
  require_dir "${DSPACE_BASE_THEME_DIR}" "DSPACE_BASE_THEME_DIR"
  require_file "${DSPACE_DEFAULT_APP_CONFIG_FILE}" "DSPACE_DEFAULT_APP_CONFIG_FILE"

  if bool_true "${STRICT_PATH_VALIDATION:-true}"; then
    local expected_base="${DSPACE_FRONTEND_DIR}/src/themes/${DSPACE_BASE_THEME_NAME}"
    if [[ "${DSPACE_BASE_THEME_DIR}" != "${expected_base}" ]]; then
      log_warn "DSPACE_BASE_THEME_DIR no coincide con ruta esperada: ${expected_base}"
    fi
  fi

  log_info "Rutas DSpace validadas correctamente"
}

create_theme_copy() {
  validate_dspace_paths

  if [[ -d "${DSPACE_TARGET_THEME_DIR}" ]]; then
    if bool_true "${OVERWRITE_EXISTING_THEME:-false}"; then
      log_warn "El theme destino ya existe y será sobrescrito: ${DSPACE_TARGET_THEME_DIR}"

      if bool_true "${CREATE_BACKUPS:-true}"; then
        local backup_dir="${ROOT_DIR}/backups/$(basename "${DSPACE_TARGET_THEME_DIR}")"
        ensure_dir "${backup_dir}"
        cp -a "${DSPACE_TARGET_THEME_DIR}" "${backup_dir}/$(basename "${DSPACE_TARGET_THEME_DIR}").$(date +%Y%m%d-%H%M%S).bak"
        log_info "Backup del theme existente creado en ${backup_dir}"
      fi

      rm -rf "${DSPACE_TARGET_THEME_DIR}"
    else
      log_info "El theme destino ya existe y OVERWRITE_EXISTING_THEME=false. Sin cambios."
      return 0
    fi
  fi

  cp -a "${DSPACE_BASE_THEME_DIR}" "${DSPACE_TARGET_THEME_DIR}"
  log_info "Theme creado desde base: ${DSPACE_TARGET_THEME_DIR}"
}

theme_entry_exists() {
  require_commands rg
  rg -n "name:\s*'${DSPACE_TARGET_THEME_NAME}'" "${DSPACE_DEFAULT_APP_CONFIG_FILE}" >/dev/null 2>&1
}

register_theme_in_config() {
  require_commands python3
  require_file "${DSPACE_DEFAULT_APP_CONFIG_FILE}" "archivo de configuración"

  if theme_entry_exists; then
    log_info "El theme ya está registrado: ${DSPACE_TARGET_THEME_NAME}"
    return 0
  fi

  if bool_true "${CREATE_BACKUPS:-true}"; then
    backup_file "${DSPACE_DEFAULT_APP_CONFIG_FILE}" "${ROOT_DIR}/backups"
  fi

  local regex_enabled="false"
  if bool_true "${DSPACE_THEME_USE_REGEX:-false}"; then
    regex_enabled="true"
  fi

  python3 - \
    "${DSPACE_DEFAULT_APP_CONFIG_FILE}" \
    "${DSPACE_TARGET_THEME_NAME}" \
    "${DSPACE_THEME_EXTENDS}" \
    "${regex_enabled}" \
    "${DSPACE_THEME_REGEX:-.*}" <<'PY'
import sys
from pathlib import Path

cfg = Path(sys.argv[1])
theme_name = sys.argv[2]
theme_extends = sys.argv[3]
use_regex = sys.argv[4] == "true"
theme_regex = sys.argv[5]

text = cfg.read_text(encoding="utf-8")

if f"name: '{theme_name}'" in text:
    print("Theme ya registrado")
    sys.exit(0)

anchor = "themes: ThemeConfig[] = ["
idx = text.find(anchor)
if idx == -1:
    raise SystemExit("No se encontró bloque themes: ThemeConfig[]")

arr_start = text.find("[", idx)
if arr_start == -1:
    raise SystemExit("No se encontró inicio del arreglo themes")

pos = arr_start
depth = 0
arr_end = -1

while pos < len(text):
    ch = text[pos]
    if ch == "[":
        depth += 1
    elif ch == "]":
        depth -= 1
        if depth == 0:
            arr_end = pos
            break
    pos += 1

if arr_end == -1:
    raise SystemExit("No se pudo localizar cierre del arreglo themes")

block_lines = [
    "  {",
    f"    name: '{theme_name}',",
    f"    extends: '{theme_extends}'" + ("," if use_regex else ""),
]

if use_regex:
    block_lines.append(f"    regex: '{theme_regex}'")

block_lines.append("  },")

block = "\n" + "\n".join(block_lines) + "\n"
new_text = text[:arr_end] + block + text[arr_end:]

cfg.write_text(new_text, encoding="utf-8")
print("Theme registrado correctamente")
PY

  log_info "Theme registrado en ${DSPACE_DEFAULT_APP_CONFIG_FILE}"
}

get_theme_assets_dir() {
  printf '%s\n' "${DSPACE_TARGET_THEME_DIR}/assets"
}

get_theme_images_dir() {
  if [[ -n "${DSPACE_TARGET_THEME_IMAGES_DIR:-}" ]]; then
    printf '%s\n' "${DSPACE_TARGET_THEME_IMAGES_DIR}"
  else
    printf '%s\n' "${DSPACE_TARGET_THEME_DIR}/assets/images"
  fi
}

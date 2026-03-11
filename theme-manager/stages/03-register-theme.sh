#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Cargar librerías si existen
[[ -f "${ROOT_DIR}/lib/common.sh" ]] && source "${ROOT_DIR}/lib/common.sh"
[[ -f "${ROOT_DIR}/lib/fs.sh" ]] && source "${ROOT_DIR}/lib/fs.sh"

# Fallbacks por si las librerías no traen estas funciones
log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
die() { log_error "$*"; exit 1; }

require_file() {
  local f="$1"
  [[ -f "$f" ]] || die "Archivo requerido no encontrado: $f"
}

ensure_dir() {
  local d="$1"
  mkdir -p "$d"
}

backup_file() {
  local src="$1"
  local backup_dir="$2"
  ensure_dir "$backup_dir"
  local ts
  ts="$(date +%Y%m%d%H%M%S)"
  local dst="${backup_dir}/$(basename "$src").${ts}.bak"
  cp "$src" "$dst"
  log_info "Backup creado: $dst"
}

# Cargar .env
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.dspace.theme-manager}"
[[ -f "${ENV_FILE}" ]] || die "No existe ENV_FILE: ${ENV_FILE}"

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

require_file "${DSPACE_DEFAULT_APP_CONFIG_FILE}"

if [[ "${CREATE_BACKUPS:-true}" == "true" ]]; then
  backup_file "${DSPACE_DEFAULT_APP_CONFIG_FILE}" "${DSPACE_THEME_BACKUP_DIR:-${ROOT_DIR}/backups}"
fi

regex_enabled="${DSPACE_THEME_USE_REGEX:-false}"

python3 - "$DSPACE_DEFAULT_APP_CONFIG_FILE" "$DSPACE_TARGET_THEME_NAME" "$DSPACE_THEME_EXTENDS" "$regex_enabled" "${DSPACE_THEME_REGEX:-.*}" <<'PY'
import sys
from pathlib import Path

cfg = Path(sys.argv[1])
name = sys.argv[2]
extends = sys.argv[3]
use_regex = sys.argv[4].lower() == "true"
regex = sys.argv[5]

text = cfg.read_text(encoding="utf-8")

begin_marker = f"// BEGIN THEME MANAGER: {name}"
end_marker = f"// END THEME MANAGER: {name}"

block_lines = [
    f"    {begin_marker}",
    "    {",
    f"      name: '{name}',",
    f"      extends: '{extends}',",
]
if use_regex:
    block_lines.append(f"      regex: '{regex}',")
block_lines.extend([
    "    },",
    f"    {end_marker}",
])
block = "\n".join(block_lines)

# Si ya existe bloque administrado, reemplazarlo
if begin_marker in text and end_marker in text:
    start = text.index(begin_marker)
    start = text.rfind("\n", 0, start) + 1
    end = text.index(end_marker, start)
    end = text.find("\n", end)
    if end == -1:
        end = len(text)
    else:
        end += 1
    new_text = text[:start] + block + "\n" + text[end:]
    cfg.write_text(new_text, encoding="utf-8")
    print("Theme manager block actualizado correctamente")
    sys.exit(0)

# Si ya existe por nombre, no duplicar
if f"name: '{name}'" in text:
    print("Theme ya registrado; no se realizaron cambios")
    sys.exit(0)

anchor = "themes: ThemeConfig[] = ["
anchor_idx = text.find(anchor)
if anchor_idx == -1:
    raise SystemExit("No se encontró el ancla exacta: themes: ThemeConfig[] = [")

insert_at = anchor_idx + len(anchor)
insertion = "\n" + block + "\n"

new_text = text[:insert_at] + insertion + text[insert_at:]
cfg.write_text(new_text, encoding="utf-8")
print("Theme registrado correctamente")
PY

log_info "Registro de theme actualizado en ${DSPACE_DEFAULT_APP_CONFIG_FILE}"

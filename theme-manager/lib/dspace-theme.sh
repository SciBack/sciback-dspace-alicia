#!/usr/bin/env bash
set -Eeuo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=theme-manager/lib/fs.sh
source "${LIB_DIR}/fs.sh"

managed_start() { local k="$1"; echo "<!-- BEGIN THEME MANAGER: ${k} -->"; }
managed_end() { local k="$1"; echo "<!-- END THEME MANAGER: ${k} -->"; }

replace_or_append_managed_block() {
  local file="$1" key="$2" content="$3"
  local start end
  start="$(managed_start "$key")"
  end="$(managed_end "$key")"

  [[ -f "$file" ]] || : > "$file"
  if [[ "${CREATE_BACKUPS:-true}" == "true" ]]; then
    backup_file "$file"
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" -v content="$content" '
    BEGIN {inblk=0; done=0}
    $0==start {inblk=1; if(!done){print start; print content; print end; done=1} next}
    $0==end {inblk=0; next}
    !inblk {print}
    END {if(!done){print ""; print start; print content; print end}}
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

ensure_theme_registered() {
  local file="$1"
  require_file "$file"
  if [[ "${CREATE_BACKUPS:-true}" == "true" ]]; then
    backup_file "$file"
  fi

  python3 - "$file" <<'PY'
import os,sys,re
path=sys.argv[1]
name=os.environ['DSPACE_TARGET_THEME_NAME']
extends=os.environ['DSPACE_BASE_THEME_NAME']
use_regex=os.environ.get('DSPACE_THEME_USE_REGEX','false').lower()=='true'
regex_val=os.environ.get('DSPACE_THEME_REGEX','.*')
assets=f"assets/{name}/images/favicons"

block_lines=[
f"    // BEGIN THEME MANAGER: {name}",
"    {",
f"      name: '{name}',",
]
if use_regex:
    block_lines.append(f"      regex: '{regex_val}',")
block_lines += [
f"      extends: '{extends}',",
"      headTags: [",
f"        {{ tagName: 'link', attributes: {{ rel: 'icon', href: '{assets}/favicon.ico', sizes: 'any' }} }},",
f"        {{ tagName: 'link', attributes: {{ rel: 'icon', href: '{assets}/favicon.svg', type: 'image/svg+xml' }} }},",
f"        {{ tagName: 'link', attributes: {{ rel: 'apple-touch-icon', href: '{assets}/apple-touch-icon.png' }} }},",
f"        {{ tagName: 'link', attributes: {{ rel: 'manifest', href: '{assets}/manifest.webmanifest' }} }},",
"      ],",
"    },",
f"    // END THEME MANAGER: {name}",
]
new_block="\n".join(block_lines)

with open(path,'r',encoding='utf-8') as f:
    data=f.read()

m=re.search(r"themes\s*:\s*ThemeConfig\[\]\s*=\s*\[",data)
if not m:
    raise SystemExit("No se encontró bloque themes: ThemeConfig[] = [")
start=m.end()
# find matching ]; from start
idx=data.find('];',start)
if idx==-1:
    raise SystemExit('No se encontró cierre del arreglo themes')
arr=data[start:idx]
arr=re.sub(r"\n?\s*// BEGIN THEME MANAGER: "+re.escape(name)+r".*?// END THEME MANAGER: "+re.escape(name)+r"\n?", "\n", arr, flags=re.S)
arr=arr.lstrip('\n')
arr_new="\n"+new_block+"\n"+arr
out=data[:start]+arr_new+data[idx:]
with open(path,'w',encoding='utf-8') as f:
    f.write(out)
print(f"Theme {name} registrado/actualizado en {path}")
PY

  log_info "Theme registrado/actualizado en $file"
}

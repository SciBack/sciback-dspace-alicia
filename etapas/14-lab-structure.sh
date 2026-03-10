#!/bin/bash
# =============================================================================
# SciBack — Etapa 14: Estructura inicial Lab (comunidades/colecciones)
# Crea jerarquía desde variables LAB_* definidas en .env.dspace.deploy
# Usa DSpace CLI: structure-builder
# =============================================================================
set -euo pipefail

ETAPA_INICIO=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.dspace.deploy}"

# Cargar variables si no vienen desde install.sh
if [[ -z "${LAB_STRUCTURE:-}" || -z "${LAB_ROOT_COMMUNITY:-}" || -z "${LAB_SUBCOMMUNITIES:-}" ]]; then
  [[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || {
    echo "[✗] No se encontró: $ENV_FILE"
    exit 1
  }
fi

if [[ "${LAB_STRUCTURE:-false}" != "true" ]]; then
  echo "[!] LAB_STRUCTURE no está en true. Etapa 14 omitida."
  exit 99
fi

DSPACE_DIR="${DSPACE_DIR:-/dspace}"
DSPACE_BIN="${DSPACE_DIR}/bin/dspace"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
LOG_FILE="/tmp/sciback-lab-structure.log"
WORK_DIR="/tmp/sciback-lab-structure"
EXPORT_XML="${WORK_DIR}/existing-structure.xml"
IMPORT_XML="${WORK_DIR}/import-structure.xml"
RESULT_XML="${WORK_DIR}/import-result.xml"

mkdir -p "$WORK_DIR"
sudo chown -R dspace:dspace "$WORK_DIR"
sudo chmod 775 "$WORK_DIR"
: > "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

TOTAL_STEPS=6

progress_bar() {
  local current="$1"
  local total="$2"
  local width=32
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local percent=$(( current * 100 / total ))

  printf "\n["
  printf "%0.s#" $(seq 1 "$filled")
  printf "%0.s-" $(seq 1 "$empty")
  printf "] %d%% (%d/%d)\n" "$percent" "$current" "$total"
}

step() {
  local n="$1"
  local msg="$2"
  echo ""
  echo -e "\033[0;34m── ${n}. ${msg} ─────────────────────────────\033[0m"
  progress_bar "$n" "$TOTAL_STEPS"
}

run_dspace() {
  sudo -u dspace "$DSPACE_BIN" "$@"
}

xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//\'/&apos;}"
  printf '%s' "$s"
}

normalize_name() {
  local input="$1"
  echo "$input" \
    | tr '[:lower:]' '[:upper:]' \
    | sed -E 's/[^A-Z0-9]+/_/g; s/_+/_/g; s/^_+|_+$//g'
}

trim() {
  echo "$1" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

generate_subcommunity_xml() {
  local subcommunity_name="$1"
  local norm var_name collections
  local col col_trimmed

  norm="$(normalize_name "$subcommunity_name")"
  var_name="LAB_COLLECTIONS__${norm}"
  collections="${!var_name:-}"

  echo "    <community>"
  echo "      <name>$(xml_escape "$subcommunity_name")</name>"

  if [[ -n "$collections" ]]; then
    IFS='|' read -r -a COLS <<< "$collections"
    for col in "${COLS[@]}"; do
      col_trimmed="$(trim "$col")"
      [[ -n "$col_trimmed" ]] || continue
      echo "      <collection>"
      echo "        <name>$(xml_escape "$col_trimmed")</name>"
      echo "      </collection>"
    done
  else
    echo "      <!-- Sin colecciones definidas para ${var_name} -->"
  fi

  echo "    </community>"
}

echo ""
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Etapa 14 — Estructura inicial SciBack Lab\033[0m"
echo -e "\033[0;34m═══════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  Tiempo estimado: ~1-2 min\033[0m"

step 1 "Validando prerrequisitos"
[[ -x "$DSPACE_BIN" ]] || { echo "[✗] No ejecutable: ${DSPACE_BIN}"; exit 1; }
[[ -n "$ADMIN_EMAIL" ]] || { echo "[✗] ADMIN_EMAIL vacío"; exit 1; }
[[ -n "${LAB_ROOT_COMMUNITY:-}" ]] || { echo "[✗] LAB_ROOT_COMMUNITY vacío"; exit 1; }
[[ -n "${LAB_SUBCOMMUNITIES:-}" ]] || { echo "[✗] LAB_SUBCOMMUNITIES vacío"; exit 1; }
echo "[✓] Prerrequisitos OK"

step 2 "Exportando estructura actual"
run_dspace structure-builder -x -e "$ADMIN_EMAIL" -o "$EXPORT_XML"
echo "[✓] Export generado: $EXPORT_XML"

step 3 "Comprobando idempotencia"
if grep -Fq "<name>${LAB_ROOT_COMMUNITY}</name>" "$EXPORT_XML"; then
  echo "[!] La comunidad raíz '${LAB_ROOT_COMMUNITY}' ya existe. Etapa omitida de forma segura."
  ETAPA_FIN=$(date +%s)
  DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
  echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"
  exit 0
fi
echo "[✓] La comunidad raíz no existe aún"

step 4 "Generando XML de importación"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<import_structure>'
  echo '  <community>'
  echo "    <name>$(xml_escape "$LAB_ROOT_COMMUNITY")</name>"

  IFS='|' read -r -a SUBS <<< "${LAB_SUBCOMMUNITIES}"
  for sub in "${SUBS[@]}"; do
    sub_trimmed="$(trim "$sub")"
    [[ -n "$sub_trimmed" ]] || continue
    generate_subcommunity_xml "$sub_trimmed"
  done

  echo '  </community>'
  echo '</import_structure>'
} > "$IMPORT_XML"

echo "[✓] XML de importación generado: $IMPORT_XML"
echo ""
echo "Contenido generado:"
sed 's/^/  /' "$IMPORT_XML"

step 5 "Importando estructura con structure-builder"
run_dspace structure-builder -f "$IMPORT_XML" -e "$ADMIN_EMAIL" -o "$RESULT_XML"
echo "[✓] Importación completada"
echo "[✓] Resultado: $RESULT_XML"

step 6 "Reiniciando Tomcat"
systemctl restart tomcat9
sleep 5
echo "[✓] Tomcat reiniciado"

echo ""
echo -e "\033[0;32m[✓]\033[0m Estructura Lab procesada correctamente"
echo "    Comunidad raíz: ${LAB_ROOT_COMMUNITY}"
echo "    Log: ${LOG_FILE}"
echo "    XML importación: ${IMPORT_XML}"
echo "    XML resultado:   ${RESULT_XML}"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

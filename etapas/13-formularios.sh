#!/usr/bin/env bash
# =============================================================================
# SciBack — Etapa 13: Formularios de envío ALICIA/RENATI para tesis
# DSpace 7.6.6
#
# FIX CRÍTICO:
#   NO usar <dc-qualifier></dc-qualifier> vacío
#   NO usar <dc-qualifier/> vacío
#   DSpace 7.6.6 puede interpretar qualifier vacío como ".null"
#   y provocar errores en DCInputsReader / Tomcat
#
# Estructura usada:
#   <form> -> <row> -> <field>
# =============================================================================

set -Eeuo pipefail

ETAPA_INICIO=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env.deploy}"

[[ -f "${ENV_FILE}" ]] || { echo "[✗] No se encontró: ${ENV_FILE}"; exit 1; }

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

[[ "${INSTALL_FORMULARIOS:-yes}" == "skip" ]] && exit 99
[[ "$(id -u)" -eq 0 ]] || { echo "[✗] Ejecutar con sudo"; exit 1; }

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()   { echo -e "${CYAN}[→]${NC} $1"; }
header() {
  echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    info "Instalando dependencia faltante: $1"
    apt-get install -y -q "$2"
  }
}

require_command xmllint libxml2-utils
require_command python3 python3
require_command curl curl
require_command grep grep
require_command tee coreutils
require_command cp coreutils
require_command mktemp coreutils
require_command systemctl systemd

DSPACE_DIR="${DSPACE_DIR:-/dspace}"
FORMS_FILE="${DSPACE_DIR}/config/submission-forms.xml"
VOCAB_DIR="${DSPACE_DIR}/config/controlled-vocabularies"

BACKUP="${FORMS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
XML_FRAGMENT="$(mktemp /tmp/sciback-thesis-forms-XXXXXX.xml)"

LOG_FILE="/tmp/sciback-input-forms-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

cleanup() {
  rm -f "${XML_FRAGMENT}"
}
trap cleanup EXIT

header "Etapa 13 — Formularios ALICIA/RENATI para tesis"
log "Archivo: ${FORMS_FILE}"
log "Log: ${LOG_FILE}"
echo -e "${CYAN}  Tiempo estimado: ~1-3 min${NC}"

header "Paso 1 — Prerequisitos"
[[ -f "${FORMS_FILE}" ]] || error "No se encontró: ${FORMS_FILE}"

for vocab in renati-type.xml renati-level.xml dc-type.xml dc-accessrights.xml dc-subject-ocde.xml; do
  [[ -f "${VOCAB_DIR}/${vocab}" ]] && log "Vocabulario OK: ${vocab}" || warn "Faltante: ${vocab}"
done

header "Paso 2 — Backup y limpieza"
cp "${FORMS_FILE}" "${BACKUP}"
log "Backup: ${BACKUP}"

if grep -q 'scibackThesisPageOne' "${FORMS_FILE}" 2>/dev/null || grep -q 'scibackThesisPageTwo' "${FORMS_FILE}" 2>/dev/null; then
  warn "Eliminando formularios scibackThesis anteriores..."
  python3 - "${FORMS_FILE}" <<'PYCLEAN'
import re
import sys

forms_file = sys.argv[1]
with open(forms_file, "r", encoding="utf-8") as fh:
    content = fh.read()

content = re.sub(r'<!--\s*SciBack thesis ALICIA.*?-->\s*', '', content, flags=re.DOTALL)
content = re.sub(r'\s*<form\s+name="scibackThesisPageOne".*?</form>', '', content, flags=re.DOTALL)
content = re.sub(r'\s*<form\s+name="scibackThesisPageTwo".*?</form>', '', content, flags=re.DOTALL)

with open(forms_file, "w", encoding="utf-8") as fh:
    fh.write(content)

print("Limpieza OK")
PYCLEAN
fi

header "Paso 3 — Generando fragmento XML"

cat > "${XML_FRAGMENT}" <<'XMLEOF'

  <!-- SciBack thesis ALICIA/RENATI v3.0 -->

  <form name="scibackThesisPageOne">

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>title</dc-element>
      <repeatable>false</repeatable>
      <label>Título</label>
      <input-type>onebox</input-type>
      <hint>Título completo de la tesis.</hint>
      <required>Debe ingresar el título.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>title</dc-element>
      <dc-qualifier>alternative</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Título alternativo</label>
      <input-type>onebox</input-type>
      <hint>Título alternativo, por ejemplo en inglés.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>contributor</dc-element>
      <dc-qualifier>author</dc-qualifier>
      <repeatable>true</repeatable>
      <label>Autor</label>
      <input-type>onebox</input-type>
      <hint>Formato recomendado: Apellidos, Nombres.</hint>
      <required>Debe ingresar al menos un autor.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>author</dc-element>
      <dc-qualifier>dni</dc-qualifier>
      <repeatable>false</repeatable>
      <label>DNI del autor</label>
      <input-type>onebox</input-type>
      <hint>DNI del autor (8 dígitos), si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>author</dc-element>
      <dc-qualifier>cext</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Carné de extranjería del autor</label>
      <input-type>onebox</input-type>
      <hint>Solo si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>author</dc-element>
      <dc-qualifier>pasaporte</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Pasaporte del autor</label>
      <input-type>onebox</input-type>
      <hint>Solo si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>author</dc-element>
      <dc-qualifier>cedula</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Cédula del autor</label>
      <input-type>onebox</input-type>
      <hint>Solo si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>contributor</dc-element>
      <dc-qualifier>advisor</dc-qualifier>
      <repeatable>true</repeatable>
      <label>Asesor</label>
      <input-type>onebox</input-type>
      <hint>Formato recomendado: Apellidos, Nombres.</hint>
      <required>Debe ingresar al menos un asesor.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>advisor</dc-element>
      <dc-qualifier>dni</dc-qualifier>
      <repeatable>false</repeatable>
      <label>DNI del asesor</label>
      <input-type>onebox</input-type>
      <hint>DNI del asesor (8 dígitos), si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>advisor</dc-element>
      <dc-qualifier>cext</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Carné de extranjería del asesor</label>
      <input-type>onebox</input-type>
      <hint>Solo si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>advisor</dc-element>
      <dc-qualifier>pasaporte</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Pasaporte del asesor</label>
      <input-type>onebox</input-type>
      <hint>Solo si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>advisor</dc-element>
      <dc-qualifier>cedula</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Cédula del asesor</label>
      <input-type>onebox</input-type>
      <hint>Solo si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>advisor</dc-element>
      <dc-qualifier>orcid</dc-qualifier>
      <repeatable>false</repeatable>
      <label>ORCID del asesor</label>
      <input-type>onebox</input-type>
      <hint>Formato recomendado: https://orcid.org/0000-0000-0000-0000</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>date</dc-element>
      <dc-qualifier>issued</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Fecha de publicación</label>
      <input-type>date</input-type>
      <hint>Fecha de sustentación o publicación.</hint>
      <required>Debe ingresar la fecha.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>publisher</dc-element>
      <repeatable>false</repeatable>
      <label>Editor / institución</label>
      <input-type>onebox</input-type>
      <hint>Ejemplo: Universidad Peruana Unión.</hint>
      <required>Debe ingresar el editor o institución.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>publisher</dc-element>
      <dc-qualifier>country</dc-qualifier>
      <repeatable>false</repeatable>
      <label>País de publicación</label>
      <input-type>onebox</input-type>
      <hint>Código ISO 3166-1 alfa-2. Ejemplo: PE.</hint>
      <required>Debe ingresar el país.</required>
    </field></row>

    <row><field>
      <dc-schema>thesis</dc-schema>
      <dc-element>degree</dc-element>
      <dc-qualifier>name</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Nombre del grado</label>
      <input-type>onebox</input-type>
      <hint>Ejemplo: Bachiller en Ingeniería Ambiental.</hint>
      <required>Debe ingresar el nombre del grado.</required>
    </field></row>

    <row><field>
      <dc-schema>thesis</dc-schema>
      <dc-element>degree</dc-element>
      <dc-qualifier>discipline</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Programa / disciplina</label>
      <input-type>onebox</input-type>
      <hint>Nombre del programa académico.</hint>
      <required>Debe ingresar la disciplina.</required>
    </field></row>

    <row><field>
      <dc-schema>thesis</dc-schema>
      <dc-element>degree</dc-element>
      <dc-qualifier>grantor</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Institución otorgante</label>
      <input-type>onebox</input-type>
      <hint>Unidad académica o institución que otorga el grado.</hint>
      <required>Debe ingresar la institución otorgante.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>level</dc-element>
      <repeatable>false</repeatable>
      <label>Nivel académico</label>
      <input-type>onebox</input-type>
      <hint>Seleccionar el nivel según RENATI.</hint>
      <required>Debe seleccionar el nivel académico.</required>
      <vocabulary closed="true">renati-level</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>type</dc-element>
      <repeatable>false</repeatable>
      <label>Tipo RENATI</label>
      <input-type>onebox</input-type>
      <hint>Seleccionar el tipo de trabajo de investigación.</hint>
      <required>Debe seleccionar el tipo RENATI.</required>
      <vocabulary closed="true">renati-type</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>type</dc-element>
      <repeatable>false</repeatable>
      <label>Tipo de recurso</label>
      <input-type>onebox</input-type>
      <hint>Tipo de recurso compatible con COAR/OpenAIRE.</hint>
      <required>Debe seleccionar el tipo de recurso.</required>
      <vocabulary closed="true">dc-type</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>language</dc-element>
      <dc-qualifier>iso</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Idioma</label>
      <input-type value-pairs-name="common_iso_languages">dropdown</input-type>
      <hint>Idioma principal del documento.</hint>
      <required>Debe seleccionar el idioma.</required>
    </field></row>

  </form>

  <form name="scibackThesisPageTwo">

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>description</dc-element>
      <dc-qualifier>abstract</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Resumen</label>
      <input-type>textarea</input-type>
      <hint>Resumen en el idioma principal del documento.</hint>
      <required>Debe ingresar el resumen.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>subject</dc-element>
      <repeatable>true</repeatable>
      <label>Palabras clave</label>
      <input-type>onebox</input-type>
      <hint>Una palabra clave por campo.</hint>
      <required>Debe ingresar al menos una palabra clave.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>subject</dc-element>
      <dc-qualifier>ocde</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Clasificación OCDE/FORD</label>
      <input-type>onebox</input-type>
      <hint>Seleccionar el campo del conocimiento según OCDE/FORD.</hint>
      <required>Debe seleccionar la clasificación OCDE/FORD.</required>
      <vocabulary closed="true">dc-subject-ocde</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>discipline</dc-element>
      <repeatable>false</repeatable>
      <label>Código del programa</label>
      <input-type>onebox</input-type>
      <hint>Código interno o código usado institucionalmente para el programa, si aplica.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>juror</dc-element>
      <repeatable>true</repeatable>
      <label>Jurado</label>
      <input-type>onebox</input-type>
      <hint>Registrar un miembro del jurado por campo.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>rights</dc-element>
      <repeatable>false</repeatable>
      <label>Condición de acceso</label>
      <input-type>onebox</input-type>
      <hint>Seleccionar la condición de acceso del recurso.</hint>
      <required>Debe seleccionar la condición de acceso.</required>
      <vocabulary closed="true">dc-accessrights</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>rights</dc-element>
      <dc-qualifier>uri</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Licencia (URI)</label>
      <input-type>onebox</input-type>
      <hint>Ejemplo: http://creativecommons.org/licenses/by/4.0/</hint>
      <required>Debe ingresar la URI de la licencia.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>date</dc-element>
      <dc-qualifier>embargoEnd</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Fecha fin de embargo</label>
      <input-type>date</input-type>
      <hint>Solo si el acceso es embargado.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>type</dc-element>
      <dc-qualifier>version</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Versión del recurso</label>
      <input-type>onebox</input-type>
      <hint>Ejemplo: publishedVersion.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>identifier</dc-element>
      <dc-qualifier>citation</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Cita bibliográfica</label>
      <input-type>textarea</input-type>
      <hint>Forma sugerida de citación del recurso.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>description</dc-element>
      <dc-qualifier>sponsorship</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Patrocinio / financiamiento</label>
      <input-type>onebox</input-type>
      <hint>Proyecto, fondo o entidad financiadora, si aplica.</hint>
      <required></required>
    </field></row>

  </form>

XMLEOF

header "Paso 4 — Verificación de seguridad del fragmento"

EMPTY_Q1="$(grep -c '<dc-qualifier></dc-qualifier>' "${XML_FRAGMENT}" || true)"
EMPTY_Q2="$(grep -c '<dc-qualifier/>' "${XML_FRAGMENT}" || true)"
EMPTY_Q1="${EMPTY_Q1:-0}"
EMPTY_Q2="${EMPTY_Q2:-0}"
TOTAL_EMPTY=$((EMPTY_Q1 + EMPTY_Q2))

[[ "${TOTAL_EMPTY}" -eq 0 ]] || error "Se detectaron ${TOTAL_EMPTY} dc-qualifier vacíos en el fragmento"
log "Verificación: 0 dc-qualifier vacíos"

FRAG_ROWS="$(grep -c '<row>' "${XML_FRAGMENT}" || true)"
FRAG_ROWS="${FRAG_ROWS:-0}"
log "Fragmento generado: ${FRAG_ROWS} campos"

header "Paso 5 — Insertando en submission-forms.xml"
python3 - "${FORMS_FILE}" "${XML_FRAGMENT}" <<'PYINSERT'
import sys

forms_file, fragment_file = sys.argv[1], sys.argv[2]

with open(forms_file, "r", encoding="utf-8") as f:
    content = f.read()

with open(fragment_file, "r", encoding="utf-8") as f:
    fragment = f.read()

anchor = "</form-definitions>"
if anchor not in content:
    print("ERROR: no se encontró </form-definitions>")
    sys.exit(1)

if "scibackThesisPageOne" in content or "scibackThesisPageTwo" in content:
    print("ERROR: ya existen formularios scibackThesis")
    sys.exit(1)

new_content = content.replace(anchor, fragment + "\n  " + anchor)

with open(forms_file, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Inserción OK")
PYINSERT

header "Paso 6 — Validación XML"
xmllint --noout "${FORMS_FILE}" >/dev/null 2>&1 && log "XML bien formado" || error "submission-forms.xml no es válido"

python3 - "${FORMS_FILE}" <<'PYVERIFY'
import sys
import xml.etree.ElementTree as ET

forms_file = sys.argv[1]
tree = ET.parse(forms_file)

for form in tree.iter("form"):
    name = form.get("name") or ""
    if name in ("scibackThesisPageOne", "scibackThesisPageTwo"):
        rows = form.findall("row")
        fields = form.findall(".//field")
        problems = []

        for field in fields:
            qualifier = field.find("dc-qualifier")
            if qualifier is not None and (qualifier.text is None or qualifier.text.strip() == ""):
                schema = field.findtext("dc-schema", default="?")
                element = field.findtext("dc-element", default="?")
                problems.append(f"{schema}.{element}")

        if problems:
            print(f"{name}: ERROR qualifiers vacíos -> {problems}")
            sys.exit(1)
        else:
            print(f"{name}: {len(rows)} rows, {len(fields)} fields OK")
PYVERIFY

header "Paso 7 — Reiniciando Tomcat"
systemctl restart tomcat9

READY=false
for i in $(seq 1 18); do
  HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/server/api 2>/dev/null || true)"
  if [[ "${HTTP_CODE}" == "200" || "${HTTP_CODE}" == "301" || "${HTTP_CODE}" == "302" ]]; then
    log "Tomcat OK (HTTP ${HTTP_CODE})"
    READY=true
    break
  fi
  echo "  HTTP ${HTTP_CODE} — Esperando... (${i}/18)"
  sleep 10
done

if [[ "${READY}" != "true" ]]; then
  warn "Tomcat no respondió a tiempo"
  info "Buscando errores recientes..."
  grep -i "DCInputsReader\|submission.forms\|SAXException\|has no name" /opt/tomcat9/logs/catalina.out 2>/dev/null | tail -10 || true
  echo ""
  info "Para restaurar backup:"
  echo "  sudo cp '${BACKUP}' '${FORMS_FILE}'"
  echo "  sudo systemctl restart tomcat9"
  error "Tomcat no arrancó correctamente"
fi

header "Etapa 13 — Completada"
echo "  scibackThesisPageOne: metadatos principales de tesis"
echo "  scibackThesisPageTwo: resumen, OCDE, acceso, embargo y apoyo"
echo "  Mapear en item-submission.xml con submission-name='scibackThesis'"
echo "  Backup: ${BACKUP}"
echo "  Log: ${LOG_FILE}"

log "Formularios listos"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

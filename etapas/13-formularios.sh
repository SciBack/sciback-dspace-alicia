#!/bin/bash
# =============================================================================
# SciBack — setup-input-forms.sh v2.0
# FIX CRÍTICO: <dc-qualifier></dc-qualifier> vacío ELIMINADO
#   DSpace 7.6.6 DCInputsReader trata qualifier vacío como "null" →
#   SAXException: "field X.null has no name attribute" → Tomcat no arranca
#   SOLUCIÓN: OMITIR <dc-qualifier> cuando no hay qualifier
# Estructura: <form> → <row> → <field> (sin <page>)
# =============================================================================
set -euo pipefail

ETAPA_INICIO=$(date +%s)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()   { echo -e "${CYAN}[→]${NC} $1"; }
header() {
  echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
}

ENV_FILE=".env.dspace.deploy"
if [[ "${1:-}" == "--env" ]]; then ENV_FILE="${2:-.env.dspace.deploy}"; fi
[[ -f "$ENV_FILE" ]] || error "No se encontró: $ENV_FILE"
source "$ENV_FILE"
[[ "$(id -u)" -eq 0 ]] || error "Ejecutar con sudo"

DSPACE_DIR="${DSPACE_DIR:-/dspace}"
FORMS_FILE="${DSPACE_DIR}/config/submission-forms.xml"
BACKUP="${FORMS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
XML_FRAGMENT="/tmp/uniq-forms-fragment.xml"

LOG_FILE="/tmp/sciback-input-forms-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

header "SciBack — Setup Input Forms UNIQ v2.0"
log "Archivo: ${FORMS_FILE} | Log: ${LOG_FILE}"

echo -e "\033[0;36m  Tiempo estimado: ~1-2 min\033[0m"

header "Paso 1 — Prerequisitos"
[[ -f "$FORMS_FILE" ]] || error "No se encontró: ${FORMS_FILE}"
command -v xmllint &>/dev/null || apt-get install -y -q libxml2-utils

VOC_DIR="${DSPACE_DIR}/config/controlled-vocabularies"
for VOC in renati-type.xml renati-level.xml dc-type.xml dc-accessrights.xml dc-subject-ocde.xml; do
  [[ -f "${VOC_DIR}/${VOC}" ]] && log "Vocabulario OK: ${VOC}" || warn "Faltante: ${VOC}"
done

header "Paso 2 — Backup y limpieza"
if grep -q 'uniqThesis' "$FORMS_FILE" 2>/dev/null; then
  warn "Eliminando formularios uniqThesis anteriores..."
  python3 - "${FORMS_FILE}" << 'PYCLEAN'
import re, sys
f = sys.argv[1]
with open(f) as fh: c = fh.read()
c = re.sub(r'<!--\s*SciBack UNIQ.*?-->\s*', '', c, flags=re.DOTALL)
c = re.sub(r'\s*<form\s+name="uniqThesis[^"]*".*?</form>', '', c, flags=re.DOTALL)
with open(f, 'w') as fh: fh.write(c)
print("Limpieza OK")
PYCLEAN
fi
cp "$FORMS_FILE" "$BACKUP"
log "Backup: ${BACKUP}"

# =============================================================================
# FRAGMENTO XML — FORMULARIOS UNIQ TESIS
# =============================================================================
# REGLA DSpace 7.6.6:
#   CON qualifier → <dc-qualifier>valor</dc-qualifier>
#   SIN qualifier → NO incluir <dc-qualifier> (OMITIR la etiqueta)
#   <dc-qualifier></dc-qualifier> vacío = ERROR FATAL Tomcat
# =============================================================================

header "Paso 3 — Generando formulario"

cat > "${XML_FRAGMENT}" << 'XMLEOF'

  <!-- SciBack UNIQ — Formulario tesis ALICIA/RENATI v2.0 -->

  <form name="uniqThesisPageOne">

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>title</dc-element>
      <repeatable>false</repeatable>
      <label>Título</label>
      <input-type>onebox</input-type>
      <hint>Título completo de la tesis en español.</hint>
      <required>Debe ingresar el título.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>title</dc-element>
      <dc-qualifier>alternative</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Título alternativo (inglés)</label>
      <input-type>onebox</input-type>
      <hint>Título en inglés, si existe.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>contributor</dc-element>
      <dc-qualifier>author</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Autor</label>
      <input-type>onebox</input-type>
      <hint>Apellidos, Nombres del graduando.</hint>
      <required>Debe ingresar el nombre del autor.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>author</dc-element>
      <dc-qualifier>dni</dc-qualifier>
      <repeatable>false</repeatable>
      <label>DNI del autor</label>
      <input-type>onebox</input-type>
      <hint>DNI del autor (8 dígitos). Obligatorio ALICIA.</hint>
      <required>Debe ingresar el DNI del autor.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>author</dc-element>
      <dc-qualifier>orcid</dc-qualifier>
      <repeatable>false</repeatable>
      <label>ORCID del autor</label>
      <input-type>onebox</input-type>
      <hint>Formato: 0000-0000-0000-0000</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>contributor</dc-element>
      <dc-qualifier>advisor</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Asesor</label>
      <input-type>onebox</input-type>
      <hint>Apellidos, Nombres del asesor de tesis.</hint>
      <required>Debe ingresar el nombre del asesor.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>advisor</dc-element>
      <dc-qualifier>dni</dc-qualifier>
      <repeatable>false</repeatable>
      <label>DNI del asesor</label>
      <input-type>onebox</input-type>
      <hint>DNI del asesor (8 dígitos). Obligatorio ALICIA.</hint>
      <required>Debe ingresar el DNI del asesor.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>advisor</dc-element>
      <dc-qualifier>orcid</dc-qualifier>
      <repeatable>false</repeatable>
      <label>ORCID del asesor</label>
      <input-type>onebox</input-type>
      <hint>Formato: 0000-0000-0000-0000</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>date</dc-element>
      <dc-qualifier>issued</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Fecha de publicación</label>
      <input-type>date</input-type>
      <hint>Año de sustentación.</hint>
      <required>Debe ingresar la fecha.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>publisher</dc-element>
      <repeatable>false</repeatable>
      <label>Editor / Institución</label>
      <input-type>onebox</input-type>
      <hint>Ej: Universidad Interamericana para la Cooperación, UNIQ</hint>
      <required>Debe ingresar el editor.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>publisher</dc-element>
      <dc-qualifier>country</dc-qualifier>
      <repeatable>false</repeatable>
      <label>País del editor</label>
      <input-type>onebox</input-type>
      <hint>Código ISO. Perú: PE</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>thesis</dc-schema>
      <dc-element>degree</dc-element>
      <dc-qualifier>name</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Nombre del grado</label>
      <input-type>onebox</input-type>
      <hint>Ej: Bachiller en Administración de Empresas</hint>
      <required>Debe ingresar el grado.</required>
    </field></row>

    <row><field>
      <dc-schema>thesis</dc-schema>
      <dc-element>degree</dc-element>
      <dc-qualifier>grantor</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Institución otorgante</label>
      <input-type>onebox</input-type>
      <hint>Universidad que otorga el grado.</hint>
      <required>Debe ingresar la institución.</required>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>level</dc-element>
      <repeatable>false</repeatable>
      <label>Nivel académico</label>
      <input-type>onebox</input-type>
      <hint>Nivel SUNEDU. Obligatorio ALICIA.</hint>
      <required>Debe seleccionar el nivel.</required>
      <vocabulary>renati-level</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>renati</dc-schema>
      <dc-element>type</dc-element>
      <repeatable>false</repeatable>
      <label>Tipo RENATI</label>
      <input-type>onebox</input-type>
      <hint>Tipo de recurso RENATI. Obligatorio ALICIA.</hint>
      <required>Debe seleccionar el tipo.</required>
      <vocabulary>renati-type</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>type</dc-element>
      <repeatable>false</repeatable>
      <label>Tipo OpenAIRE</label>
      <input-type>onebox</input-type>
      <hint>Tipo de recurso OpenAIRE/COAR.</hint>
      <required></required>
      <vocabulary>dc-type</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>language</dc-element>
      <dc-qualifier>iso</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Idioma</label>
      <input-type value-pairs-name="common_iso_languages">dropdown</input-type>
      <hint>Idioma principal del documento.</hint>
      <required></required>
    </field></row>

  </form>

  <form name="uniqThesisPageTwo">

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>description</dc-element>
      <dc-qualifier>abstract</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Resumen</label>
      <input-type>textarea</input-type>
      <hint>Resumen en español (máx. 500 palabras).</hint>
      <required>Debe ingresar el resumen.</required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>subject</dc-element>
      <dc-qualifier>ocde</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Clasificación OCDE/FORD</label>
      <input-type>onebox</input-type>
      <hint>Área del conocimiento OCDE. Obligatorio ALICIA.</hint>
      <required>Debe seleccionar la clasificación OCDE.</required>
      <vocabulary>dc-subject-ocde</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>subject</dc-element>
      <repeatable>true</repeatable>
      <label>Palabras clave</label>
      <input-type>onebox</input-type>
      <hint>Una palabra clave por campo.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>rights</dc-element>
      <repeatable>false</repeatable>
      <label>Condición de acceso</label>
      <input-type>onebox</input-type>
      <hint>Acceso al documento según COAR.</hint>
      <required>Debe seleccionar la condición.</required>
      <vocabulary>dc-accessrights</vocabulary>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>rights</dc-element>
      <dc-qualifier>uri</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Licencia (URI)</label>
      <input-type>onebox</input-type>
      <hint>Ej: https://creativecommons.org/licenses/by/4.0/</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>identifier</dc-element>
      <dc-qualifier>uri</dc-qualifier>
      <repeatable>false</repeatable>
      <label>URI / Handle</label>
      <input-type>onebox</input-type>
      <hint>Se asigna automáticamente.</hint>
      <required></required>
    </field></row>

    <row><field>
      <dc-schema>dc</dc-schema>
      <dc-element>date</dc-element>
      <dc-qualifier>embargoEnd</dc-qualifier>
      <repeatable>false</repeatable>
      <label>Fecha fin de embargo</label>
      <input-type>date</input-type>
      <hint>Solo si el documento tiene embargo.</hint>
      <required></required>
    </field></row>

  </form>

XMLEOF

# ─── VALIDACIÓN DE SEGURIDAD ─────────────────────────────────────────────────
EMPTY_Q="$(grep -c '<dc-qualifier></dc-qualifier>' "${XML_FRAGMENT}" || true)"
EMPTY_Q2="$(grep -c '<dc-qualifier/>' "${XML_FRAGMENT}" || true)"
EMPTY_Q="${EMPTY_Q:-0}"
EMPTY_Q2="${EMPTY_Q2:-0}"
TOTAL_EMPTY=$((EMPTY_Q + EMPTY_Q2))

if [[ "$TOTAL_EMPTY" -gt 0 ]]; then
  error "¡DETECTADOS ${TOTAL_EMPTY} <dc-qualifier> vacíos! Esto causaría el error en Tomcat. Abortando."
fi
log "Verificación: 0 <dc-qualifier> vacíos ✓"

FRAG_ROWS="$(grep -c '<row>' "${XML_FRAGMENT}" || true)"
FRAG_ROWS="${FRAG_ROWS:-0}"
log "Fragmento: ${FRAG_ROWS} campos"

header "Paso 4 — Insertando en submission-forms.xml"
python3 - "${FORMS_FILE}" "${XML_FRAGMENT}" << 'PYINSERT'
import sys
forms_file, fragment_file = sys.argv[1], sys.argv[2]
with open(forms_file, 'r', encoding='utf-8') as f: content = f.read()
with open(fragment_file, 'r', encoding='utf-8') as f: fragment = f.read()
ANCHOR = '</form-definitions>'
if ANCHOR not in content:
    print("ERROR: no se encontró </form-definitions>"); sys.exit(1)
if 'uniqThesisPageOne' in content:
    print("ERROR: ya existe uniqThesisPageOne"); sys.exit(1)
new_content = content.replace(ANCHOR, fragment + '  ' + ANCHOR)
with open(forms_file, 'w', encoding='utf-8') as f: f.write(new_content)
# Verificación
import re
with open(forms_file) as f: check = f.read()
empty_in_uniq = 0
for form_match in re.finditer(r'<form\s+name="uniqThesis[^"]*".*?</form>', check, re.DOTALL):
    form_xml = form_match.group(0)
    empty_in_uniq += form_xml.count('<dc-qualifier></dc-qualifier>') + form_xml.count('<dc-qualifier/>')
print(f"Rows total: {check.count('<row>')}, uniqThesis refs: {check.count('uniqThesis')}")
if empty_in_uniq > 0:
    print(f"⚠️  ALERTA: {empty_in_uniq} dc-qualifier vacíos en formularios uniqThesis")
    sys.exit(1)
else:
    print("✓ 0 dc-qualifier vacíos en formularios uniqThesis")
PYINSERT

header "Paso 5 — Validación XML"
xmllint --noout "${FORMS_FILE}" 2>/dev/null && log "XML bien formado ✓" || warn "Advertencias xmllint"

python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('${FORMS_FILE}')
for f in tree.iter('form'):
    name = f.get('name') or ''
    if 'uniq' in name:
        rows = f.findall('row')
        fields = f.findall('.//field')
        problems = []
        for field in fields:
            q = field.find('dc-qualifier')
            if q is not None and (q.text is None or q.text.strip() == ''):
                s = (field.find('dc-schema').text or '?') if field.find('dc-schema') is not None else '?'
                e = (field.find('dc-element').text or '?') if field.find('dc-element') is not None else '?'
                problems.append(f'{s}.{e}')
        status = '✓' if not problems else f'✗ PROBLEMA en: {problems}'
        print(f'  {name}: {len(rows)} rows, {len(fields)} fields {status}')
"

header "Paso 6 — Reiniciando Tomcat"
systemctl stop tomcat9
sleep 5
systemctl start tomcat9

READY=false
for i in $(seq 1 18); do
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/server/api 2>/dev/null || true)
  if [[ "$HTTP" == "200" ]]; then log "Tomcat OK ✓"; READY=true; break; fi
  echo "  HTTP ${HTTP} — Esperando... (${i}/18)"; sleep 10
done

if [[ "$READY" != "true" ]]; then
  warn "Tomcat no respondió en 3 minutos"
  echo ""
  info "Buscando errores en catalina.out..."
  grep -i "DCInputsReader\|submission.forms\|SAXException\|has no name" \
    /opt/tomcat9/logs/catalina.out 2>/dev/null | tail -5 || true
  echo ""
  info "Para restaurar backup:"
  echo "  sudo cp ${BACKUP} ${FORMS_FILE}"
  echo "  sudo systemctl restart tomcat9"
  error "Tomcat no arrancó — revisar logs"
fi

header "✅ Input Forms UNIQ v2.0 — Configurado"
echo ""
echo "  uniqThesisPageOne (17 campos):"
echo "    Título, Título alt., Autor, DNI autor, ORCID autor,"
echo "    Asesor, DNI asesor, ORCID asesor, Fecha, Editor, País,"
echo "    Grado, Institución, Nivel SUNEDU, Tipo RENATI, Tipo OpenAIRE, Idioma"
echo ""
echo "  uniqThesisPageTwo (7 campos):"
echo "    Resumen, OCDE/FORD, Palabras clave, Acceso, Licencia, Handle, Embargo"
echo ""
echo "  Mapear colección en item-submission.xml:"
echo "    <name-map collection-handle=\"${HANDLE_PREFIX:-20.500.XXXXX}/YY\""
echo "             submission-name=\"uniqThesis\"/>"
echo ""
echo "  Backup: ${BACKUP} | Log: ${LOG_FILE}"
log "Input forms completado ✓"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

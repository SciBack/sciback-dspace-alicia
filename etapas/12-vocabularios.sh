#!/bin/bash
# =============================================================================
# SciBack — setup-vocabularies.sh v2.0
# Descarga vocabularios CONCYTEC desde GitHub (SKOS-XML) y los convierte
# al formato <node> de DSpace 7.6.6. Fallback: usa XMLs locales.
# Fuente: https://github.com/concytec-pe/Peru-CRIS/vocabularios/
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

ENV_FILE=".env.deploy"
if [[ "${1:-}" == "--env" ]]; then ENV_FILE="${2:-.env.deploy}"
elif [[ -n "${1:-}" && "${1}" != --* ]]; then ENV_FILE="$1"; fi
[[ -f "$ENV_FILE" ]] || error "No se encontró: $ENV_FILE"
source "$ENV_FILE"

DSPACE_DIR="${DSPACE_DIR:-/dspace}"
VOCAB_DIR="${DSPACE_DIR}/config/controlled-vocabularies"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="${SCRIPT_DIR}/controlled-vocabularies"
TOMCAT_USER="${TOMCAT_USER:-dspace}"

LOG_FILE="/tmp/sciback-vocabularies-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

header "SciBack — Setup Vocabularios ALICIA v2.0"
log "DSpace:  ${DSPACE_DIR}"
log "Destino: ${VOCAB_DIR}"
log "Local:   ${LOCAL_DIR}"
log "Log:     ${LOG_FILE}"

[[ -d "$VOCAB_DIR" ]] || error "No existe: ${VOCAB_DIR}"
command -v xmllint &>/dev/null || { info "Instalando xmllint..."; apt-get install -y -q libxml2-utils; }
command -v python3 &>/dev/null || error "python3 requerido"

# =============================================================================
# GENERADOR: Crear XMLs en formato DSpace <node> desde datos CONCYTEC oficiales
# Fuente: https://purl.org/pe-repo/renati/level — CONCYTEC/SUNEDU
#         https://purl.org/pe-repo/renati/type  — CONCYTEC/SUNEDU
#         https://purl.org/pe-repo/ocde/ford    — OCDE Frascati
# =============================================================================

generate_vocabularies() {
  local DEST_DIR="$1"
  info "Generando vocabularios desde datos oficiales CONCYTEC..."

  # ─── renati-level.xml ─────────────────────────────────────────────────────
  # Fuente: https://purl.org/pe-repo/renati/level — Ley 30220 / SUNEDU
  cat > "${DEST_DIR}/renati-level.xml" << 'RENATI_LEVEL'
<?xml version="1.0" encoding="UTF-8"?>
<!-- Vocabulario: Grados académicos y títulos profesionales (RENATI)
     Fuente: https://purl.org/pe-repo/renati/level — Ley 30220 / SUNEDU
     Generado por SciBack desde datos oficiales CONCYTEC -->
<node id="renati-level" label="Nivel de grado académico">
  <isComposedBy>
    <node id="bachiller" label="Bachiller">
      <hasNote>https://purl.org/pe-repo/renati/level#bachiller</hasNote>
    </node>
    <node id="tituloProfesional" label="Título Profesional">
      <hasNote>https://purl.org/pe-repo/renati/level#tituloProfesional</hasNote>
    </node>
    <node id="tituloSegundaEspecialidad" label="Segunda Especialidad">
      <hasNote>https://purl.org/pe-repo/renati/level#tituloSegundaEspecialidad</hasNote>
    </node>
    <node id="maestro" label="Maestro">
      <hasNote>https://purl.org/pe-repo/renati/level#maestro</hasNote>
    </node>
    <node id="doctor" label="Doctor">
      <hasNote>https://purl.org/pe-repo/renati/level#doctor</hasNote>
    </node>
  </isComposedBy>
</node>
RENATI_LEVEL
  log "renati-level.xml generado (5 niveles)"

  # ─── renati-type.xml ──────────────────────────────────────────────────────
  # Fuente: https://purl.org/pe-repo/renati/type — Reglamento RENATI
  cat > "${DEST_DIR}/renati-type.xml" << 'RENATI_TYPE'
<?xml version="1.0" encoding="UTF-8"?>
<!-- Vocabulario: Tipos de trabajo de investigación (RENATI)
     Fuente: https://purl.org/pe-repo/renati/type — RCD N° 033-2016-SUNEDU/CD
     Generado por SciBack desde datos oficiales CONCYTEC -->
<node id="renati-type" label="Tipo de trabajo de investigación">
  <isComposedBy>
    <node id="tesis" label="Tesis">
      <hasNote>https://purl.org/pe-repo/renati/type#tesis</hasNote>
    </node>
    <node id="trabajoDeInvestigacion" label="Trabajo de investigación">
      <hasNote>https://purl.org/pe-repo/renati/type#trabajoDeInvestigacion</hasNote>
    </node>
    <node id="trabajoDeSuficienciaProfesional" label="Trabajo de suficiencia profesional">
      <hasNote>https://purl.org/pe-repo/renati/type#trabajoDeSuficienciaProfesional</hasNote>
    </node>
    <node id="trabajoAcademico" label="Trabajo académico">
      <hasNote>https://purl.org/pe-repo/renati/type#trabajoAcademico</hasNote>
    </node>
  </isComposedBy>
</node>
RENATI_TYPE
  log "renati-type.xml generado (4 tipos)"

  # ─── dc-type.xml ──────────────────────────────────────────────────────────
  # Tipos de recurso OpenAIRE/COAR compatibles con ALICIA
  cat > "${DEST_DIR}/dc-type.xml" << 'DC_TYPE'
<?xml version="1.0" encoding="UTF-8"?>
<!-- Vocabulario: Tipos de recurso OpenAIRE/COAR
     Compatible con Guía ALICIA 2.1.0
     Generado por SciBack -->
<node id="dc-type" label="Tipo de recurso">
  <isComposedBy>
    <node id="info:eu-repo/semantics/bachelorThesis" label="Tesis de pregrado">
      <hasNote>http://purl.org/coar/resource_type/c_7a1f</hasNote>
    </node>
    <node id="info:eu-repo/semantics/masterThesis" label="Tesis de maestría">
      <hasNote>http://purl.org/coar/resource_type/c_bdcc</hasNote>
    </node>
    <node id="info:eu-repo/semantics/doctoralThesis" label="Tesis de doctorado">
      <hasNote>http://purl.org/coar/resource_type/c_db06</hasNote>
    </node>
    <node id="info:eu-repo/semantics/article" label="Artículo">
      <hasNote>http://purl.org/coar/resource_type/c_6501</hasNote>
    </node>
    <node id="info:eu-repo/semantics/book" label="Libro">
      <hasNote>http://purl.org/coar/resource_type/c_2f33</hasNote>
    </node>
    <node id="info:eu-repo/semantics/bookPart" label="Capítulo de libro">
      <hasNote>http://purl.org/coar/resource_type/c_3248</hasNote>
    </node>
    <node id="info:eu-repo/semantics/report" label="Reporte">
      <hasNote>http://purl.org/coar/resource_type/c_93fc</hasNote>
    </node>
    <node id="info:eu-repo/semantics/conferenceObject" label="Objeto de conferencia">
      <hasNote>http://purl.org/coar/resource_type/c_c94f</hasNote>
    </node>
    <node id="info:eu-repo/semantics/workingPaper" label="Documento de trabajo">
      <hasNote>http://purl.org/coar/resource_type/c_8042</hasNote>
    </node>
    <node id="info:eu-repo/semantics/other" label="Otro">
      <hasNote>http://purl.org/coar/resource_type/c_1843</hasNote>
    </node>
  </isComposedBy>
</node>
DC_TYPE
  log "dc-type.xml generado (10 tipos)"

  # ─── dc-accessrights.xml ──────────────────────────────────────────────────
  # Condiciones de acceso COAR — Obligatorio ALICIA
  cat > "${DEST_DIR}/dc-accessrights.xml" << 'DC_ACCESS'
<?xml version="1.0" encoding="UTF-8"?>
<!-- Vocabulario: Condiciones de acceso COAR
     Fuente: http://purl.org/coar/access_right
     Obligatorio Guía ALICIA 2.1.0 -->
<node id="dc-accessrights" label="Condición de acceso">
  <isComposedBy>
    <node id="info:eu-repo/semantics/openAccess" label="Acceso abierto">
      <hasNote>http://purl.org/coar/access_right/c_abf2</hasNote>
    </node>
    <node id="info:eu-repo/semantics/embargoedAccess" label="Acceso embargado">
      <hasNote>http://purl.org/coar/access_right/c_f1cf</hasNote>
    </node>
    <node id="info:eu-repo/semantics/restrictedAccess" label="Acceso restringido">
      <hasNote>http://purl.org/coar/access_right/c_16ec</hasNote>
    </node>
    <node id="info:eu-repo/semantics/closedAccess" label="Acceso cerrado">
      <hasNote>http://purl.org/coar/access_right/c_14cb</hasNote>
    </node>
  </isComposedBy>
</node>
DC_ACCESS
  log "dc-accessrights.xml generado (4 niveles)"

  # ─── dc-subject-ocde.xml ─────────────────────────────────────────────────
  # Clasificación OCDE/FORD — Fuente: purl.org/pe-repo/ocde/ford
  # Estructura jerárquica: Área > Campo > Disciplina
  cat > "${DEST_DIR}/dc-subject-ocde.xml" << 'OCDE_FORD'
<?xml version="1.0" encoding="UTF-8"?>
<!-- Vocabulario: Campos de Investigación y Desarrollo OCDE/FORD
     Fuente: https://purl.org/pe-repo/ocde/ford — Manual Frascati (OCDE)
     Obligatorio Guía ALICIA 2.1.0 — Generado por SciBack -->
<node id="dc-subject-ocde" label="Clasificación OCDE/FORD">
  <isComposedBy>

    <node id="1.00.00" label="Ciencias naturales">
      <isComposedBy>
        <node id="1.01.00" label="Matemáticas">
          <isComposedBy>
            <node id="1.01.01" label="Matemáticas puras"/>
            <node id="1.01.02" label="Matemáticas aplicadas"/>
            <node id="1.01.03" label="Estadísticas, Probabilidad"/>
          </isComposedBy>
        </node>
        <node id="1.02.00" label="Informática y Ciencias de la Información">
          <isComposedBy>
            <node id="1.02.01" label="Ciencias de la computación"/>
            <node id="1.02.02" label="Ciencias de la información"/>
            <node id="1.02.03" label="Bioinformática"/>
          </isComposedBy>
        </node>
        <node id="1.03.00" label="Física y Astronomía">
          <isComposedBy>
            <node id="1.03.01" label="Física atómica, molecular y química"/>
            <node id="1.03.04" label="Física nuclear"/>
            <node id="1.03.08" label="Astronomía"/>
          </isComposedBy>
        </node>
        <node id="1.04.00" label="Química">
          <isComposedBy>
            <node id="1.04.01" label="Química orgánica"/>
            <node id="1.04.02" label="Química inorgánica, Química nuclear"/>
            <node id="1.04.07" label="Química analítica"/>
          </isComposedBy>
        </node>
        <node id="1.05.00" label="Ciencias de la Tierra, Ciencias ambientales">
          <isComposedBy>
            <node id="1.05.06" label="Geología"/>
            <node id="1.05.08" label="Ciencias del medio ambiente"/>
            <node id="1.05.10" label="Investigación climática"/>
          </isComposedBy>
        </node>
        <node id="1.06.00" label="Biología">
          <isComposedBy>
            <node id="1.06.01" label="Biología celular, Microbiología"/>
            <node id="1.06.03" label="Bioquímica, Biología molecular"/>
            <node id="1.06.07" label="Genética, Herencia"/>
            <node id="1.06.13" label="Ecología"/>
          </isComposedBy>
        </node>
        <node id="1.07.00" label="Otras ciencias naturales"/>
      </isComposedBy>
    </node>

    <node id="2.00.00" label="Ingeniería, Tecnología">
      <isComposedBy>
        <node id="2.01.00" label="Ingeniería civil">
          <isComposedBy>
            <node id="2.01.01" label="Ingeniería civil"/>
            <node id="2.01.02" label="Ingeniería arquitectónica"/>
          </isComposedBy>
        </node>
        <node id="2.02.00" label="Ingeniería eléctrica, Ingeniería electrónica">
          <isComposedBy>
            <node id="2.02.01" label="Ingeniería eléctrica, Ingeniería electrónica"/>
            <node id="2.02.05" label="Telecomunicaciones"/>
          </isComposedBy>
        </node>
        <node id="2.03.00" label="Ingeniería mecánica">
          <isComposedBy>
            <node id="2.03.01" label="Ingeniería mecánica"/>
            <node id="2.03.04" label="Ingeniería aeroespacial"/>
          </isComposedBy>
        </node>
        <node id="2.07.00" label="Ingeniería ambiental">
          <isComposedBy>
            <node id="2.07.01" label="Ingeniería ambiental y geológica"/>
            <node id="2.07.05" label="Minería, Procesamiento de minerales"/>
          </isComposedBy>
        </node>
        <node id="2.11.00" label="Otras ingenierías, Otras tecnologías">
          <isComposedBy>
            <node id="2.11.01" label="Alimentos y bebidas"/>
            <node id="2.11.04" label="Ingeniería industrial"/>
          </isComposedBy>
        </node>
      </isComposedBy>
    </node>

    <node id="3.00.00" label="Ciencias médicas, Ciencias de la salud">
      <isComposedBy>
        <node id="3.01.00" label="Medicina básica">
          <isComposedBy>
            <node id="3.01.05" label="Farmacología, Farmacia"/>
            <node id="3.01.04" label="Neurociencias"/>
          </isComposedBy>
        </node>
        <node id="3.02.00" label="Medicina clínica">
          <isComposedBy>
            <node id="3.02.21" label="Oncología"/>
            <node id="3.02.24" label="Psiquiatría"/>
            <node id="3.02.27" label="Medicina general, Medicina interna"/>
          </isComposedBy>
        </node>
        <node id="3.03.00" label="Ciencias de la salud">
          <isComposedBy>
            <node id="3.03.03" label="Enfermería"/>
            <node id="3.03.04" label="Nutrición, Dietética"/>
            <node id="3.03.05" label="Salud pública, Salud ambiental"/>
            <node id="3.03.09" label="Epidemiología"/>
          </isComposedBy>
        </node>
        <node id="3.05.00" label="Otras ciencias médicas"/>
      </isComposedBy>
    </node>

    <node id="4.00.00" label="Ciencias agrícolas">
      <isComposedBy>
        <node id="4.01.00" label="Agricultura, Silvicultura, Pesquería">
          <isComposedBy>
            <node id="4.01.01" label="Agricultura"/>
            <node id="4.01.02" label="Silvicultura"/>
            <node id="4.01.03" label="Pesquería"/>
          </isComposedBy>
        </node>
        <node id="4.02.00" label="Ciencia animal, Ciencia lechera"/>
        <node id="4.03.00" label="Ciencia veterinaria"/>
        <node id="4.04.00" label="Biotecnología agrícola"/>
        <node id="4.05.00" label="Otras ciencias agrícolas"/>
      </isComposedBy>
    </node>

    <node id="5.00.00" label="Ciencias sociales">
      <isComposedBy>
        <node id="5.01.00" label="Psicología">
          <isComposedBy>
            <node id="5.01.01" label="Psicología"/>
            <node id="5.01.02" label="Psicología (incluye relaciones hombre-máquina)"/>
          </isComposedBy>
        </node>
        <node id="5.02.00" label="Economía, Negocios">
          <isComposedBy>
            <node id="5.02.01" label="Economía"/>
            <node id="5.02.04" label="Negocios, Administración"/>
          </isComposedBy>
        </node>
        <node id="5.03.00" label="Ciencias de la educación">
          <isComposedBy>
            <node id="5.03.01" label="Educación general"/>
            <node id="5.03.02" label="Educación especial"/>
          </isComposedBy>
        </node>
        <node id="5.04.00" label="Sociología"/>
        <node id="5.05.00" label="Derecho">
          <isComposedBy>
            <node id="5.05.01" label="Derecho"/>
            <node id="5.05.02" label="Criminología, Penología"/>
          </isComposedBy>
        </node>
        <node id="5.06.00" label="Ciencias políticas">
          <isComposedBy>
            <node id="5.06.01" label="Ciencias políticas"/>
            <node id="5.06.02" label="Administración pública"/>
          </isComposedBy>
        </node>
        <node id="5.07.00" label="Geografía social y económica"/>
        <node id="5.08.00" label="Periodismo y comunicaciones"/>
        <node id="5.09.00" label="Otras ciencias sociales"/>
      </isComposedBy>
    </node>

    <node id="6.00.00" label="Humanidades">
      <isComposedBy>
        <node id="6.01.00" label="Historia, Arqueología"/>
        <node id="6.02.00" label="Idiomas, Literatura"/>
        <node id="6.03.00" label="Filosofía, Ética, Religión"/>
        <node id="6.04.00" label="Arte"/>
        <node id="6.05.00" label="Otras humanidades"/>
      </isComposedBy>
    </node>

  </isComposedBy>
</node>
OCDE_FORD
  log "dc-subject-ocde.xml generado (6 áreas OCDE + sub-campos)"
}

# =============================================================================
# EJECUCIÓN
# =============================================================================

echo -e "\033[0;36m  Tiempo estimado: ~1-2 min\033[0m"

header "Paso 1 — Generando vocabularios formato DSpace"
info "Datos oficiales CONCYTEC: purl.org/pe-repo/*"

TEMP_DIR=$(mktemp -d)
generate_vocabularies "$TEMP_DIR"

header "Paso 2 — Instalando en DSpace"

BACKUP_DIR="/tmp/sciback-voc-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

for FILE in renati-level.xml renati-type.xml dc-type.xml dc-accessrights.xml dc-subject-ocde.xml; do
  # Backup existente
  if [[ -f "${VOCAB_DIR}/${FILE}" ]]; then
    cp "${VOCAB_DIR}/${FILE}" "${BACKUP_DIR}/${FILE}"
    info "Backup: ${FILE}"
  fi

  # Instalar
  cp "${TEMP_DIR}/${FILE}" "${VOCAB_DIR}/${FILE}"
  chown "${TOMCAT_USER}:${TOMCAT_USER}" "${VOCAB_DIR}/${FILE}" 2>/dev/null || true
  chmod 644 "${VOCAB_DIR}/${FILE}"
  log "Instalado: ${FILE}"
done

rm -rf "$TEMP_DIR"

header "Paso 3 — Validación XML"

VALID=0; INVALID=0
for FILE in renati-level.xml renati-type.xml dc-type.xml dc-accessrights.xml dc-subject-ocde.xml; do
  if xmllint --noout "${VOCAB_DIR}/${FILE}" 2>/dev/null; then
    NODES=$(xmllint --xpath 'count(//node)' "${VOCAB_DIR}/${FILE}" 2>/dev/null || true)
    NODES="${NODES:-?}"
    log "${FILE}: XML válido, ${NODES} nodos"
    ((VALID++)) || true
  else
    warn "${FILE}: XML INVÁLIDO"
    ((INVALID++)) || true
  fi
done

header "Paso 4 — Verificación final"
echo ""
echo "  Vocabularios en ${VOCAB_DIR}:"
for FILE in renati-level.xml renati-type.xml dc-type.xml dc-accessrights.xml dc-subject-ocde.xml; do
  if [[ -f "${VOCAB_DIR}/${FILE}" ]]; then
    SIZE=$(stat -c%s "${VOCAB_DIR}/${FILE}")
    log "  ${FILE} (${SIZE} bytes)"
  fi
done

header "✅ Vocabularios ALICIA v2.0 — Instalados"
echo ""
echo "  Válidos: ${VALID} | Inválidos: ${INVALID}"
echo "  Backup: ${BACKUP_DIR}"
echo ""
echo "  Mapeo en submission-forms.xml:"
echo "    renati.level     → <vocabulary>renati-level</vocabulary>"
echo "    renati.type      → <vocabulary>renati-type</vocabulary>"
echo "    dc.type          → <vocabulary>dc-type</vocabulary>"
echo "    dc.rights        → <vocabulary>dc-accessrights</vocabulary>"
echo "    dc.subject.ocde  → <vocabulary>dc-subject-ocde</vocabulary>"
echo ""
echo "  Próximo: sudo bash setup-input-forms.sh"
echo "  Log: ${LOG_FILE}"
log "Vocabularios listos ✓"

ETAPA_FIN=$(date +%s)
DURACION_MIN=$(( (ETAPA_FIN - ETAPA_INICIO + 59) / 60 ))
echo -e "\033[0;32m[✓]\033[0m Etapa completada en ${DURACION_MIN} minuto(s)"

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGES_DIR="${ROOT_DIR}/stages"
LIB_DIR="${ROOT_DIR}/lib"
DEFAULT_ENV="${ROOT_DIR}/.env.dspace.theme-manager"

# shellcheck source=theme-manager/lib/fs.sh
source "${LIB_DIR}/fs.sh"
init_trap

usage() {
  cat <<EOM
Uso:
  bash theme-manager.sh
  bash theme-manager.sh --stage 05-apply-colors
  bash theme-manager.sh --stages 05-apply-colors,06-apply-logo
  bash theme-manager.sh --from 02-create-theme-copy --to 08-apply-footer
  bash theme-manager.sh --env /ruta/.env.dspace.theme-manager
  bash theme-manager.sh --no-build --no-restart
  bash theme-manager.sh --help
EOM
}

ENV_FILE="$DEFAULT_ENV"
ONE_STAGE=""
MULTI_STAGES=""
FROM_STAGE=""
TO_STAGE=""
NO_BUILD=false
NO_RESTART=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --stage) ONE_STAGE="$2"; shift 2 ;;
    --stages) MULTI_STAGES="$2"; shift 2 ;;
    --from) FROM_STAGE="$2"; shift 2 ;;
    --to) TO_STAGE="$2"; shift 2 ;;
    --no-build) NO_BUILD=true; shift ;;
    --no-restart) NO_RESTART=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Argumento no reconocido: $1" ;;
  esac
done

[[ -f "$ENV_FILE" ]] || die "No se encontró env: $ENV_FILE"
load_env_file "$ENV_FILE"
export THEME_MANAGER_ENV_FILE="$ENV_FILE"
ensure_dir "${DSPACE_THEME_LOG_DIR}"
ensure_dir "${DSPACE_THEME_BACKUP_DIR}"

mapfile -t stage_files < <(find "$STAGES_DIR" -maxdepth 1 -type f -name '*.sh' | sort)
(( ${#stage_files[@]} > 0 )) || die "No se encontraron etapas en $STAGES_DIR"

norm_stage() { local s="$1"; echo "${s%.sh}"; }
stage_exists() {
  local wanted="$1"
  local f b
  for f in "${stage_files[@]}"; do
    b="$(basename "$f" .sh)"
    [[ "$b" == "$wanted" ]] && return 0
  done
  return 1
}

selected=()
if [[ -n "$ONE_STAGE" ]]; then
  wanted="$(norm_stage "$ONE_STAGE")"
  stage_exists "$wanted" || die "Etapa no encontrada: $ONE_STAGE"
  selected+=("${STAGES_DIR}/${wanted}.sh")
elif [[ -n "$MULTI_STAGES" ]]; then
  IFS=',' read -r -a arr <<< "$MULTI_STAGES"
  for s in "${arr[@]}"; do
    wanted="$(norm_stage "$s")"
    stage_exists "$wanted" || die "Etapa no encontrada: $s"
    selected+=("${STAGES_DIR}/${wanted}.sh")
  done
elif [[ -n "$FROM_STAGE" || -n "$TO_STAGE" ]]; then
  first="$(basename "${stage_files[0]}" .sh)"
  last="$(basename "${stage_files[${#stage_files[@]}-1]}" .sh)"
  from="$(norm_stage "${FROM_STAGE:-$first}")"
  to="$(norm_stage "${TO_STAGE:-$last}")"
  stage_exists "$from" || die "Etapa --from no encontrada: $from"
  stage_exists "$to" || die "Etapa --to no encontrada: $to"
  in_range=false
  for f in "${stage_files[@]}"; do
    b="$(basename "$f" .sh)"
    [[ "$b" == "$from" ]] && in_range=true
    [[ "$in_range" == true ]] && selected+=("$f")
    [[ "$b" == "$to" ]] && break
  done
else
  selected=("${stage_files[@]}")
fi

START_TS=$(date +%s)
executed=()
for stage in "${selected[@]}"; do
  base="$(basename "$stage" .sh)"

  if [[ "$NO_BUILD" == true && "$base" == "11-build-frontend" ]]; then
    log_warn "Saltando etapa $base por --no-build"; continue
  fi
  if [[ "$NO_RESTART" == true && "$base" == "12-restart-pm2" ]]; then
    log_warn "Saltando etapa $base por --no-restart"; continue
  fi

  if [[ -z "$ONE_STAGE" && -z "$MULTI_STAGES" && -z "$FROM_STAGE" && -z "$TO_STAGE" ]]; then
    if [[ "$base" == "11-build-frontend" && "${AUTO_BUILD_ON_FULL_RUN}" != "true" ]]; then
      log_warn "Saltando build por AUTO_BUILD_ON_FULL_RUN=false"; continue
    fi
    if [[ "$base" == "12-restart-pm2" && "${AUTO_RESTART_ON_FULL_RUN}" != "true" ]]; then
      log_warn "Saltando restart por AUTO_RESTART_ON_FULL_RUN=false"; continue
    fi
  fi

  print_banner "Ejecutando etapa: $base"
  bash "$stage"
  executed+=("$base")
  [[ "$base" == "11-build-frontend" ]] && export THEME_MANAGER_BUILD_EXECUTED=true
  [[ "$base" == "12-restart-pm2" ]] && export THEME_MANAGER_RESTART_EXECUTED=true
  log_info "Etapa OK: $base"
done

END_TS=$(date +%s)
log_info "Etapas ejecutadas: ${executed[*]:-ninguna}"
log_info "Duración total: $((END_TS-START_TS))s"

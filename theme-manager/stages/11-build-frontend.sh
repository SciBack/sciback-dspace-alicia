#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/fs.sh"
init_trap

require_dir "${DSPACE_FRONTEND_DIR}"
require_command yarn

start=$(date +%s)
log_info "Build Angular iniciado en ${DSPACE_FRONTEND_DIR}"

if [[ "${DSPACE_RUN_YARN_INSTALL}" == "true" ]]; then
  log_info "Ejecutando install: ${DSPACE_YARN_INSTALL_COMMAND}"
  (cd "${DSPACE_FRONTEND_DIR}" && run_as_configured_user "${DSPACE_YARN_INSTALL_COMMAND}")
fi

set +e
(cd "${DSPACE_FRONTEND_DIR}" && run_as_configured_user "${DSPACE_YARN_BUILD_COMMAND}")
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  cat <<EOM
ERROR: Angular build failed
Possible causes:
- Node version incompatible
- Missing dependency
- Yarn cache corrupted
- Invalid theme asset path
- Invalid HTML/SCSS customization
Suggested fix:
- run yarn install
- verify Node version
- verify theme target files
- inspect the backup and managed replacement blocks
EOM
  exit $rc
fi

end=$(date +%s)
log_info "Build completado en $((end-start))s"

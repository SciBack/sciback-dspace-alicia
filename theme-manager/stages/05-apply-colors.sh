#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/lib/dspace-theme.sh"
init_trap

sass_block=$(cat <<EOB
\$primary: ${DSPACE_THEME_PRIMARY};
\$secondary: ${DSPACE_THEME_SECONDARY};
\$accent: ${DSPACE_THEME_ACCENT};
EOB
)
css_block=$(cat <<EOB
:root {
  --ds-primary: ${DSPACE_THEME_PRIMARY};
  --ds-secondary: ${DSPACE_THEME_SECONDARY};
  --ds-accent: ${DSPACE_THEME_ACCENT};
}
EOB
)
replace_or_append_managed_block "${DSPACE_THEME_SCSS_VARIABLE_OVERRIDES_FILE}" "colors" "$sass_block"
replace_or_append_managed_block "${DSPACE_THEME_CSS_VARIABLE_OVERRIDES_FILE}" "colors" "$css_block"
log_info "Colores institucionales aplicados"

#!/usr/bin/env bash
# install.sh — register dsh-workspace-launcher in a DeepSeek Harness profile (0.2.x).
#
# Installs the bundle plugin/dsh-workspace-launcher through the `dsh` CLI when it
# is on PATH; otherwise prints the Plugin Manager steps. It never patches a
# Harness package.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_dir="$repo_root/plugin/dsh-workspace-launcher"
profile="${DSH_PROFILE:-desktop}"
dsh_home="${DSH_HOME:-$HOME/.dsh}"

step() { printf '[dsh-workspace-launcher] %s\n' "$1"; }

[ -d "$plugin_dir" ] || { echo "plugin directory not found: $plugin_dir" >&2; exit 1; }

step "target profile: $profile"
step "bundle directory: $plugin_dir"

if ! command -v dsh >/dev/null 2>&1; then
  step "the 'dsh' CLI is not on PATH."
  cat <<EOF
Install it from the Harness Plugin Manager instead:
  1) Plugins → install from folder → $plugin_dir
  2) Enable "dsh-workspace-launcher"
  3) Reload the page

Manual alternative: link the package into $dsh_home/profiles/$profile/node_modules
and add this to that profile's cordis.patch.yml:

- insert:
    - id: workspace-open
      name: 'dsh-workspace-launcher'
EOF
  exit 0
fi

dsh plugin --profile "$profile" add "$plugin_dir"
step "installed. Reload the Harness page."

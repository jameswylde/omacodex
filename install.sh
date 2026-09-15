#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
omarchy plugin validate "$source_dir"
plugin_dir="$HOME/.config/omarchy/plugins/omacodex.usage"
if [[ -e "$plugin_dir" || -L "$plugin_dir" ]]; then
  if [[ "$(readlink -f -- "$plugin_dir")" != "$source_dir" ]]; then
    echo "A different plugin already exists at $plugin_dir; move it before installing." >&2
    exit 1
  fi
else
  mkdir -p -- "$(dirname -- "$plugin_dir")"
  ln -s -- "$source_dir" "$plugin_dir"
fi
omarchy-shell shell rescanPlugins
omarchy plugin enable omacodex.usage --section right
echo "Codex is enabled in the right bar section."

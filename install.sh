#!/usr/bin/env bash
# Symlinks this repo into ~/.config/omarchy/plugins/ so omarchy-shell picks
# it up, keeping the repo itself as the single source of truth.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="vimdash"
DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

mkdir -p "$HOME/.config/omarchy/plugins"

if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
  echo "Refusing to overwrite non-symlink at $DEST" >&2
  exit 1
fi

ln -sfn "$REPO_DIR" "$DEST"
echo "Linked $DEST -> $REPO_DIR"

BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
BIND_LINE='o.bind("SUPER + APOSTROPHE", "Vimdash", "omarchy-shell shell toggle red.vimdash")'

if [ -f "$BINDINGS_FILE" ]; then
  if ! grep -qF "red.vimdash" "$BINDINGS_FILE"; then
    printf '%s\n' "$BIND_LINE" >> "$BINDINGS_FILE"
    echo "Added default keybind (SUPER + APOSTROPHE) to $BINDINGS_FILE"
  else
    echo "Keybind for red.vimdash already present in $BINDINGS_FILE, leaving it alone"
  fi
else
  echo "No $BINDINGS_FILE found; add manually:" >&2
  echo "  $BIND_LINE" >&2
fi

echo "Reload with: omarchy-shell shell rescanPlugins"
echo "Test with:   omarchy-shell shell toggle red.vimdash"

#!/usr/bin/env bash
# Uninstaller for omarchy-wallpaper-engine. Leaves linux-wallpaperengine
# installed (remove it yourself with: yay -R linux-wallpaperengine-git).
set -euo pipefail

BIN_DST="$HOME/.local/bin/omarchy-we"
AUTOSTART="$HOME/.config/hypr/autostart.lua"
HOOK="$HOME/.config/omarchy/hooks/theme-set.d/50-wallpaper-engine"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-we"

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n'  "$*"; }

# Stop the live wallpaper and restore a normal background first.
if command -v omarchy-we >/dev/null 2>&1; then
  info "Stopping live wallpaper and restoring theme background"
  omarchy-we stop || true
fi

info "Removing CLI symlink"
rm -f "$BIN_DST"; ok "removed $BIN_DST"

info "Removing theme-set hook"
rm -f "$HOOK"; ok "removed hook"

if [[ -f "$AUTOSTART" ]]; then
  info "Removing autostart entry"
  # Drop our comment line and the launch line.
  sed -i '/omarchy-wallpaper-engine)/d; /omarchy-we launch/d' "$AUTOSTART"
  ok "cleaned $AUTOSTART"
fi

info "Removing saved state"
rm -rf "$STATE_DIR"; ok "removed $STATE_DIR"

echo
ok "Uninstalled. (linux-wallpaperengine left in place.)"

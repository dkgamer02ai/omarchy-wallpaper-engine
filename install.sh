#!/usr/bin/env bash
# Installer for omarchy-wallpaper-engine.
# Use Wallpaper Engine (Steam Workshop) wallpapers as live Omarchy wallpapers.
#
#   ./install.sh            Install everything (deps, cli, autostart, hook)
#   ./install.sh --no-deps  Skip installing linux-wallpaperengine
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/bin/omarchy-we"
BIN_DST="$HOME/.local/bin/omarchy-we"
HOOK_SRC="$REPO_DIR/hooks/theme-set"
AUTOSTART="$HOME/.config/hypr/autostart.lua"
AUTOSTART_LINE='o.launch_on_start("omarchy-we launch")'
TRANSPARENT_BG="$HOME/.config/omarchy/backgrounds/transparent.png"
MENU_EXT="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
MENU_ENTRY='  "style.wallpaper-engine": {"icon":"󰸉","label":"Wallpaper Engine","keywords":"live animated video scene we steam workshop","action":"omarchy-we menu"},'

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✓\033[0m %s\n'  "$*"; }
warn()  { printf '\033[1;33m!\033[0m %s\n'  "$*"; }

INSTALL_DEPS=1
[[ "${1:-}" == "--no-deps" ]] && INSTALL_DEPS=0

# --- sanity ---------------------------------------------------------------
command -v omarchy >/dev/null 2>&1 || { echo "This is not an Omarchy system (omarchy CLI not found)."; exit 1; }

# --- 1. dependency: linux-wallpaperengine ---------------------------------
if [[ $INSTALL_DEPS -eq 1 ]] && ! command -v linux-wallpaperengine >/dev/null 2>&1; then
  info "Installing linux-wallpaperengine (AUR)…"
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed linux-wallpaperengine-git
  elif command -v paru >/dev/null 2>&1; then
    paru -S --needed linux-wallpaperengine-git
  else
    warn "No AUR helper (yay/paru). Install linux-wallpaperengine-git manually, then rerun with --no-deps."
    exit 1
  fi
elif command -v linux-wallpaperengine >/dev/null 2>&1; then
  ok "linux-wallpaperengine already installed"
else
  warn "linux-wallpaperengine is missing — nothing will render until you install it:"
  warn "    yay -S linux-wallpaperengine-git"
fi

# --- 2. cli ---------------------------------------------------------------
info "Installing omarchy-we CLI → $BIN_DST"
mkdir -p "$(dirname "$BIN_DST")"
chmod +x "$BIN_SRC"
ln -nsf "$BIN_SRC" "$BIN_DST"
ok "omarchy-we linked"

# --- 3. transparent background asset --------------------------------------
info "Creating transparent background placeholder"
mkdir -p "$(dirname "$TRANSPARENT_BG")"
if command -v magick >/dev/null 2>&1; then
  magick -size 1920x1080 xc:none "$TRANSPARENT_BG"
else
  cp "$REPO_DIR/assets/transparent.png" "$TRANSPARENT_BG"
fi
ok "transparent.png ready"

# --- 4. autostart ---------------------------------------------------------
touch "$AUTOSTART"
if grep -qF 'omarchy-we launch' "$AUTOSTART"; then
  ok "autostart entry already present"
else
  info "Adding autostart entry to $AUTOSTART"
  printf '\n-- Restore live Wallpaper Engine wallpaper on login (omarchy-wallpaper-engine)\n%s\n' "$AUTOSTART_LINE" >> "$AUTOSTART"
  ok "autostart entry added"
fi

# --- 5. theme-set hook ----------------------------------------------------
info "Installing theme-set hook"
if omarchy hook install theme-set "$HOOK_SRC" >/dev/null 2>&1; then
  ok "theme-set hook installed via 'omarchy hook install'"
else
  HOOK_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
  mkdir -p "$HOOK_DIR"
  install -m 0755 "$HOOK_SRC" "$HOOK_DIR/50-wallpaper-engine"
  ok "theme-set hook installed manually → $HOOK_DIR/50-wallpaper-engine"
fi

# --- 6. menu > Style entry ------------------------------------------------
# Adds one row to the Omarchy menu that opens the thumbnail picker directly.
info "Adding 'Wallpaper Engine' to menu > Style"
mkdir -p "$(dirname "$MENU_EXT")"
[[ -s "$MENU_EXT" ]] || printf '{\n}\n' > "$MENU_EXT"
# Drop a previous block so reinstalls don't duplicate the row.
sed -i '/omarchy-we-menu-start/,/omarchy-we-menu-end/d' "$MENU_EXT"
if awk -v e="$MENU_ENTRY" '
     /^}/ && !d { print "// omarchy-we-menu-start"; print e; print "// omarchy-we-menu-end"; d=1 }
     { print }
     END { exit !d }
   ' "$MENU_EXT" > "$MENU_EXT.tmp"; then
  mv "$MENU_EXT.tmp" "$MENU_EXT"
  ok "menu entry added → $MENU_EXT"
else
  rm -f "$MENU_EXT.tmp"
  warn "Could not find the closing '}' in $MENU_EXT — add this line yourself:"
  printf '%s\n' "$MENU_ENTRY"
fi

echo
ok "Done. Pick a wallpaper with:"
echo "     menu > Style > Wallpaper Engine    # thumbnail picker"
echo "     omarchy-we list        # see what you have"
echo "     omarchy-we set <n>     # set by number, id, or title"
echo "     omarchy-we menu        # same picker, from a terminal"

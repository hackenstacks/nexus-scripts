#!/bin/sh
# nexus-theme.sh — Set wallpaper and regenerate all themes to match
#
# Usage:
#   nexus-theme.sh /path/to/image.jpg   — set new wallpaper + retheme
#   nexus-theme.sh                       — retheme from last-used wallpaper
#
# What it does:
#   1. Sets wallpaper via swaybg (Wayland only)
#   2. Runs matugen to extract colors from the image
#   3. Writes themed configs for: labwc titlebar, foot terminal, fuzzel launcher
#   4. Reloads labwc window decorations (SIGUSR1)
#
# New foot/fuzzel colors take effect on next open (no daemon reload needed).
# Must be run from within a labwc/Wayland session for wallpaper to change.

MATUGEN="$HOME/.nix-profile/bin/matugen"
WALLPAPER_FILE="$HOME/.config/labwc/current-wallpaper"
DEFAULT_WALLPAPER="/usr/share/lxqt/wallpapers/origami-dark-labwc.png"

# --- resolve wallpaper ---
if [ -n "$1" ]; then
    WALLPAPER="$1"
else
    WALLPAPER=$(cat "$WALLPAPER_FILE" 2>/dev/null || echo "$DEFAULT_WALLPAPER")
fi

if [ ! -f "$WALLPAPER" ]; then
    echo "nexus-theme: wallpaper not found: $WALLPAPER" >&2
    exit 1
fi

# --- save as current ---
echo "$WALLPAPER" > "$WALLPAPER_FILE"

echo "nexus-theme: applying $(basename "$WALLPAPER")"

# --- set wallpaper (Wayland only) ---
if [ -n "$WAYLAND_DISPLAY" ]; then
    pkill swaybg 2>/dev/null
    swaybg -i "$WALLPAPER" -m fill &
else
    echo "nexus-theme: not in Wayland session — themes will update but wallpaper unchanged"
fi

# --- generate all themes via matugen ---
exec "$MATUGEN" image "$WALLPAPER" --quiet

#!/usr/bin/env bash
set -euo pipefail
NEW="${1:-}"
[ -n "$NEW" ] || exit 0

if pgrep -x noctalia >/dev/null 2>&1 && command -v noctalia >/dev/null 2>&1; then
    noctalia msg wallpaper-set "$NEW"
elif pgrep -x swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
    swww img "$NEW" --transition-type none
elif pgrep -x hyprpaper >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1; then
    hyprctl hyprpaper preload "$NEW" >/dev/null 2>&1 || true
    hyprctl hyprpaper wallpaper ",$NEW" >/dev/null
fi

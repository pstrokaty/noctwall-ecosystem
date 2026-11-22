#!/usr/bin/env bash
set -euo pipefail

if pgrep -x noctalia >/dev/null 2>&1 && command -v noctalia >/dev/null 2>&1; then
    WALL=$(noctalia msg wallpaper-get 2>/dev/null | tr -d "
" || true)
    [ -n "$WALL" ] && { echo "$WALL"; exit 0; }
fi

if pgrep -x swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
    WALL=$(swww query 2>/dev/null | sed -n "s/.*currently displaying: image: //p" | head -n 1 | tr -d "
" || true)
    [ -n "$WALL" ] && { echo "$WALL"; exit 0; }
fi

if pgrep -x hyprpaper >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1; then
    WALL=$(hyprctl hyprpaper listactive 2>/dev/null | awk -F" = " "{print \$2}" | head -n 1 | tr -d "
" || true)
    [ -n "$WALL" ] && { echo "$WALL"; exit 0; }
fi

[ -f "$HOME/.cache/noctwall/last-wallpaper.txt" ] && cat "$HOME/.cache/noctwall/last-wallpaper.txt"

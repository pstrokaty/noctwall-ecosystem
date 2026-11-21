#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DIR="${1:-$HOME/Obrazy/Wallpapers/UltraDual}"
[ -d "$DIR" ] || DIR="$HOME/Obrazy/Wallpapers"
OLD=$(noctalia msg wallpaper-get | tr -d "\n")
NEXT=$(find "$DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) ! -iname "*_fg.*" ! -path "$OLD" | shuf -n 1)
[ -n "$NEXT" ] && "$SCRIPT_DIR/set-wallpaper.sh" "$NEXT"

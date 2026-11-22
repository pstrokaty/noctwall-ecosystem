#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

read -r CFG_DIR CFG_SUB OLD < <(python3 -c '
import json, os, subprocess
cfg_p = os.path.expanduser("~/.config/noctwall/config.json")
wdir = os.path.expanduser("~/Pictures/Wallpapers")
sub = ""
cmd = ["noctwall-backend-get"]
try:
    p = json.load(open(cfg_p, encoding="utf-8")).get("paths", {})
    if p.get("wallpapersDir"):
        wdir = os.path.expanduser(p["wallpapersDir"])
    if p.get("randomSubdir") is not None:
        sub = p["randomSubdir"]
    if isinstance(p.get("wallpaperGetCmd"), list) and p["wallpaperGetCmd"]:
        cmd = [os.path.expanduser(x) for x in p["wallpaperGetCmd"]]
except Exception:
    pass
old = subprocess.run(cmd, capture_output=True, text=True).stdout.strip()
print(f"{wdir}	{sub}	{old}")
')

DIR="${1:-}"
if [ -z "$DIR" ]; then
    if [ -n "$CFG_SUB" ] && [ -d "$CFG_DIR/$CFG_SUB" ]; then
        DIR="$CFG_DIR/$CFG_SUB"
    else
        DIR="$CFG_DIR"
    fi
fi

[ -d "$DIR" ] || exit 0
NEXT=$(find "$DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) ! -iname "*_fg.*" ! -path "$OLD" | shuf -n 1)
[ -n "$NEXT" ] && "$SCRIPT_DIR/set-wallpaper.sh" "$NEXT"

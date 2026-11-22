#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
export PATH="$ROOT_DIR/bin:$HOME/.local/bin:$PATH"

NEW=$(realpath "$1")
[ -n "$NEW" ] || exit 0

OLD=$(python3 -c '
import json, os, subprocess
cfg_p = os.path.expanduser("~/.config/noctwall/config.json")
cmd = ["noctwall-backend-get"]
try:
    c = json.load(open(cfg_p, encoding="utf-8")).get("paths", {}).get("wallpaperGetCmd")
    if isinstance(c, list) and c:
        cmd = [os.path.expanduser(x) for x in c]
except Exception:
    pass
out = subprocess.run(cmd, capture_output=True, text=True).stdout.strip()
print(out)
')

[ "$OLD" = "$NEW" ] && exit 0

mkdir -p "$HOME/.cache/noctwall"
echo "$NEW" > "$HOME/.cache/noctwall/last-wallpaper.txt"

if grep -Eq "^[[:space:]]*fill_mode[[:space:]]*=[[:space:]]*"span"" "$HOME/.local/state/noctalia/settings.toml" 2>/dev/null; then
    SPAN=true
else
    SPAN=false
fi

KIND=""
FIELD=""
LINE=""
read -r KIND FIELD LINE < <(noctwall-fx elige "$NEW" 2>/dev/null | tail -n 1) || true

qs -p "$ROOT_DIR" ipc call wallfx play "$OLD" "$NEW" "$KIND" "$FIELD" "$LINE" "$SPAN"

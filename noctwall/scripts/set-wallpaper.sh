#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
export PATH="$ROOT_DIR/bin:$HOME/.local/bin:$PATH"

NEW=$(realpath "$1")
OLD=$(noctalia msg wallpaper-get | tr -d "\r\n")

[ -n "$NEW" ] || exit 0
[ "$OLD" = "$NEW" ] && exit 0

mkdir -p "$HOME/.cache/noctwall"
echo "$NEW" > "$HOME/.cache/noctwall/last-wallpaper.txt"

if grep -Eq "^[[:space:]]*fill_mode[[:space:]]*=[[:space:]]*\"span\"" "$HOME/.local/state/noctalia/settings.toml" 2>/dev/null; then
    SPAN=true
else
    SPAN=false
fi

KIND=""
FIELD=""
LINE=""
read -r KIND FIELD LINE < <(noctwall-fx elige "$NEW" 2>/dev/null | tail -n 1) || true

qs -p "$ROOT_DIR" ipc call wallfx play "$OLD" "$NEW" "$KIND" "$FIELD" "$LINE" "$SPAN"

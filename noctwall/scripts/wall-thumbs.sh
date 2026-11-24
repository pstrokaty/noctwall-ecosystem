#!/usr/bin/env bash
set -u

CFG_FILE="$HOME/.config/noctwall/config.json"
PIC_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
[ -n "$PIC_DIR" ] || PIC_DIR="$HOME/Pictures"
CFG_SRC="$PIC_DIR/Wallpapers"
CFG_DST="$HOME/.cache/noctwall/thumbs"
if [ -f "$CFG_FILE" ] && command -v python3 >/dev/null 2>&1; then
    CFG_SRC="$(python3 -c "import json,os,sys; p=json.load(open(sys.argv[1])).get("paths",{}); print(os.path.expanduser(p.get("wallpapersDir") or sys.argv[2]))" "$CFG_FILE" "$CFG_SRC" 2>/dev/null || echo "$CFG_SRC")"
    CFG_DST="$(python3 -c "import json,os,sys; p=json.load(open(sys.argv[1])).get("paths",{}); print(os.path.expanduser(p.get("thumbsDir") or sys.argv[2]))" "$CFG_FILE" "$CFG_DST" 2>/dev/null || echo "$CFG_DST")"
fi
SRC="${1:-$CFG_SRC}"
DST="${2:-$CFG_DST}"
GEOM="900x420^"
JOBS=4

command -v magick >/dev/null 2>&1 || exit 0
[ -d "$SRC" ] || exit 0
mkdir -p "$DST" || exit 0

while IFS= read -r -d "" img; do
    rel="${img#$SRC/}"
    key="${rel//\//__}"
    out="$DST/${key}.jpg"
    if [ -s "$out" ] && [ ! "$img" -nt "$out" ]; then
        continue
    fi
    ( magick "$img" -auto-orient -thumbnail "$GEOM" -strip -quality 85 "$out.tmp" 2>/dev/null \
        && mv -f -- "$out.tmp" "$out" || rm -f -- "$out.tmp" ) &
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
done < <(find "$SRC" -maxdepth 2 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
    ! -iname "*_fg.*" -print0)
wait

find "$DST" -maxdepth 1 -type f -name "*.jpg.tmp" -delete 2>/dev/null

while IFS= read -r -d "" thumb; do
    base="$(basename "$thumb")"
    rel="${base%.jpg}"
    orig="$SRC/${rel//__/\/}"
    [ -f "$orig" ] || rm -f -- "$thumb"
done < <(find "$DST" -maxdepth 1 -type f -name "*.jpg" -print0)

exit 0

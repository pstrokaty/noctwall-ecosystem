#!/usr/bin/env bash
set -u

SRC="${1:-$HOME/Obrazy/Wallpapers}"
DST="${2:-$HOME/.cache/noctwall/thumbs}"
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

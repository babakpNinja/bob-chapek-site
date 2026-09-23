#!/bin/sh
# Cache-bust mutable asset URLs at container start (issue #47).
#
# The edge and browsers hold an asset for hours, so a changed image under an
# unchanged name keeps serving the OLD bytes -- Bob opened the freshly deployed
# page and got the previous cover. The page was right; the cached asset was not.
#
# This rewrites every asset reference in the served HTML to carry ?v=<sha1 prefix
# of the file's own bytes>. The token changes only when the bytes change, so an
# unchanged asset keeps a cacheable URL while a changed one becomes a new URL no
# cache can resolve to the old object. The stamp rides a query string, so no file
# is renamed and no path breaks. Idempotent: each pattern requires the path to
# end right after the URL, so an already-stamped URL (?v=...) is skipped.
#
# Usage: stamp-assets.sh <web-root>
# Kept as its own script so tests can exercise it directly against a temp tree.
set -eu

ROOT=${1:?usage: stamp-assets.sh <web-root>}

echo "[entrypoint] stamping asset URLs (cache-bust)"
# Every HTML page in the image, once, into a list. The snapshots under
# /versions/ reference the same shared assets, so they are stamped too.
find "$ROOT" -name '*.html' -type f > /tmp/_pages.txt
find "$ROOT/assets" -type f | while IFS= read -r f; do
  rel=${f#"$ROOT/"}
  sum=$(sha1sum "$f" | cut -c1-12)
  while IFS= read -r page; do
    # Both quote styles, and the root-absolute form the snapshots use. Each
    # pattern demands the URL end right after the path, so an already-stamped
    # URL (path then ?v=) is left alone on a second run.
    sed -i \
      -e "s|\"$rel\"|\"$rel?v=$sum\"|g" \
      -e "s|'$rel'|'$rel?v=$sum'|g" \
      -e "s|\"/$rel\"|\"/$rel?v=$sum\"|g" \
      -e "s|'/$rel'|'/$rel?v=$sum'|g" "$page"
  done < /tmp/_pages.txt
done
rm -f /tmp/_pages.txt

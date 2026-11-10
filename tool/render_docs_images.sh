#!/usr/bin/env bash
# Regenerates the developer guide's images:
#   docs/guide/images/_scenes/<page>.html  ->  docs/guide/images/<page>/<stage name>.png
#
# Each scene file is an HTML page of <tut-stage> elements, drawn with the
# Codelessly Editor's tutorial toolkit (CodelesslyEditor/tool/docs_images; see
# its README.md for the elements). Every stage renders at 2x and is checked
# (marks outside the stage, overlapping labels, missing images fail the run).
#
#   tool/render_docs_images.sh                 # every page
#   tool/render_docs_images.sh 02-quickstart   # one page
#   DOCS_IMAGES_TOOL=~/src/CodelesslyEditor/tool/docs_images tool/render_docs_images.sh
#
# Needs: the toolkit (a sibling CodelesslyEditor checkout by default, or
# DOCS_IMAGES_TOOL), Node 18+ with Playwright installed globally
# (npm i -g playwright && npx playwright install chromium), and Python 3 with
# Pillow to shrink the PNGs (256 colours; skipped with a warning without it).
# Screenshots used as bases live in _scenes/shots/ with their targets.json.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES="$ROOT/docs/guide/images"
SCENES="$IMAGES/_scenes"

TOOL="${DOCS_IMAGES_TOOL:-}"
if [ -z "$TOOL" ]; then
  for c in "$ROOT/../CodelesslyEditor/tool/docs_images" "$ROOT/../../CodelesslyEditor/tool/docs_images"; do
    if [ -f "$c/render.mjs" ]; then TOOL="$c"; break; fi
  done
fi
if [ -z "$TOOL" ] || [ ! -f "$TOOL/render.mjs" ]; then
  echo "render_docs_images: the tutorial toolkit was not found. Set DOCS_IMAGES_TOOL to CodelesslyEditor/tool/docs_images." >&2
  exit 1
fi
TOOL="$(cd "$TOOL" && pwd)"

# Scenes include "_toolkit/annotate.js": point it at the toolkit (not committed).
ln -sfn "$TOOL" "$SCENES/_toolkit"

pages=()
if [ $# -gt 0 ]; then
  for p in "$@"; do pages+=("$SCENES/${p%.html}.html"); done
else
  for f in "$SCENES"/*.html; do pages+=("$f"); done
fi

for f in "${pages[@]}"; do
  out="$IMAGES/$(basename "$f" .html)"
  mkdir -p "$out"
  find "${out:?}" -maxdepth 1 -name '*.png' -delete
  node "$TOOL/render.mjs" "$f" --out "$out" --check --quiet
done

# Shrink: 256-colour palettes keep these flat diagrams and UI captures crisp at
# about a third of the size.
if python3 -c 'import PIL' 2>/dev/null; then
  python3 - "$IMAGES" "${pages[@]}" <<'PY'
import os, sys
from PIL import Image
images, pages = sys.argv[1], sys.argv[2:]
total = 0
for page in pages:
    d = os.path.join(images, os.path.basename(page)[:-5])
    for f in sorted(os.listdir(d)):
        if not f.endswith('.png'):
            continue
        p = os.path.join(d, f)
        im = Image.open(p).convert('RGB')
        im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(p, optimize=True)
        total += os.path.getsize(p)
print(f'render_docs_images: {total // 1024} KB of PNGs')
PY
else
  echo "render_docs_images: Pillow not found, PNGs left unoptimised (pip install Pillow)." >&2
fi

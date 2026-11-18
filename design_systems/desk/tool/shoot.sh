#!/bin/bash
# Expands one of Desk's example sites and renders it, light and dark, at the three sizes:
#
#   bash design_systems/desk/tool/shoot.sh <example> [sizes] [extra render options...]
#
# <example> is a folder under design_systems/desk/examples (its pages/*.txt, its site/site.json). The pictures go to
# examples/<example>/out/<screen>@<w>x<h>-<light|dark>.png, the outline beside them.
set -e
desk="$(cd "$(dirname "$0")/.." && pwd)"
sdk="$(cd "$desk/../.." && pwd)"
ex="$desk/examples/$1"; shift
sizes="${1:-1440x900,834x1112,390x844}"; [ $# -gt 0 ] && shift
# A Windows path for the render tool (Git Bash rewrites /c/... only for native programs it starts itself).
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
bash "$sdk/tool/notation/notation.sh" expand "$ex"
for mode in light dark; do
  bash "$sdk/tool/codelessly" render "$(win "$ex/site")" --out "$(win "$ex/out")" --sizes "$sizes" --theme $mode --outline "$@" \
    | grep -v '^  \|^canvas\|^$\|^wrote\|^Rendering' || true
done

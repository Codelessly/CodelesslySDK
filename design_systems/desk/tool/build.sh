#!/bin/bash
# Desk's build: the manifest from tool/build.py, the components from components/src/components/*.txt (the notation),
# then the manifest again so it lists every component. Run from anywhere:
#
#   bash design_systems/desk/tool/build.sh
set -e
desk="$(cd "$(dirname "$0")/.." && pwd)"
sdk="$(cd "$desk/../.." && pwd)"
py="$(command -v python 2>/dev/null || command -v python3)"; "$py" -c "" 2>/dev/null || py=python
"$py" "$desk/tool/build.py"
bash "$sdk/tool/notation/notation.sh" expand "$desk/components/src"
"$py" "$desk/tool/build.py"

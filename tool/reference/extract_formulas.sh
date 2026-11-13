#!/usr/bin/env bash
# Writes the SDK's formula function table to <out.json> (default: the API
# worktree's tool/reference/data/formulas.json next to this SDK checkout,
# as the pubspec_overrides.yaml names it).
#   tool/reference/extract_formulas.sh [out.json]
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdk="$(cd "$here/../.." && pwd)"
out="${1:-}"
if [ -z "$out" ]; then
  api="$(sed -n 's/^ *path: *//p' "$sdk/pubspec_overrides.yaml" 2>/dev/null | head -1)"
  [ -n "$api" ] || { echo "Name the output file: no codelessly_api path in pubspec_overrides.yaml." >&2; exit 2; }
  out="$api/tool/reference/data/formulas.json"
fi
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
mkdir -p "$(dirname "$out")"
cd "$sdk" && CODELESSLY_FORMULAS_OUT="$out" "${FLUTTER:-flutter}" test --no-pub tool/reference/extract_formulas.dart > /dev/null
echo "wrote $out"

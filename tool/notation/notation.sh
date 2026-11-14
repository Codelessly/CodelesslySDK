#!/bin/bash
# The compact notation's tools, runnable from a fresh checkout:
#
#   tool/notation/notation.sh prompt [--design-system <folder>]
#   tool/notation/notation.sh expand <file.txt> [--design-system <folder>] [--id <canvas id>] [--out <file.json>]
#
# It finds Flutter's dart, makes the SDK use the codelessly_api checked out
# beside it (../CodelesslyAPI: the notation is newer than the published
# package), resolves dependencies when they are stale, and runs
# tool/notation/<command>.dart with the rest of the arguments.
set -e
sdk="$(cd "$(dirname "$0")/../.." && pwd)"
cmd="${1:-}"
case "$cmd" in
  prompt|expand) shift ;;
  *) echo "usage: tool/notation/notation.sh prompt|expand [arguments] (see the head of this file)" >&2; exit 2 ;;
esac

flutter_bin=""
if [ -n "${FLUTTER:-}" ] && [ -x "$FLUTTER" ]; then
  flutter_bin="$FLUTTER"
elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  flutter_bin="$FLUTTER_ROOT/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
else
  for f in /opt/flutter/bin/flutter "$HOME/flutter/bin/flutter" /workspace/.tools/flutter/bin/flutter /usr/local/flutter/bin/flutter; do
    if [ -x "$f" ]; then flutter_bin="$f"; break; fi
  done
fi
if [ -z "$flutter_bin" ]; then
  echo "Flutter not found. Set FLUTTER to the flutter command: FLUTTER=/path/to/flutter/bin/flutter tool/notation/notation.sh $cmd ..." >&2
  echo "Find one with: ls -d /opt/flutter ~/flutter /workspace/.tools/flutter 2>/dev/null" >&2
  exit 2
fi
dart_bin="$(dirname "$flutter_bin")/dart"

# codelessly_api from the checkout beside the SDK, as tool/render/render.sh
# does (the same marker, so the two agree on one pubspec_overrides.yaml).
overrides="$sdk/pubspec_overrides.yaml"
marker="# Written by tool/render/render.sh"
api=""
for d in "${CODELESSLY_API:-}" "$sdk/../CodelesslyAPI" "$sdk/../codelessly_api"; do
  if [ -n "$d" ] && [ -f "$d/pubspec.yaml" ] && grep -q '^name: codelessly_api' "$d/pubspec.yaml"; then
    api="$(cd "$d" && pwd)"
    break
  fi
done
if [ ! -f "$overrides" ] && [ -n "$api" ]; then
  printf '%s: codelessly_api from %s.\ndependency_overrides:\n  codelessly_api:\n    path: %s\n' "$marker" "$api" "$api" > "$overrides"
  echo "Using codelessly_api from $api (written to pubspec_overrides.yaml)." >&2
fi
used="$api"
if [ -f "$overrides" ]; then
  used="$(sed -n '/codelessly_api:/,/path:/s/^ *path: *//p' "$overrides" | head -1)"
  case "$used" in ''|/*) ;; *) used="$(cd "$sdk" && cd "$used" 2>/dev/null && pwd)" ;; esac
fi
if [ -z "$used" ] || [ ! -f "$used/lib/notation.dart" ]; then
  {
    echo "The notation needs codelessly_api from its master branch; this checkout would compile against ${used:-the published package}, which does not have it."
    echo "Check out CodelesslyAPI's master beside this repository (../CodelesslyAPI), or set CODELESSLY_API to its folder, and run this again."
    echo "If ../CodelesslyAPI is there but has no lib/notation.dart: git -C ../CodelesslyAPI fetch origin master && git -C ../CodelesslyAPI checkout master"
  } >&2
  exit 2
fi

config="$sdk/.dart_tool/package_config.json"
stale=0
[ -f "$config" ] || stale=1
for f in "$sdk/pubspec.yaml" "$overrides" "$used/pubspec.yaml"; do
  [ -f "$f" ] && [ "$f" -nt "$config" ] && stale=1
done
if [ $stale = 1 ]; then
  echo "Resolving the SDK's dependencies (flutter pub get)..." >&2
  log="$(mktemp)"
  if ! (cd "$sdk" && "$flutter_bin" pub get --no-example > "$log" 2>&1); then
    echo "flutter pub get failed:" >&2
    tail -30 "$log" >&2
    rm -f "$log"
    exit 2
  fi
  rm -f "$log"
fi
exec "$dart_bin" run "$sdk/tool/notation/$cmd.dart" "$@"

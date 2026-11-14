#!/usr/bin/env bash
# Validate and render Codelessly layout documents. See tool/render/README.md.
#   tool/render/render.sh <document.json | dir> --out <dir> [--sizes 390x844,...] [--screen id]
#       [--full-page] [--fonts dir] [--theme light|dark|system] [--tap id] [--hover id] [--focus id] [--type id=text]
#       [--set name=json] [--scroll id=px] [--drag id=dx,dy] [--navigate screen?param=value] [--wait ms] [--now time]
#       [--label text] [--compare png|dir] [--compare-map screen=name] [--validate-only]
#       [--component Type [--props json] [--slots file]]
# Exit status: 0 no errors (warnings allowed), 1 errors, 2 bad arguments or a crash.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdk="$(cd "$here/../.." && pwd)"

# Paths are taken relative to where the command is run; make them absolute.
args=()
out=""
expect_path=0
for a in "$@"; do
  if [ $expect_path = 1 ]; then
    # `--fonts system` names the system's font directories, not a path.
    if [ "${prev:-}" != "--fonts" ] || [ "$a" != "system" ]; then
      case "$a" in /*) ;; *) a="$PWD/$a" ;; esac
    fi
    expect_path=0
    args+=("$a")
    [ "${prev:-}" = "--out" ] && out="$a"
    prev=""
    continue
  fi
  case "$a" in
    --out|--fonts|--slots|--compare) expect_path=1; prev="$a"; args+=("$a") ;;
    --*) args+=("$a") ;;
    *)
      # A positional argument right after a value-taking option is that option's value.
      if [ ${#args[@]} -gt 0 ] && [[ "${args[-1]}" =~ ^--(sizes|screen|tap|hover|focus|key|type|set|scroll|drag|navigate|wait|now|label|component|props|theme|compare-map)$ ]]; then
        args+=("$a")
      else
        case "$a" in /*) ;; *) a="$PWD/$a" ;; esac
        args+=("$a")
      fi
      ;;
  esac
done
if [ -z "$out" ]; then
  echo "--out <dir> is required. Run with --help for usage." >&2
  exit 2
fi
mkdir -p "$out"

# Flutter: $FLUTTER (the flutter command), else $FLUTTER_ROOT/bin/flutter,
# else flutter on the PATH, else /opt/flutter/bin/flutter.
flutter_bin=""
if [ -n "${FLUTTER:-}" ]; then
  flutter_bin="$FLUTTER"
elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  flutter_bin="$FLUTTER_ROOT/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
elif [ -x /opt/flutter/bin/flutter ]; then
  flutter_bin=/opt/flutter/bin/flutter
fi
if [ -z "$flutter_bin" ] || [ ! -x "$flutter_bin" ]; then
  echo "Flutter not found: set FLUTTER to the flutter command, or FLUTTER_ROOT to the Flutter SDK, or put flutter on the PATH." >&2
  exit 2
fi

# One run at a time per SDK checkout: flutter test rewrites the checkout's
# build/ (native assets, test assets, the compiled harness) as it starts, so
# runs started together wait their turn here (each still takes its own --out).
mkdir -p "$sdk/build"
lock="$sdk/build/.render.lock"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$lock"
  if ! flock -n 9; then
    echo "Another render run is using this SDK checkout; waiting for it to finish." >&2
    flock 9
  fi
else
  # No flock (macOS): a lock directory, taken over when its owner is gone.
  waited=0
  until mkdir "$lock.d" 2>/dev/null; do
    owner="$(cat "$lock.d/pid" 2>/dev/null || true)"
    if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then rm -rf "$lock.d"; continue; fi
    [ $waited = 0 ] && echo "Another render run is using this SDK checkout; waiting for it to finish." >&2
    waited=1
    sleep 1
  done
  echo $$ > "$lock.d/pid"
  release_lock() { rm -rf "$lock.d"; }
fi

# codelessly_api from a sibling checkout (../CodelesslyAPI or ../codelessly_api)
# when there is one and the SDK has no pubspec_overrides.yaml of its own; else
# the published package. An override this script wrote says so on its first line.
overrides="$sdk/pubspec_overrides.yaml"
marker="# Written by tool/render/render.sh"
api=""
for d in "${CODELESSLY_API:-}" "$sdk/../CodelesslyAPI" "$sdk/../codelessly_api"; do
  if [ -n "$d" ] && [ -f "$d/pubspec.yaml" ] && grep -q '^name: codelessly_api' "$d/pubspec.yaml"; then
    api="$(cd "$d" && pwd)"
    break
  fi
done
if [ ! -f "$overrides" ] || head -1 "$overrides" | grep -q "^$marker"; then
  if [ -n "$api" ]; then
    want="$(printf '%s: codelessly_api from %s.\ndependency_overrides:\n  codelessly_api:\n    path: %s\n' "$marker" "$api" "$api")"
    if [ "$(cat "$overrides" 2>/dev/null)" != "$want" ]; then
      printf '%s\n' "$want" > "$overrides"
      echo "Using codelessly_api from $api (written to pubspec_overrides.yaml)." >&2
    fi
  elif [ -f "$overrides" ]; then
    rm -f "$overrides"
  fi
fi

# Dependencies: resolved when the package config is missing or older than
# what it is resolved from.
config="$sdk/.dart_tool/package_config.json"
stale=0
[ -f "$config" ] || stale=1
for f in "$sdk/pubspec.yaml" "$overrides" "${api:+$api/pubspec.yaml}"; do
  [ -n "$f" ] && [ -f "$f" ] && [ "$f" -nt "$config" ] && stale=1
done
if [ $stale = 1 ]; then
  echo "Resolving the SDK's dependencies (flutter pub get)..." >&2
  if ! (cd "$sdk" && "$flutter_bin" pub get --no-example > "$out/.pub-get.log" 2>&1); then
    echo "flutter pub get failed:" >&2
    tail -30 "$out/.pub-get.log" >&2
    exit 2
  fi
  rm -f "$out/.pub-get.log"
fi

work="$(mktemp -d "$out/.render.XXXXXX")"
trap 'rm -rf "$work"; [ "$(type -t release_lock)" = function ] && release_lock' EXIT
printf '%s\n' "${args[@]}" > "$work/args"
(
  cd "$sdk" && CODELESSLY_RENDER_ARGS="$work/args" "$flutter_bin" test --no-pub \
    tool/render/render_harness.dart > "$work/flutter.log" 2>&1
)
if [ -f "$work/args.report" ]; then
  cat "$work/args.report"
else
  echo "The render harness did not finish. Its output:" >&2
  grep -v "Woah\|superuser\|^  /\|📎" "$work/flutter.log" | tail -60 >&2
  exit 2
fi
status="$(cat "$work/args.status" 2>/dev/null || echo 2)"
exit "$status"

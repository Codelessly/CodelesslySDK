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
# Scripts run on the QuickJS library tool/build_quickjs.sh builds, when it is there and none is named.
if [ -z "${CODELESSLY_QUICKJS_LIBRARY:-}" ]; then
  for lib in "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.so" "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.dylib"; do
    if [ -f "$lib" ]; then export CODELESSLY_QUICKJS_LIBRARY="$lib"; break; fi
  done
fi

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
# else flutter on the PATH, else the usual install places.
places="${CODELESSLY_FLUTTER_PLACES:-/opt/flutter/bin/flutter $HOME/flutter/bin/flutter $HOME/.tools/flutter/bin/flutter /workspace/.tools/flutter/bin/flutter /usr/local/flutter/bin/flutter $HOME/development/flutter/bin/flutter /snap/bin/flutter}"
flutter_bin=""
if [ -n "${FLUTTER:-}" ]; then
  flutter_bin="$FLUTTER"
elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  flutter_bin="$FLUTTER_ROOT/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
else
  for f in $places; do
    if [ -x "$f" ]; then flutter_bin="$f"; break; fi
  done
fi
if [ -z "$flutter_bin" ] || [ ! -x "$flutter_bin" ]; then
  {
    if [ -n "${FLUTTER:-}" ]; then
      echo "Flutter not found: FLUTTER is set to $FLUTTER, which is not an executable flutter command."
    else
      echo "Flutter not found: FLUTTER is unset, FLUTTER_ROOT${FLUTTER_ROOT:+ ($FLUTTER_ROOT)} has no bin/flutter, the PATH has no flutter, and none of: $places."
    fi
    echo "Set FLUTTER to the flutter command on each run, for example:"
    echo "  FLUTTER=/path/to/flutter/bin/flutter tool/render/render.sh <site> --out <dir>"
    echo "(or FLUTTER_ROOT=/path/to/flutter, the Flutter SDK's folder). Find one with: ls -d /opt/flutter ~/flutter /workspace/.tools/flutter 2>/dev/null"
    echo "This command and the reference it follows (codelessly_api's docs/reference/STARTER.md) are on the master branch of"
    echo "CodelesslySDK and CodelesslyAPI: if tool/render or docs/reference is missing, run git fetch origin master && git checkout master in each."
  } >&2
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
# What this run uses, first: the SDK and API versions (and their commits).
version_of() { sed -n 's/^version: *//p' "$1/pubspec.yaml" 2>/dev/null | head -1; }
commit_of() {
  local c
  c="$(git -C "$1" rev-parse --short HEAD 2>/dev/null)" || return 0
  printf ' @ %s%s' "$c" "$(git -C "$1" symbolic-ref -q --short HEAD 2>/dev/null | sed 's/^/ on /')"
}
api_used="$api"
if [ -f "$overrides" ] && ! head -1 "$overrides" | grep -q "^$marker"; then
  api_used="$(sed -n '/codelessly_api:/,/path:/s/^ *path: *//p' "$overrides" | head -1)"
  case "$api_used" in ''|/*) ;; *) api_used="$(cd "$sdk" && cd "$api_used" 2>/dev/null && pwd)" ;; esac
fi
if [ -n "$api_used" ] && [ -f "$api_used/pubspec.yaml" ]; then
  api_desc="codelessly_api $(version_of "$api_used")$(commit_of "$api_used") from $api_used"
  [ -f "$api_used/docs/reference/STARTER.md" ] || api_desc="$api_desc (no docs/reference here: check out its master branch)"
else
  api_desc="codelessly_api published ($(sed -n '/^  codelessly_api:/,/version:/s/^ *version: *//p' "$sdk/pubspec.lock" 2>/dev/null | tr -d '"' | head -1))"
fi
echo "Rendering with codelessly_sdk $(version_of "$sdk")$(commit_of "$sdk") at $sdk, $api_desc, Flutter $flutter_bin." >&2

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

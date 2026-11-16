# Shared by the SDK's command-line tools (tool/codelessly, tool/render/render.sh,
# tool/notation/notation.sh, tool/stream/replay.sh): find Flutter, use a sibling
# codelessly_api checkout, resolve dependencies when stale. Source it with the
# SDK's root in $sdk:
#
#   sdk="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
#   . "$sdk/tool/lib/env.sh"
#
# Every function sets globals (flutter_bin, dart_bin, api, overrides) and
# returns non-zero after printing what to do; callers exit 2 then.

# The marker on the first line of a pubspec_overrides.yaml these tools wrote;
# an overrides file without it is the checkout's own and is never touched.
codelessly_override_marker="# Written by tool/render/render.sh"

# codelessly_find_flutter <command shown in the help>
# Sets flutter_bin and dart_bin: $FLUTTER (the flutter command), else
# $FLUTTER_ROOT/bin/flutter, else flutter on the PATH, else the usual install
# places ($CODELESSLY_FLUTTER_PLACES overrides the list).
codelessly_find_flutter() {
  local usage="${1:-tool/codelessly <command>}"
  local places="${CODELESSLY_FLUTTER_PLACES:-/opt/flutter/bin/flutter $HOME/flutter/bin/flutter $HOME/.tools/flutter/bin/flutter /workspace/.tools/flutter/bin/flutter /usr/local/flutter/bin/flutter $HOME/development/flutter/bin/flutter /snap/bin/flutter}"
  flutter_bin=""
  if [ -n "${FLUTTER:-}" ]; then
    flutter_bin="$FLUTTER"
  elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
    flutter_bin="$FLUTTER_ROOT/bin/flutter"
  elif command -v flutter >/dev/null 2>&1; then
    flutter_bin="$(command -v flutter)"
  else
    local f
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
      echo "  FLUTTER=/path/to/flutter/bin/flutter $usage"
      echo "(or FLUTTER_ROOT=/path/to/flutter, the Flutter SDK's folder). Find one with: ls -d /opt/flutter ~/flutter /workspace/.tools/flutter 2>/dev/null"
      echo "This command and the reference it follows (codelessly_api's docs/reference/STARTER.md) are on the master branch of"
      echo "CodelesslySDK and CodelesslyAPI: if tool/render or docs/reference is missing, run git fetch origin master && git checkout master in each."
    } >&2
    return 2
  fi
  dart_bin="$(dirname "$flutter_bin")/dart"
  [ -x "$dart_bin" ] || dart_bin="$(command -v dart 2>/dev/null || echo dart)"
}

# codelessly_find_api
# Sets api to a sibling codelessly_api checkout ($CODELESSLY_API, ../CodelesslyAPI
# or ../codelessly_api beside the SDK), or "" when there is none.
codelessly_find_api() {
  api=""
  local d
  for d in "${CODELESSLY_API:-}" "$sdk/../CodelesslyAPI" "$sdk/../codelessly_api"; do
    if [ -n "$d" ] && [ -f "$d/pubspec.yaml" ] && grep -q '^name: codelessly_api' "$d/pubspec.yaml"; then
      api="$(cd "$d" && pwd)"
      return 0
    fi
  done
  return 0
}

# codelessly_api_in_use
# Prints the codelessly_api folder the SDK compiles against: the path an
# overrides file of the checkout's own names, else the sibling ($api), else "".
codelessly_api_in_use() {
  local overrides="$sdk/pubspec_overrides.yaml" used="$api"
  if [ -f "$overrides" ] && ! head -1 "$overrides" | grep -q "^$codelessly_override_marker"; then
    used="$(sed -n '/codelessly_api:/,/path:/s/^ *path: *//p' "$overrides" | head -1)"
    case "$used" in ''|/*) ;; *) used="$(cd "$sdk" && cd "$used" 2>/dev/null && pwd)" ;; esac
  fi
  printf '%s' "$used"
}

# codelessly_write_api_override
# Points the SDK at the sibling codelessly_api ($api) with a pubspec_overrides.yaml
# that says on its first line that these tools wrote it; removes that file when
# the sibling is gone. An overrides file of the checkout's own is left alone.
codelessly_write_api_override() {
  local overrides="$sdk/pubspec_overrides.yaml" want
  if [ ! -f "$overrides" ] || head -1 "$overrides" | grep -q "^$codelessly_override_marker"; then
    if [ -n "$api" ]; then
      want="$(printf '%s: codelessly_api from %s.\ndependency_overrides:\n  codelessly_api:\n    path: %s\n' "$codelessly_override_marker" "$api" "$api")"
      if [ "$(cat "$overrides" 2>/dev/null)" != "$want" ]; then
        printf '%s\n' "$want" > "$overrides"
        echo "Using codelessly_api from $api (written to pubspec_overrides.yaml)." >&2
      fi
    elif [ -f "$overrides" ]; then
      rm -f "$overrides"
    fi
  fi
}

# codelessly_pub_get
# Runs flutter pub get in the SDK when its package config is missing or older
# than the pubspec, the overrides file or the sibling API's pubspec.
codelessly_pub_get() {
  local config="$sdk/.dart_tool/package_config.json" stale=0 f log
  [ -f "$config" ] || stale=1
  for f in "$sdk/pubspec.yaml" "$sdk/pubspec_overrides.yaml" "${api:+$api/pubspec.yaml}"; do
    [ -n "$f" ] && [ -f "$f" ] && [ "$f" -nt "$config" ] && stale=1
  done
  [ $stale = 1 ] || return 0
  echo "Resolving the SDK's dependencies (flutter pub get)..." >&2
  log="$(mktemp)"
  if ! (cd "$sdk" && "$flutter_bin" pub get --no-example > "$log" 2>&1); then
    echo "flutter pub get failed:" >&2
    tail -30 "$log" >&2
    rm -f "$log"
    return 2
  fi
  rm -f "$log"
}

# codelessly_version_line
# "codelessly_sdk <version> @ <commit> on <branch> at <path>, codelessly_api ..."
codelessly_version_line() {
  local used api_desc
  used="$(codelessly_api_in_use)"
  if [ -n "$used" ] && [ -f "$used/pubspec.yaml" ]; then
    api_desc="codelessly_api $(_codelessly_version_of "$used")$(_codelessly_commit_of "$used") from $used"
    [ -f "$used/docs/reference/STARTER.md" ] || api_desc="$api_desc (no docs/reference here: check out its master branch)"
  else
    api_desc="codelessly_api published ($(sed -n '/^  codelessly_api:/,/version:/s/^ *version: *//p' "$sdk/pubspec.lock" 2>/dev/null | tr -d '"' | head -1))"
  fi
  printf 'codelessly_sdk %s%s at %s, %s' "$(_codelessly_version_of "$sdk")" "$(_codelessly_commit_of "$sdk")" "$sdk" "$api_desc"
}

_codelessly_version_of() { sed -n 's/^version: *//p' "$1/pubspec.yaml" 2>/dev/null | head -1; }
_codelessly_commit_of() {
  local c
  c="$(git -C "$1" rev-parse --short HEAD 2>/dev/null)" || return 0
  printf ' @ %s%s' "$c" "$(git -C "$1" symbolic-ref -q --short HEAD 2>/dev/null | sed 's/^/ on /')"
}

# codelessly_take_lock
# One flutter test harness at a time per SDK checkout: flutter test rewrites
# the checkout's build/ as it starts. Waits for a run already going.
codelessly_take_lock() {
  mkdir -p "$sdk/build"
  local lock="$sdk/build/.render.lock" owner waited=0
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$lock"
    if ! flock -n 9; then
      echo "Another render run is using this SDK checkout; waiting for it to finish." >&2
      flock 9
    fi
  else
    # No flock (macOS): a lock directory, taken over when its owner is gone.
    until mkdir "$lock.d" 2>/dev/null; do
      owner="$(cat "$lock.d/pid" 2>/dev/null || true)"
      if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then rm -rf "$lock.d"; continue; fi
      [ $waited = 0 ] && echo "Another render run is using this SDK checkout; waiting for it to finish." >&2
      waited=1
      sleep 1
    done
    echo $$ > "$lock.d/pid"
    codelessly_lock_dir="$lock.d"
  fi
}

# codelessly_release_lock: frees a lock directory (flock's is freed on exit).
codelessly_release_lock() { [ -n "${codelessly_lock_dir:-}" ] && rm -rf "$codelessly_lock_dir"; return 0; }

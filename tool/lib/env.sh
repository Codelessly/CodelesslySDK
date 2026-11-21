# Shared by the SDK's command-line tools (tool/codelessly, tool/render/render.sh,
# tool/notation/notation.sh, tool/stream/replay.sh): find Flutter, use a sibling
# codelessly_api checkout, resolve dependencies when stale. Source it with the
# SDK's root in $sdk:
#
#   sdk="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
#   . "$sdk/tool/lib/env.sh"
#
# Every function sets globals (flutter_bin, dart_bin, api, api_used, overrides)
# and returns non-zero after printing what to do; callers exit 2 then.
#
# These run before every command, so they start no process where bash can do
# the work itself (reading a file's lines, a folder's path by `cd`): on Windows
# each `$(...)`, `grep`, `sed` or `head` is 30 ms or more, and a dozen of them
# were a second of every command.

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
  elif _codelessly_which flutter; then
    flutter_bin="$REPLY"
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
  dart_bin="${flutter_bin%/*}/dart"
  [ "$dart_bin" != "$flutter_bin/dart" ] && [ -x "$dart_bin" ] || dart_bin="$(command -v dart 2>/dev/null || echo dart)"
}

# _codelessly_which <command>
# Sets REPLY to the command's file on the PATH (as `command -v` finds it) and
# returns 0, or returns 1 when the PATH has none.
_codelessly_which() {
  local d IFS=:
  REPLY=""
  for d in $PATH; do
    d="${d:-.}"
    if [ -f "$d/$1" ] && [ -x "$d/$1" ]; then REPLY="$d/$1"; return 0; fi
  done
  return 1
}

# _codelessly_abs <folder>
# Sets REPLY to the folder's path as `cd` there and `pwd` say it ("" when it
# cannot be entered), by going there and back in this shell.
_codelessly_abs() {
  local here="$PWD"
  REPLY=""
  if CDPATH= cd -- "$1" 2>/dev/null; then
    REPLY="$PWD"
    CDPATH= cd -- "$here" 2>/dev/null || true
  fi
  return 0
}

# _codelessly_own_overrides <pubspec_overrides.yaml>
# Whether the file is there and is the checkout's own (its first line is not
# these tools' marker).
_codelessly_own_overrides() {
  local first=""
  [ -f "$1" ] || return 1
  IFS= read -r first < "$1" || true
  case "$first" in "$codelessly_override_marker"*) return 1 ;; esac
  return 0
}

# codelessly_find_api
# Sets api to a sibling codelessly_api checkout ($CODELESSLY_API, ../CodelesslyAPI
# or ../codelessly_api beside the SDK), or "" when there is none.
codelessly_find_api() {
  api=""
  local d line
  for d in "${CODELESSLY_API:-}" "$sdk/../CodelesslyAPI" "$sdk/../codelessly_api"; do
    if [ -n "$d" ] && [ -f "$d/pubspec.yaml" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          "name: codelessly_api"*)
            _codelessly_abs "$d"
            api="$REPLY"
            return 0
            ;;
        esac
      done < "$d/pubspec.yaml"
    fi
  done
  return 0
}

# codelessly_set_api_used
# Sets api_used to the codelessly_api folder the SDK compiles against: the path
# an overrides file of the checkout's own names, else the sibling ($api), else "".
codelessly_set_api_used() {
  local overrides="$sdk/pubspec_overrides.yaml" line in=0 here="$PWD"
  api_used="$api"
  _codelessly_own_overrides "$overrides" || return 0
  # The first `path:` under `codelessly_api:`.
  api_used=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [ $in = 0 ]; then
      case "$line" in *codelessly_api:*) in=1 ;; esac
    elif [[ "$line" =~ ^\ *path:\ *(.*)$ ]]; then
      api_used="${BASH_REMATCH[1]}"
      break
    else
      case "$line" in *path:*) in=0 ;; esac
    fi
  done < "$overrides"
  case "$api_used" in
    ''|/*) ;;
    *)
      # Relative to the SDK (or a Windows path, which `cd` takes from anywhere).
      if CDPATH= cd -- "$sdk" 2>/dev/null && CDPATH= cd -- "$api_used" 2>/dev/null; then api_used="$PWD"; else api_used=""; fi
      CDPATH= cd -- "$here" 2>/dev/null || true
      ;;
  esac
  return 0
}

# codelessly_api_in_use
# Prints what codelessly_set_api_used sets.
codelessly_api_in_use() {
  codelessly_set_api_used
  printf '%s' "$api_used"
}

# _codelessly_override_path
# Sets REPLY to the path the override names codelessly_api by: `../<folder>`
# for the checkout beside the SDK, which pub reads on every system; else the
# folder as Dart reads it (under Git Bash on Windows `C:/Users/...`: written
# as bash says it, `/c/Users/...`, pub get could not find the package).
_codelessly_override_path() {
  local beside name
  _codelessly_abs "$sdk/.."
  beside="$REPLY"
  if [ -n "$beside" ] && [ "$beside" != "/" ]; then
    case "$api" in
      "$beside"/*)
        name="${api#"$beside"/}"
        case "$name" in
          */*) ;;
          *) REPLY="../$name"; return 0 ;;
        esac
        ;;
    esac
  fi
  REPLY="$api"
  if command -v cygpath >/dev/null 2>&1; then REPLY="$(cygpath -m "$api")"; fi
  return 0
}

# codelessly_write_api_override
# Points the SDK at the sibling codelessly_api ($api) with a pubspec_overrides.yaml
# that says on its first line that these tools wrote it; removes that file when
# the sibling is gone. An overrides file of the checkout's own is left alone.
codelessly_write_api_override() {
  local overrides="$sdk/pubspec_overrides.yaml" want have=""
  if [ ! -f "$overrides" ] || ! _codelessly_own_overrides "$overrides"; then
    if [ -n "$api" ]; then
      _codelessly_override_path
      printf -v want '%s: codelessly_api from %s.\ndependency_overrides:\n  codelessly_api:\n    path: %s\n' "$codelessly_override_marker" "$api" "$REPLY"
      if [ -f "$overrides" ]; then IFS= read -r -d '' have < "$overrides" || true; fi
      if [ "$have" != "$want" ]; then
        printf '%s' "$want" > "$overrides"
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
  local api_desc sdk_version sdk_commit
  codelessly_set_api_used
  if [ -n "$api_used" ] && [ -f "$api_used/pubspec.yaml" ]; then
    _codelessly_version_of "$api_used"
    api_desc="codelessly_api $REPLY"
    _codelessly_commit_of "$api_used"
    api_desc="$api_desc$REPLY from $api_used"
    [ -f "$api_used/docs/reference/STARTER.md" ] || api_desc="$api_desc (no docs/reference here: check out its master branch)"
  else
    api_desc="codelessly_api published ($(sed -n '/^  codelessly_api:/,/version:/s/^ *version: *//p' "$sdk/pubspec.lock" 2>/dev/null | tr -d '"' | head -1))"
  fi
  _codelessly_version_of "$sdk"
  sdk_version="$REPLY"
  _codelessly_commit_of "$sdk"
  sdk_commit="$REPLY"
  printf 'codelessly_sdk %s%s at %s, %s' "$sdk_version" "$sdk_commit" "$sdk" "$api_desc"
}

# _codelessly_version_of <package folder>: sets REPLY to its pubspec's version.
_codelessly_version_of() {
  local line
  REPLY=""
  [ -f "$1/pubspec.yaml" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      version:*)
        line="${line%$'\r'}"
        line="${line#version:}"
        REPLY="${line#"${line%%[! ]*}"}"
        return 0
        ;;
    esac
  done < "$1/pubspec.yaml"
  return 0
}

# _codelessly_commit_of <checkout>: sets REPLY to " @ <commit> on <branch>"
# (no " on ..." with no branch checked out; "" outside a git checkout).
_codelessly_commit_of() {
  local c="" b=""
  REPLY=""
  { IFS= read -r c; IFS= read -r b; } < <(git -C "$1" rev-parse --short HEAD 2>/dev/null && git -C "$1" symbolic-ref -q --short HEAD 2>/dev/null) || true
  c="${c%$'\r'}"
  b="${b%$'\r'}"
  [ -n "$c" ] || return 0
  REPLY=" @ $c${b:+ on $b}"
  return 0
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

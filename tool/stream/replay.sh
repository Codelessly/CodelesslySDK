#!/usr/bin/env bash
# Replay a recorded ui_apply stream headless and make it visible and measured.
# See tool/stream/README.md.
#   tool/stream/replay.sh <stream.jsonl> --out <dir> [--sizes 390x844,1440x900] [--fonts dir]...
#       [--frame-ms 100 | --frames 180] [--no-video]
# Writes <out>/<size>/{video.mp4, contact.png, metrics.json} and prints the metrics.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdk="$(cd "$here/../.." && pwd)"
[ $# -ge 1 ] || { echo "usage: replay.sh <stream.jsonl> --out <dir> [--sizes WxH,...] [--fonts dir] [--frame-ms n] [--frames n] [--no-video]" >&2; exit 2; }
stream="$1"; shift
case "$stream" in /*) ;; *) stream="$PWD/$stream" ;; esac
out=""; video=1; args=("$stream"); fonts=0
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="$2"; case "$out" in /*) ;; *) out="$PWD/$out" ;; esac; args+=(--out "$out"); shift 2 ;;
    --fonts) f="$2"; case "$f" in /*) ;; *) f="$PWD/$f" ;; esac; args+=(--fonts "$f"); fonts=1; shift 2 ;;
    --rate) echo "--rate: rates are baked into the stream files; make them with make_streams.dart --rates" >&2; exit 2 ;;
    --no-video) video=0; shift ;;
    --*) args+=("$1" "$2"); shift 2 ;;
    *) echo "unexpected argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$out" ] || { echo "--out <dir> is required" >&2; exit 2; }
# Default fonts: the reference apps' font files next to the SDK, when present.
if [ $fonts = 0 ] && [ -d "$sdk/../references" ]; then args+=(--fonts "$sdk/../references"); fi
mkdir -p "$out"
flutter_bin="${FLUTTER:-$(command -v flutter || echo /opt/flutter/bin/flutter)}"
work="$(mktemp -d "$out/.replay.XXXXXX")"
trap 'rm -rf "$work"' EXIT
printf '%s\n' "${args[@]}" > "$work/args"
( cd "$sdk" && CODELESSLY_REPLAY_ARGS="$work/args" "$flutter_bin" test --no-pub tool/stream/replay_harness.dart > "$work/flutter.log" 2>&1 )
if [ ! -f "$work/args.report" ]; then
  echo "The replay harness did not finish. Its output:" >&2
  grep -v "Woah\|superuser\|^  /\|📎" "$work/flutter.log" | tail -60 >&2
  exit 2
fi
if [ $video = 1 ]; then
  for d in "$out"/*/; do
    [ -f "$d/frames.json" ] && python3 "$here/compose.py" "$d" || exit 2
  done
fi
cat "$work/args.report"

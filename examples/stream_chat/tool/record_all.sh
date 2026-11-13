#!/usr/bin/env bash
# The live matrix: records real generations with tool/record.dart, replays
# each into a video, a contact sheet and metrics (tool/stream/replay.sh,
# including the scripted "works when used" interaction for apps), and
# writes ONE summary table (Markdown + JSON).
#
#   ANTHROPIC_API_KEY=... examples/stream_chat/tool/record_all.sh [--repeats 2] [--app-repeats 1]
#       [--only cards|pages|apps] [--date YYYY-MM-DD] [--no-replay] [--dry-run]
#
# Cells (each repeated --repeats times; apps --app-repeats times):
#   cards  flights, weather x claude-haiku-5-5, claude-sonnet-5-5, claude-opus-5-5 x --prompt compact, full;
#          each with its follow-up edit
#   pages  restaurant_menu, saas_pricing x claude-haiku-5-5, claude-sonnet-5-5, compact
#   apps   form_builder, sudoku, basketball, kanban, habits, memory x claude-sonnet-5-5, claude-opus-5-5, compact,
#          scripts on; claude-haiku-5-5 once each; sudoku and basketball also with scripts off (sonnet)
# Recordings: tool/stream/streams/live/<date>/; replays: tool/stream/out/live/<date>/; the table:
# tool/stream/out/live/<date>/summary.md and summary.json.
#
# The key is read only from ANTHROPIC_API_KEY, by record.dart; this script
# never prints it, and the recordings hold no request headers.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk="$(cd "$here/../.." && pwd)"
repeats=2; app_repeats=1; only=""; date="$(date +%Y-%m-%d)"; replay=1; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repeats) repeats="$2"; shift 2 ;;
    --app-repeats) app_repeats="$2"; shift 2 ;;
    --only) only="$2"; shift 2 ;;
    --date) date="$2"; shift 2 ;;
    --no-replay) replay=0; shift ;;
    --dry-run) dry=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [ $dry = 0 ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "ANTHROPIC_API_KEY is not set. This script makes real requests; run it as" >&2
  echo "  ANTHROPIC_API_KEY=<your key> $0" >&2
  exit 2
fi
streams="$sdk/tool/stream/streams/live/$date"
outs="$sdk/tool/stream/out/live/$date"
mkdir -p "$streams" "$outs"
flutter_bin="${FLUTTER:-$(command -v flutter || echo /opt/flutter/bin/flutter)}"
dart_bin="$(dirname "$flutter_bin")/dart"

# The example builds against the sibling codelessly_api, as checked out.
"$here/tool/use_local_api.sh" > /dev/null
(cd "$here" && "$flutter_bin" pub get > /dev/null)
# The replay runs generated scripts in QuickJS (built once for this machine).
[ -f "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.so" ] || [ -f "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.dylib" ] \
  || (cd "$sdk" && "$flutter_bin" pub get > /dev/null && tool/build_quickjs.sh > /dev/null) || echo "QuickJS could not be built: scripts will not run in the replays" >&2

cells=()
add() { cells+=("$*"); }
if [ -z "$only" ] || [ "$only" = cards ]; then
  for ui in flights weather; do for m in claude-haiku-5-5 claude-sonnet-5-5 claude-opus-5-5; do for p in compact full; do
    for r in $(seq 1 "$repeats"); do add "$ui $m $p on $r --followup"; done
  done; done; done
fi
if [ -z "$only" ] || [ "$only" = pages ]; then
  for ui in restaurant_menu saas_pricing; do for m in claude-haiku-5-5 claude-sonnet-5-5; do
    for r in $(seq 1 "$repeats"); do add "$ui $m compact on $r"; done
  done; done
fi
if [ -z "$only" ] || [ "$only" = apps ]; then
  for ui in form_builder sudoku basketball kanban habits memory; do
    for m in claude-sonnet-5-5 claude-opus-5-5; do for r in $(seq 1 "$app_repeats"); do add "$ui $m compact on $r"; done; done
    add "$ui claude-haiku-5-5 compact on 1"
  done
  for ui in sudoku basketball; do add "$ui claude-sonnet-5-5 compact off 1"; done
fi

echo "${#cells[@]} cells -> $streams"
for cell in "${cells[@]}"; do
  set -- $cell
  ui=$1; model=$2; prompt=$3; scripts=$4; rep=$5; shift 5
  suffix=""; if [ "$scripts" = off ]; then suffix=".scripts-off"; fi
  name="$ui@$model.$prompt$suffix.r$rep"
  out="$streams/$name.jsonl"
  echo "== $name"
  if [ $dry = 1 ]; then
    echo "   dart run tool/record.dart --ui $ui --model $model --prompt $prompt --scripts $scripts --out $out $*"
    continue
  fi
  if [ ! -f "$out" ]; then
    (cd "$here" && "$dart_bin" run tool/record.dart --ui "$ui" --model "$model" --prompt "$prompt" --scripts "$scripts" --out "$out" "$@" \
      > "$streams/$name.log" 2>&1) || echo "   record failed (see $name.log)"
  fi
  if [ $replay = 1 ]; then
    for s in "$streams/$name".jsonl "$streams/$name".retry*.jsonl "$streams/$name".followup.jsonl; do
      [ -f "$s" ] || continue
      base="$(basename "$s" .jsonl)"
      [ -f "$outs/$base/390x844/metrics.json" ] && continue
      "$sdk/tool/stream/replay.sh" "$s" --out "$outs/$base" --sizes 390x844 > /dev/null 2>&1 || echo "   replay failed: $base"
    done
  fi
done
[ $dry = 1 ] && exit 0
python3 "$sdk/tool/stream/live_summary.py" "$streams" "$outs"
echo "Summary: $outs/summary.md"

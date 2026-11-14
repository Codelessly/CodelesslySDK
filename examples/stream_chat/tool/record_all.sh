#!/usr/bin/env bash
# The live matrix: records real generations with tool/record.dart, replays
# each into a video, a contact sheet and metrics (tool/stream/replay.sh,
# including the scripted "works when used" interaction for apps), and
# writes ONE summary table (Markdown + JSON).
#
#   ANTHROPIC_API_KEY=... examples/stream_chat/tool/record_all.sh [--repeats 2] [--app-repeats 1]
#       [--only cards|pages|apps|usecases|ssui] [--design-system <id>] [--date YYYY-MM-DD] [--no-replay] [--dry-run]
#
# Cells (each repeated --repeats times; apps --app-repeats times):
#   cards  flights, weather x claude-haiku-5-5, claude-sonnet-5-5, claude-opus-5-5 x --prompt compact, full;
#          each with its follow-up edit
#   pages  restaurant_menu, saas_pricing x claude-haiku-5-5, claude-sonnet-5-5, compact
#   apps   form_builder, sudoku, basketball, kanban, habits, memory x claude-sonnet-5-5, claude-opus-5-5, compact,
#          scripts on; claude-haiku-5-5 once each; sudoku and basketball also with scripts off (sonnet)
#   usecases  the fifteen inline use cases (dashboard ... image_gallery) x claude-haiku-5-5, claude-sonnet-5-5, compact
#   ssui   with the SSUI design system: the fifteen use cases, flights and weather x claude-haiku-5-5, claude-sonnet-5-5,
#          compact, once, each with its follow-up
# --design-system <id> (an id in the SDK's design_systems/, or a folder) makes every cell use that design system
# (record.dart --design-system); cells with --prompt full are skipped, as the full prompt has no design system. A cell
# with a design system is named <ui>@<model>.<prompt>.<id>.r<n>; its replay renders with it (the recording's meta).
# Recordings: tool/stream/streams/live/<date>/; replays: tool/stream/out/live/<date>/; the table:
# tool/stream/out/live/<date>/summary.md and summary.json.
#
# The key is read only from ANTHROPIC_API_KEY, by record.dart; this script
# never prints it, and the recordings hold no request headers.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk="$(cd "$here/../.." && pwd)"
repeats=2; app_repeats=1; only=""; date="$(date +%Y-%m-%d)"; replay=1; dry=0; design_system=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repeats) repeats="$2"; shift 2 ;;
    --app-repeats) app_repeats="$2"; shift 2 ;;
    --only) only="$2"; shift 2 ;;
    --design-system) design_system="$2"; shift 2 ;;
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
[ $dry = 1 ] || mkdir -p "$streams" "$outs"
flutter_bin="${FLUTTER:-$(command -v flutter || echo /opt/flutter/bin/flutter)}"
dart_bin="$(dirname "$flutter_bin")/dart"

if [ $dry = 0 ]; then
  # The example builds against the sibling codelessly_api, as checked out.
  "$here/tool/use_local_api.sh" > /dev/null
  (cd "$here" && "$flutter_bin" pub get > /dev/null)
  # The replay runs generated scripts in QuickJS (built once for this machine).
  [ -f "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.so" ] || [ -f "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.dylib" ] \
    || (cd "$sdk" && "$flutter_bin" pub get --no-example > /dev/null && tool/build_quickjs.sh > /dev/null) \
    || echo "QuickJS could not be built: scripts will not run in the replays" >&2
fi

cells=()
# A cell: ui model prompt scripts repeat design-system (- for none) [record.dart options...]
ds_all="${design_system:--}"
add() { cells+=("$1 $2 $3 $4 $5 $ds_all ${*:6}"); }
add_ds() { local ds="$1"; shift; cells+=("$1 $2 $3 $4 $5 $ds ${*:6}"); }
if [ -z "$only" ] || [ "$only" = cards ]; then
  for ui in flights weather; do for m in claude-haiku-5-5 claude-sonnet-5-5 claude-opus-5-5; do for p in compact full; do
    for r in $(seq 1 "$repeats"); do add $ui $m $p on $r --followup; done
  done; done; done
fi
if [ -z "$only" ] || [ "$only" = pages ]; then
  for ui in restaurant_menu saas_pricing; do for m in claude-haiku-5-5 claude-sonnet-5-5; do
    for r in $(seq 1 "$repeats"); do add $ui $m compact on $r; done
  done; done
fi
if [ -z "$only" ] || [ "$only" = apps ]; then
  for ui in form_builder sudoku basketball kanban habits memory; do
    for m in claude-sonnet-5-5 claude-opus-5-5; do for r in $(seq 1 "$app_repeats"); do add $ui $m compact on $r; done; done
    add $ui claude-haiku-5-5 compact on 1
  done
  for ui in sudoku basketball; do add $ui claude-sonnet-5-5 compact off 1; done
fi

usecases="dashboard order_summary approval question_flow reservation checkout map_list carousel itinerary comparison
  data_table message_draft plan_progress code_diff image_gallery"
if [ -z "$only" ] || [ "$only" = usecases ]; then
  for ui in $usecases; do
    for m in claude-haiku-5-5 claude-sonnet-5-5; do add $ui $m compact on 1 --followup; done
  done
fi
if [ "$only" = ssui ]; then
  for ui in $usecases flights weather; do
    for m in claude-haiku-5-5 claude-sonnet-5-5; do add_ds "${design_system:-ssui}" $ui $m compact on 1 --followup; done
  done
fi

# The full prompt is the base's file form, with no design system.
if [ "$ds_all" != - ]; then
  kept=()
  for cell in "${cells[@]}"; do set -- $cell; [ "$3" = full ] || kept+=("$cell"); done
  skipped=$(( ${#cells[@]} - ${#kept[@]} ))
  [ $skipped = 0 ] || echo "$skipped cells with --prompt full skipped: the full prompt has no design system"
  cells=("${kept[@]}")
fi

echo "${#cells[@]} cells -> $streams"
for cell in "${cells[@]}"; do
  set -- $cell
  ui=$1; model=$2; prompt=$3; scripts=$4; rep=$5; ds=$6; shift 6
  suffix=""; if [ "$scripts" = off ]; then suffix=".scripts-off"; fi
  ds_args=()
  if [ "$ds" != - ]; then suffix="$suffix.$(basename "$ds")"; ds_args=(--design-system "$ds"); fi
  name="$ui@$model.$prompt$suffix.r$rep"
  out="$streams/$name.jsonl"
  echo "== $name"
  if [ $dry = 1 ]; then
    echo "   dart run tool/record.dart --ui $ui --model $model --prompt $prompt --scripts $scripts ${ds_args[*]} --out $out $*"
    continue
  fi
  if [ ! -f "$out" ]; then
    (cd "$here" && "$dart_bin" run tool/record.dart --ui "$ui" --model "$model" --prompt "$prompt" --scripts "$scripts" "${ds_args[@]}" \
      --out "$out" "$@" > "$streams/$name.log" 2>&1) || echo "   record failed (see $name.log)"
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

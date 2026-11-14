#!/usr/bin/env bash
# The third arm of the head to head: the same seventeen card briefs, written
# in the notation with a design system's blocks (and only those blocks named
# to the model).
#
#   ANTHROPIC_API_KEY=... examples/stream_chat/tool/record_blocks_arm.sh \
#       [--design-system cards] [--tag 2026-11-14-blocks-1] [--models claude-haiku-5-5,claude-sonnet-5-5] [--only flights,weather]
#
# Recordings go to tool/stream/streams/live/<tag>/<brief>@<model>.notation.*,
# beside the other arms' (tool/stream/arms_table.py reads the three).
# The blocks listed are the design system's BLOCKS.txt (one comma-separated
# line) when it has one, else all its components.
# The key is read only from ANTHROPIC_API_KEY by the recorder and never printed.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk="$(cd "$here/../.." && pwd)"
ds="cards"; tag="$(date +%Y-%m-%d)-blocks-1"; models="claude-haiku-5-5,claude-sonnet-5-5"; only=""
briefs="flights weather dashboard order_summary approval question_flow reservation checkout map_list carousel itinerary comparison data_table message_draft plan_progress code_diff image_gallery"
while [ $# -gt 0 ]; do
  case "$1" in
    --design-system) ds="$2"; shift 2 ;;
    --tag) tag="$2"; shift 2 ;;
    --models) models="$2"; shift 2 ;;
    --only) only="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "ANTHROPIC_API_KEY is not set." >&2; exit 2; }
[ -d "$ds" ] || ds="$sdk/design_systems/$ds"
[ -f "$ds/design_system.json" ] || { echo "No design_system.json in $ds" >&2; exit 2; }
out="$sdk/tool/stream/streams/live/$tag"; mkdir -p "$out"
components=(); [ -f "$ds/BLOCKS.txt" ] && components=(--components "$(tr -d '\n ' < "$ds/BLOCKS.txt")")
[ -n "$only" ] && briefs="${only//,/ }"
dart_bin="$(dirname "${FLUTTER:-$(command -v flutter || echo /opt/flutter/bin/flutter)}")/dart"
"$here/tool/use_local_api.sh" > /dev/null
cd "$here"
for model in ${models//,/ }; do
  for ui in $briefs; do
    if "$dart_bin" run tool/record_notation.dart --ui "$ui" --model "$model" --design-system "$ds" "${components[@]}" \
        --out "$out/$ui@$model.notation.jsonl" > "$out/$ui@$model.log" 2>&1; then echo "ok   $ui@$model"; else echo "FAIL $ui@$model (see $out/$ui@$model.log)"; fi
  done
done

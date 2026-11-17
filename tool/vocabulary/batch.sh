#!/bin/bash
# The vocabulary loop's two mechanical steps (JOURNAL.md says how the loop runs). From the SDK folder:
#
#   tool/vocabulary/batch.sh prepare <batch> <briefs file> <awk condition>   e.g. prepare b08 tool/vocabulary/briefs-2.txt 'NR>60'
#       writes corpus/<batch>/prompt.txt (the open prompt as it is today) and one briefs/<slug>.txt per chosen
#       line, and prints the slugs as a JSON list for the writers.
#   tool/vocabulary/batch.sh count <out folder> [<earlier vocabulary.json>]
#       expands every answer of every batch with today's parser, aliases and definitions, and prints the size.
set -e
py="${PYTHON:-/c/Users/searc/AppData/Local/Programs/Python/Python314/python.exe}"
case "$1" in
  prepare)
    b="tool/vocabulary/corpus/$2"; mkdir -p "$b/answers" "$b/briefs"
    tool/notation/notation.sh prompt --open --width 1280 > "$b/prompt.txt" 2>/dev/null
    grep -v '^#' "$3" | awk "$4" | while IFS='|' read -r slug brief; do
      slug=$(echo $slug | tr -d ' ')
      printf 'App: %s\n\nWrite two to four screens of this app, each under a line `### <screen name>`, starting with App (an app window) or Page (a page that scrolls). Overlays (dialogs, sheets, menus) go after the screen that opens them. Realistic content. Every interaction in the brief is written, not described. Output only the notation.\n' "$(echo "$brief" | sed 's/^ //')" > "$b/briefs/$slug.txt"
    done
    ls "$b/briefs" | sed 's/.txt$//' | awk 'BEGIN{printf "["} {printf "%s\"%s\"", (NR>1?",":""), $0} END{print "]"}'
    ;;
  count)
    out="$2"; rm -rf "$out"
    tool/notation/notation.sh vocabulary $(ls -d tool/vocabulary/corpus/*/answers) --design-system design_systems/cards --out "$out" 2>&1 | grep "files," || true
    PYTHONUTF8=1 "$py" tool/vocabulary/count.py "$out/vocabulary.json" ${3:+"$3"} | head -14
    ;;
  *) echo "usage: tool/vocabulary/batch.sh prepare|count … (see the head of this file)" >&2; exit 2 ;;
esac

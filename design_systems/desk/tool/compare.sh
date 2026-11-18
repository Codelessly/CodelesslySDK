#!/bin/bash
# The side-by-side sheets of design_systems/desk/examples/compare: for each reference screen, at each size, the
# native web build of the same brief (its branch's picture, cropped to the native half of a compare picture), the
# second-cycle DSL build (experiments/dsl-api-9b) and Desk's, in that order.
#
#   bash design_systems/desk/tool/compare.sh <editor worktree with the experiments and the uisdk8 branches>
#
# The inputs are copied to examples/compare/<screen>/ (1-native-web, 2-dsl-second-cycle, 3-desk), the sheets
# written beside them (<screen>@<size>.sheet.png).
set -e
desk="$(cd "$(dirname "$0")/.." && pwd)"
sdk="$(cd "$desk/../.." && pwd)"
editor="${1:?the editor worktree}"
exp="$editor/experiments/dsl-api-9b"
crop() { python "$desk/tool/crop_png.py" "$@" >/dev/null; }
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
tmp="$(mktemp -d)"
native() { git -C "$editor" show "origin/uisdk8/$1:experiments/ui-sdk-8/$1/$2" > "$tmp/n.png"; }

# screen, size, native's source and crop box, the DSL build's picture, Desk's picture
row() {
  local screen=$1 size=$2 slug=$3 src=$4 box=$5 dsl=$6 mine=$7
  local out="$desk/examples/compare/$screen"
  mkdir -p "$out"
  native "$slug" "$src"
  if [ "$box" = whole ]; then cp "$tmp/n.png" "$out/$size-1-native-web.png"; else crop "$tmp/n.png" "$out/$size-1-native-web.png" $box; fi
  local h=${size#*x}
  crop "$exp/$dsl" "$out/$size-2-dsl-second-cycle.png" 0 0 ${size%x*} "$h"
  cp "$desk/examples/$mine" "$out/$size-3-desk.png"
}

row mail 1440x900 mail-client out/mailbox@1440x900.png whole mail-client/out/mailbox@1440x900.png mail/out/mailbox@1440x900-light.png
row mail 834x1112 mail-client out/mailbox@834x1112.png whole mail-client/out/mailbox@834x1112.png mail/out/mailbox@834x1112-light.png
row mail 390x844 mail-client out/mailbox@390x844.png whole mail-client/out/mailbox@390x844.png mail/out/mailbox@390x844-light.png
row admin 1440x900 admin-console compare/members@1440x900.png "0 40 1447 940" admin-console/out/members@1440x900.png admin/out/members@1440x900-light.png
row admin 834x1112 admin-console compare/members@834x1112.png "0 40 841 1152" admin-console/out/members@834x1112.png admin/out/members@834x1112-light.png
row admin 390x844 admin-console compare/members@390x844.png "0 40 397 884" admin-console/out/members@390x844.png admin/out/members@390x844-light.png
row kanban 1440x900 kanban-board compare/board@1440x900.png "4 55 1444 955" kanban-board/out/board@1440x900.png kanban/out/board@1440x900-light.png
row kanban 834x1112 kanban-board compare/board@834x1112.png "4 55 838 1167" kanban-board/out/board@834x1112.png kanban/out/board@834x1112-light.png
row kanban 390x844 kanban-board compare/board@390x844.png "4 55 394 899" kanban-board/out/board@390x844.png kanban/out/board@390x844-light.png
row kanban-dialog 1440x900 kanban-board compare/card-dialog@1440x900.png "4 55 1444 955" kanban-board/out/board@1440x900-dialog.png kanban/out/board@1440x900-light-dialog.png
row kanban-dialog 390x844 kanban-board compare/card-dialog@390x844.png "4 55 394 899" kanban-board/out/board@390x844-dialog.png kanban/out/board@390x844-light-dialog.png

for screen in mail admin kanban kanban-dialog; do
  for size in 1440x900 834x1112 390x844; do
    d="$desk/examples/compare/$screen"
    [ -f "$d/$size-3-desk.png" ] || continue
    h=$([ "$size" = 1440x900 ] && echo 560 || echo 720)
    bash "$sdk/tool/codelessly" sheet "$(win "$d/$size-1-native-web.png")" "$(win "$d/$size-2-dsl-second-cycle.png")" "$(win "$d/$size-3-desk.png")" \
      --columns 3 --height $h --title "$screen $size: native web build | DSL build, second cycle | Desk" --out "$(win "$d/$screen@$size.sheet.png")" >/dev/null
  done
done
rm -rf "$tmp"
ls "$desk"/examples/compare/*/*.sheet.png

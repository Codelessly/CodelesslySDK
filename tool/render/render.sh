#!/usr/bin/env bash
# Validate and render Codelessly layout documents. See tool/render/README.md.
#   tool/render/render.sh <document.json | dir> --out <dir> [--sizes 390x844,...] [--screen id]
#       [--full-page] [--fonts dir] [--theme light|dark|system] [--tap id] [--hover id] [--focus id] [--type id=text]
#       [--set name=json] [--scroll id=px] [--drag id=dx,dy] [--navigate screen?param=value] [--wait ms] [--now time]
#       [--label text] [--compare png|dir] [--compare-map screen=name] [--validate-only]
#       [--component Type [--props json] [--slots file]]
#       [--design-system folder]   (with one document: render it with that design system's blocks and theme)
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
want_ds=0
design_system=""
for a in "$@"; do
  if [ $want_ds = 1 ]; then
    case "$a" in /*) ;; *) a="$PWD/$a" ;; esac
    design_system="$a"
    want_ds=0
    continue
  fi
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
    --design-system) want_ds=1 ;;
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

# --design-system <folder> with one document: the document is rendered as a
# site of its own that uses that design system (its blocks and its theme),
# which is what a card expanded from the notation needs.
if [ -n "$design_system" ]; then
  doc=""
  for i in "${!args[@]}"; do
    case "${args[$i]}" in *.json) if [ -f "${args[$i]}" ]; then doc="$i"; break; fi ;; esac
  done
  if [ -z "$doc" ] || [ ! -f "$design_system/design_system.json" ]; then
    echo "--design-system <folder> goes with one document (.json) and a folder that holds design_system.json." >&2
    exit 2
  fi
  site="$out/.site"
  rm -rf "$site" && mkdir -p "$site"
  cp "${args[$doc]}" "$site/$(basename "${args[$doc]}")"
  # The manifest names the design system relative to itself.
  rel="$(realpath --relative-to="$site" "$design_system" 2>/dev/null || python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$design_system" "$site")"
  printf '{"schema": 3, "pages": ["%s"], "designSystem": "%s"}\n' "$(basename "${args[$doc]}")" "$rel" > "$site/site.json"
  args[$doc]="$site"
fi

# Flutter, codelessly_api from a sibling checkout, dependencies and the lock
# that makes runs on one checkout take turns: tool/lib/env.sh.
. "$sdk/tool/lib/env.sh"
codelessly_find_flutter "tool/render/render.sh <site> --out <dir>" || exit 2
codelessly_take_lock
codelessly_find_api
echo "Rendering with $(codelessly_version_line), Flutter $flutter_bin." >&2
codelessly_write_api_override
codelessly_pub_get || exit 2

work="$(mktemp -d "$out/.render.XXXXXX")"
trap 'rm -rf "$work"; codelessly_release_lock' EXIT
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

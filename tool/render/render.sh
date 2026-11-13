#!/usr/bin/env bash
# Validate and render Codelessly layout documents. See tool/render/README.md.
#   tool/render/render.sh <document.json | dir> --out <dir> [--sizes 390x844,...] [--screen id]
#       [--full-page] [--fonts dir] [--tap id] [--hover id] [--focus id] [--type id=text] [--set name=json]
#       [--scroll id=px] [--navigate screen] [--wait ms] [--label text] [--validate-only]
# Exit status: 0 no errors (warnings allowed), 1 errors, 2 bad arguments or a crash.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdk="$(cd "$here/../.." && pwd)"

# Paths are taken relative to where the command is run; make them absolute.
args=()
out=""
expect_path=0
for a in "$@"; do
  if [ $expect_path = 1 ]; then
    case "$a" in /*) ;; *) a="$PWD/$a" ;; esac
    expect_path=0
    args+=("$a")
    [ "${prev:-}" = "--out" ] && out="$a"
    prev=""
    continue
  fi
  case "$a" in
    --out|--fonts) expect_path=1; prev="$a"; args+=("$a") ;;
    --*) args+=("$a") ;;
    *)
      # A positional argument right after a value-taking option is that option's value.
      if [ ${#args[@]} -gt 0 ] && [[ "${args[-1]}" =~ ^--(sizes|screen|tap|hover|focus|type|set|scroll|navigate|wait|label)$ ]]; then
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
flutter_bin="${FLUTTER:-$(command -v flutter || echo /opt/flutter/bin/flutter)}"
work="$(mktemp -d "$out/.render.XXXXXX")"
trap 'rm -rf "$work"' EXIT
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

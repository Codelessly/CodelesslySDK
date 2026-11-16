#!/bin/bash
# The compact notation's tools, runnable from a fresh checkout:
#
#   tool/notation/notation.sh prompt [--design-system <folder>]
#   tool/notation/notation.sh expand <file.txt> [--design-system <folder>] [--id <canvas id>] [--out <file.json>]
#   tool/notation/notation.sh apply <document.json> <ops.json> [--design-system <folder>] [--out <file.json>]
#
# It finds Flutter's dart, makes the SDK use the codelessly_api checked out
# beside it (../CodelesslyAPI: the notation is newer than the published
# package), resolves dependencies when they are stale, and runs
# tool/notation/<command>.dart with the rest of the arguments.
set -e
sdk="$(cd "$(dirname "$0")/../.." && pwd)"
cmd="${1:-}"
case "$cmd" in
  prompt|expand|apply) shift ;;
  *) echo "usage: tool/notation/notation.sh prompt|expand|apply [arguments] (see the head of this file)" >&2; exit 2 ;;
esac

# Flutter's dart, codelessly_api from the checkout beside the SDK (the same
# pubspec_overrides.yaml render.sh writes) and dependencies: tool/lib/env.sh.
. "$sdk/tool/lib/env.sh"
codelessly_find_flutter "tool/notation/notation.sh $cmd ..." || exit 2
codelessly_find_api
codelessly_write_api_override
used="$(codelessly_api_in_use)"
if [ -z "$used" ] || [ ! -f "$used/lib/notation.dart" ]; then
  {
    echo "The notation needs codelessly_api from its master branch; this checkout would compile against ${used:-the published package}, which does not have it."
    echo "Check out CodelesslyAPI's master beside this repository (../CodelesslyAPI), or set CODELESSLY_API to its folder, and run this again."
    echo "If ../CodelesslyAPI is there but has no lib/notation.dart: git -C ../CodelesslyAPI fetch origin master && git -C ../CodelesslyAPI checkout master"
  } >&2
  exit 2
fi
codelessly_pub_get || exit 2
exec "$dart_bin" run "$sdk/tool/notation/$cmd.dart" "$@"

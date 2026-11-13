#!/usr/bin/env bash
# Points this example at the codelessly_api checkout the SDK is developed
# against (it resolves the hosted version otherwise, which may predate what
# the SDK uses): writes pubspec_overrides.yaml (gitignored) here.
#
#   tool/use_local_api.sh [path/to/CodelesslyAPI]
#
# The API checkout is, in order: the argument, $CODELESSLY_API, the path in
# the SDK's own pubspec_overrides.yaml, or ../CodelesslyAPI next to the SDK.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk="$(cd "$here/../.." && pwd)"
api="${1:-${CODELESSLY_API:-}}"
if [ -z "$api" ] && [ -f "$sdk/pubspec_overrides.yaml" ]; then
  rel="$(sed -n 's/^ *path: *//p' "$sdk/pubspec_overrides.yaml" | head -1)"
  if [ -n "$rel" ]; then case "$rel" in /*) api="$rel" ;; *) api="$sdk/$rel" ;; esac; fi
fi
[ -n "$api" ] || api="$sdk/../CodelesslyAPI"
if [ ! -f "$api/pubspec.yaml" ] || ! grep -q '^name: codelessly_api' "$api/pubspec.yaml"; then
  echo "No codelessly_api checkout at $api: pass its path, or set CODELESSLY_API." >&2
  exit 2
fi
api="$(cd "$api" && pwd)"
printf 'dependency_overrides:\n  codelessly_api:\n    path: %s\n' "$api" > "$here/pubspec_overrides.yaml"
echo "examples/stream_chat uses codelessly_api at $api"

#!/usr/bin/env bash
# The example's CI check: resolve against the sibling codelessly_api, then
# analyze and run its tests (no network: the live request is checked
# offline). Exits non-zero on any issue.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_bin="${FLUTTER:-$(command -v flutter || echo /opt/flutter/bin/flutter)}"
"$here/tool/use_local_api.sh" "$@"
cd "$here"
"$flutter_bin" pub get > /dev/null
"$flutter_bin" analyze --fatal-infos
"$flutter_bin" test

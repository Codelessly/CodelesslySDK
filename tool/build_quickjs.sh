#!/bin/bash
# Builds the codelessly_quickjs native library for this machine, for the
# SDK's tests on the Dart VM (flutter test). Apps get it from the
# codelessly_quickjs Flutter plugin instead.
#
# The plugin is a dev dependency (github.com/Codelessly/CodelesslyQuickJS);
# this finds it through pub and runs its own build script.
#
# Usage: tool/build_quickjs.sh  ->  .dart_tool/codelessly_quickjs/libcodelessly_quickjs.{so,dylib}
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(python3 - <<'PY'
import json, os
config = json.load(open('.dart_tool/package_config.json'))
for package in config['packages']:
    if package['name'] == 'codelessly_quickjs':
        uri = package['rootUri']
        path = uri[len('file://'):] if uri.startswith('file://') else os.path.join('.dart_tool', uri)
        print(os.path.normpath(path))
PY
)
if [ -z "$ROOT" ]; then
  echo "codelessly_quickjs isn't resolved: run flutter pub get." >&2
  exit 1
fi
bash "$ROOT/tool/build.sh" "$PWD/.dart_tool/codelessly_quickjs"

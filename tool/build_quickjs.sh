#!/bin/bash
# Builds the codelessly_quickjs native library for this machine, for the
# SDK's tests on the Dart VM (flutter test). Apps get it from the
# codelessly_quickjs Flutter plugin instead.
#
# Usage: tool/build_quickjs.sh  ->  .dart_tool/codelessly_quickjs/libcodelessly_quickjs.{so,dylib}
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=.dart_tool/codelessly_quickjs
mkdir -p "$OUT/build"
cmake -S codelessly_quickjs/src -B "$OUT/build" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$OUT/build" --parallel >/dev/null
for f in "$OUT/build"/libcodelessly_quickjs.so "$OUT/build"/libcodelessly_quickjs.dylib; do
  [ -f "$f" ] && cp "$f" "$OUT/"
done
ls "$OUT"/libcodelessly_quickjs.*

#!/usr/bin/env bash
# Regenerates the golden set for one widget group's v1 sample pages:
#
#   tool/update_samples.sh <group>
#
# test/samples/<group>/*.json  — v1 page documents (`{"document": {...}}`, the
#   editor's stored page format, with a `rootNode` listing the canvases), written
#   by hand to cover the group's widget types.
# → test/goldens/samples-<group>   SDK 8.x's rect for every node (rendered by
#   CodelesslyEditor/packages/codelessly_canvas/test/export_v1_goldens_test.dart)
# → test/fixtures/samples-<group>  the same pages migrated to v2
#   (CodelesslyAPI/v2/migrate).
#
# The `bindings` group is rendered at runtime instead (variables and
# conditions applied; tool/v1_runtime/export_v1_runtime_goldens_test.dart):
# its pages carry the layout's v1 `variables` and `conditions` next to the
# document.
#
# Env: EDITOR_DIR (default /home/user/CodelesslyEditor), API_DIR (default
# ../../CodelesslyAPI from v2/, i.e. the sibling checkout).
set -euo pipefail
group="$1"
v2="$(cd "$(dirname "$0")/.." && pwd)"
editor="${EDITOR_DIR:-/home/user/CodelesslyEditor}"
api="${API_DIR:-$v2/../../CodelesslyAPI}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/in" "$tmp/pages"
for f in "$v2/test/samples/$group"/*.json; do
  gzip -c "$f" > "$tmp/in/$(basename "$f" .json).json.gz"
done
rm -rf "$v2/test/goldens/samples-$group" "$v2/test/fixtures/samples-$group"
if [ "$group" = bindings ]; then
  # Runtime goldens: SDK 8.x with the pages' variables and conditions applied
  # (tool/v1_runtime), run from a throwaway package on the editor's SDK 8.x.
  pkg="$tmp/exporter"
  mkdir -p "$pkg/test"
  cp "$v2/tool/v1_runtime/export_v1_runtime_goldens_test.dart" "$pkg/test/"
  cat > "$pkg/pubspec.yaml" <<YAML
name: v1_runtime_exporter
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
  codelessly_api:
    path: $editor/CodelesslyAPI
  codelessly_sdk:
    path: $editor/CodelesslySDK
  codelessly_canvas:
    path: $editor/packages/codelessly_canvas
  provider: ^6.1.2
dev_dependencies:
  flutter_test:
    sdk: flutter
dependency_overrides:
  codelessly_api:
    path: $editor/CodelesslyAPI
YAML
  (cd "$pkg" && flutter pub get --offline >/dev/null && flutter test test/export_v1_runtime_goldens_test.dart \
    --dart-define=input="$tmp/in" \
    --dart-define=goldens="$v2/test/goldens/samples-$group" \
    --dart-define=pages="$tmp/pages" 2>&1 | grep -E "exported|failed|Error" || true)
else
(cd "$editor/packages/codelessly_canvas" && flutter test test/export_v1_goldens_test.dart \
  --dart-define=input="$tmp/in" \
  --dart-define=goldens="$v2/test/goldens/samples-$group" \
  --dart-define=pages="$tmp/pages" 2>&1 | grep -E "exported|failed|Error" || true)
fi
(cd "$api/v2/migrate" && dart run bin/migrate_pages.dart "$tmp/pages" "$v2/test/fixtures/samples-$group")

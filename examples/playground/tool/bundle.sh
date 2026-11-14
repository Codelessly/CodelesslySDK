#!/bin/bash
# Bundles the SDK's design systems into assets/design_systems/<id>.json.
set -e
cd "$(dirname "$0")/.."
for id in ssui paper harbor; do
  (cd ../stream_chat && dart run tool/design_system_bundle.dart ../../design_systems/$id ../playground/assets/design_systems/$id.json)
done

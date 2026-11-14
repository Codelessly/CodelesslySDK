#!/bin/bash
# Copies what the shell shows into its assets: the Skip design system as one file, its two extra token sets, the
# app's constants and the generated screens.
set -e
cd "$(dirname "$0")"
(cd ../../stream_chat && dart run tool/design_system_bundle.dart ../../design_systems/skip ../prompt_app/shell/assets/skip.json)
cp ../../../design_systems/skip/themes/pink.json ../../../design_systems/skip/themes/athlete.json assets/themes/
cp ../app.json assets/app.json
cp ../screens_skip/home.*.json ../screens_skip/history.*.json ../screens_skip/session.*.json assets/screens/

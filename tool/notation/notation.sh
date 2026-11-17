#!/bin/bash
# The compact notation's tools, runnable from a fresh checkout:
#
#   tool/notation/notation.sh prompt [--design-system <folder>] [--width <canvas width>] [--open [--no-define] [--no-glossary]]
#   tool/notation/notation.sh expand <file.txt> [--design-system <folder>] [--named] [--id <canvas id>] [--width <canvas width>] [--no-reflow] [--site <site.json>] [--out <file.json>] [--open [--vocabulary <file.json>]] [--aliases <file.json>]
#   tool/notation/notation.sh vocabulary <folder or files> [--design-system <folder>] [--aliases <file.json>] [--no-aliases] [--out <dir>] [--sites <dir>]
#   tool/notation/notation.sh apply <document.json> <ops.json> [--design-system <folder>] [--out <file.json>]
#   tool/notation/notation.sh migrate <file.txt> [more files] [--design-system <folder>]... [--check] [--stdout] [--dart | --markdown]
#
# --open is the open vocabulary (codelessly_api docs/design/19-open-vocabulary.md):
# prompt --open teaches the grammar and the core only, and asks for every
# word the answer invents to be defined after its last screen (--no-define:
# not asked, as the first corpus was written); with --design-system it names
# the design system's words beyond the core on one line, the glossary
# (--no-glossary: left out, as corpus-define d01 and d02 were written); expand --open lets a
# word the notation does not have stand in and records it; vocabulary reads a
# corpus of answers (tool/vocabulary/corpus/<name>) and writes which words
# they reached for and how each resolved (vocabulary.json, VOCABULARY.md).
#
# migrate is a one-off: it rewrites files written in the grammar codelessly_api
# read up to 32.x (key:value, =name, key:=expression, -> actions) to the
# grammar of 33.0.0 (key=value, key={expression}, bind=name, onTap={actions}),
# in place. The parser reads the new grammar only; migrate.dart carries its
# own copy of how the old one split a line, and is to be deleted, with this
# command, once the sites written before 2026-11-16 are migrated.
#
# It finds Flutter's dart, makes the SDK use the codelessly_api checked out
# beside it (../CodelesslyAPI: the notation is newer than the published
# package), resolves dependencies when they are stale, and runs
# tool/notation/<command>.dart with the rest of the arguments.
set -e
sdk="$(cd "$(dirname "$0")/../.." && pwd)"
cmd="${1:-}"
case "$cmd" in
  prompt|expand|apply|migrate|vocabulary) shift ;;
  *) echo "usage: tool/notation/notation.sh prompt|expand|apply|migrate|vocabulary [arguments] (see the head of this file)" >&2; exit 2 ;;
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

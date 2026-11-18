#!/bin/bash
# The compact notation's tools, runnable from a fresh checkout:
#
#   tool/notation/notation.sh prompt [--design-system <folder>] [--width <canvas width>] [--open [--no-define] [--no-glossary | --glossary=names|signatures]]
#   tool/notation/notation.sh expand <file.txt> [--design-system <folder>] [--named] [--nearest-colors] [--id <canvas id>] [--width <canvas width>] [--no-reflow] [--site <site.json or folder>] [--no-site] [--out <file.json>] [--open [--vocabulary <file.json>]] [--aliases <file.json>]
#   tool/notation/notation.sh expand <site folder> [--width <page width, default 1440>] [--no-reflow] [--design-system <folder>]
#   tool/notation/notation.sh vocabulary <folder or files> [--design-system <folder>] [--aliases <file.json>] [--no-aliases] [--out <dir>] [--sites <dir>]
#   tool/notation/notation.sh print <document.json> [--design-system <folder>] [--out <file.txt>] [--check]
#   tool/notation/notation.sh apply <document.json> <ops.json> [--design-system <folder>] [--out <file.json>]
#   tool/notation/notation.sh migrate <file or folder>... [--check] [--stdout] [--design-system <folder>]... [--site <site.json>] [--notation | --markdown | --dart | --python | --json | --html] [--from 32]
#
# --open is the open vocabulary (codelessly_api docs/design/19-open-vocabulary.md):
# prompt --open teaches the grammar and the core only, and asks for every
# word the answer invents to be defined after its last screen (--no-define:
# not asked, as the first corpus was written); with --design-system it lists
# the design system's words beyond the core, the glossary, one signature line
# each (--glossary=names: their names on one line, as corpus-define d03 was
# written; --no-glossary: left out, as d01 and d02 were written); expand --open lets a
# word the notation does not have stand in and records it; vocabulary reads a
# corpus of answers (tool/vocabulary/corpus/<name>) and writes which words
# they reached for and how each resolved (vocabulary.json, VOCABULARY.md).
#
# A file in a site's folder (a site.json beside it or up to two folders above
# it, as site.json or site/site.json; or the one --site names) is expanded
# with the site: its components are callable by name (those written in the
# notation, components/*.txt, expanded first in the order they call each
# other, and the expanded ones site.json lists), its variables are read by
# name (a page or a component that writes one declares no copy), its theme
# gives the looks a line does not say. No design_system.json is needed for
# that. Given the site folder (or its project folder, or its site.json)
# expand writes the whole site: every components/*.txt, then every
# pages/*.txt (each to the JSON site.json lists by that name, else
# site/components/<Name>.json and site/<page>.json, the page's file name its
# canvas id), one line per file and every issue; exit 1 when there is any.
#
# print is expand the other way: a document in the notation, which parses back
# to the same document (--check does that, and counts the lines whose fields
# the notation still has no word for).
#
# migrate rewrites files, in place, to the grammar codelessly_api reads now:
# a variable bound as `@name` (`bind=name`, `bindEnd=name` and a block's
# `key=name` rewritten; a state line added for each variable a screen binds
# and nothing declares), in notation files, Markdown, Dart, Python, JSON and
# HTML, a folder at a time; --check lists what is still to rewrite. --from 32
# first rewrites the grammar read up to 32.x (key:value, =name, key:=expression,
# -> actions). The head of migrate.dart says what each form becomes.
#
# It finds Flutter's dart, makes the SDK use the codelessly_api checked out
# beside it (../CodelesslyAPI: the notation is newer than the published
# package), resolves dependencies when they are stale, and runs
# tool/notation/<command>.dart with the rest of the arguments.
set -e
sdk="$(cd "$(dirname "$0")/../.." && pwd)"
cmd="${1:-}"
case "$cmd" in
  prompt|expand|print|apply|migrate|vocabulary) shift ;;
  *) echo "usage: tool/notation/notation.sh prompt|expand|print|apply|migrate|vocabulary [arguments] (see the head of this file)" >&2; exit 2 ;;
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

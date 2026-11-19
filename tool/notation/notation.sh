#!/bin/bash
# The compact notation's tools, runnable from a fresh checkout:
#
#   tool/notation/notation.sh prompt [--design-system <folder>] [--width <canvas width>] [--open [--no-define] [--no-glossary | --glossary=names|signatures]] [--dictionary <folder>]...
#   tool/notation/notation.sh expand <file.txt> [--design-system <folder>] [--named] [--nearest-colors] [--id <canvas id>] [--width <canvas width>] [--no-reflow] [--site <site.json or folder>] [--no-site] [--out <file.json>] [--open] [--vocabulary <file.json> | --no-record] [--aliases <file.json>] [--dictionary <folder>]...
#   tool/notation/notation.sh expand <site folder> [--width <page width, default 1440>] [--no-reflow] [--design-system <folder>] [--open] [--vocabulary <file.json> | --no-record] [--dictionary <folder>]...
#   tool/notation/notation.sh validate <site folder | file.txt> [--open] [the options of expand]
#   tool/notation/notation.sh vocabulary <folder or files> [--design-system <folder>] [--aliases <file.json>] [--no-aliases] [--out <dir>] [--sites <dir>]
#   tool/notation/notation.sh vocabulary <site folder | vocabulary.json | folder of them>... [--design-system <folder>] [--aliases <file.json>] [--out <dir>]
#   tool/notation/notation.sh print <document.json> [--design-system <folder>] [--out <file.txt>] [--check] [--dictionary <folder>]...
#   tool/notation/notation.sh apply <document.json> <ops.json> [--design-system <folder>] [--out <file.json>]
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
# The record (docs/design/19 section 15; tool/notation/vocabulary_record.dart):
# every expand, open or closed, saves every word the files used and how each
# resolved (core, a component, the site's component, an alias, a definition
# and whose, a primitive, refused with the issue, unknown: a placeholder),
# with its kind, the shapes it was written in, its files and lines, a
# writer's definition's text, and when it was first and last seen. It is
# kept across expands: a word rewritten since is still there, no longer
# used. A site's (the folder, or one of its files) is <site folder>/
# vocabulary.json and VOCABULARY.md (the folder holding pages/ and
# components/); a file of no site's is <file>.vocabulary.json and
# <file>.VOCABULARY.md beside it; --vocabulary <file.json> puts it there;
# --no-record saves none. Each word that stood in as a placeholder is said
# (`placeholder: Word (type) pages/home.txt:3 (1 use)`, and a total), with
# --open too, where it does not fail the expand; tool/codelessly render says
# it again (placeholder_word, read from the record). validate is expand
# writing nothing: what it would say, as JSON on stdout (issues,
# placeholders, the words beyond the core that did not resolve or that the
# writer defined, component files not loaded). vocabulary given site folders
# (with their drafts/), records, or a folder of them, writes the harvest
# across runs: every word beyond the core, by runs and apps, its shapes,
# how it resolved, the writers' definitions, ranked candidates to support.
#
# A dictionary is a folder of definitions (a <Word>.txt each, a `define`)
# kept apart from any one site: prompt, expand, validate and print read the
# folders --dictionary names (written again for each further one) or, with
# none written, those CODELESSLY_DICTIONARY lists (separated as in PATH;
# --no-dictionary reads none), and a site's site.json adds its own
# ("dictionary": ["../words"]). A word is read from the first that defines
# it: the page's own define, the site's, the design system's, then the
# dictionaries in order (tool/notation/dictionary.dart). The record names
# the dictionary's folder a word came from; the prompt lists their words.
#
# A components/*.txt that starts with `define Name …` (or `primitive`) is the
# site's definitions, read by every page and component as a define after a
# page's last line; one that is neither that nor `component Name` is said,
# as is a second file of one component and a component JSON site.json
# lists that nothing writes. A page whose first line is `### Name` is read
# without it.
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
# It finds Flutter's dart, makes the SDK use the codelessly_api checked out
# beside it (../CodelesslyAPI: the notation is newer than the published
# package), resolves dependencies when they are stale, and runs
# tool/notation/<command>.dart with the rest of the arguments.
set -e
# The notation's arguments are files and words, never a bare `/`: Git Bash's
# rewriting of POSIX paths for Dart is what they need. MSYS2_ARG_CONV_EXCL='*',
# which `tool/codelessly render` needs for `--key /`, turned it off and Dart
# looked for /c/Users/... ("Could not find file .../expand.dart": test 9).
unset MSYS2_ARG_CONV_EXCL MSYS_NO_PATHCONV
sdk="$(cd "$(dirname "$0")/../.." && pwd)"
cmd="${1:-}"
case "$cmd" in
  prompt|expand|print|apply|vocabulary) shift ;;
  validate) shift; set -- "$@" --validate; cmd=expand ;;
  *) echo "usage: tool/notation/notation.sh prompt|expand|validate|print|apply|vocabulary [arguments] (see the head of this file)" >&2; exit 2 ;;
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

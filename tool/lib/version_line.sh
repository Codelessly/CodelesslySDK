#!/usr/bin/env bash
# Prints the line that names the versions a render runs with (tool/lib/env.sh's codelessly_version_line):
#   codelessly_sdk <version> @ <commit> on <branch> at <path>, codelessly_api <version> @ <commit> on <branch> from <path>
# tool/cli (tool/codelessly render) keeps it in build/.version-line and asks again only when a checkout's commit
# or branch, a pubspec or the overrides file changed: making it costs a dozen process starts.
set -u
sdk="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$sdk/tool/lib/env.sh"
codelessly_find_api
codelessly_version_line
echo

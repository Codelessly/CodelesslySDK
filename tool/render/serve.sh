#!/usr/bin/env bash
# The render server: the render harness kept running, so render.sh's runs on this checkout skip Flutter's start
# (about 5 s each) and cost the rendering alone, and several of them render at the same time. render.sh and
# tool/codelessly render use it whenever it is up and current; nothing else changes (same arguments, same report,
# same files).
#
#   tool/render/serve.sh [--workers n] [--idle seconds] [--queue n] [--request-timeout seconds] [--recycle-mb n]
#                                           start it (in the background) and wait until it takes requests
#   tool/render/serve.sh --status [--json]  is it up, since when, its workers, its queue, what it served and how fast
#   tool/render/serve.sh --stop             stop it, and its workers
#
# It is one address (build/.render-server/port) and several workers behind it, each Flutter's headless engine in a
# process of its own (rendering runs on one thread of a process): requests from separate agents are rendered at
# the same time, one on each worker, and a request of many captures is shared among the workers that are idle
# (tool/cli/src/pool.dart, tool/render/src/fan.dart). --workers says how many: by default half the processors, no
# more than half the machine's memory holds at a gigabyte each, 16 at most; --workers 1 renders one request after
# another, as before there were workers. A worker is replaced by a fresh one when it holds more than --recycle-mb
# megabytes (1024), when it stops, or when a request took longer than --request-timeout seconds (1200) on it.
# More than --queue requests waiting (256) are refused with a line saying so.
#
# It stops by itself after --idle seconds without a request (default 1800). It serves the code it started with:
# when the SDK's lib/ or tool/render/, its pubspecs or the sibling codelessly_api's lib/ change after it started,
# render.sh stops it and renders the usual way (start it again to serve the new code). Its state is in
# build/.render-server/ (log in server.log, each worker's in w<n>.log); CODELESSLY_RENDER_SERVER=<folder> names another
# folder (a second server on the checkout, with a folder of its own: rm -rf'd when it stops).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdk="$(cd "$here/../.." && pwd)"
dir="${CODELESSLY_RENDER_SERVER:-$sdk/build/.render-server}"
. "$sdk/tool/lib/env.sh"

alive() { [ -f "$dir/pid" ] && kill -0 "$(cat "$dir/pid")" 2>/dev/null; }

stop_server() {
  alive || { rm -rf "$dir"; return 0; }
  touch "$dir/stop"
  for _ in $(seq 1 100); do alive || break; sleep 0.1; done
  # Its process group: the server and the workers it started.
  alive && { kill -TERM -- "-$(cat "$dir/pid")" 2>/dev/null || kill -TERM "$(cat "$dir/pid")" 2>/dev/null; }
  rm -rf "$dir"
}

case "${1:-}" in
  --stop) stop_server; echo "Render server stopped."; exit 0 ;;
  --status)
    if alive && [ -f "$dir/ready" ]; then
      if [ "${2:-}" = "--json" ]; then
        CODELESSLY_SDK="$sdk" "$sdk/build/codelessly_cli" render-pool-status --json
        exit $?
      fi
      echo "Render server up since $(date -r "$dir/ready" '+%F %T') (pid $(cat "$dir/pid")), $(cat "$dir/served" 2>/dev/null || echo 0) runs served."
      [ -x "$sdk/build/codelessly_cli" ] && CODELESSLY_SDK="$sdk" "$sdk/build/codelessly_cli" render-pool-status
      exit 0
    fi
    alive && { echo "Render server starting (pid $(cat "$dir/pid"))."; exit 0; }
    echo "No render server."; exit 1 ;;
esac
pool_args=()
idle=1800
while [ $# -gt 0 ]; do
  case "$1" in
    --idle) idle="${2:?--idle seconds}"; shift 2 ;;
    --workers|--queue|--request-timeout|--recycle-mb|--recycle-after)
      [ $# -ge 2 ] || { echo "$1 needs a number." >&2; exit 2; }
      case "$2" in ''|*[!0-9]*) echo "$1 takes a whole number (given \"$2\")." >&2; exit 2 ;; esac
      pool_args+=("$1" "$2"); shift 2 ;;
    *) echo "Unknown option $1. tool/render/serve.sh [--workers n] [--idle seconds] [--queue n] [--request-timeout seconds] [--recycle-mb n] | --status [--json] | --stop" >&2; exit 2 ;;
  esac
done

if alive && [ -f "$dir/ready" ]; then
  echo "Render server already up (pid $(cat "$dir/pid")); tool/render/serve.sh --stop stops it."
  exit 0
fi
stop_server

codelessly_find_flutter "tool/render/serve.sh" || exit 2
codelessly_take_lock
codelessly_find_api
codelessly_write_api_override
codelessly_pub_get || exit 2
codelessly_build_cli "tool/codelessly serve" || exit 2
if [ -z "${CODELESSLY_QUICKJS_LIBRARY:-}" ]; then
  for lib in "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.so" "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.dylib"; do
    if [ -f "$lib" ]; then export CODELESSLY_QUICKJS_LIBRARY="$lib"; break; fi
  done
fi
# The assets Flutter makes for this package's tests (the workers' engines read them): made by a first
# `flutter test`, which runs nothing here.
if [ ! -d "$sdk/build/unit_test_assets" ]; then
  echo "Preparing Flutter's test assets for the SDK (once)..." >&2
  (cd "$sdk" && "$flutter_bin" test --no-pub tool/render/render_harness.dart > /dev/null 2>&1) || true
fi

mkdir -p "$dir"
echo "Starting the render server ($(codelessly_version_line))..." >&2
# Paths as the server (a Dart program) reads them: under Git Bash on Windows C:/…, not /c/….
dir_arg="$dir" flutter_arg="$flutter_bin" sdk_arg="$sdk"
if command -v cygpath >/dev/null 2>&1; then
  dir_arg="$(cygpath -m "$dir")" flutter_arg="$(cygpath -m "$flutter_bin")" sdk_arg="$(cygpath -m "$sdk")"
fi
# Its own process group (setsid), so --stop ends the server and its workers together.
# Fd 9 (the lock) is closed for it: the lock is only held while it starts.
group=""; command -v setsid >/dev/null 2>&1 && group=setsid
# Every stream redirected on the job itself, and exec, so nothing of the caller's (a pipe an MCP server reads to
# its end) stays open in a shell that outlives this script.
(cd "$sdk" && exec env CODELESSLY_SDK="$sdk_arg" \
  $group "$sdk/build/codelessly_cli" render-pool --dir "$dir_arg" --flutter "$flutter_arg" --idle "$idle" ${pool_args[@]+"${pool_args[@]}"}) > "$dir/server.log" 2>&1 < /dev/null 9>&- &
echo $! > "$dir/pid"
for _ in $(seq 1 3000); do
  [ -f "$dir/ready" ] && break
  alive || break
  sleep 0.1
done
codelessly_release_lock
if [ -f "$dir/ready" ]; then
  echo "Render server up (pid $(cat "$dir/pid")): render.sh runs on this checkout use it; it stops after ${idle}s idle." >&2
  exit 0
fi
echo "The render server did not start. Its output:" >&2
grep -v "Woah\|superuser\|^  /\|📎" "$dir/server.log" | tail -40 >&2
stop_server
exit 2

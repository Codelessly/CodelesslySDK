#!/usr/bin/env bash
# The render server: the render harness kept running, so render.sh's runs on this checkout skip Flutter's start
# (about 5 s each) and cost the rendering alone. render.sh uses it whenever it is up and current; nothing else
# changes (same arguments, same report, same files).
#
#   tool/render/serve.sh [--idle seconds]   start it (in the background) and wait until it takes requests
#   tool/render/serve.sh --status           is it up, since when, how many runs it served
#   tool/render/serve.sh --stop             stop it
#
# It stops by itself after --idle seconds without a request (default 1800). It serves the code it started with:
# when the SDK's lib/ or tool/render/, its pubspecs or the sibling codelessly_api's lib/ change after it started,
# render.sh stops it and renders the usual way (start it again to serve the new code). Its state is in
# build/.render-server/ (log in server.log).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdk="$(cd "$here/../.." && pwd)"
dir="$sdk/build/.render-server"
. "$sdk/tool/lib/env.sh"

alive() { [ -f "$dir/pid" ] && kill -0 "$(cat "$dir/pid")" 2>/dev/null; }

stop_server() {
  alive || { rm -rf "$dir"; return 0; }
  touch "$dir/stop"
  for _ in $(seq 1 100); do alive || break; sleep 0.1; done
  # Its process group: the flutter tool and the test process it started.
  alive && { kill -TERM -- "-$(cat "$dir/pid")" 2>/dev/null || kill -TERM "$(cat "$dir/pid")" 2>/dev/null; }
  rm -rf "$dir"
}

case "${1:-}" in
  --stop) stop_server; echo "Render server stopped."; exit 0 ;;
  --status)
    if alive && [ -f "$dir/ready" ]; then
      echo "Render server up since $(date -r "$dir/ready" '+%F %T') (pid $(cat "$dir/pid")), $(cat "$dir/served" 2>/dev/null || echo 0) runs served."
      exit 0
    fi
    alive && { echo "Render server starting (pid $(cat "$dir/pid"))."; exit 0; }
    echo "No render server."; exit 1 ;;
esac
idle=1800
if [ "${1:-}" = "--idle" ]; then idle="${2:?--idle seconds}"; fi

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
if [ -z "${CODELESSLY_QUICKJS_LIBRARY:-}" ]; then
  for lib in "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.so" "$sdk/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.dylib"; do
    if [ -f "$lib" ]; then export CODELESSLY_QUICKJS_LIBRARY="$lib"; break; fi
  done
fi

mkdir -p "$dir"
echo "Starting the render server ($(codelessly_version_line))..." >&2
# Its own process group (setsid), so --stop ends the flutter tool and the test process together.
# Fd 9 (the lock) is closed for it: the lock is only held while it starts.
group=""; command -v setsid >/dev/null 2>&1 && group=setsid
# Every stream redirected on the job itself, and exec, so nothing of the caller's (a pipe an MCP server reads to
# its end) stays open in a shell that outlives this script.
(cd "$sdk" && exec env CODELESSLY_RENDER_SERVE="$dir" CODELESSLY_RENDER_IDLE="$idle" \
  $group "$flutter_bin" test --no-pub tool/render/render_harness.dart) > "$dir/server.log" 2>&1 < /dev/null 9>&- &
echo $! > "$dir/pid"
for _ in $(seq 1 1800); do
  [ -f "$dir/ready" ] && break
  alive || break
  sleep 0.2
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

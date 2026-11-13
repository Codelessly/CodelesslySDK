#!/usr/bin/env bash
# Replays every stream in tool/stream/streams (or those given) into
# tool/stream/out/<stream>/ and writes tool/stream/out/summary.md.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
streams=("$@")
[ ${#streams[@]} -gt 0 ] || streams=("$here"/streams/*.jsonl)
for s in "${streams[@]}"; do
  name="$(basename "$s" .jsonl)"
  echo "== $name"
  "$here/replay.sh" "$s" --out "$here/out/$name" > /dev/null || echo "FAILED $name"
done
python3 "$here/summary.py" "$here/out" > "$here/out/summary.md"
cat "$here/out/summary.md"

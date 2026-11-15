#!/bin/bash
# Designs the desktop blocks of briefs.json with the block designer, several at a time.
#   ANTHROPIC_API_KEY=... examples/showcase/desktop/blocks/run.sh <out dir> [names...]
# Each is shown the designed page it is a part of: examples/showcase/desktop/reference/<page>.png.
here="$(cd "$(dirname "$0")" && pwd)"; sdk="$(cd "$here/../../../.." && pwd)"; out="$1"; shift
mkdir -p "$out"
names="${*:-$(python3 -c "import json;print(' '.join(json.load(open('$here/briefs.json'))))")}"
one() {
  n="$1"
  python3 - "$here/briefs.json" "$n" "$out" <<'P'
import json,sys
b=json.load(open(sys.argv[1]))[sys.argv[2]]
open(f'{sys.argv[3]}/{sys.argv[2]}.brief.txt','w').write(b['brief']); open(f'{sys.argv[3]}/{sys.argv[2]}.page.txt','w').write(b['page']); open(f'{sys.argv[3]}/{sys.argv[2]}.ref.txt','w').write(b['reference'])
P
  (cd "$sdk" && python3 examples/showcase/tool/design_block.py --name "$n" --brief-file "$out/$n.brief.txt" --card-file "$out/$n.page.txt" \
     --out "$out/$n" --width 1280 --narrow 768 --rounds 3 --reference "$here/../reference/$(cat "$out/$n.ref.txt").png" > "$out/$n.log" 2>&1; echo "$n exit $?" >> "$out/done.txt")
}
export -f one; export here sdk out
printf '%s\n' $names | xargs -P 6 -I{} bash -c 'one {}'

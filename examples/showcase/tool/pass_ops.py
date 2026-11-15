#!/usr/bin/env python3
"""What the design pass changes again and again: the kept operations of recorded passes, counted.

    python3 examples/showcase/tool/pass_ops.py [examples/showcase/design-pass-runs] [--top 60] [--styles]

Each run folder holds before.json (the UI the pass was given) and ops.json (the operations kept). A patch is
counted as "<node type> <property path>=<value>", with how many runs it appears in and how many times; with
--styles, text restyles are counted as (the style the text had, the theme style it was given, its color). A
change that recurs across runs and needs no node the composer did not write is a candidate for a default of
the notation or of the design system's theme (design 16).
"""
import collections, glob, json, os, sys

root = next((a for a in sys.argv[1:] if not a.startswith('--') and not a.isdigit()), 'examples/showcase/design-pass-runs')
top = int(sys.argv[sys.argv.index('--top') + 1]) if '--top' in sys.argv else 60


def flat(d, pre=''):
    for k, v in d.items():
        if isinstance(v, dict) and k != 'style':
            yield from flat(v, pre + k + '.')
        else:
            yield pre + k, v


count, runs_of, styles, runs = collections.Counter(), collections.defaultdict(set), collections.Counter(), 0
for f in sorted(glob.glob(f'{root}/*/*/ops.json')):
    d = os.path.dirname(f)
    try:
        ops = json.load(open(f))['ops']
        before = json.load(open(f'{d}/before.json'))['nodes']
    except Exception:
        continue
    runs += 1
    for o in ops:
        if o.get('op') == 'set':
            node = o.get('node', {})
            key = f"SET {node.get('type')} {json.dumps(node.get('props', {}))[:50]}"
            count[key] += 1
            runs_of[key].add(d)
            continue
        if o.get('op') != 'patch':
            continue
        was = before.get(o.get('id'), {})
        kind = was.get('type', '?')
        for k, v in flat(o.get('patch', {})):
            if k == 'props.style' and isinstance(v, dict):
                key = f"{kind} style from={v.get('from')} color={v.get('color')}"
                had = (was.get('props') or {}).get('style')
                had = had.get('from', f"size{had.get('fontSize')}w{had.get('fontWeight')}") if isinstance(had, dict) else had
                styles[(had, v.get('from'), v.get('color'))] += 1
            else:
                key = f"{kind} {k}={json.dumps(v)[:60]}"
            count[key] += 1
            runs_of[key].add(d)
print(f'{runs} runs under {root}')
if '--styles' in sys.argv:
    for k, c in styles.most_common(top):
        print(c, k)
else:
    for k, c in sorted(count.items(), key=lambda x: (-len(runs_of[x[0]]), -x[1]))[:top]:
        print(len(runs_of[k]), c, k)

"""gaps.py <vocabulary.json> [n]

What to fix next, read across types: the unknown parameters, flags and events of a corpus grouped by their
NAME (a name written on many types is one concept to give every type, not one fix per type), then the types
with the most unknown words on them, then unknown verbs and functions, and unknown types by reach."""
import collections, json, sys

d = json.load(open(sys.argv[1], encoding='utf-8'))
n = int(sys.argv[2]) if len(sys.argv) > 2 else 25
words = d['words']
types = {w['word']: w for w in words if w['kind'] == 'type'}


def res(t):
    return types.get(t, {}).get('resolved', '?')


for kind in ('parameter', 'flag', 'event'):
    by = collections.defaultdict(lambda: dict(types=set(), files=set(), uses=0))
    for w in words:
        if w['kind'] == kind and w['resolved'] == 'unknown':
            b = by[w['word']]
            b['types'].add(w.get('on', ''))
            b['files'].update(w.get('in', []))
            b['uses'] += w.get('uses', 0)
    total = sum(1 for w in words if w['kind'] == kind and w['resolved'] == 'unknown')
    multi = sum(len(b['types']) for b in by.values() if len(b['types']) > 1)
    on_unknown = sum(1 for w in words if w['kind'] == kind and w['resolved'] == 'unknown' and res(w.get('on', '')) == 'unknown')
    print(f'== unknown {kind}s: {total} entries, {len(by)} names; {multi} entries are a name written on 2+ types; {on_unknown} are on a type we do not have')
    for name, b in sorted(by.items(), key=lambda kv: (-len(kv[1]['files']), -len(kv[1]['types'])))[:n]:
        ts = sorted(b['types'], key=lambda t: res(t))
        print(f"  {name:16} files {len(b['files']):2} types {len(b['types']):2} uses {b['uses']:3}  on: {', '.join(ts[:9])}{' …' if len(ts) > 9 else ''}")

by_type = collections.Counter()
for w in words:
    if w['kind'] in ('parameter', 'flag', 'event', 'variant', 'text') and w['resolved'] == 'unknown':
        by_type[w.get('on', '')] += 1
print('== types with the most unknown words on them (type: unknown words, how the type resolves, files)')
for t, c in by_type.most_common(n):
    print(f"  {t:18} {c:3}  {res(t):10} files {types.get(t, {}).get('files', 0)}")
for kind in ('verb', 'function'):
    u = [w for w in words if w['kind'] == kind and w['resolved'] == 'unknown']
    print(f'== unknown {kind}s ({len(u)}): ' + ', '.join(f"{w['word']}({w.get('files', 0)})" for w in sorted(u, key=lambda w: -w.get('files', 0))[:40]))
u = [w for w in words if w['kind'] == 'type' and w['resolved'] == 'unknown']
print(f'== unknown types ({len(u)}): ' + ', '.join(f"{w['word']}({w.get('files', 0)})" for w in sorted(u, key=lambda w: -w.get('files', 0))))

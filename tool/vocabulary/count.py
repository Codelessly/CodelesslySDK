"""count.py <vocabulary.json> [<earlier vocabulary.json>]

The size of a vocabulary corpus: the distinct words in a run of `notation.sh vocabulary`. A word is counted
once per kind and, for a parameter, flag, event or variant, per type it was written on (`size` on IconButton
and `size` on Chip are two entries: each has to be mapped or built on its own). Types are every type word
written, known or not; the other kinds are those the notation did not know or read through an alias (what a
type's own parameters are is not recorded when they are known).

With an earlier file, also lists the words that are new since it."""
import json, sys

KINDS = ['types', 'parameters', 'flags', 'events', 'verbs', 'functions', 'variants', 'aliases']


def words(path):
    d = json.load(open(path, encoding='utf-8'))
    out = {}
    for kind in KINDS:
        for e in d.get(kind, []):
            out[(kind, e.get('on', ''), e['word'])] = e
    return d, out


d, now = words(sys.argv[1])
by = {}
for (kind, _, _), e in now.items():
    r = e.get('resolved', '?')
    by.setdefault(kind, {}).setdefault(r, 0)
    by[kind][r] += 1
print(f"{d.get('files')} files, {d.get('screens')} screens, {d.get('lines', {}).get('nodes')} lines")
print(f'{len(now)} distinct words')
for kind in KINDS:
    if kind in by:
        print(f"  {kind:11} {sum(by[kind].values()):5}  " + ', '.join(f'{r} {n}' for r, n in sorted(by[kind].items())))
unknown = sum(n for k in by.values() for r, n in k.items() if r == 'unknown')
print(f'  resolved {len(now) - unknown} ({100 * (len(now) - unknown) / max(1, len(now)):.1f}%), unknown {unknown}')
if len(sys.argv) > 2:
    _, before = words(sys.argv[2])
    new = [k for k in now if k not in before]
    print(f'{len(new)} new since {sys.argv[2]}:')
    for kind, on, word in sorted(new, key=lambda k: (-now[k].get('files', 0), k)):
        e = now[(kind, on, word)]
        print(f"  {kind[:-1]:9} {(on + '.' if on else '') + word:34} {e.get('resolved', '?'):9} files {e.get('files', 0)} uses {e.get('uses', 0)}")

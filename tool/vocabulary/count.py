"""count.py <vocabulary.json> [<earlier vocabulary.json>]

The size of a vocabulary corpus: the distinct words in a run of `notation.sh vocabulary`, every word an answer
used, known or not (its `words`; tool/notation/vocabulary_words.dart says how each kind is read). A word is
counted once per kind and, for a text, parameter, flag, event or variant, once per type it was written on
(`size` on IconButton and `size` on Chip are two entries: each is mapped or built on its own). Each resolves as
core, component, alias, definition (a word defined in the notation), universal (a word every line understands,
read where the type has no word of that name or honoured by the stand-in of a type we do not have: codelessly_api
docs/design/21-universal-words.md) or unknown; the resolved share is all but unknown.

With an earlier file, also lists the words that are new since it, and those that resolve otherwise. An earlier
file written before every word was recorded (it has no `words`) is read as it was counted then: every type, and
only the parameters, flags, events, verbs, functions and variants the notation did not know, and the aliases; so
the words new since it include the known ones it never held."""
import json
import sys

KINDS = ['type', 'text', 'parameter', 'flag', 'event', 'variant', 'verb', 'function', 'statement']
RESOLUTIONS = ['core', 'component', 'alias', 'definition', 'universal', 'unknown']
OLD = {'types': 'type', 'parameters': 'parameter', 'flags': 'flag', 'events': 'event', 'verbs': 'verb',
       'functions': 'function', 'variants': 'variant', 'aliases': 'alias'}


def words(path):
    d = json.load(open(path, encoding='utf-8'))
    out = {}
    if 'words' in d:
        for e in d['words']:
            out[(e['kind'], e.get('on', ''), e['word'])] = e
        return d, out
    # Written before every word was recorded.
    for section, kind in OLD.items():
        for e in d.get(section, []):
            on, word = e.get('on', ''), e['word']
            if kind == 'variant' and '.' in word:
                on, word = word.split('.', 1)
            if kind == 'alias':
                kind = 'type' if word[:1].isupper() and not on else 'parameter'
            out[(kind, on, word)] = e
    return d, out


d, now = words(sys.argv[1])
by = {}
for (kind, _, _), e in now.items():
    r = e.get('resolved', '?')
    by.setdefault(kind, {}).setdefault(r, 0)
    by[kind][r] += 1
print(f"{d.get('files')} files, {d.get('screens')} screens, {d.get('lines', {}).get('nodes')} lines")
print(f'{len(now)} distinct words')
order = [k for k in KINDS if k in by] + [k for k in by if k not in KINDS]
for kind in order:
    row = by[kind]
    print(f"  {kind:10} {sum(row.values()):5}  " + ', '.join(f'{r} {row[r]}' for r in RESOLUTIONS + sorted(set(row) - set(RESOLUTIONS)) if r in row))
total = {r: sum(k.get(r, 0) for k in by.values()) for r in RESOLUTIONS}
unknown = total['unknown']
print(f"  {'all':10} {len(now):5}  " + ', '.join(f'{r} {n}' for r, n in total.items() if n))
print(f'  resolved {len(now) - unknown} ({100 * (len(now) - unknown) / max(1, len(now)):.1f}%), unknown {unknown}')
if len(sys.argv) > 2:
    _, before = words(sys.argv[2])
    new = [k for k in now if k not in before]
    changed = [k for k in now if k in before and before[k].get('resolved') != now[k].get('resolved')]
    print(f'{len(new)} new since {sys.argv[2]}:')
    for kind, on, word in sorted(new, key=lambda k: (-now[k].get('files', 0), k)):
        e = now[(kind, on, word)]
        print(f"  {kind:9} {(on + '.' if on else '') + word:34} {e.get('resolved', '?'):10} files {e.get('files', 0)} uses {e.get('uses', 0)}")
    if changed:
        print(f'{len(changed)} resolved otherwise than in {sys.argv[2]}:')
        for kind, on, word in sorted(changed, key=lambda k: (-now[k].get('files', 0), k)):
            print(f"  {kind:9} {(on + '.' if on else '') + word:34} {before[(kind, on, word)].get('resolved', '?'):10} -> {now[(kind, on, word)].get('resolved', '?')}")

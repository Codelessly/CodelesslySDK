"""Bytes of the site as written (pages + components + manifest) against the same pages written without
components: each call replaced by its definition's nodes (and theirs, transitively), as a copy would be.
Minified JSON, as in docs/design/06 §9.4. A list template counts once (it is written once either way)."""
import json, os

here = os.path.dirname(os.path.abspath(__file__))
def mini(v): return len(json.dumps(v, separators=(',', ':'), ensure_ascii=False).encode())
site = json.load(open(f'{here}/site.json'))
comps = {}
for f in sorted(os.listdir(f'{here}/components')):
    d = json.load(open(f'{here}/components/{f}'))
    comps[d['widget']['type']] = d

def inlined_nodes(doc):
    """Bytes of a document's nodes with each call replaced by its definition's nodes."""
    total = 0
    for n in doc['nodes'].values():
        t = n.get('type')
        if t in comps:
            total += inlined_nodes(comps[t]) + mini(comps[t].get('variables', {}))
        else:
            total += mini(n)
    return total

uses = {t: 0 for t in comps}
def count(doc):
    for n in doc['nodes'].values():
        if n.get('type') in comps:
            uses[n['type']] += 1
            count(comps[n['type']])

rows, with_total, without_total = [], mini(site), mini(site)
pages = [json.load(open(f'{here}/{p}')) for p in site['pages']]
for p in pages:
    count(p)
    w = mini(p)
    wo = w - sum(mini(n) for n in p['nodes'].values()) + inlined_nodes(p)
    rows.append((p['id'], len(p['nodes']), w, wo))
    with_total += w
    without_total += wo
comp_bytes = {t: mini(d) for t, d in comps.items()}
with_total += sum(comp_bytes.values())
print('page        nodes  with components  written out')
for r in rows: print(f'{r[0]:<11} {r[1]:>5}  {r[2]:>15,}  {r[3]:>11,}')
print(f'components ({len(comps)} files): {sum(comp_bytes.values()):,} bytes')
shared = {t: (uses[t], comp_bytes[t]) for t in comps if uses[t] > 1}
print('called more than once (calls, bytes):', ', '.join(f'{t} {u}x {b:,}' for t, (u, b) in sorted(shared.items())))
print(f'site total: {with_total:,} bytes with components, {without_total:,} written out '
      f'({without_total - with_total:,} duplicated bytes saved, {100 * (without_total - with_total) / without_total:.0f}%)')

#!/usr/bin/env python3
"""Are the values on a generated card right after it is used? An automatic answer, so a model and a grammar
can be compared by a number and not by someone looking at pictures.

    python3 tool/values/check.py <cases.json> <recordings dir> --design-system <folder> [--model claude-sonnet-5-5]
        [--out <dir>] [--only id,id]

<cases.json> is a list of {"id", "steps", "expect", "forbid"}: the recording `<id>@<model>.notation[.retryN].json`
(the last try) is rendered, the steps are driven, and the texts on screen are read (the render tool's
--dump-layout). `expect` is a list of regular expressions each of which some text must match; `forbid` a list
none may match. A step is {"choose": n} (the n-th option of the card's first choosing control: an option list,
chips, segments, a radio group) or {"press": n} (its n-th button) or {"tap": "<node path>"} (as the render tool
names it) or {"block": "NowPlaying", "tap": "play"} (a node of the first call of that block). "optional": true on a step lets a card without
that control pass (one that acts on the choice alone has no button).
More step kinds, for cards with several controls: {"choose": n, "nth": m} (the n-th option of the m-th choosing
control; a card with fewer controls than m+1 uses its last one, so a flow written with one control that changes its
options and a flow written with a control per question are both driven by the same steps), {"press": "<regex>", "nth": k}
(the k-th button whose label matches, or the k-th copy of the one a list repeats: a button's own label is read from the
card, so a card that puts Approve first still passes),
{"block": "FlightOption", "nth": 2} (tap the 3rd node of that block, or the 3rd copy of the one node a list repeats;
"tap": "sub" taps a node inside it), {"block": "InputField", "nth": 0, "type": "SAVE10"} (type into its field),
{"wait": ms}, {"key": "ArrowRight"}. A case may also have "order": [[re, re, ...], ...]: in each list, the texts
matching the expressions must appear in that order on screen (top to bottom, then left to right), which is how a
sort, a ranking or a queue is checked.
A card taller than the window cannot be tapped below its edge, so cases are rendered 1800 tall ("height": n in a case changes it).
Prints one line a case and the totals; exit code 0 always (it measures, it does not gate). No model is called.
"""
import glob, json, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SDK = os.path.dirname(os.path.dirname(HERE))
CHOOSERS = {'OptionList': 'opt', 'ChoiceChips': 'chip', 'Segments': 'cell', 'DayPicker': 'day'}
FIELDS = {'InputField': 'field', 'TextInput': 'field', 'TextArea': 'field'}
BUTTONS = {'ActionButton': 'btn', 'TotalBar': 'cta', 'iconButton': None, 'filledButton': None, 'outlinedButton': None, 'textButton': None, 'elevatedButton': None}


def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def labels_of(n):
    """The words a button shows (a TotalBar's button shows its cta), each from the prop or the binding that writes it."""
    out = []
    for k in (('cta',) if n['type'] == 'TotalBar' else ('label', 'text', 'icon', 'tooltip')):
        for v in ((n.get('props') or {}).get(k), (n.get('bind') or {}).get('props.' + k)):
            if isinstance(v, str):
                out.append(v)
    return out


def field_of(n):
    """The part of a field block that takes the typing: its one-line field, or its area when it shows several lines."""
    lines = (n.get('props') or {}).get('lines')
    return 'area' if isinstance(lines, (int, float)) and lines > 1 else FIELDS.get(n['type'], 'field')


def copy_of(nodes, ids, n):
    """The n-th node of a block, or the n-th copy of the one node a list repeats: (node id with its copy mark)."""
    if len(ids) > n:
        return ids[n]
    if len(ids) == 1:
        return f'{ids[0]}#{n}' if n else ids[0]
    return None


def resolve(step, doc):
    nodes = doc['nodes']
    if 'block' in step:
        ids = [k for k, n in nodes.items() if n['type'] == step['block']]
        # A card that wrote the plain field where the block was expected is typed into all the same.
        if not ids and 'type' in step and step['block'] in FIELDS:
            plain = [k for k, n in nodes.items() if n['type'] == 'textField']
            at = copy_of(nodes, plain, step.get('nth', 0)) if plain else None
            return ('type', f"{at}={step['type']}") if at else None
        at = copy_of(nodes, ids, step.get('nth', 0)) if ids else None
        if at is None:
            return None
        if 'type' in step:
            return ('type', f"{at}/{field_of(nodes[at.split('#')[0]])}={step['type']}")
        return f"{at}/{step['tap']}" if step.get('tap') else at
    if 'tap' in step:
        return step['tap']
    if 'wait' in step:
        return ('wait', str(step['wait']))
    if 'key' in step:
        return ('key', step['key'])
    if 'choose' in step:
        found = [k for k, n in nodes.items() if n['type'] in CHOOSERS]
        if found:
            k = found[min(step.get('nth', 0), len(found) - 1)]
            # Segments has a cell of its own per option (cell0, cell1…); the others repeat one (opt#0, opt#1…).
            sep = '' if nodes[k]['type'] == 'Segments' else '#'
            return f"{k}/{CHOOSERS[nodes[k]['type']]}{sep}{step['choose']}"
        radios = [k for k, n in nodes.items() if n['type'] in ('radio', 'choiceChip', 'listTile')]
        return radios[step['choose']] if len(radios) > step['choose'] else None
    if 'press' in step:
        buttons = [(k, BUTTONS[n['type']], labels_of(n)) for k, n in nodes.items() if n['type'] in BUTTONS]
        if isinstance(step['press'], str):  # by label; "nth" is which of those, or which copy when a list repeats one
            found = [b for b in buttons if any(re.search(step['press'], w) for w in b[2])]
            at = copy_of(nodes, [b[0] for b in found], step.get('nth', 0)) if found else None
            if at is None:
                return None
            inner = found[0][1] if '#' in at or len(found) == 1 else dict((b[0], b[1]) for b in found)[at]
            return f'{at}/{inner}' if inner else at
        if len(buttons) <= step['press']:
            return None
        k, inner, _ = buttons[step['press']]
        return f'{k}/{inner}' if inner else k
    return None


def ordered(texts, rule):
    """True when the texts matching the expressions of `rule` come in that order on screen."""
    at = -1
    for e in rule:
        nxt = next((i for i in range(at + 1, len(texts)) if re.search(e, texts[i])), None)
        if nxt is None:
            return False
        at = nxt
    return True


def main():
    cases = json.load(open(sys.argv[1]))
    recordings, ds = sys.argv[2], os.path.abspath(opt('--design-system'))
    model, out = opt('--model', 'claude-sonnet-5-5'), opt('--out', '/tmp/values-check')
    only = set(opt('--only', '').split(',')) - {''}
    right = total = 0
    for case in cases:
        cid = case['id']
        if only and cid not in only:
            continue
        tries = sorted(glob.glob(os.path.join(recordings, f'{cid}@{model}.notation.retry*.json')))
        f = tries[-1] if tries else os.path.join(recordings, f'{cid}@{model}.notation.json')
        total += 1
        if not os.path.exists(f):
            print(f'{cid:20} MISSING')
            continue
        doc = json.load(open(f))
        site = os.path.join(out, cid)
        shutil.rmtree(f'{site}/o', ignore_errors=True)  # an earlier run's captures must not be read as this one's
        os.makedirs(site, exist_ok=True)
        json.dump(doc, open(f'{site}/{cid}.json', 'w'))
        json.dump({'schema': 3, 'pages': [f'{cid}.json'], 'designSystem': os.path.relpath(ds, site)}, open(f'{site}/site.json', 'w'))
        steps, unresolved = [], []
        for s in case.get('steps', []):
            target = resolve(s, doc)
            if isinstance(target, tuple):
                flag = {'type': '--type', 'wait': '--wait', 'key': '--key'}[target[0]]
                steps.extend([flag, target[1]])
            elif target:
                steps.extend(['--tap', target])
            elif not s.get('optional'):  # a card that acts on the choice alone has no button to press
                unresolved.append(json.dumps(s))
        r = subprocess.run(['tool/render/render.sh', site, '--out', f'{site}/o', '--sizes', f"420x{case.get('height', 1800)}", '--dump-layout'] + steps,
                           cwd=SDK, capture_output=True, text=True)
        log = r.stdout + r.stderr
        errors = [l.strip() for l in log.splitlines() if l.startswith('ERROR')]
        dumps = glob.glob(f'{site}/o/*.layout.json')
        if not dumps:  # a render that wrote no dump is a failed render, not a card with no text
            errors.append('ERROR no layout dump was written')
        boxes = sorted((b for b in json.load(open(dumps[0])) if 'text' in b), key=lambda b: (b.get('y', 0), b.get('x', 0))) if dumps else []
        texts = [b['text'] for b in boxes]
        missing = [e for e in case.get('expect', []) if not any(re.search(e, t) for t in texts)]
        shown = [e for e in case.get('forbid', []) if any(re.search(e, t) for t in texts)]
        misordered = [r for r in case.get('order', []) if not ordered(texts, r)]
        ok = not missing and not shown and not unresolved and not errors and not misordered
        right += ok
        why = '; '.join(([f'not shown: {missing}'] if missing else []) + ([f'shown: {shown}'] if shown else []) + ([f'not in this order: {misordered}'] if misordered else []) +
                        ([f'no node for {unresolved}'] if unresolved else []) + ([f'{len(errors)} render error(s)'] if errors else []))
        print(f"{cid:20} {'right' if ok else 'WRONG':6} {why}")
    print(f'\n{right} of {total} right')


if __name__ == '__main__':
    main()

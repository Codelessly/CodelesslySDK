#!/usr/bin/env python3
"""Are the values on a generated card right after it is used? An automatic answer, so a model and a grammar
can be compared by a number and not by someone looking at pictures.

    python3 tool/values/check.py <cases.json> <recordings dir> --design-system <folder> [--model claude-haiku-5-5]
        [--out <dir>] [--only id,id]

<cases.json> is a list of {"id", "steps", "expect", "forbid"}: the recording `<id>@<model>.notation[.retryN].json`
(the last try) is rendered, the steps are driven, and the texts on screen are read (the render tool's
--dump-layout). `expect` is a list of regular expressions each of which some text must match; `forbid` a list
none may match. A step is {"choose": n} (the n-th option of the card's first choosing control: an option list,
chips, segments, a radio group) or {"press": n} (its n-th button) or {"tap": "<node path>"} (as the render tool
names it) or {"block": "NowPlaying", "tap": "play"} (a node of the first call of that block). "optional": true on a step lets a card without
that control pass (one that acts on the choice alone has no button).
Prints one line a case and the totals; exit code 0 always (it measures, it does not gate). No model is called.
"""
import glob, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SDK = os.path.dirname(os.path.dirname(HERE))
CHOOSERS = {'OptionList': 'opt', 'ChoiceChips': 'chip', 'Segments': 'seg'}
BUTTONS = {'ActionButton': 'btn', 'TotalBar': 'cta', 'filledButton': None, 'outlinedButton': None, 'textButton': None, 'elevatedButton': None}


def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def resolve(step, doc):
    nodes = doc['nodes']
    if 'block' in step:
        ids = [k for k, n in nodes.items() if n['type'] == step['block']]
        return f"{ids[0]}/{step['tap']}" if ids else None
    if 'tap' in step:
        return step['tap']
    if 'choose' in step:
        for k, n in nodes.items():
            if n['type'] in CHOOSERS:
                return f"{k}/{CHOOSERS[n['type']]}#{step['choose']}"
        radios = [k for k, n in nodes.items() if n['type'] in ('radio', 'choiceChip', 'listTile')]
        return radios[step['choose']] if len(radios) > step['choose'] else None
    if 'press' in step:
        buttons = [(k, BUTTONS[n['type']]) for k, n in nodes.items() if n['type'] in BUTTONS]
        if len(buttons) <= step['press']:
            return None
        k, inner = buttons[step['press']]
        return f'{k}/{inner}' if inner else k
    return None


def main():
    cases = json.load(open(sys.argv[1]))
    recordings, ds = sys.argv[2], os.path.abspath(opt('--design-system'))
    model, out = opt('--model', 'claude-haiku-5-5'), opt('--out', '/tmp/values-check')
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
        os.makedirs(site, exist_ok=True)
        json.dump(doc, open(f'{site}/{cid}.json', 'w'))
        json.dump({'schema': 3, 'pages': [f'{cid}.json'], 'designSystem': os.path.relpath(ds, site)}, open(f'{site}/site.json', 'w'))
        steps, unresolved = [], []
        for s in case.get('steps', []):
            target = resolve(s, doc)
            if target:
                steps.extend(['--tap', target])
            elif not s.get('optional'):  # a card that acts on the choice alone has no button to press
                unresolved.append(json.dumps(s))
        r = subprocess.run(['tool/render/render.sh', site, '--out', f'{site}/o', '--sizes', '420x900', '--dump-layout'] + steps,
                           cwd=SDK, capture_output=True, text=True)
        log = r.stdout + r.stderr
        errors = [l.strip() for l in log.splitlines() if l.startswith('ERROR')]
        dumps = glob.glob(f'{site}/o/*.layout.json')
        texts = [b['text'] for b in json.load(open(dumps[0])) if 'text' in b] if dumps else []
        missing = [e for e in case.get('expect', []) if not any(re.search(e, t) for t in texts)]
        shown = [e for e in case.get('forbid', []) if any(re.search(e, t) for t in texts)]
        ok = not missing and not shown and not unresolved and not errors
        right += ok
        why = '; '.join(([f'not shown: {missing}'] if missing else []) + ([f'shown: {shown}'] if shown else []) +
                        ([f'no node for {unresolved}'] if unresolved else []) + ([f'{len(errors)} render error(s)'] if errors else []))
        print(f"{cid:20} {'right' if ok else 'WRONG':6} {why}")
    print(f'\n{right} of {total} right')


if __name__ == '__main__':
    main()

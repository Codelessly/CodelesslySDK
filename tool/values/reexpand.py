#!/usr/bin/env python3
"""Expands recorded answers again with the notation as it is now, so a change to how the notation is read can
be measured on the same answers (no model is called, so nothing varies but the reading).

    python3 tool/values/reexpand.py <recordings dir> <out dir> --design-system <folder> [--model claude-haiku-5-5]

For each `<id>@<model>.notation[.retryN].jsonl` in <recordings dir> (the last try of each id), the text the model
wrote is expanded with tool/notation/notation.sh and written to <out dir>/<id>@<model>.notation.json, the name
tool/values/check.py reads. Prints how many expanded and how many had lines that were not read.
"""
import glob, json, os, re, subprocess, sys

SDK = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main():
    src, out, ds = sys.argv[1], os.path.abspath(sys.argv[2]), os.path.abspath(opt('--design-system'))
    model = opt('--model', 'claude-haiku-5-5')
    os.makedirs(out, exist_ok=True)
    last = {}
    for f in sorted(glob.glob(os.path.join(src, f'*@{model}.notation*.jsonl'))):
        last[os.path.basename(f).split('@')[0]] = f  # retryN sorts after the first try
    done = unread = 0
    for cid, f in sorted(last.items()):
        text = None
        for line in open(f):
            try:
                meta = json.loads(line).get('meta')
            except ValueError:
                continue
            if isinstance(meta, dict) and isinstance(meta.get('text'), str):
                text = meta['text']
        if text is None:
            print(f'{cid}: no text in {f}')
            continue
        txt = os.path.join(out, f'{cid}.txt')
        open(txt, 'w').write(text.rstrip('\n') + '\n')
        r = subprocess.run(['tool/notation/notation.sh', 'expand', txt, '--design-system', ds, '--out', os.path.join(out, f'{cid}@{model}.notation.json')],
                           cwd=SDK, capture_output=True, text=True)
        issues = [l for l in (r.stdout + r.stderr).splitlines() if re.search(r': line \d+:\d+:', l)]
        done += 1
        unread += bool(issues)
        for l in issues[:3]:
            print(f'{cid}: {l.split(": ", 1)[-1][:160]}')
    print(f'{done} expanded, {unread} with lines not read')


if __name__ == '__main__':
    main()

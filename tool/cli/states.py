#!/usr/bin/env python3
"""Render every state of a site from one manifest, compare each with its reference, and summarize.

    tool/codelessly states <states.json> [--out dir] [--only name]... [--sizes WxH,...] [--no-sheet]

A screen is right only when every state of it is: empty, filled, errors, a dialog open, hovered, at each size.
Recreating an app (the reference apps' parity work) or checking a site after a change means rendering each of
those states, comparing each with its reference, and reading the worst first. This runs the render command once
per state (`--label <state>`), then writes:

* `<out>/summary.md` and `summary.json`: per state and size, the errors, warnings and share of pixels matching
  its reference, worst first, with the problems' codes;
* `<out>/sheet.png`: every capture, one row per state (`--no-sheet` skips it);
* `<out>/<state>/`: that state's PNGs, `diagnostics-<state>.json`, compare images and layout dumps.

It exits 1 when any state has errors (or matches its reference less than `minMatch`), else 0.

The manifest (paths relative to it):

    {
      "documents": ["site"],                 // what to render: documents or a site folder
      "sizes": "390x844,834x1112,1440x900",  // default sizes (a state can name its own)
      "args": ["--fonts", "fonts"],          // passed to every render (--full-page, --theme dark, --now ...)
      "references": "screenshots",           // optional: a folder of reference PNGs (render --compare's naming)
      "minMatch": 0.97,                      // optional: below this share of matching pixels a state fails
      "ignore": ["unknown_screen"],          // optional: codes left out of the counts (still in diagnostics)
      "states": [
        {"name": "home", "screen": "home"},
        {"name": "home-annual", "screen": "home", "steps": [{"tap": "billing-toggle"}], "sizes": "1440x900"},
        {"name": "contact-errors", "screen": "contact", "steps": [{"type": "email=nope"}, {"tap": "submit"}]},
        {"name": "speaker", "steps": [{"navigate": "speaker?id=ada"}], "args": ["--full-page"],
         "compare": {"390x844": "screenshots/mobile/07_speaker.png"}}
      ]
    }

A step is `{"<render option without -->": value}` (`tap`, `hover`, `type`, `set`, `scroll`, `drag`, `key`,
`navigate`, `wait`, `focus`; `{"unfocus": true}`), or a list of raw arguments (`["--tap", "go"]`). A state's
`compare` is a reference file, a folder, or a map from size to file (each size then renders on its own); its
`documents` replace the manifest's for that state (a page alone, so other pages' problems are not its own).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SDK = HERE.parents[1]
RENDER = SDK / 'tool' / 'render' / 'render.sh'
sys.path.insert(0, str(HERE))


def step_args(steps) -> list[str]:
    out: list[str] = []
    for s in steps or []:
        if isinstance(s, str):
            out.append(s)
        elif isinstance(s, list):
            out += [str(x) for x in s]
        elif isinstance(s, dict):
            for k, v in s.items():
                if v is True:
                    out.append(f'--{k}')
                elif isinstance(v, (dict, list)):
                    out += [f'--{k}', json.dumps(v)]
                else:
                    out += [f'--{k}', str(v)]
    return out


def rel(base: Path, p: str) -> str:
    return p if p == 'system' or Path(p).is_absolute() else str((base / p).resolve())


def absolutize(base: Path, args: list[str]) -> list[str]:
    """Paths after --fonts, --compare, --slots, --design-system are relative to the manifest."""
    out = []
    for i, a in enumerate(args):
        if i and args[i - 1] in ('--fonts', '--compare', '--slots', '--design-system'):
            a = rel(base, a)
        out.append(a)
    return out


def run_render(cmd: list[str]) -> tuple[int, str]:
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def main(argv=None):
    p = argparse.ArgumentParser(prog='tool/codelessly states', description=__doc__.split('\n\n')[0])
    p.add_argument('manifest')
    p.add_argument('--out', help='default: <manifest folder>/out/states')
    p.add_argument('--only', action='append', help='only states whose name contains this (repeatable)')
    p.add_argument('--sizes', help='override every size')
    p.add_argument('--no-sheet', action='store_true')
    p.add_argument('--outline', action='store_true', help='also write <state>/outline.txt (node boxes and problems)')
    a = p.parse_args(argv)

    mpath = Path(a.manifest).resolve()
    m = json.loads(mpath.read_text())
    base = mpath.parent
    out = Path(a.out).resolve() if a.out else base / 'out' / 'states'
    out.mkdir(parents=True, exist_ok=True)
    docs = [rel(base, d) for d in m.get('documents', [])]
    if not docs:
        raise SystemExit('The manifest names no "documents".')
    common = absolutize(base, [str(x) for x in m.get('args', [])])
    refs = m.get('references')
    min_match = m.get('minMatch')

    results = []
    states = [s for s in m.get('states', []) if not a.only or any(o in s['name'] for o in a.only)]
    if not states:
        raise SystemExit('No states to render (the manifest has none, or --only matched none).')
    for s in states:
        name = s['name']
        sdir = out / name
        sdir.mkdir(parents=True, exist_ok=True)
        sizes = a.sizes or s.get('sizes') or m.get('sizes') or '390x844,834x1112,1440x900'
        args = common + absolutize(base, [str(x) for x in s.get('args', [])])
        if s.get('screen'):
            args += ['--screen', s['screen']]
        args += step_args(s.get('steps'))
        args += ['--label', name]
        if a.outline:
            args.append('--dump-layout')
        for k, v in (s.get('compareMap') or {}).items():
            args += ['--compare-map', f'{k}={v}']
        compare = s.get('compare', refs)
        runs: list[tuple[str, list[str]]] = []
        if isinstance(compare, dict):
            for size in sizes.split(','):
                extra = ['--compare', rel(base, compare[size])] if size in compare else []
                runs.append((size, extra))
        else:
            runs.append((sizes, ['--compare', rel(base, compare)] if compare else []))
        t0 = time.time()
        status, log = 0, ''
        diag_file = sdir / f'diagnostics-{name}.json'
        merged = {'errors': 0, 'warnings': 0, 'images': [], 'comparisons': [], 'diagnostics': []}
        seen = set()
        for size, extra in runs:
            diag_file.unlink(missing_ok=True)
            state_docs = [rel(base, d) for d in s['documents']] if s.get('documents') else docs
            code, text = run_render([str(RENDER), *state_docs, '--out', str(sdir), '--sizes', size, *args, *extra])
            status = max(status, code)
            log += text
            if diag_file.exists():  # each run writes the label's file: merge the runs (one per size) into one
                d = json.loads(diag_file.read_text())
                merged['images'] += d.get('images', [])
                merged['comparisons'] += d.get('comparisons', [])
                for x in d.get('diagnostics', []):
                    key = json.dumps(x, sort_keys=True)
                    if key not in seen:  # validation problems repeat in every run
                        seen.add(key)
                        merged['diagnostics'].append(x)
        merged['errors'] = sum(1 for x in merged['diagnostics'] if x.get('severity') == 'error')
        merged['warnings'] = len(merged['diagnostics']) - merged['errors']
        has_diagnostics = bool(merged['images'] or merged['diagnostics'])
        if has_diagnostics:
            diag_file.write_text(json.dumps(merged, indent=1))
        (sdir / 'render.log').write_text(log)
        ignore = set(m.get('ignore') or [])
        diags = [x for x in merged['diagnostics'] if x.get('code') not in ignore]
        comps, images = merged['comparisons'], merged['images']
        errors = [d for d in diags if d.get('severity') == 'error']
        warnings = [d for d in diags if d.get('severity') != 'error']
        worst = min((c['matching'] for c in comps if 'matching' in c), default=None)
        failed = (status == 2 and not has_diagnostics) or bool(errors) or (min_match is not None and worst is not None and worst < min_match)
        if a.outline:
            import outline
            types, parents = outline.load_documents(docs)
            lines = []
            for lf in sorted(sdir.glob('*.layout.json')):
                cap = lf.name.replace('.png.layout.json', '').replace('.layout.json', '')
                lines.append(f'== {cap}')
                lines += outline.outline_capture(json.loads(lf.read_text()), types, parents,
                                                 outline.capture_diagnostics(sdir, cap))
                lines.append('')
            (sdir / 'outline.txt').write_text('\n'.join(lines))
        results.append({
            'state': name, 'status': status, 'failed': failed, 'seconds': round(time.time() - t0, 1),
            'errors': len(errors), 'warnings': len(warnings),
            'codes': sorted({d.get('code') for d in diags}),
            'matching': worst, 'comparisons': comps, 'images': [str(sdir / i) for i in images],
            'problems': [f"{d.get('severity')} {d.get('code')} {d.get('nodeId') or d.get('path') or ''}: "
                         f"{(d.get('message') or '')[:200]}" for d in errors + warnings][:12],
            'log': None if has_diagnostics else log[-1500:],
        })
        mark = 'FAIL' if failed else 'ok  '
        match = f'{worst * 100:.1f}% match' if worst is not None else 'no reference'
        print(f'{mark} {name:<32} {len(errors)} errors, {len(warnings)} warnings, {match} ({results[-1]["seconds"]}s)',
              flush=True)

    results.sort(key=lambda r: (not r['failed'], r['matching'] if r['matching'] is not None else 2, -r['errors']))
    (out / 'summary.json').write_text(json.dumps(results, indent=1))
    md = ['# States', '', f'{len(results)} states from `{mpath}`; worst first.', '',
          '| State | Result | Errors | Warnings | Worst match | Codes |', '|---|---|---|---|---|---|']
    for r in results:
        match = f"{r['matching'] * 100:.1f}%" if r['matching'] is not None else ''
        md.append(f"| {r['state']} | {'FAIL' if r['failed'] else 'ok'} | {r['errors']} | {r['warnings']} | {match} | "
                  f"{', '.join(c for c in r['codes'] if c)} |")
    for r in results:
        if r['problems'] or r['log']:
            md += ['', f"## {r['state']}", '']
            md += [f'- {x}' for x in r['problems']]
            if r['log']:
                md += ['', '```', r['log'], '```']
    (out / 'summary.md').write_text('\n'.join(md) + '\n')
    if not a.no_sheet:
        import sheet
        try:
            made = sheet.make_sheet([str(out / r['state']) for r in sorted(results, key=lambda r: r['state'])],
                                    str(out / 'sheet.png'), height=360, title=f'{mpath.name}: {len(results)} states')
            if made:
                print(f'wrote {made}')
        except SystemExit as e:
            print(f'(no sheet: {e})', file=sys.stderr)
    print(f'wrote {out / "summary.md"}')
    return 1 if any(r['failed'] for r in results) else 0


if __name__ == '__main__':
    sys.exit(main())

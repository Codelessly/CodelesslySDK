#!/usr/bin/env python3
"""Builds the showcase: the 17 cards written in the notation with the Cards blocks, rendered at 420 wide.

    python3 examples/showcase/tool/build.py [--only flights,weather] [--sheet ours-sheet-r3.png] [--theme dark]

For each cards/<brief>.txt: expands it under design_systems/cards into site/<brief>.json, renders it with the
steps in STEPS (its main interaction driven), crops the capture to the card and writes renders/ours/<brief>.png.
Then it draws the contact sheet renders/ours-sheet.png (six per row, labelled). The design system itself is
built by design_systems/cards/tool/build.py, which calls this.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                               # examples/showcase
SDK = os.path.dirname(os.path.dirname(ROOT))
DS = f'{SDK}/design_systems/cards'
WIDTH = 420

# What the render tool does to each card before the capture: its main interaction.
STEPS = {
    'approval': [],
    'carousel': [],
    'checkout': [],
    'code_diff': [],
    'comparison': [],
    'dashboard': [],
    'data_table': [],
    'flights': [],
    'image_gallery': [],
    'itinerary': [],
    'map_list': [],
    'message_draft': [],
    'order_summary': [],
    'plan_progress': [],
    'question_flow': [],
    'reservation': [],
    'weather': [],
}
try:
    from steps import STEPS as _S, EXTRA  # the per-card steps live beside this file
    STEPS.update(_S)
except ImportError:
    EXTRA = {}


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def run(cmd, **k):
    env = {**os.environ, 'PATH': '/opt/flutter/bin:' + os.environ.get('PATH', '')}
    return subprocess.run(cmd, cwd=SDK, env=env, capture_output=True, text=True, **k)


def expand(brief):
    r = run(['tool/notation/notation.sh', 'expand', f'{ROOT}/cards/{brief}.txt', '--design-system', DS, '--id', brief,
             '--out', f'{ROOT}/site/{brief}.json'])
    issues = [l for l in (r.stdout + r.stderr).splitlines() if '.txt: line' in l or 'does not load' in l]
    if r.returncode and not issues:
        issues = [(r.stdout + r.stderr).strip()[-600:]]
    return issues


def crop(src, dst):
    """Cuts the capture to the card: keeps the rows the card's shell (the page color) covers."""
    im = Image.open(src).convert('RGB')
    w, h = im.size
    px = im.load()
    page = px[2, 2]
    y = h - 1
    while y > 0 and max(abs(a - b) for a, b in zip(px[2, y], page)) > 5:
        y -= 1
    # Under a design system whose page color is the canvas's own (Cards: colors.page), the rows below the shell
    # are that color too: cut at the last row with anything else on it.
    while y > 0 and all(max(abs(a - b) for a, b in zip(px[x, y], page)) <= 3 for x in range(0, w, 2)):
        y -= 1
    im.crop((0, 0, w, min(h, y + 1))).save(dst)


def render(brief, steps, label, theme):
    out = f'{ROOT}/renders/_raw'
    cmd = ['tool/render/render.sh', f'{ROOT}/site', '--out', out, '--sizes', f'{WIDTH}x3200', '--full-page', '--screen', brief,
           '--label', label] + steps
    if theme:
        cmd += ['--theme', theme]
    r = run(cmd)
    lines = [l for l in (r.stdout + r.stderr).splitlines()]
    report = [l for i, l in enumerate(lines) if l.startswith(('ERROR', 'WARNING')) or (i and lines[i - 1].startswith(('ERROR', 'WARNING')))]
    tail = [l for l in lines if 'error(s)' in l]
    png = f'{out}/{brief}@{WIDTH}x3200-' + (f'{theme}-' if theme else '') + f'{label}.png'
    return (png if os.path.exists(png) else None), report, (tail[-1] if tail else 'no summary: ' + '\n'.join(lines[-6:]))


def sheet(names, folder, dst, per_row=6, scale=1.0):
    font = ImageFont.truetype('/usr/share/fonts/opentype/inter/Inter-Medium.otf', 15)
    ims = [(n, Image.open(f'{folder}/{n}.png')) for n in names if os.path.exists(f'{folder}/{n}.png')]
    gap, top = 20, 26
    rows = [ims[i:i + per_row] for i in range(0, len(ims), per_row)]
    w = gap + per_row * (WIDTH + gap)
    h = gap + sum(top + max(im.size[1] for _, im in r) + gap for r in rows)
    out = Image.new('RGB', (w, h), (236, 236, 236))
    d = ImageDraw.Draw(out)
    y = gap
    for r in rows:
        x = gap
        for n, im in r:
            d.text((x + 2, y), n, fill=(60, 62, 80), font=font)
            out.paste(im, (x, y + top))
            x += WIDTH + gap
        y += top + max(im.size[1] for _, im in r) + gap
    out.save(dst)


def recrop():
    raw = f'{ROOT}/renders/_raw'
    for f in os.listdir(raw):
        if f.endswith('.png') and '@' in f and '-dark-' not in f and '-light-' not in f and 'x3200' in f:
            brief, label = f.split('@')[0], f.split('@')[1].split('-', 1)[1][:-4]
            crop(f'{raw}/{f}', f'{ROOT}/renders/ours/{brief}.png' if label == 'main' else f'{ROOT}/renders/states/{brief}-{label}.png')


def main():
    if '--recrop' in sys.argv:
        recrop()
        return sheet(sorted(STEPS), f'{ROOT}/renders/ours', f'{ROOT}/renders/' + (arg('--sheet') or 'ours-sheet.png'))
    only = arg('--only')
    theme = arg('--theme')
    briefs = sorted(STEPS)
    todo = only.split(',') if only else briefs
    os.makedirs(f'{ROOT}/site', exist_ok=True)
    folder = f'{ROOT}/renders/ours' + (f'-{theme}' if theme else '')
    os.makedirs(folder, exist_ok=True)
    os.makedirs(f'{ROOT}/renders/_raw', exist_ok=True)
    present = [b for b in briefs if os.path.exists(f'{ROOT}/cards/{b}.txt')]
    with open(f'{ROOT}/site/site.json', 'w') as f:
        json.dump({'schema': 3, 'pages': [f'{b}.json' for b in present], 'designSystem': '../../../design_systems/cards'}, f, indent=1)
    bad = 0
    summary = {}
    # Every card is expanded again each time (a block's parameters may have changed); only `todo` is rendered.
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(6) as pool:
        for b, issues in zip(present, pool.map(expand, present)):
            for i in issues:
                print('  NOTATION', i)
            bad += len(issues)
    for b in todo:
        if b not in present:
            continue
        png, report, tail = render(b, STEPS[b], 'main', theme)
        print(f'{b}: {tail}')
        for l in report:
            print('   ', l[:400])
        if 'ERROR' in ''.join(report):
            bad += 1
        if png:
            crop(png, f'{folder}/{b}.png')
        for label, steps in ({} if theme else EXTRA.get(b, {})).items():
            png, report, tail = render(b, steps, label, theme)
            print(f'{b} [{label}]: {tail}')
            for l in report:
                print('   ', l[:400])
            if png:
                os.makedirs(f'{ROOT}/renders/states', exist_ok=True)
                crop(png, f'{ROOT}/renders/states/{b}-{label}.png')
        lines = [l for l in open(f'{ROOT}/cards/{b}.txt').read().splitlines() if l.strip()]
        summary[b] = len(lines)
    dst = f'{ROOT}/renders/' + ('ours-sheet.png' if not theme else f'ours-sheet-{theme}.png')
    sheet(briefs, folder, dst)
    if arg('--sheet'):
        sheet(briefs, folder, f'{ROOT}/renders/{arg("--sheet")}')
    print('lines:', json.dumps(summary))
    print('sheet:', dst)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()

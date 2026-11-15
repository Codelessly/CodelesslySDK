#!/usr/bin/env python3
"""Renders the plain-parts cards and pages before (no design system) and after (design_systems/cards, its designed
defaults for plain parts), and draws the contact sheets.

    python3 examples/showcase/designed-defaults/tool/sheets.py [all|cards|pages|narrow|parts] [--only a,b] [--no-render]

For each group, every notation file is expanded twice: `before` with no design system (the bundled SSUI defaults),
`after` with design_systems/cards and `--named` (theme names, as a UiSession writes them, so dark mode follows).
Each variant is one site rendered in one call per theme (light, dark), cropped to the canvas, and laid out on a
sheet: before | after side by side per card, light then dark. A sheet taller than 8000 px is split into parts.

Inputs: cards/*.txt (17 recorded Sonnet answers, 2026-11-14-notation-5, and 8 held-out ones, 2026-11-15-heldout-
generic), pages/*.txt (two real generated app screens from examples/prompt_app and four written here, with
desktop variants `*_desktop.txt` rendered 1280 wide), parts.txt (every plain part). Work files go to _build/.
"""
import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # examples/showcase/designed-defaults
SDK = os.path.dirname(os.path.dirname(os.path.dirname(ROOT)))
DS = f'{SDK}/design_systems/cards'
BUILD = os.environ.get('DD_BUILD', f'{ROOT}/_build')
MAX_H = 8000
FONT = '/usr/share/fonts/opentype/inter/Inter-Medium.otf'


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def run(cmd):
    env = {**os.environ, 'PATH': '/opt/flutter/bin:' + os.environ.get('PATH', '')}
    return subprocess.run(cmd, cwd=SDK, env=env, capture_output=True, text=True)


def expand(src, out, cid, after):
    cmd = ['tool/notation/notation.sh', 'expand', src, '--id', cid, '--out', out]
    if after:
        cmd += ['--design-system', DS, '--named']
    r = run(cmd)
    return [l for l in (r.stdout + r.stderr).splitlines() if ': line ' in l]


def build_site(group, variant, files, width):
    """Expands `files` ({id: path}) into one site; returns the site folder."""
    site = f'{BUILD}/{group}-{variant}/site'
    shutil.rmtree(site, ignore_errors=True)
    os.makedirs(site)
    jobs = [(p, f'{site}/{cid}.json', cid, variant == 'after') for cid, p in files.items()]
    with ThreadPoolExecutor(6) as pool:
        for (p, _, cid, _), issues in zip(jobs, pool.map(lambda j: expand(*j), jobs)):
            for i in issues[:3]:
                print(f'  {group}/{variant} {cid}: {i.split(": ", 1)[-1][:200]}')
    manifest = {'schema': 3, 'pages': sorted(f'{cid}.json' for cid in files)}
    if variant == 'after':
        manifest['designSystem'] = os.path.relpath(DS, site)
    json.dump(manifest, open(f'{site}/site.json', 'w'), indent=1)
    return site


def render(site, out, size, theme, steps=(), label=None, keep=False, full=True, screen=None):
    if not keep:
        shutil.rmtree(out, ignore_errors=True)
    cmd = ['tool/render/render.sh', site, '--out', out, '--sizes', size] + (['--full-page'] if full else [])
    if theme == 'dark':
        cmd += ['--theme', 'dark']
    if label:
        cmd += ['--label', label]
    if screen:
        cmd += ['--screen', screen]
    cmd += list(steps)
    r = run(cmd)
    tail = [l for l in (r.stdout + r.stderr).splitlines() if 'error(s)' in l]
    print(f'  render {os.path.relpath(out, BUILD)}: {tail[-1] if tail else (r.stdout + r.stderr)[-400:]}')
    try:
        diags = json.load(open(f'{out}/diagnostics.json'))['diagnostics']
        errs = [d for d in diags if d.get('severity') == 'error']
        for d in errs[:8]:
            print(f'    ERROR {d.get("file")} {d.get("code")} {d.get("nodeId")}: {d.get("message", "")[:160]}')
    except (OSError, ValueError, KeyError):
        pass


def crop(png):
    """Cuts a full-page capture to its content: drops the rows at the bottom that are one flat color."""
    im = Image.open(png).convert('RGB')
    w, h = im.size
    px = im.load()
    bg = px[w - 1, h - 1]

    def flat(y):
        return all(max(abs(a - b) for a, b in zip(px[x, y], bg)) <= 3 for x in range(0, w, 3))

    y = h - 1
    while y > 0 and flat(y):
        y -= 1
    return im.crop((0, 0, w, min(h, y + 17)))


def captures(group, variant, files, size, theme):
    out = f'{BUILD}/{group}-{variant}/{theme}-{size}'
    return {cid: f'{out}/{cid}@{size}' + ('-dark' if theme == 'dark' else '') + '.png' for cid in files}, out


def do_render(group, files, size, variants=('before', 'after'), themes=('light', 'dark')):
    for v in variants:
        site = build_site(group, v, files, size)
        for t in themes:
            _, out = captures(group, v, files, size, t)
            render(site, out, size, t)


def sheet(title, columns, rows, dst, cell_w):
    """columns: header names; rows: [(label, [png or None per column])]. Writes dst (split past MAX_H)."""
    font = ImageFont.truetype(FONT, 15)
    big = ImageFont.truetype(FONT, 20)
    gap, top = 20, 26
    blocks = []
    for label, pngs in rows:
        ims = [crop(p) if p and os.path.exists(p) else None for p in pngs]
        h = max((im.size[1] for im in ims if im), default=40)
        blocks.append((label, ims, h))
    w = gap + len(columns) * (cell_w + gap)
    parts, cur, cur_h = [], [], 70
    for b in blocks:
        bh = top + b[2] + gap
        if cur and cur_h + bh > MAX_H:
            parts.append(cur)
            cur, cur_h = [], 70
        cur.append(b)
        cur_h += bh
    parts.append(cur)
    names = []
    for n, part in enumerate(parts):
        h = 70 + sum(top + b[2] + gap for b in part)
        out = Image.new('RGB', (w, h), (228, 229, 233))
        d = ImageDraw.Draw(out)
        d.text((gap, 18), title + (f'  (part {n + 1} of {len(parts)})' if len(parts) > 1 else ''), fill=(30, 32, 40), font=big)
        for i, c in enumerate(columns):
            d.text((gap + i * (cell_w + gap) + cell_w - 60, 46), c, fill=(90, 92, 110), font=font)
        y = 70
        for label, ims, bh in part:
            for i, im in enumerate(ims):
                x = gap + i * (cell_w + gap)
                d.text((x + 2, y), label, fill=(60, 62, 80), font=font)
                if im:
                    out.paste(im.crop((0, 0, min(cell_w, im.size[0]), im.size[1])), (x, y + top))
            y += top + bh + gap
        name = dst if len(parts) == 1 else dst.replace('.png', f'-{n + 1}.png')
        out.save(name)
        names.append(name)
    for stale in [f for f in os.listdir(os.path.dirname(dst)) if f.startswith(os.path.basename(dst)[:-4] + '-') and f[:-4].split('-')[-1].isdigit()]:
        if f'{os.path.dirname(dst)}/{stale}' not in names:
            os.remove(f'{os.path.dirname(dst)}/{stale}')
    if len(parts) > 1 and os.path.exists(dst):
        os.remove(dst)
    print('  sheet', ', '.join(os.path.relpath(n, SDK) for n in names))


def sources(folder, suffix=''):
    return {f[:-4]: f'{folder}/{f}' for f in sorted(os.listdir(folder)) if f.endswith('.txt') and f[:-4].endswith(suffix)}


def main():
    what = next((a for a in sys.argv[1:] if not a.startswith('--') and a in ('all', 'cards', 'pages', 'narrow', 'parts', 'widgets', 'surfaces')), 'all')
    only = arg('--only')
    norender = '--no-render' in sys.argv
    os.makedirs(BUILD, exist_ok=True)

    def pick(files):
        return {k: v for k, v in files.items() if not only or k in only.split(',')}

    if what in ('all', 'cards'):
        files = pick(sources(f'{ROOT}/cards'))
        size = '420x3200'
        if not norender:
            do_render('cards', files, size)
        for v in ('before', 'after'):
            rows = [(cid, [captures('cards', v, files, size, t)[0][cid] for t in ('light', 'dark')]) for cid in files]
            sheet(f'Inline cards, {v}: ' + ('no design system (bundled SSUI defaults)' if v == 'before' else 'design_systems/cards, designed defaults'),
                  ['light', 'dark'], rows, f'{ROOT}/cards-{v}.png', 420)
    if what in ('all', 'narrow'):
        files = pick(sources(f'{ROOT}/cards'))
        size = '320x3200'
        if not norender:
            do_render('narrow', files, size, variants=('after',))
        rows = [(cid, [captures('narrow', 'after', files, size, t)[0][cid] for t in ('light', 'dark')]) for cid in files]
        sheet('Inline cards at 320 wide, designed defaults', ['light', 'dark'], rows, f'{ROOT}/narrow-after.png', 320)
    if what in ('all', 'pages'):
        mobile = pick({k: v for k, v in sources(f'{ROOT}/pages').items() if not k.endswith('_desktop')})
        desktop = pick(sources(f'{ROOT}/pages', '_desktop'))
        if not norender:
            do_render('pages', mobile, '390x3200')
            if desktop:
                do_render('desktop', desktop, '1280x3200')
        for v in ('before', 'after'):
            rows = [(cid, [captures('pages', v, mobile, '390x3200', t)[0][cid] for t in ('light', 'dark')]) for cid in mobile]
            sheet(f'Pages (390), {v}', ['light', 'dark'], rows, f'{ROOT}/pages-{v}.png', 390)
            if desktop:
                rows = [(cid, [captures('desktop', v, desktop, '1280x3200', t)[0][cid] for t in ('light', 'dark')]) for cid in desktop]
                sheet(f'Pages (1280), {v}', ['light', 'dark'], rows, f'{ROOT}/pages-desktop-{v}.png', 1280)
    if what in ('all', 'widgets'):
        # Every catalog type that draws something, at rest and in its other states, then the open states.
        site = build_site('widgets', 'after', {'widgets': f'{ROOT}/widgets.txt'}, '420x3200')
        states = [('rest', []), ('select', ['--tap', 'sel']), ('date', ['--tap', 'dp']), ('time', ['--tap', 'tp']),
                  ('datetime', ['--tap', 'dti']), ('accordion', ['--tap', 'acc'])]
        out = f'{BUILD}/widgets-after/shots'
        if not norender:
            shutil.rmtree(out, ignore_errors=True)
            for t in ('light', 'dark'):
                for label, steps in states:
                    render(site, out, '420x3200' if label == 'rest' else '420x900', t, steps, label, keep=True, full=label == 'rest')
        def shot(label, t):
            size = '420x3200' if label == 'rest' else '420x900'
            return f'{out}/widgets@{size}' + ('-dark' if t == 'dark' else '') + f'-{label}.png'
        rows = [(label, [shot(label, t) for t in ('light', 'dark')]) for label, _ in states]
        sheet('Every catalog type that draws, designed defaults (design_systems/cards): at rest, then open states',
              ['light', 'dark'], rows, f'{ROOT}/all-widgets.png', 420)
    if what in ('all', 'surfaces'):
        # The Flutter-backed surfaces, opened by tapping the buttons of surfaces.json.
        site = f'{BUILD}/surfaces/site'
        shutil.rmtree(site, ignore_errors=True)
        os.makedirs(site)
        shutil.copy(f'{ROOT}/surfaces.json', f'{site}/surfaces.json')
        json.dump({'schema': 3, 'pages': ['surfaces.json'], 'designSystem': os.path.relpath(DS, site)}, open(f'{site}/site.json', 'w'))
        states = [('rest', []), ('confirm', ['--tap', 'bConfirm']), ('toast', ['--tap', 'bToast', '--wait', '600']),
                  ('toastok', ['--tap', 'bToastOk', '--wait', '600']), ('dialog', ['--tap', 'bDialog']), ('sheet', ['--tap', 'bSheet']),
                  ('popover', ['--tap', 'bPop'])]
        out = f'{BUILD}/surfaces/shots'
        if not norender:
            shutil.rmtree(out, ignore_errors=True)
            for t in ('light', 'dark'):
                for label, steps in states:
                    render(site, out, '390x700', t, steps, label, keep=True, full=False, screen='surf')
        rows = [(label, [f'{out}/surf@390x700' + ('-dark' if t == 'dark' else '') + f'-{label}.png' for t in ('light', 'dark')])
                for label, _ in states]
        sheet('Flutter-backed surfaces under the designed defaults', ['light', 'dark'], rows, f'{ROOT}/surfaces.png', 390)
    if what in ('all', 'parts'):
        files = {'parts': f'{ROOT}/parts.txt'}
        if not norender:
            do_render('parts', files, '420x3200', variants=('after',))
        lt, dk = (captures('parts', 'after', files, '420x3200', t)[0]['parts'] for t in ('light', 'dark'))
        sheet('Every plain part, designed defaults (design_systems/cards)', ['light', 'dark'], [('parts', [lt, dk])], f'{ROOT}/parts.png', 420)


if __name__ == '__main__':
    main()

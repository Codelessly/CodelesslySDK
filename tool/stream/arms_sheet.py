#!/usr/bin/env python3
"""The head to head as pictures: per brief, each arm's answer side by side with what it cost.

    python3 tool/stream/arms_sheet.py --out <dir> [--model claude-haiku-5-5] [--only flights,weather] \
        --a2ui "A2UI, its own renderer=2026-11-14-a2ui-1" \
        --arm "Notation, generic parts=2026-11-14-notation-5:ssui" \
        --arm "Notation, designed blocks=2026-11-14-blocks-1:cards"

Folders are under tool/stream/streams/live/. An --a2ui arm is drawn by A2UI's own web renderer
(examples/stream_chat/tool/a2ui_own_renderer, which must be bundled once: npm install && npm run bundle);
an --arm is the recorded document drawn by this SDK under the design system after the colon. A cell that
was retried shows its retry. Writes <dir>/<brief>.png (one row: the arms in the order given) and
<dir>/sheet-<n>.png (the rows stacked, at most six per sheet so no image is taller than a viewer shows).
Nothing here calls a model.
"""
import glob
import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SDK = os.path.dirname(os.path.dirname(HERE))
LIVE = os.path.join(HERE, 'streams', 'live')
OWN = os.path.join(SDK, 'examples', 'stream_chat', 'tool', 'a2ui_own_renderer')
W, PAD, HEAD = 390, 24, 64


def font(size, bold=False):
    for p in ['/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if bold else ''),
              '/usr/share/fonts/truetype/liberation/LiberationSans-%s.ttf' % ('Bold' if bold else 'Regular')]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def opts(name):
    return [sys.argv[i + 1] for i, a in enumerate(sys.argv[:-1]) if a == name]


def summary(folder, ui, model, form):
    f = os.path.join(LIVE, folder, f'{ui}@{model}.{form}.summary.json')
    if not os.path.exists(f):
        return None
    s = json.load(open(f))
    first, last = s['turns'][0], s['turns'][-1]
    return {'in': first['input_tokens'] + first.get('cache_read_input_tokens', 0) + first.get('cache_creation_input_tokens', 0),
            'out': sum(t['output_tokens'] for t in s['turns']), 'total': sum(t['totalMs'] for t in s['turns']) / 1000,
            'turns': len(s['turns']), 'errors': len(last.get('errors', []))}


def shoot_a2ui(folder, out):
    os.makedirs(out, exist_ok=True)
    r = subprocess.run(['node', 'shoot.js', os.path.join(LIVE, folder), out], cwd=OWN, capture_output=True, text=True)
    if r.returncode:
        print('A2UI renderer failed:', (r.stdout + r.stderr)[-600:])


def render_ours(folder, ds, ui, model, out):
    retries = sorted(glob.glob(os.path.join(LIVE, folder, f'{ui}@{model}.notation.retry*.json')))
    doc = retries[-1] if retries else os.path.join(LIVE, folder, f'{ui}@{model}.notation.json')
    if not os.path.exists(doc):
        return None
    site = os.path.join(out, '_site', ui)
    os.makedirs(site, exist_ok=True)
    shutil.copy(doc, os.path.join(site, f'{ui}.json'))
    json.dump({'schema': 3, 'pages': [f'{ui}.json'], 'designSystem': os.path.relpath(os.path.join(SDK, 'design_systems', ds), site)},
              open(os.path.join(site, 'site.json'), 'w'))
    raw = os.path.join(out, '_raw', ui)
    subprocess.run(['tool/render/render.sh', site, '--out', raw, '--sizes', f'{W}x1800'], cwd=SDK, capture_output=True, text=True)
    shots = glob.glob(os.path.join(raw, '*.png'))
    return shots[0] if shots else None


def trim(im, bg=(255, 255, 255)):
    """The image without the empty page under the card."""
    if im.mode == 'RGBA':  # A capture is transparent where the screen draws nothing: show the page there.
        page = Image.new('RGB', im.size, bg)
        page.paste(im, mask=im.split()[3])
        im = page
    im = im.convert('RGB')
    px, (w, h) = im.load(), im.size
    y = h - 1
    while y > 40 and all(px[x, y] == px[0, h - 1] for x in range(0, w, 6)):
        y -= 1
    return im.crop((0, 0, w, min(h, y + 17)))


def main():
    out = opts('--out')[0]
    model = (opts('--model') or ['claude-haiku-5-5'])[0]
    arms = []  # (label, folder, design system or None for A2UI's own renderer)
    for i, a in enumerate(sys.argv[:-1]):
        if a == '--a2ui':
            label, folder = sys.argv[i + 1].split('=', 1)
            arms.append((label, folder, None))
        elif a == '--arm':
            label, rest = sys.argv[i + 1].split('=', 1)
            folder, ds = rest.split(':', 1)
            arms.append((label, folder, ds))
    briefs = sorted({os.path.basename(f).split('@')[0] for _, folder, _ in arms for f in glob.glob(os.path.join(LIVE, folder, f'*@{model}.*summary.json'))})
    if opts('--only'):
        briefs = [b for b in briefs if b in opts('--only')[0].split(',')]
    os.makedirs(out, exist_ok=True)
    for n, (label, folder, ds) in enumerate(arms):
        if ds is None:
            shoot_a2ui(folder, os.path.join(out, f'_arm{n}'))
    rows = []
    for ui in briefs:
        cells = []
        for n, (label, folder, ds) in enumerate(arms):
            if ds is None:
                png, s = os.path.join(out, f'_arm{n}', f'{ui}@{model}.png'), summary(folder, ui, model, 'a2ui')
            else:
                png, s = render_ours(folder, ds, ui, model, os.path.join(out, f'_arm{n}')), summary(folder, ui, model, 'notation')
            im = trim(Image.open(png)) if png and os.path.exists(png) else Image.new('RGB', (W, 120), (250, 250, 250))
            if im.width != W:
                im = im.resize((W, round(im.height * W / im.width)))
            cells.append((label, s, im))
        h = HEAD + max(c[2].height for c in cells) + PAD
        row = Image.new('RGB', (PAD + len(cells) * (W + PAD), h + 34), (244, 244, 245))
        d = ImageDraw.Draw(row)
        d.text((PAD, 8), ui.replace('_', ' '), fill=(24, 24, 27), font=font(18, True))
        for i, (label, s, im) in enumerate(cells):
            x = PAD + i * (W + PAD)
            d.text((x, 38), label, fill=(24, 24, 27), font=font(13, True))
            if s:
                note = f"{s['in']:,} tokens in · {s['out']:,} out · {s['total']:.1f} s" + (f" · {s['turns']} tries" if s['turns'] > 1 else '') + \
                    (f" · {s['errors']} errors" if s['errors'] else '')
                d.text((x, 58), note, fill=(113, 113, 122), font=font(11))
            row.paste(im, (x, 34 + HEAD - 16))
        row.save(os.path.join(out, f'{ui}.png'))
        rows.append(row)
        print(ui, 'ok')
    for k in range(0, len(rows), 6):
        part = rows[k:k + 6]
        sheet = Image.new('RGB', (part[0].width, sum(r.height for r in part)), (244, 244, 245))
        y = 0
        for r in part:
            sheet.paste(r, (0, y))
            y += r.height
        sheet.save(os.path.join(out, f'sheet-{k // 6 + 1}.png'))


if __name__ == '__main__':
    main()

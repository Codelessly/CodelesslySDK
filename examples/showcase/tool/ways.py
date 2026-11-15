#!/usr/bin/env python3
"""The same UIs rendered several ways, put side by side and packed for blind judging (design 16 section 10).

    python3 examples/showcase/tool/ways.py render --set <folder of cases> --out <dir> [--width 390] [--dark]
        --variant ssui= --variant designed=design_systems/cards --variant pass=design_systems/cards+ops
        [--cases a,b,c]
      Each case folder holds ui.txt (the notation) and, for "+ops", ops.json (a recorded pass). A variant is a
      name, then the design system the notation is expanded and rendered with (none: the bundled look), then
      "+ops" to apply the case's recorded operations. A variant's cases are rendered in one run (one page each).
      From 900 wide the notation is expanded at that width (a wide page), else at its default.
      Writes <out>/<variant>/<case>.png (and <case>-dark.png with --dark), cropped, and <variant>/problems.txt.

    python3 examples/showcase/tool/ways.py sheet --out <file.png> --col <title>=<dir> [--col ...] [--cases a,b]
        [--suffix -dark] [--max 7600]
      Rows are cases, columns are the folders' pictures of them; a sheet taller than --max continues in
      <file>-2.png and so on.

    python3 examples/showcase/tool/ways.py pack --out <dir> --col <variant>=<dir> [--col ...] [--seed 7]
      For blind judging by a person or an agent with no API key at hand: <out>/<case>/A.png, B.png... in a
      shuffled order, and <out>/key.json (which letter is which variant; not to be shown to a judge). A judge
      writes <out>/<case>/<judge name>.json: {"rank": [letters, best first], "scores": {letter: 1-10}, "why": ""}.

    python3 examples/showcase/tool/ways.py tally --out <dir>
      Reads the judges' files with the key; writes <out>/judge.json (as judge.py does) and prints mean scores,
      mean rank and how often each variant ranked above each other one.
"""
import collections, glob, itertools, json, os, random, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design_block import SDK, opt, run  # noqa: E402

PAGE = {False: (243, 244, 246), True: (20, 20, 20)}


def opts(name):
    return [sys.argv[i + 1] for i, a in enumerate(sys.argv) if a == name]


def crop(src, dst, dark):
    """The capture on the page color, without the empty rows under the content."""
    from PIL import Image, ImageChops
    im = Image.open(src).convert('RGBA')
    bg = Image.new('RGB', im.size, PAGE[dark])
    bg.paste(im, mask=im.split()[3])
    box = ImageChops.difference(bg, Image.new('RGB', im.size, bg.getpixel((bg.width - 1, bg.height - 1)))).getbbox()
    if box:
        bg = bg.crop((0, 0, bg.width, min(bg.height, box[3] + 16)))
    bg.save(dst)


def render():
    root, out, width = opt('--set'), os.path.abspath(opt('--out')), int(opt('--width', '390'))
    cases = opt('--cases').split(',') if opt('--cases') else sorted(c for c in os.listdir(root) if os.path.exists(f'{root}/{c}/ui.txt'))
    for v in opts('--variant'):
        name, spec = v.split('=', 1)
        ds, ops = (spec[:-4], True) if spec.endswith('+ops') else (spec, False)
        ds = os.path.abspath(os.path.join(SDK, ds)) if ds else ''
        d, site = f'{out}/{name}', f'{out}/{name}/.site'
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(site)
        problems = []
        for c in cases:
            code, log = run(['tool/notation/notation.sh', 'expand', os.path.abspath(f'{root}/{c}/ui.txt'), '--id', c, '--out', f'{site}/{c}.json'] + (['--design-system', ds, '--named'] if ds else []) + (['--width', str(width)] if width >= 900 else []))
            problems += [f'{c}: {l}' for l in log.splitlines() if l.startswith(('ERROR', 'WARNING'))]
            if ops:
                # A recorded pass names the canvas as it was then ("card"); the nodes' ids are the same.
                recorded = json.load(open(f'{root}/{c}/ops.json'))
                was = json.load(open(f'{root}/{c}/before.json'))['roots'][0] if os.path.exists(f'{root}/{c}/before.json') else c
                text = json.dumps(recorded).replace(f'"{was}"', f'"{c}"') if was != c else json.dumps(recorded)
                open(f'{site}/{c}.ops', 'w').write(text)
                code, log = run(['tool/notation/notation.sh', 'apply', f'{site}/{c}.json', f'{site}/{c}.ops', '--design-system', ds, '--out', f'{site}/{c}.json'])
                problems += [f'{c}: {l}' for l in log.splitlines() if l.startswith('ERROR')]
                os.remove(f'{site}/{c}.ops')
        manifest = {'schema': 3, 'pages': [f'{c}.json' for c in cases]}
        if ds:
            manifest['designSystem'] = os.path.relpath(ds, site)
        json.dump(manifest, open(f'{site}/site.json', 'w'))
        for dark in ([False, True] if '--dark' in sys.argv else [False]):
            raw = f'{d}/.raw'
            shutil.rmtree(raw, ignore_errors=True)
            code, log = run(['tool/render/render.sh', site, '--out', raw, '--sizes', f'{width}x1400'] + (['--theme', 'dark'] if dark else []))
            if not dark:
                lines = log.splitlines()
                problems += [l + (' ' + lines[i + 1].strip() if i + 1 < len(lines) else '') for i, l in enumerate(lines) if l.startswith(('ERROR', 'WARNING'))]
            for c in cases:
                shots = glob.glob(f'{raw}/{c}@*.png')
                if shots:
                    crop(shots[0], f"{d}/{c}{'-dark' if dark else ''}.png", dark)
                else:
                    problems.append(f'{c}: no capture{" (dark)" if dark else ""}')
            shutil.rmtree(raw, ignore_errors=True)
        open(f'{d}/problems.txt', 'w').write('\n'.join(problems) + '\n')
        print(f'{name}: {len(cases)} cases, {len(problems)} reported')


def columns():
    return [c.split('=', 1) for c in opts('--col')]


def case_names(cols, suffix=''):
    if opt('--cases'):
        return opt('--cases').split(',')
    return sorted({os.path.basename(f)[:-4 - len(suffix)] for _, d in cols for f in glob.glob(f'{d}/*{suffix}.png') if suffix or not f.endswith('-dark.png')})


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    out, cols, suffix, limit = opt('--out'), columns(), opt('--suffix', ''), int(opt('--max', '7600'))
    dark = suffix == '-dark'
    try:
        font = ImageFont.truetype(f'{SDK}/design_systems/cards/fonts/Inter-SemiBold.otf', 15)
    except Exception:
        font = ImageFont.load_default()
    rows = []
    for c in case_names(cols, suffix):
        ims = [Image.open(f'{d}/{c}{suffix}.png').convert('RGB') if os.path.exists(f'{d}/{c}{suffix}.png') else None for _, d in cols]
        rows.append((c, ims))
    widths = [max([im.width for _, ims in rows if (im := ims[i])] or [200]) for i in range(len(cols))]
    gap, head = 24, 34
    total = sum(widths) + gap * (len(cols) + 1)
    ink, ground = ((235, 235, 235), (10, 10, 10)) if dark else ((17, 24, 39), (255, 255, 255))
    pages, cur, y = [], [], 0
    for c, ims in rows:
        h = max([im.height for im in ims if im] or [40]) + head + gap
        if cur and y + h > limit:
            pages.append(cur)
            cur, y = [], 0
        cur.append((c, ims, h))
        y += h
    pages.append(cur)
    for n, page in enumerate(pages):
        im = Image.new('RGB', (total, sum(h for _, _, h in page) + gap), ground)
        draw, y = ImageDraw.Draw(im), gap
        for c, ims, h in page:
            x = gap
            for (title, _), pic, w in zip(cols, ims, widths):
                draw.text((x, y), f'{c} · {title}', fill=ink, font=font)
                if pic:
                    im.paste(pic, (x, y + head - 8))
                x += w + gap
            y += h
        name = out if n == 0 else out.replace('.png', f'-{n + 1}.png')
        os.makedirs(os.path.dirname(os.path.abspath(name)), exist_ok=True)
        im.save(name)
        print(name, im.size)


def pack():
    out, cols = opt('--out'), columns()
    random.seed(int(opt('--seed', '7')))
    key = {}
    for c in case_names(cols):
        order = [v for v, d in cols if os.path.exists(f'{d}/{c}.png')]
        random.shuffle(order)
        os.makedirs(f'{out}/{c}', exist_ok=True)
        key[c] = {}
        for letter, v in zip('ABCDEFGH', order):
            shutil.copy(f'{dict(cols)[v]}/{c}.png', f'{out}/{c}/{letter}.png')
            key[c][letter] = v
    json.dump(key, open(f'{out}/key.json', 'w'), indent=1)
    print(f'{out}: {len(key)} cases, {len(cols)} versions each')


def tally():
    out = opt('--out')
    key = json.load(open(f'{out}/key.json'))
    results, scores, ranks, above = [], collections.defaultdict(list), collections.defaultdict(list), collections.Counter()
    for c, named in key.items():
        for f in sorted(glob.glob(f'{out}/{c}/*.json')):
            try:
                text = open(f).read()
                j = json.loads(text[text.find('{'):text.rfind('}') + 1])
                r = {'case': c, 'judge': os.path.basename(f)[:-5], 'rank': [named[x] for x in j['rank']], 'scores': {named[k]: v for k, v in j['scores'].items()}, 'why': j.get('why', '')}
            except Exception as e:
                results.append({'case': c, 'judge': os.path.basename(f)[:-5], 'error': str(e)})
                continue
            results.append(r)
            for v, s in r['scores'].items():
                scores[v].append(s)
            for i, v in enumerate(r['rank']):
                ranks[v].append(i + 1)
            for a, b in itertools.combinations(r['rank'], 2):
                above[(a, b)] += 1
    json.dump(results, open(f'{out}/judge.json', 'w'), indent=1)
    good = [r for r in results if 'error' not in r]
    print(f'{len(good)} judgments ({len(results) - len(good)} unreadable)')
    for v in sorted(scores, key=lambda v: -sum(scores[v]) / len(scores[v])):
        print(f'  {v:16s} mean score {sum(scores[v]) / len(scores[v]):.2f}   mean rank {sum(ranks[v]) / len(ranks[v]):.2f}   first in {sum(1 for r in good if r["rank"][0] == v)}')
    for a, b in itertools.combinations(sorted(scores), 2):
        print(f'  {a} above {b}: {above[(a, b)]}, {b} above {a}: {above[(b, a)]}')


if __name__ == '__main__':
    {'render': render, 'sheet': sheet, 'pack': pack, 'tally': tally}[sys.argv[1]]()

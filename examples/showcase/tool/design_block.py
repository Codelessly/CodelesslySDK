#!/usr/bin/env python3
"""A block designed on demand: a strong model writes a new block for a design system at the full API, sees
how it rendered, and revises it. The experiment for the gap between ready-made blocks and new design.

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/design_block.py --name PollResults \
        --brief-file <what the block shows> --card-file <the request a card using it answers> \
        --out <dir> [--model claude-opus-5-5] [--rounds 2] [--design-system design_systems/cards]

Each round: the model answers with the block (a component document) and one card in the notation that uses
it; both are checked and rendered at 420 wide, light and dark, the block alone from its own preview and the
card as it first appears; the pictures and every problem reported go back for the next round. Writes
<out>/round<n>/ (answer.txt, the block, card.txt, block-light.png, block-dark.png, light.png, dark.png,
problems.txt) and <out>/summary.json (seconds and tokens per round). The design system is copied to <out>/ds
and only the copy is changed. The key is read from the environment and never written.

Without a model (a person or an agent as the designer, given exactly what the model is given):

    python3 examples/showcase/tool/design_block.py brief --name PollResults --out <dir>
        writes <dir>/brief.txt: the instructions the model gets, word for word
    python3 examples/showcase/tool/design_block.py check --name PollResults --out <dir> \
        --block <the block's JSON file> --card <the card's notation file>
        one round of the same check: <dir>/round<n>/ with the four pictures and problems.txt
"""
import base64, json, os, re, shutil, subprocess, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SDK = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))


def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def run(cmd):
    r = subprocess.run(cmd, cwd=SDK, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def ask(model, system, messages):
    body = {'model': model, 'max_tokens': 16000, 'system': system, 'messages': messages}
    req = urllib.request.Request('https://api.anthropic.com/v1/messages', data=json.dumps(body).encode(), headers={
        'content-type': 'application/json', 'x-api-key': os.environ['ANTHROPIC_API_KEY'], 'anthropic-version': '2023-06-01'})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=900) as r:
        answer = json.loads(r.read())
    return ''.join(b.get('text', '') for b in answer['content']), round(time.time() - t0, 1), answer.get('usage', {})


def fenced(text, tag):
    m = re.search(r'```' + tag + r'\s*\n([\s\S]*?)\n```', text)
    return m.group(1) if m else None


def image(path):
    return {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/png', 'data': base64.b64encode(open(path, 'rb').read()).decode()}}


def crop(src, dst, dark=False):
    from PIL import Image
    im = Image.open(src).convert('RGBA')
    box = im.getbbox()
    if box:
        im = im.crop((0, 0, im.width, min(im.height, box[3] + 12)))
    # What the capture leaves transparent is the page: light, or the dark set's page.
    bg = Image.new('RGB', im.size, (20, 20, 20) if dark else (236, 236, 236))
    bg.paste(im, mask=im.split()[3])
    bg.save(dst)


def setup(out, src):
    """A copy of the design system under <out>/ds; its manifest."""
    ds = os.path.join(out, 'ds')
    if os.path.exists(ds):
        shutil.rmtree(ds)
    os.makedirs(out, exist_ok=True)
    shutil.copytree(src, ds, ignore=shutil.ignore_patterns('__pycache__'))
    return ds, json.load(open(f'{ds}/design_system.json'))


def brief_for(name, ds, manifest):
    """What the designer is told: the system's principles, its theme names, three of its blocks, the notation."""
    theme = manifest['theme']
    examples = '\n\n'.join(f'{n}.json\n' + open(f'{ds}/components/{n}.json').read() for n in ('ProgressLine', 'OptionList', 'StatTile'))
    # The prompt alone: what the tool prints while it builds is not part of it.
    notation = subprocess.run(['tool/notation/notation.sh', 'prompt', '--design-system', ds], cwd=SDK, capture_output=True, text=True).stdout
    at = notation.find('You describe a UI')
    notation = notation[at:] if at >= 0 else notation
    # What the engine already draws, so a block uses it and does not draw it again by hand: every node type by
    # name, and the chart nodes in full (a designer left without them draws a chart point by point).
    api_ref = os.path.join(os.path.dirname(SDK), 'CodelesslyAPI', 'docs', 'reference')
    types, charts = '', ''
    if os.path.exists(f'{api_ref}/catalog.json'):
        cat = json.load(open(f'{api_ref}/catalog.json'))
        ws = cat.get('nodeTypes', [])
        types = ', '.join(sorted(ws) if isinstance(ws, dict) else sorted(w['type'] if isinstance(w, dict) else str(w) for w in ws))
    if os.path.exists(f'{api_ref}/charts.md'):
        page = open(f'{api_ref}/charts.md').read()
        for name in ('barChart', 'lineChart', 'ChartSeries'):
            m = re.search(r'^### `?' + name + r'`?\n[\s\S]*?(?=^### |\Z)', page, re.M)
            if m:
                charts += m.group(0).strip() + '\n\n'
    system = f"""You are the designer of the "{manifest['name']}" design system: {manifest['description']}
You add one new block to it, at the same visual bar as the blocks it has. A block is a component document (JSON, schema 3): its declaration under "widget" (type, doc, props with kind and default, events) and its nodes, which read their parameters as ${{props.name}} and the theme as ${{theme.colors.name}}. Colors, text styles, radii and shadows are the theme's names, never literal values, so the block is right in light and dark. Sizes, padding and gaps inside a block are yours to write as numbers, as the blocks below do (the system's rule against writing sizes is for someone composing a card from blocks, not for a block's author); radii and shadows take the theme's names. Where the request leaves a rule open (a week's first day, a currency, how many steps), choose the common case, take it as a parameter with that default, and say so in the block's doc.

THE SYSTEM'S PRINCIPLES
{open(f'{ds}/DESIGN.md').read()}

THEME NAMES
colors: {', '.join(theme['colors'])}
text styles (a text's "style"): {', '.join(theme['textStyles'])}
radii (${{theme.radii.name}}): {json.dumps(theme.get('radii'))}
spacing (${{theme.spacing.n}}): {json.dumps(theme.get('spacing'))}
shadows (${{theme.shadows.name}}): {', '.join(theme.get('shadows', {}))}

THREE OF ITS BLOCKS, AS WRITTEN
{examples}

NODE TYPES A BLOCK MAY USE (the engine draws these; use one where it fits, and never draw by hand what a node already is: a chart is a lineChart or barChart node, not a path)
{types}

THE CHART NODES
{charts}
HOW A CARD IS WRITTEN WITH THE BLOCKS (the notation)
{notation}

ANSWER FORMAT
First two or three sentences on the design decisions. Then the block, whole, in a ```json fence (its "id" and "widget.type" are {name}; keep the whole block under about 12,000 characters; keep its doc to one sentence that says how to call it, and give it a "previews" entry with realistic props and a size, as the examples have: that is how you will see it). Then one card that uses it, in a ```notation fence, written as the notation above (your block is called by its name like the others)."""
    return system


def check(name, ds, manifest, d, block, written):
    """Validates and renders a block and the card that uses it into <d>: the block alone from its first preview
    and the card as it first appears, light and dark. Returns the problems reported."""
    os.makedirs(d, exist_ok=True)
    problems = []
    if not block or not written:
        return ['The answer must hold a ```json fence with the block and a ```notation fence with the card.']
    try:
        json.loads(block)
    except ValueError as e:
        return [f'The block is not valid JSON: {e}']
    open(f'{ds}/components/{name}.json', 'w').write(block)
    open(f'{d}/{name}.json', 'w').write(block)
    open(f'{d}/card.txt', 'w').write(written.rstrip('\n') + '\n')
    ref = f'components/{name}.json'
    if ref not in manifest['components']:
        manifest['components'].append(ref)
        json.dump(manifest, open(f'{ds}/design_system.json', 'w'), indent=1)
    site = f'{d}/site'
    os.makedirs(site, exist_ok=True)
    code, log = run(['tool/notation/notation.sh', 'expand', f'{d}/card.txt', '--design-system', ds, '--id', 'card', '--out', f'{site}/card.json'])
    problems += [l for l in log.splitlines() if 'line ' in l or 'does not load' in l or 'rror' in l]
    if not os.path.exists(f'{site}/card.json'):
        return problems

    def reported(log):
        lines = log.splitlines()
        return [l for i, l in enumerate(lines) if l.startswith(('ERROR', 'WARNING')) or (i and lines[i - 1].startswith(('ERROR', 'WARNING')))]

    json.dump({'schema': 3, 'pages': ['card.json'], 'designSystem': os.path.relpath(ds, site)}, open(f'{site}/site.json', 'w'))
    for mode in ('light', 'dark'):
        dark = ['--theme', 'dark'] if mode == 'dark' else []
        for label, cmd in (('', ['tool/render/render.sh', site, '--out', f'{d}/raw-{mode}', '--sizes', '420x1400']),
                           ('block-', ['tool/render/render.sh', site, '--component', name, '--out', f'{d}/block-{mode}'])):
            code, log = run(cmd + dark)
            if mode == 'light':
                problems += [l for l in reported(log) if l not in problems]
            folder = cmd[cmd.index('--out') + 1]
            shots = sorted(f for f in os.listdir(folder) if f.endswith('.png')) if os.path.isdir(folder) else []
            if shots:
                crop(f'{folder}/{shots[0]}', f'{d}/{label}{mode}.png', dark=mode == 'dark')
    open(f'{d}/problems.txt', 'w').write('\n'.join(problems) + '\n')
    return problems


def main():
    name, out = opt('--name'), os.path.abspath(opt('--out'))
    src = os.path.join(SDK, opt('--design-system', 'design_systems/cards'))
    mode = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else 'run'
    if mode == 'check':
        # The check alone, for a designer who is not this script's model: <out>/ds is kept between calls.
        ds = os.path.join(out, 'ds')
        manifest = json.load(open(f'{ds}/design_system.json')) if os.path.exists(ds) else setup(out, src)[1]
        n = len([x for x in os.listdir(out) if x.startswith('round')]) + 1
        problems = check(name, ds, manifest, f'{out}/round{n}', open(opt('--block')).read(), open(opt('--card')).read())
        print(f'round{n}: {len(problems)} problem(s)')
        print('\n'.join(problems))
        print(f'look at: {out}/round{n}/block-light.png block-dark.png light.png dark.png')
        return
    ds, manifest = setup(out, src)
    system = brief_for(name, ds, manifest)
    if mode == 'brief':
        open(f'{out}/brief.txt', 'w').write(system)
        print(f'{out}/brief.txt ({len(system)} characters)')
        return
    model, rounds = opt('--model', 'claude-opus-5-5'), int(opt('--rounds', '2'))
    brief, card = open(opt('--brief-file')).read().strip(), open(opt('--card-file')).read().strip()
    messages = [{'role': 'user', 'content': f'THE BLOCK TO DESIGN: {name}\n{brief}\n\nTHE CARD THAT USES IT answers this request:\n{card}'}]
    summary = {'name': name, 'model': model, 'rounds': []}
    t_all = time.time()
    for n in range(1, rounds + 1):
        text, seconds, usage = ask(model, system, messages)
        d = f'{out}/round{n}'
        os.makedirs(d, exist_ok=True)
        open(f'{d}/answer.txt', 'w').write(text)
        t0 = time.time()
        problems = check(name, ds, manifest, d, fenced(text, 'json'), fenced(text, 'notation'))
        summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'checkAndRenderSeconds': round(time.time() - t0, 1), 'problems': len(problems),
                                  'input_tokens': usage.get('input_tokens'), 'output_tokens': usage.get('output_tokens')})
        print(json.dumps(summary['rounds'][-1]))
        if n == rounds:
            break
        back = [{'type': 'text', 'text': 'This is how it rendered: your block alone from its first preview (light, then dark), then the card as it first appears (light, then dark).'}]
        back += [image(f'{d}/{m}.png') for m in ('block-light', 'block-dark', 'light', 'dark') if os.path.exists(f'{d}/{m}.png')]
        back.append({'type': 'text', 'text': ('Problems reported:\n' + '\n'.join(problems) + '\n\n' if problems else 'No problems were reported.\n\n') +
                     'Look at it as the art director: hierarchy, spacing, alignment, contrast in both modes, whether it sits at the bar of the other blocks, and whether anything is broken or empty. Fix every problem, then answer again in the same format, block and card whole.'})
        messages += [{'role': 'assistant', 'content': text}, {'role': 'user', 'content': back}]
    summary['totalSeconds'] = round(time.time() - t_all, 1)
    json.dump(summary, open(f'{out}/summary.json', 'w'), indent=1)


if __name__ == '__main__':
    main()

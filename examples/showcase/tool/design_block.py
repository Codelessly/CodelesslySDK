#!/usr/bin/env python3
"""A block designed on demand: a strong model writes a new block for a design system at the full API, sees
how it rendered, and revises it. The experiment for the gap between ready-made blocks and new design.

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/design_block.py --name PollResults \
        --brief-file <what the block shows> --card-file <the request a card using it answers> \
        --out <dir> [--model claude-opus-5-5] [--rounds 2] [--design-system design_systems/cards]

Each round: the model answers with the block (a component document) and one card in the notation that uses
it; both are checked and rendered at 420 wide, light and dark, the block alone from its own preview and the
card as it first appears, the card again in a 320-wide column, and, when the answer gives steps in a ```use fence, the card after them with
its texts tested; the pictures and every problem reported go
back for the next round. The round with the fewest problems is kept, and the script exits 1 when that round
still has any. Writes
<out>/round<n>/ (answer.txt, the block, card.txt, block-light.png, block-dark.png, light.png, dark.png,
problems.txt) and <out>/summary.json (seconds and tokens per round). The design system is copied to <out>/ds
and only the copy is changed. The key is read from the environment and never written.

Without a model (a person or an agent as the designer, given exactly what the model is given):

    python3 examples/showcase/tool/design_block.py brief --name PollResults --out <dir>
        writes <dir>/brief.txt: the instructions the model gets, word for word
    python3 examples/showcase/tool/design_block.py check --name PollResults --out <dir> \
        --block <the block's JSON file> --card <the card's notation file> [--use <a JSON file of steps and texts>]
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
    body = {'model': model, 'max_tokens': 32000, 'system': system, 'messages': messages}
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
        for chart_name in ('barChart', 'lineChart', 'ChartSeries'):
            m = re.search(r'^### `?' + chart_name + r'`?\n[\s\S]*?(?=^### |\Z)', page, re.M)
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
First two or three sentences on the design decisions. Then the block, whole, in a ```json fence (its "id" and "widget.type" are {name}; keep the whole block under about 12,000 characters; keep its doc to one sentence that says how to call it, and give it a "previews" entry with realistic props and a size, as the examples have: that is how you will see it). Then one card that uses it, in a ```notation fence, written as the notation above (your block is called by its name like the others). If the block does anything when used (a tap, a drag, typing), end with a ```use fence holding JSON that proves it works: {{"steps": [...], "expect": [...], "forbid": [...]}}. A step is {{"tap": "<node>"}}, {{"type": "<node>", "text": "..."}}, {{"drag": "<node>", "by": [dx, dy]}} or {{"wait": ms}}. <node> is the id of a node inside your block, or a node of the card: a card's node is its type and its number among that type from 1 (ActionButton1, OptionList1), with a part inside it after a slash (ActionButton1/btn is the button, OptionList1/opt#1 its second option, ChoiceChips1/chip#0, Segments1/cell#2, InputField1/field, TotalBar1/cta); expect and forbid are regular expressions tested against the texts on the card after the steps (expect: each must match some text; forbid: none may). Choose steps and texts that would fail if the block only looked right: the value that must change, the state that must clear. A block that only shows data needs no use fence."""
    return system


def check(name, ds, manifest, d, block, written, use=None):
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
        # One entry per problem (its line and the line under it, which says where), without the build's own chatter.
        lines = [re.sub(r'^(Running build hooks\.\.\.)+', '', l) for l in lines]
        return [l + ('\n' + lines[i + 1] if i + 1 < len(lines) and not lines[i + 1].startswith(('ERROR', 'WARNING')) else '')
                for i, l in enumerate(lines) if l.startswith(('ERROR', 'WARNING'))]

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
    # The same card in a narrow chat column: what overflows or breaks there is a problem too. (Outside runs,
    # 2026-11-15: blocks that passed at one width were sized for it and broke at others.)
    code, log = run(['tool/render/render.sh', site, '--out', f'{d}/raw-narrow', '--sizes', '320x1400'])
    problems += [f'At 320 wide: {l}' for l in reported(log) if l not in problems]
    shots = sorted(f for f in os.listdir(f'{d}/raw-narrow') if f.endswith('.png')) if os.path.isdir(f'{d}/raw-narrow') else []
    if shots:
        crop(f'{d}/raw-narrow/{shots[0]}', f'{d}/narrow.png', dark=False)
    problems += used(name, site, d, use)
    open(f'{d}/problems.txt', 'w').write('\n'.join(problems) + '\n')
    return problems


def used(name, site, d, use):
    """Drives the card as the designer's ```use fence says and tests the texts on it afterwards: what a block
    does, not only how it first looks. (Outside runs, 2026-11-15: six blocks passed the first-state check and
    one was usable.) With no fence, the card as it first appears is still read for values that were not worked out."""
    try:
        case = json.loads(use) if use else {}
        card = json.load(open(f'{site}/card.json'))
    except (ValueError, OSError) as e:
        return [f'The use fence is not valid JSON: {e}'] if use else []
    at = next((k for k, n in card['nodes'].items() if n['type'] == name), None)
    steps, problems = [], []
    def node(ref):
        # A node of the card as written (ActionButton1/btn), else a node inside the block.
        return ref if ref.split('/')[0].split('#')[0] in card['nodes'] else f'{at}/{ref}'

    for s in case.get('steps', []):
        if at is None:
            return [f'The card does not call {name}, so its use cannot be driven.']
        if 'tap' in s:
            steps += ['--tap', node(s['tap'])]
        elif 'type' in s:
            steps += ['--type', f"{node(s['type'])}={s.get('text', '')}"]
        elif 'drag' in s:
            steps += ['--drag', f"{node(s['drag'])}={s['by'][0]},{s['by'][1]}"]
        elif 'wait' in s:
            steps += ['--wait', str(s['wait'])]
    code, log = run(['tool/render/render.sh', site, '--out', f'{d}/raw-used', '--sizes', '420x1400', '--dump-layout'] + steps)
    problems += [f'After the steps: {l.strip()}' for l in log.splitlines() if l.startswith('ERROR') and 'interaction_failed' in l]
    folder = f'{d}/raw-used'
    dumps = [f for f in os.listdir(folder) if f.endswith('.layout.json')] if os.path.isdir(folder) else []
    texts = [b['text'] for b in json.load(open(f'{folder}/{dumps[0]}')) if b.get('text')] if dumps else []
    shots = sorted(f for f in os.listdir(folder) if f.endswith('.png')) if os.path.isdir(folder) else []
    if shots and steps:
        crop(f'{folder}/{shots[0]}', f'{d}/used.png', dark=False)
    shown = ' | '.join(texts)[:600]
    for e in case.get('expect', []):
        if not any(re.search(e, t) for t in texts):
            problems.append(f'After the steps no text on the card matches {e!r}. The card shows: {shown}')
    for e in list(case.get('forbid', [])) + [r'\$\{', r'\{[a-z_][A-Za-z0-9_.]*\}', r'\bNaN\b', r'\bundefined\b']:
        hit = next((t for t in texts if re.search(e, t)), None)
        if hit is not None:
            problems.append(f'After the steps a text on the card matches {e!r}, which must not show: "{hit[:120]}"')
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
        problems = check(name, ds, manifest, f'{out}/round{n}', open(opt('--block')).read(), open(opt('--card')).read(),
                         open(opt('--use')).read() if opt('--use') else None)
        print(f'round{n}: {len(problems)} problem(s)')
        print('\n'.join(problems))
        print(f'look at: {out}/round{n}/block-light.png block-dark.png light.png dark.png narrow.png used.png')
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
        # The designer may keep what it has: a further round is taken only when it would change something. (Six
        # outside runs found a forced third round as often made a block worse as better.)
        if n > 1 and text.strip().upper().startswith('SHIP') and '```' not in text:
            summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'kept': n - 1, 'input_tokens': usage.get('input_tokens'), 'output_tokens': usage.get('output_tokens')})
            summary['final'] = n - 1
            print(json.dumps(summary['rounds'][-1]))
            break
        summary['final'] = n
        t0 = time.time()
        problems = check(name, ds, manifest, d, fenced(text, 'json'), fenced(text, 'notation'), fenced(text, 'use'))
        summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'checkAndRenderSeconds': round(time.time() - t0, 1), 'problems': len(problems),
                                  'input_tokens': usage.get('input_tokens'), 'output_tokens': usage.get('output_tokens')})
        print(json.dumps(summary['rounds'][-1]))
        if n == rounds:
            break
        back = [{'type': 'text', 'text': 'This is how it rendered: your block alone from its first preview (light, then dark), then the card as it first appears (light, then dark), then the card in a narrow column (320 wide), then, when you gave steps, the card after them.'}]
        back += [image(f'{d}/{m}.png') for m in ('block-light', 'block-dark', 'light', 'dark', 'narrow', 'used') if os.path.exists(f'{d}/{m}.png')]
        back.append({'type': 'text', 'text': ('Problems reported:\n' + '\n'.join(problems) + '\n\n' if problems else 'No problems were reported.\n\n') +
                     'Look at it as the art director: hierarchy, spacing, alignment, contrast in both modes, whether it sits at the bar of the other blocks, and whether anything is broken or empty. If nothing is reported and you would ship it as it is, answer with the one word SHIP and nothing else: a round that changes what was already right makes it worse. Otherwise fix every problem and answer again in the same format, block and card whole.'})
        messages += [{'role': 'assistant', 'content': text}, {'role': 'user', 'content': back}]
    # The round kept is the one with the fewest problems (the later of equals), not simply the last: a further
    # round has made a block worse (outside runs, 2026-11-15: 58, 4, then 38 problems, and the third shipped).
    checked = [r for r in summary['rounds'] if 'problems' in r]
    if checked:
        best = min(checked, key=lambda r: (r['problems'], -r['round']))
        summary['final'] = best['round']
        summary['problems'] = best['problems']
        summary['status'] = 'passed' if best['problems'] == 0 else 'failed'
    summary['totalSeconds'] = round(time.time() - t_all, 1)
    json.dump(summary, open(f'{out}/summary.json', 'w'), indent=1)
    print(json.dumps({k: summary.get(k) for k in ('final', 'status', 'problems', 'totalSeconds')}))
    if summary.get('status') == 'failed':
        sys.exit(1)


if __name__ == '__main__':
    main()

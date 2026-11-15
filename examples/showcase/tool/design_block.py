#!/usr/bin/env python3
"""A block designed on demand: a strong model writes a new block for a design system at the full API, sees
how it rendered, and revises it. The experiment for the gap between ready-made blocks and new design.

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/design_block.py --name PollResults \
        --brief-file <what the block shows> --card-file <the request a card using it answers> \
        --out <dir> [--model claude-opus-5-5] [--rounds 2] [--design-system design_systems/cards]

Each round: the model answers with the block (a component document) and one card in the notation that uses
it; both are checked and rendered at 420 wide, light and dark; the pictures and every problem reported go
back for the next round. Writes <out>/round<n>/ (the block, the card, light.png, dark.png, problems.txt)
and <out>/summary.json (seconds and tokens per round). The design system is copied to <out>/ds and only the
copy is changed. The key is read from the environment and never written.
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


def crop(src, dst):
    from PIL import Image
    im = Image.open(src).convert('RGBA')
    box = im.getbbox()
    if box:
        im = im.crop((0, 0, im.width, min(im.height, box[3] + 12)))
    bg = Image.new('RGB', im.size, (236, 236, 236))
    bg.paste(im, mask=im.split()[3])
    bg.save(dst)


def main():
    name, out = opt('--name'), os.path.abspath(opt('--out'))
    model, rounds = opt('--model', 'claude-opus-5-5'), int(opt('--rounds', '2'))
    src = os.path.join(SDK, opt('--design-system', 'design_systems/cards'))
    brief, card = open(opt('--brief-file')).read().strip(), open(opt('--card-file')).read().strip()
    ds = os.path.join(out, 'ds')
    if os.path.exists(ds):
        shutil.rmtree(ds)
    os.makedirs(out, exist_ok=True)
    shutil.copytree(src, ds, ignore=shutil.ignore_patterns('__pycache__'))
    manifest = json.load(open(f'{ds}/design_system.json'))
    theme = manifest['theme']
    examples = '\n\n'.join(f'{n}.json\n' + open(f'{ds}/components/{n}.json').read() for n in ('ProgressLine', 'OptionList', 'StatTile'))
    _, notation = run(['tool/notation/notation.sh', 'prompt', '--design-system', ds])
    notation = notation[notation.index('You describe a UI'):]
    system = f"""You are the designer of the "{manifest['name']}" design system: {manifest['description']}
You add one new block to it, at the same visual bar as the blocks it has. A block is a component document (JSON, schema 3): its declaration under "widget" (type, doc, props with kind and default, events) and its nodes, which read their parameters as ${{props.name}} and the theme as ${{theme.colors.name}}. Colors, text styles, radii and shadows are the theme's names, never literal values, so the block is right in light and dark.

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

HOW A CARD IS WRITTEN WITH THE BLOCKS (the notation)
{notation}

ANSWER FORMAT
First two or three sentences on the design decisions. Then the block, whole, in a ```json fence (its "id" and "widget.type" are {name}; keep its doc to one sentence that says how to call it, and give it a "previews" entry with realistic props and a size, as the examples have: that is how you will see it). Then one card that uses it, in a ```notation fence, written as the notation above (your block is called by its name like the others)."""
    messages = [{'role': 'user', 'content': f'THE BLOCK TO DESIGN: {name}\n{brief}\n\nTHE CARD THAT USES IT answers this request:\n{card}'}]
    summary = {'name': name, 'model': model, 'rounds': []}
    t_all = time.time()
    for n in range(1, rounds + 1):
        text, seconds, usage = ask(model, system, messages)
        d = f'{out}/round{n}'
        os.makedirs(d, exist_ok=True)
        open(f'{d}/answer.txt', 'w').write(text)
        block, written = fenced(text, 'json'), fenced(text, 'notation')
        problems = []
        t0 = time.time()
        if not block or not written:
            problems.append('The answer must hold a ```json fence with the block and a ```notation fence with the card.')
        else:
            try:
                json.loads(block)
            except ValueError as e:
                problems.append(f'The block is not valid JSON: {e}')
        if not problems:
            open(f'{ds}/components/{name}.json', 'w').write(block)
            open(f'{d}/{name}.json', 'w').write(block)
            open(f'{d}/card.txt', 'w').write(written + '\n')
            ref = f'components/{name}.json'
            if ref not in manifest['components']:
                manifest['components'].append(ref)
                json.dump(manifest, open(f'{ds}/design_system.json', 'w'), indent=1)
            site = f'{d}/site'
            os.makedirs(site, exist_ok=True)
            code, log = run(['tool/notation/notation.sh', 'expand', f'{d}/card.txt', '--design-system', ds, '--id', 'card', '--out', f'{site}/card.json'])
            problems += [l for l in log.splitlines() if 'line ' in l or 'does not load' in l or 'rror' in l]
            if os.path.exists(f'{site}/card.json'):
                json.dump({'schema': 3, 'pages': ['card.json'], 'designSystem': os.path.relpath(ds, site)}, open(f'{site}/site.json', 'w'))
                for mode in ('light', 'dark'):
                    cmd = ['tool/render/render.sh', site, '--out', f'{d}/raw-{mode}', '--sizes', '420x1400'] + (['--theme', 'dark'] if mode == 'dark' else [])
                    code, log = run(cmd)
                    lines = log.splitlines()
                    if mode == 'light':
                        problems += [l for i, l in enumerate(lines) if l.startswith(('ERROR', 'WARNING')) or (i and lines[i - 1].startswith(('ERROR', 'WARNING')))]
                    shots = [f for f in os.listdir(f'{d}/raw-{mode}') if f.endswith('.png')] if os.path.isdir(f'{d}/raw-{mode}') else []
                    if shots:
                        crop(f'{d}/raw-{mode}/{shots[0]}', f'{d}/{mode}.png')
                    # The block alone, from its own previews: a card may not show it until something is tapped.
                    cmd = ['tool/render/render.sh', site, '--component', name, '--out', f'{d}/block-{mode}'] + (['--theme', 'dark'] if mode == 'dark' else [])
                    code, log = run(cmd)
                    lines = log.splitlines()
                    if mode == 'light':
                        problems += [l for i, l in enumerate(lines) if (l.startswith(('ERROR', 'WARNING')) or (i and lines[i - 1].startswith(('ERROR', 'WARNING')))) and l not in problems]
                    shots = sorted(f for f in os.listdir(f'{d}/block-{mode}') if f.endswith('.png')) if os.path.isdir(f'{d}/block-{mode}') else []
                    if shots:
                        crop(f'{d}/block-{mode}/{shots[0]}', f'{d}/block-{mode}.png')
        open(f'{d}/problems.txt', 'w').write('\n'.join(problems) + '\n')
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

#!/usr/bin/env python3
"""The style pass: a card a fast model wrote from plain parts is on screen; a design agent looks at it and
restyles it in place with edit operations. The card is not written again, so what it says, its state and its
actions stay as they were; only how it looks changes. The experiment for "fast, then designed".

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/style_pass.py --card <document.json> --out <dir> \
        [--request <file: what the user asked for>] [--model claude-opus-5-5] [--rounds 2] \
        [--design-system design_systems/cards] [--site <site folder>] [--width 420] [--narrow 320] [--blocks]

--blocks tells the agent of the design system's own blocks (each one's purpose, props and events, and the three
closest to the request as written) and lets it put a block in place of plain nodes that show the same thing.

--width and --narrow are the widths it is rendered at (a full page on a desktop: --width 1280 --narrow 768).
--site renders the card in its full site manifest, including sibling pages and theme overrides.

<document.json> is the card as a layout document (a recording's .notation.json, or what
tool/notation/notation.sh expand wrote). Each round: the agent is shown the card's render (light, dark and 320
wide) and its nodes, and answers with {"ops": [...]}; the ops are applied (tool/notation/notation.sh apply),
the result is rendered with the design system's theme, and what the appliers and the renderer report, plus
any text the card showed before and no longer shows, go back with the new pictures. The round with the
fewest problems is kept. Writes <out>/before/, <out>/round<n>/ (answer.txt, ops.json, card.json, light.png,
dark.png, narrow.png, problems.txt), <out>/after.json and <out>/summary.json (seconds and tokens per round).
The key is read from the environment and never written.

--block-pictures <dir> (with --blocks) also shows the agent pictures of those three blocks: <dir>/<Type>.png, which
`style_pass.py block-pictures --out <dir>` renders from each block's first preview.

    python3 examples/showcase/tool/style_pass.py brief --card <document.json> --out <dir>
        writes <dir>/brief.txt: the instructions the agent gets, word for word (no model is called)

With no key at hand the design agent can be any agent that reads files and pictures; the tool does the rest:

    style_pass.py prepare --card <document.json> --out <dir> [the options above]
        renders the card (before/light.png, dark.png, narrow.png), writes brief.txt and, with --block-pictures,
        copies the closest blocks' pictures to <dir>/blocks/
    style_pass.py check --out <dir> --round <n>
        reads <dir>/round<n>/answer.txt (the agent's answer), applies and renders it and writes
        round<n>/problems.txt and the three pictures, as a round of the run does
    style_pass.py finish --out <dir>
        keeps the round with the fewest problems: after.json and summary.json
"""
import json, os, shutil, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design_block import SDK, ask, crop, fenced, image, opt, run  # noqa: E402


def reported(log):
    lines = [l for l in log.splitlines()]
    return [l + ('\n' + lines[i + 1] if i + 1 < len(lines) and not lines[i + 1].startswith(('ERROR', 'WARNING')) else '')
            for i, l in enumerate(lines) if l.startswith(('ERROR', 'WARNING'))]


def render(card, ds, d, width=420, narrow=320, site=None):
    """Renders <card> with the design system's theme into <d>: light.png, dark.png, narrow.png. Returns the
    problems the renderer reported (light, at 420 and at 320) and the texts on the card."""
    os.makedirs(d, exist_ok=True)
    problems, texts = [], []
    source = card
    screen = None
    if site:
        manifest = json.load(open(f'{site}/site.json'))
        screen = json.load(open(card))['roots'][0]
        local = f'{d}/.site'
        os.makedirs(local, exist_ok=True)
        staged = dict(manifest)
        staged['designSystem'] = os.path.relpath(ds, local)
        found = False
        for page in manifest['pages']:
            original = os.path.join(site, page)
            target = os.path.join(local, page)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            if json.load(open(original))['roots'][0] == screen:
                shutil.copyfile(card, target)
                found = True
            elif not os.path.exists(target):
                os.symlink(original, target)
        if not found:
            raise ValueError(f'{screen} is not a page in {site}/site.json')
        json.dump(staged, open(f'{local}/site.json', 'w'))
        source = local
    # A card is captured in a tall window; a page (a desktop width) to its end, and an app window (a canvas
    # as tall as its window) at the window's size.
    tall, whole = 1400, []
    if width >= 700:
        doc = json.load(open(card))
        height = doc['nodes'][doc['roots'][0]].get('layout', {}).get('height')
        tall, whole = 800, ([] if isinstance(height, dict) and 'fill' in height else ['--full-page'])
    for name, extra in (('light', ['--sizes', f'{width}x{tall}', '--dump-layout'] + whole), ('dark', ['--sizes', f'{width}x{tall}', '--theme', 'dark'] + whole),
                        ('narrow', ['--sizes', f'{narrow}x{tall}'] + whole)):
        folder = f'{d}/raw-{name}'
        shutil.rmtree(folder, ignore_errors=True)
        code, log = run(['tool/render/render.sh', source, '--out', folder] + (['--screen', screen] if screen else ['--design-system', ds]) + extra)
        if name != 'dark':
            problems += [(f'At {narrow} wide: ' if name == 'narrow' else '') + l for l in reported(log) if l not in problems]
        shots = sorted(f for f in os.listdir(folder) if f.endswith('.png')) if os.path.isdir(folder) else []
        if shots:
            crop(f'{folder}/{shots[0]}', f'{d}/{name}.png', dark=name == 'dark')
        dumps = [f for f in os.listdir(folder) if f.endswith('.layout.json')] if os.path.isdir(folder) else []
        if dumps:
            texts = [b['text'] for b in json.load(open(f'{folder}/{dumps[0]}')) if b.get('text')]
    return problems, texts


NEAR = []  # the closest blocks of the last brief, by type


def own_blocks(ds, manifest):
    """The design system's own blocks (not the stock controls it copies from its base), as their documents."""
    base = os.path.join(os.path.dirname(ds), 'ssui', 'components')
    stock = set(os.listdir(base)) if os.path.isdir(base) and os.path.basename(ds) != 'ssui' else set()
    out = []
    for ref in manifest['components']:
        if os.path.basename(ref) in stock or not os.path.exists(f'{ds}/{ref}'):
            continue
        d = json.load(open(f'{ds}/{ref}'))
        if isinstance(d.get('widget'), dict):
            out.append(d)
    return out


def blocks_section(ds, manifest, doc, request, exemplars=3):
    """What the agent is told of the system's blocks: each one's purpose, props and events, and the few closest
    to this request as written, so it sees the bar and can use a block where one fits."""
    blocks = own_blocks(ds, manifest)
    if not blocks:
        return ''
    words = lambda t: {w for w in ''.join(c.lower() if c.isalnum() else ' ' for c in t).split() if len(w) > 3}
    said = words(request + ' ' + ' '.join(str((n.get('props') or {}).get('text', '')) for n in doc['nodes'].values()))
    lines = []
    for d in blocks:
        w = d['widget']
        props = ', '.join(f"{p['key']} ({(p.get('type') or {}).get('kind', '?')}{', required' if p.get('required') else ''})" for p in w.get('props', []))
        events = ', '.join(e['key'] for e in w.get('events', []))
        root = (d['nodes'].get((d.get('roots') or [''])[0]) or {}).get('layout') or {}
        size = json.dumps({k: root[k] for k in ('width', 'height') if k in root})
        lines.append(f"{w['type']}: {w.get('doc', '')}\n    props: {props or 'none'}{'; events: ' + events if events else ''}{'; takes children' if w.get('slots') else ''}\n    layout: {size}")
    near = sorted(blocks, key=lambda d: -len(said & words(d['widget'].get('doc', '') + ' ' + d['widget']['type'])))[:exemplars]
    shown = '\n\n'.join(f"{d['widget']['type']}\n{json.dumps(d['nodes'], indent=1)}" for d in near)
    NEAR[:] = [d['widget']['type'] for d in near]
    return f"""
THE SYSTEM'S BLOCKS (the bar; use one where it fits)
A block is a designed part. Where a group of plain nodes shows what a block shows, put the block in their place: set a node whose "type" is the block's name under the same parent ("props" for fixed values; "bind": {{"props.name": "${{…}}"}} for a value that was bound; an event as "actions": [{{"trigger": {{"type": "event", "event": "onPressed"}}, "actions": [the same actions the plain node had]}}]), then remove the plain nodes it replaces. Everything those nodes said, every binding and every action must be carried into the block; if a block cannot show all of it, do not use it there. A block node has no size of its own in the document: write its "layout" with the width and height listed for it below (a block 46 high is {{"height": 46}}, never {{"hug": 0}} and never left out, or it is drawn flat); its width may be {{"fill": n}} or {{"hug": 0}} where the row needs it. Two blocks side by side must both fit at the narrow width with their labels and icons: stack them or drop an icon if they do not. Where no block fits, build at the same bar from plain nodes.
{chr(10).join(lines)}

THE CLOSEST BLOCKS, AS WRITTEN (this is the level of composition to reach: a focal element, drawn detail, grouped facts)
{shown}
"""


def brief_for(ds, doc, request, blocks=False):
    manifest = json.load(open(f'{ds}/design_system.json'))
    theme = manifest['theme']
    code, ops = run(['tool/notation/notation.sh', 'apply', '--reference'])
    ops = ops[ops.find('set:'):] if 'set:' in ops else ops
    example = json.load(open(f'{ds}/components/StatTile.json'))['nodes']
    return f"""You are the art director of the "{manifest['name']}" design system: {manifest['description']}
A fast model has just written a card from plain parts (rows, columns, texts, the stock controls) and it is on screen now. It is correct and it looks generic. You restyle it IN PLACE, by edit operations on its nodes, so that it sits at the visual bar of this design system. The card is not written again.

WHAT MUST NOT CHANGE
- What the card says: every text, number and label, and every binding ("bind", "${{…}}" in a value), stays as it is. Do not rewrite copy.
- What the card does: every "actions" list, every variable, every node id and every node's type. Do not remove a node that shows content or takes input{', unless a block takes its place and carries what it said and did' if blocks else ''}.
- The order of its content, unless the layout needs it.

WHAT YOU MAY CHANGE
- Layout: padding, spacing, alignment, sizes (a number, {{"hug": n}}, {{"fill": n}}).
- Decoration: fills, strokes, radius, shadows; the card's own surface.
- Text: "props.style" (a theme text style by name with {{"from": "name"}}, color, fontSize, fontWeight).
- Structure for the sake of looks: wrap nodes in a new row, column or box (set the new node under the old parent, then move the nodes into it), add a divider, an icon ({{"type": "icon", "props": {{"icon": "name"}}}}, Material rounded names), an accent bar or a tinted panel.
Make the hierarchy read at a glance: one focal value or title, calm secondary detail, grouped rows on a quiet panel, generous and even spacing, the one main action clear. Use the theme's names for every color, radius, shadow and text style so it follows light and dark. It must hold in dark mode and in a 320-wide column.

THE SYSTEM'S PRINCIPLES
{open(f'{ds}/DESIGN.md').read()}

THEME NAMES
colors: {', '.join([k for k in ('primary', 'onPrimary', 'surface', 'onSurface', 'error', 'success', 'warning') if k in theme] + list(theme['colors']))}
text styles ({{"from": "name"}}): {', '.join(theme.get('textStyles', {}))}
radii (bound, not written: "bind": {{"decoration.radius": "${{theme.radii.name}}"}}): {', '.join(theme.get('radii', {}))}
shadows (bound the same way: "bind": {{"decoration.effects": "${{theme.shadows.name}}"}}; there is no "shadows" key): {', '.join(theme.get('shadows', {}))}
A color is written as one of the names above, exactly, or as #AARRGGBB; prefer names, and write no name that is not listed.

HOW NODES OF THIS SYSTEM ARE WRITTEN (one of its blocks, for the shape of layout, decoration and text style)
{json.dumps(example, indent=1)}

{blocks_section(ds, manifest, doc, request) if blocks else ''}
THE EDIT OPERATIONS
{ops.strip()}

THE CARD NOW (its nodes; the canvas is "{doc['roots'][0]}")
{json.dumps(doc['nodes'], indent=1)}
{('WHAT THE USER ASKED FOR' + chr(10) + request + chr(10)) if request else ''}
ANSWER
Two or three sentences on what you change and why. Then one ```json fence holding {{"ops": [...]}}: every op in the order it is applied. Patch what exists; set only what is new."""


def check_round(out, ds, n, text, problems0, texts0, width, narrow, site=None):
    """Applies and renders the answer of round <n>; writes its problems. Returns (problems, how many ops)."""
    d = f'{out}/round{n}'
    os.makedirs(d, exist_ok=True)
    open(f'{d}/answer.txt', 'w').write(text)
    ops = fenced(text, 'json')
    problems = []
    if not ops:
        problems = ['The answer must hold a ```json fence with {"ops": [...]}.']
    else:
        open(f'{d}/ops.json', 'w').write(ops)
        # Each round's ops are applied to the card as it was before the pass: a round replaces the last, it does not stack on it.
        code, log = run(['tool/notation/notation.sh', 'apply', f'{out}/before.json', f'{d}/ops.json', '--design-system', ds, '--out', f'{d}/card.json'])
        problems += [l for l in log.splitlines() if l.startswith('ERROR')]
        if os.path.exists(f'{d}/card.json'):
            rendered, texts = render(f'{d}/card.json', ds, d, width, narrow, site)
            problems += [l for l in rendered if l not in problems0]
            shown = ' '.join(texts)
            # With a block in place of plain nodes a text may be drawn in parts or joined with another: it is
            # gone only when what it said is nowhere on the card.
            # ...or in pieces (a block draws "07:15" and "09:50" where the card said "07:15 → 09:50"): every
            # word of it that holds a letter or a digit must still be on the card.
            words = lambda t: [w for w in t.split() if any(c.isalnum() for c in w)]
            gone = [t for t in texts0 if t not in texts and t not in shown and not all(w in shown for w in words(t))]
            problems += [f'A text the card showed is gone: "{t[:80]}". The pass must not change what the card says.' for t in gone[:12]]
    open(f'{d}/problems.txt', 'w').write('\n'.join(problems) + '\n')
    try:
        count = len(json.loads(ops).get('ops', [])) if ops else 0
    except Exception:
        count = 0
    return problems, count


def finish(out, summary):
    checked = [r for r in summary['rounds'] if 'problems' in r and os.path.exists(f"{out}/round{r['round']}/card.json")]
    if checked:
        best = min(checked, key=lambda r: (r['problems'], -r['round']))
        summary['final'], summary['problems'] = best['round'], best['problems']
        summary['status'] = 'passed' if best['problems'] == 0 else 'failed'
        shutil.copy(f"{out}/round{best['round']}/card.json", f'{out}/after.json')
        shutil.copy(f"{out}/round{best['round']}/ops.json", f'{out}/ops.json')
    else:
        summary['status'] = 'failed'
    json.dump(summary, open(f'{out}/summary.json', 'w'), indent=1)
    print(json.dumps({k: summary.get(k) for k in ('final', 'status', 'problems', 'totalSeconds')}))


def block_pictures(ds, out):
    """Each own block's first preview, rendered alone: <out>/<Type>.png."""
    manifest = json.load(open(f'{ds}/design_system.json'))
    site = f'{out}/.site'
    os.makedirs(site, exist_ok=True)
    json.dump({'schema': 3, 'roots': ['c'], 'nodes': {'c': {'type': 'canvas', 'children': []}}}, open(f'{site}/empty.json', 'w'))
    json.dump({'schema': 3, 'pages': ['empty.json'], 'designSystem': os.path.relpath(ds, site)}, open(f'{site}/site.json', 'w'))
    for d in own_blocks(ds, manifest):
        t = d['widget']['type']
        raw = f'{out}/.raw'
        shutil.rmtree(raw, ignore_errors=True)
        run(['tool/render/render.sh', site, '--component', t, '--out', raw])
        shots = sorted(f for f in os.listdir(raw) if f.endswith('.png')) if os.path.isdir(raw) else []
        if shots:
            crop(f'{raw}/{shots[0]}', f'{out}/{t}.png')
        print(t, 'ok' if shots else 'no picture', flush=True)
        shutil.rmtree(raw, ignore_errors=True)
    shutil.rmtree(site, ignore_errors=True)


def main():
    if '--help' in sys.argv or '-h' in sys.argv:
        print(__doc__)
        return
    mode = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else 'run'
    out = os.path.abspath(opt('--out'))
    os.makedirs(out, exist_ok=True)
    ds = os.path.join(SDK, opt('--design-system', 'design_systems/cards'))
    if mode == 'block-pictures':
        return block_pictures(ds, out)
    if mode in ('check', 'finish'):
        st = json.load(open(f'{out}/state.json'))
        if mode == 'check':
            n = int(opt('--round'))
            t0 = time.time()
            problems, count = check_round(out, st['ds'], n, open(f'{out}/round{n}/answer.txt').read(), st['problems0'], st['texts0'], st['width'], st['narrow'], st.get('site'))
            st['rounds'] = [r for r in st['rounds'] if r['round'] != n] + [{'round': n, 'checkAndRenderSeconds': round(time.time() - t0, 1), 'problems': len(problems), 'ops': count}]
            json.dump(st, open(f'{out}/state.json', 'w'), indent=1)
            print(f'round {n}: {count} operations, {len(problems)} problem(s). Pictures: {out}/round{n}/light.png, dark.png, narrow.png')
            print('\n'.join(problems) if problems else 'No problems were reported.')
        else:
            finish(out, {'model': st.get('model'), 'card': st['card'], 'designSystem': os.path.relpath(st['ds'], SDK), 'blocks': st['blocks'], 'blockPictures': st['pictures'],
                         'before': {'problems': len(st['problems0']), 'texts': len(st['texts0'])}, 'rounds': sorted(st['rounds'], key=lambda r: r['round'])})
        return
    card = os.path.abspath(opt('--card'))
    doc = json.load(open(card))
    request = open(opt('--request')).read().strip() if opt('--request') else ''
    width, narrow = int(opt('--width', '420')), int(opt('--narrow', '320'))
    blocks, pictures = '--blocks' in sys.argv, opt('--block-pictures')
    system = brief_for(ds, doc, request, blocks=blocks)
    shots = [(t, f'{os.path.abspath(pictures)}/{t}.png') for t in NEAR if os.path.exists(f'{os.path.abspath(pictures)}/{t}.png')] if blocks and pictures else []
    if width >= 700:
        system += PAGE_TIER
    if width != 420:
        system = system.replace('a card', 'a screen').replace('The card', 'The screen').replace('the card', 'the screen').replace('THE CARD', 'THE SCREEN').replace('in a 320-wide column', f'at {narrow} wide').replace('It is correct', f'It is shown {width} wide. It is correct')
    if mode == 'brief':
        open(f'{out}/brief.txt', 'w').write(system)
        print(f'{out}/brief.txt ({len(system)} characters)')
        return
    model, rounds = opt('--model', 'claude-opus-5-5'), int(opt('--rounds', '2'))
    shutil.copy(card, f'{out}/before.json')
    t_all = time.time()
    site = os.path.abspath(opt('--site')) if opt('--site') else None
    problems0, texts0 = render(f'{out}/before.json', ds, f'{out}/before', width, narrow, site)
    if mode == 'prepare':
        open(f'{out}/brief.txt', 'w').write(system)
        os.makedirs(f'{out}/blocks', exist_ok=True)
        for t, f in shots:
            shutil.copy(f, f'{out}/blocks/{t}.png')
        json.dump({'ds': ds, 'site': site, 'card': os.path.relpath(card, SDK), 'width': width, 'narrow': narrow, 'problems0': problems0, 'texts0': texts0, 'blocks': blocks,
                   'pictures': [t for t, _ in shots], 'model': opt('--model', ''), 'rounds': []}, open(f'{out}/state.json', 'w'), indent=1)
        print(f'{out}: brief.txt, before/, {len(shots)} block picture(s)')
        return
    summary = {'model': model, 'card': os.path.relpath(card, SDK), 'designSystem': os.path.relpath(ds, SDK), 'blocks': blocks, 'blockPictures': [t for t, _ in shots],
               'before': {'problems': len(problems0), 'texts': len(texts0)}, 'rounds': []}
    shown = [{'type': 'text', 'text': 'The card as it is on screen now: light, dark, and narrow.'}]
    shown += [image(f'{out}/before/{m}.png') for m in ('light', 'dark', 'narrow') if os.path.exists(f'{out}/before/{m}.png')]
    if shots:
        shown.append({'type': 'text', 'text': 'The closest blocks of the system as they are drawn (the bar to reach): ' + ', '.join(t for t, _ in shots) + ', in that order.'})
        shown += [image(f) for _, f in shots]
    if opt('--reference') and os.path.exists(opt('--reference')):
        # A page of the same kind, designed from scratch: the bar to reach, not the content to copy.
        from PIL import Image
        ref = Image.open(opt('--reference')).convert('RGB')
        ref = ref.crop((0, 0, ref.width, min(ref.height, 2000)))
        ref.save(f'{out}/reference.png')
        shown.append({'type': 'text', 'text': 'A page of the same kind (other content), designed from scratch for the desktop: its hierarchy, density, type scale and use of the accent are the bar to reach. Do not copy its content or invent parts this screen does not have.'})
        shown.append(image(f'{out}/reference.png'))
    messages = [{'role': 'user', 'content': shown}]
    for n in range(1, rounds + 1):
        text, seconds, usage = ask(model, system, messages)
        d = f'{out}/round{n}'
        if n > 1 and text.strip().upper().startswith('SHIP') and '```' not in text:
            os.makedirs(d, exist_ok=True)
            open(f'{d}/answer.txt', 'w').write(text)
            summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'kept': n - 1, 'input_tokens': usage.get('input_tokens'), 'output_tokens': usage.get('output_tokens')})
            print(json.dumps(summary['rounds'][-1]))
            break
        t0 = time.time()
        problems, count = check_round(out, ds, n, text, problems0, texts0, width, narrow, site)
        summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'checkAndRenderSeconds': round(time.time() - t0, 1), 'problems': len(problems), 'ops': count,
                                  'input_tokens': usage.get('input_tokens'), 'output_tokens': usage.get('output_tokens')})
        print(json.dumps(summary['rounds'][-1]))
        if n == rounds:
            break
        back = [{'type': 'text', 'text': 'This is the card with your operations applied: light, dark, and narrow.'}]
        back += [image(f'{d}/{m}.png') for m in ('light', 'dark', 'narrow') if os.path.exists(f'{d}/{m}.png')]
        back.append({'type': 'text', 'text': ('Problems reported:\n' + '\n'.join(problems) + '\n\n' if problems else 'No problems were reported.\n\n') + SECOND_LOOK})
        messages += [{'role': 'assistant', 'content': text}, {'role': 'user', 'content': back}]
    summary['totalSeconds'] = round(time.time() - t_all, 1)
    finish(out, summary)
    if summary['status'] == 'failed':
        sys.exit(1)


PAGE_TIER = '''

THIS SCREEN IS A DESKTOP PAGE, NOT A CHAT CARD: USE THE PAGE TIER
The system has two tiers of one language. The card tier (the principles above, the block shown) is for a chat card about 420 wide. This screen is a website page or an app window, and takes the page tier: the same colors, ink, hairlines and fonts, at a page's scale.
- Text styles: heading1Wide (a landing page's headline, 56), heading2Wide (a section's or an article's title, 36), heading3Wide (a card's or panel's title, 20), titleWide (an app page's title, 28), headingWide (17 semibold), strongWide (15 semibold), bodyWide (15), leadWide (18, under a headline), mutedWide (14), smallWide (13.5), captionWide (12.5), eyebrowWide (the label over a title, in the accent), columnHead (a table's header cell), numberHero / numberLarge / number / figure for figures. Not cardTitle, blockTitle, rowTitle, lead, meta or eyebrow: they are too small here.
- Surfaces: a website is on pageFill (white), with alternate bands on band ruled off by line; an app's content is on page (light gray) with its sidebar, top bar and panels on card. A panel: radius cardWide (16), a line hairline, shadow cardWide, padding 24. A tile inside it: tileWide (12). Not the 26 corner of a chat card.
- The accent does the wayfinding: the selected navigation item is activeTint with its label and icon in accent; a feature's or a figure's icon sits on an iconTile tile, in the accent; the recommended option is marked by the accent (a 2 px accent border, an accent badge), not by a gray outline or a tinted gradient. One primary button per view.
- Scale and rhythm: a website's bands have 88 above and below, a headline block has 20 to 24 between its parts, grids of tiles 24 apart; an app's content has 24 around it and 16 to 20 between panels. A control is 40 high (44 for a headline's actions); a table's row 52. Prices and key figures are large (numberLarge or bigger), not body text. Content never runs the full width of a 1280 window: a form's fields sit in a column at most 640 wide or two across, running text at most 720.
- The layout the screen came with is the system's own and is usually right: keep its widths (a field or a form at the width it has, not stretched across the window), its bar heights and its sections as they are. Do not add tinted wells or dividers around what already reads as a group.
- An app window is dense and is read above the fold: keep the panels the size they are, keep figures that sit four across four across, and do not make a panel taller or push a table down to add air. Restyle type, color, alignment and rhythm; do not enlarge.
- What a page needs that a card does not: a top bar with a title and its actions level with each other, even columns that end together, table columns aligned with their headers (text left, numbers right), panels in a row equally tall.'''

SECOND_LOOK = ('Look at it as the art director: hierarchy, spacing, alignment, contrast in both modes, whether it sits at the bar of the system, and whether anything is broken, clipped or empty. '
               'If it is right, answer with the single word SHIP. Otherwise answer with the WHOLE list of operations again, corrected '
               '(it replaces your last list and is applied to the card as it was at the start), in a ```json fence.')

if __name__ == '__main__':
    main()

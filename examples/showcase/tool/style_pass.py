#!/usr/bin/env python3
"""The style pass: a card a fast model wrote from plain parts is on screen; a design agent looks at it and
restyles it in place with edit operations. The card is not written again, so what it says, its state and its
actions stay as they were; only how it looks changes. The experiment for "fast, then designed".

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/style_pass.py --card <document.json> --out <dir> \
        [--request <file: what the user asked for>] [--model claude-opus-5-5] [--rounds 2] \
        [--design-system design_systems/cards] [--width 420] [--narrow 320]

--width and --narrow are the widths it is rendered at (a full page on a desktop: --width 1280 --narrow 768).

<document.json> is the card as a layout document (a recording's .notation.json, or what
tool/notation/notation.sh expand wrote). Each round: the agent is shown the card's render (light, dark and 320
wide) and its nodes, and answers with {"ops": [...]}; the ops are applied (tool/notation/notation.sh apply),
the result is rendered with the design system's theme, and what the appliers and the renderer report, plus
any text the card showed before and no longer shows, go back with the new pictures. The round with the
fewest problems is kept. Writes <out>/before/, <out>/round<n>/ (answer.txt, ops.json, card.json, light.png,
dark.png, narrow.png, problems.txt), <out>/after.json and <out>/summary.json (seconds and tokens per round).
The key is read from the environment and never written.

    python3 examples/showcase/tool/style_pass.py brief --card <document.json> --out <dir>
        writes <dir>/brief.txt: the instructions the agent gets, word for word (no model is called)
"""
import json, os, shutil, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design_block import SDK, ask, crop, fenced, image, opt, run  # noqa: E402


def reported(log):
    lines = [l for l in log.splitlines()]
    return [l + ('\n' + lines[i + 1] if i + 1 < len(lines) and not lines[i + 1].startswith(('ERROR', 'WARNING')) else '')
            for i, l in enumerate(lines) if l.startswith(('ERROR', 'WARNING'))]


def render(card, ds, d, width=420, narrow=320):
    """Renders <card> with the design system's theme into <d>: light.png, dark.png, narrow.png. Returns the
    problems the renderer reported (light, at 420 and at 320) and the texts on the card."""
    os.makedirs(d, exist_ok=True)
    problems, texts = [], []
    for name, extra in (('light', ['--sizes', f'{width}x1400', '--dump-layout']), ('dark', ['--sizes', f'{width}x1400', '--theme', 'dark']),
                        ('narrow', ['--sizes', f'{narrow}x1400'])):
        folder = f'{d}/raw-{name}'
        shutil.rmtree(folder, ignore_errors=True)
        code, log = run(['tool/render/render.sh', card, '--out', folder, '--design-system', ds] + extra)
        if name != 'dark':
            problems += [(f'At {narrow} wide: ' if name == 'narrow' else '') + l for l in reported(log) if l not in problems]
        shots = sorted(f for f in os.listdir(folder) if f.endswith('.png')) if os.path.isdir(folder) else []
        if shots:
            crop(f'{folder}/{shots[0]}', f'{d}/{name}.png', dark=name == 'dark')
        dumps = [f for f in os.listdir(folder) if f.endswith('.layout.json')] if os.path.isdir(folder) else []
        if dumps:
            texts = [b['text'] for b in json.load(open(f'{folder}/{dumps[0]}')) if b.get('text')]
    return problems, texts


def brief_for(ds, doc, request):
    manifest = json.load(open(f'{ds}/design_system.json'))
    theme = manifest['theme']
    code, ops = run(['tool/notation/notation.sh', 'apply', '--reference'])
    ops = ops[ops.find('set:'):] if 'set:' in ops else ops
    example = json.load(open(f'{ds}/components/StatTile.json'))['nodes']
    return f"""You are the art director of the "{manifest['name']}" design system: {manifest['description']}
A fast model has just written a card from plain parts (rows, columns, texts, the stock controls) and it is on screen now. It is correct and it looks generic. You restyle it IN PLACE, by edit operations on its nodes, so that it sits at the visual bar of this design system. The card is not written again.

WHAT MUST NOT CHANGE
- What the card says: every text, number and label, and every binding ("bind", "${{…}}" in a value), stays as it is. Do not rewrite copy.
- What the card does: every "actions" list, every variable, every node id and every node's type. Do not remove a node that shows content or takes input.
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

THE EDIT OPERATIONS
{ops.strip()}

THE CARD NOW (its nodes; the canvas is "{doc['roots'][0]}")
{json.dumps(doc['nodes'], indent=1)}
{('WHAT THE USER ASKED FOR' + chr(10) + request + chr(10)) if request else ''}
ANSWER
Two or three sentences on what you change and why. Then one ```json fence holding {{"ops": [...]}}: every op in the order it is applied. Patch what exists; set only what is new."""


def main():
    card, out = os.path.abspath(opt('--card')), os.path.abspath(opt('--out'))
    ds = os.path.join(SDK, opt('--design-system', 'design_systems/cards'))
    mode = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else 'run'
    os.makedirs(out, exist_ok=True)
    doc = json.load(open(card))
    request = open(opt('--request')).read().strip() if opt('--request') else ''
    width, narrow = int(opt('--width', '420')), int(opt('--narrow', '320'))
    system = brief_for(ds, doc, request)
    if width != 420:
        system = system.replace('a card', 'a screen').replace('The card', 'The screen').replace('the card', 'the screen').replace('THE CARD', 'THE SCREEN').replace('in a 320-wide column', f'at {narrow} wide').replace('It is correct', f'It is shown {width} wide. It is correct')
    if mode == 'brief':
        open(f'{out}/brief.txt', 'w').write(system)
        print(f'{out}/brief.txt ({len(system)} characters)')
        return
    model, rounds = opt('--model', 'claude-opus-5-5'), int(opt('--rounds', '2'))
    shutil.copy(card, f'{out}/before.json')
    t_all = time.time()
    problems0, texts0 = render(f'{out}/before.json', ds, f'{out}/before', width, narrow)
    summary = {'model': model, 'card': os.path.relpath(card, SDK), 'designSystem': os.path.relpath(ds, SDK),
               'before': {'problems': len(problems0), 'texts': len(texts0)}, 'rounds': []}
    shown = [{'type': 'text', 'text': 'The card as it is on screen now: light, dark, and narrow.'}]
    shown += [image(f'{out}/before/{m}.png') for m in ('light', 'dark', 'narrow') if os.path.exists(f'{out}/before/{m}.png')]
    messages = [{'role': 'user', 'content': shown}]
    for n in range(1, rounds + 1):
        text, seconds, usage = ask(model, system, messages)
        d = f'{out}/round{n}'
        os.makedirs(d, exist_ok=True)
        open(f'{d}/answer.txt', 'w').write(text)
        if n > 1 and text.strip().upper().startswith('SHIP') and '```' not in text:
            summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'kept': n - 1, 'input_tokens': usage.get('input_tokens'), 'output_tokens': usage.get('output_tokens')})
            print(json.dumps(summary['rounds'][-1]))
            break
        ops = fenced(text, 'json')
        problems = []
        t0 = time.time()
        if not ops:
            problems = ['The answer must hold a ```json fence with {"ops": [...]}.']
        else:
            open(f'{d}/ops.json', 'w').write(ops)
            # Each round's ops are applied to the card as it was before the pass: a round replaces the last, it does not stack on it.
            code, log = run(['tool/notation/notation.sh', 'apply', f'{out}/before.json', f'{d}/ops.json', '--design-system', ds, '--out', f'{d}/card.json'])
            problems += [l for l in log.splitlines() if l.startswith('ERROR')]
            if os.path.exists(f'{d}/card.json'):
                rendered, texts = render(f'{d}/card.json', ds, d, width, narrow)
                problems += [l for l in rendered if l not in problems0]
                gone = [t for t in texts0 if t not in texts]
                problems += [f'A text the card showed is gone: "{t[:80]}". The pass must not change what the card says.' for t in gone[:12]]
        open(f'{d}/problems.txt', 'w').write('\n'.join(problems) + '\n')
        summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'checkAndRenderSeconds': round(time.time() - t0, 1), 'problems': len(problems),
                                  'ops': len(json.loads(ops).get('ops', [])) if ops and ops.strip().startswith('{') else 0,
                                  'input_tokens': usage.get('input_tokens'), 'output_tokens': usage.get('output_tokens')})
        print(json.dumps(summary['rounds'][-1]))
        if n == rounds:
            break
        back = [{'type': 'text', 'text': 'This is the card with your operations applied: light, dark, and narrow.'}]
        back += [image(f'{d}/{m}.png') for m in ('light', 'dark', 'narrow') if os.path.exists(f'{d}/{m}.png')]
        back.append({'type': 'text', 'text': ('Problems reported:\n' + '\n'.join(problems) + '\n\n' if problems else 'No problems were reported.\n\n') +
                     'Look at it as the art director: hierarchy, spacing, alignment, contrast in both modes, whether it sits at the bar of the system, and whether anything is broken, clipped or empty. '
                     'If it is right, answer with the single word SHIP. Otherwise answer with the WHOLE list of operations again, corrected '
                     '(it replaces your last list and is applied to the card as it was at the start), in a ```json fence.'})
        messages += [{'role': 'assistant', 'content': text}, {'role': 'user', 'content': back}]
    checked = [r for r in summary['rounds'] if 'problems' in r and os.path.exists(f"{out}/round{r['round']}/card.json")]
    if checked:
        best = min(checked, key=lambda r: (r['problems'], -r['round']))
        summary['final'], summary['problems'] = best['round'], best['problems']
        summary['status'] = 'passed' if best['problems'] == 0 else 'failed'
        shutil.copy(f"{out}/round{best['round']}/card.json", f'{out}/after.json')
    else:
        summary['status'] = 'failed'
    summary['totalSeconds'] = round(time.time() - t_all, 1)
    json.dump(summary, open(f'{out}/summary.json', 'w'), indent=1)
    print(json.dumps({k: summary.get(k) for k in ('final', 'status', 'problems', 'totalSeconds')}))
    if summary['status'] == 'failed':
        sys.exit(1)


if __name__ == '__main__':
    main()

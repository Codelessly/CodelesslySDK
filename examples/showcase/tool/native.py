#!/usr/bin/env python3
"""Desktop pages designed from scratch: a strong model writes each request of
examples/showcase/desktop/requests.json as a whole layout document at the full API, with no design system and
no components: the API's reference, one paragraph of style, and the request. It then sees its page rendered
and revises it as its own art director. The pages that come out are the references for what a desktop layout
is, before any block is made from them.

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/native.py --out examples/showcase/desktop/native \
        [--only a,b] [--model claude-opus-5-5] [--rounds 3] [--width 1280] [--narrow 768] [--style <file>]
        [--theme-of design_systems/cards]

--theme-of gives the model a design system's theme and nothing else of it (its token names and values, its
"In brief" as the paragraph of style; none of its components): the page is written with the theme's names, and
every value the page needed that the theme does not have is listed after the document under MISSING TOKENS.
That list is what the theme lacks to be a desktop's as well.

Each round: the answer's document is validated and rendered at --width (a website to its end, an app window at
the window's size) and at --narrow; the pictures and everything reported go back, and the model answers with
the whole document again, or SHIP. The round with the fewest errors is kept (the later of equals).
Writes <out>/<page>/round<n>/ (answer.txt, doc.json, light.png, narrow.png, problems.txt), <out>/<page>.json,
<page>.png, <page>-narrow.png and <out>/summary.json. The key is read from the environment and never written."""
import concurrent.futures, json, os, re, shutil, sys, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design_block import SDK, crop, image, opt, run  # noqa: E402

API = os.path.join(os.path.dirname(SDK), 'CodelesslyAPI', 'docs', 'reference')
PAGES = ('STARTER', 'layout', 'decoration', 'interaction', 'charts', 'lists')
FONTS = os.path.join(SDK, 'design_systems', 'cards', 'fonts')
LOOKS = ['--fonts', FONTS]  # or a design system: its theme and fonts

STYLE = ('A calm, confident product design. A light neutral page (#FFF6F7F9) with white surfaces; near-black ink (#FF0F172A) with two quieter '
         'grays for secondary and tertiary text; one accent (#FF2563EB) used sparingly for the primary action, links and the selected state, and '
         'soft tints of green, amber and red for status. Type is Inter (body 15 with a 1.55 line height) with Inter Display for headings, set large '
         'and tight (a website\'s title 44 to 60, an app screen\'s 22 to 28; weight 700; letter spacing about -0.02 em); figures are large. '
         'Surfaces have generous corners (16 to 24 for cards, 10 to 12 for controls), hairline borders (#FFE5E7EB) and very soft, wide shadows; '
         'spacing is generous and on an 8 px rhythm; pictures are drawn from shapes and gradients, never photos or image URLs. Code is JetBrains Mono.')


def theme_section(ds):
    """A design system's theme as the model is to use it, and its one paragraph of style."""
    m = json.load(open(f'{ds}/design_system.json'))
    t = m['theme']
    design = open(f'{ds}/DESIGN.md').read() if os.path.exists(f'{ds}/DESIGN.md') else ''
    brief = re.search(r'^## In brief\s*\n(.*?)(?=^## )', design, re.S | re.M)
    style = ' '.join(brief.group(1).split()) if brief else m.get('description', '')
    # The paragraph is about the look; what it says about composing the system's blocks does not apply here.
    style = re.sub(r'A card closes on[^.]*\.|Write no colors[^.]*\.[^.]*\.?$|compose the blocks\.?', '', style).strip()
    styles = '\n'.join(f'  {k}: ' + ', '.join(f'{a} {v[a]}' for a in ('fontFamily', 'fontSize', 'fontWeight', 'height', 'letterSpacing') if a in v)
                       for k, v in t['textStyles'].items() if isinstance(v, dict))
    example = open(f'{ds}/components/StatTile.json').read()
    section = f"""

THE THEME ({m['name']})
The document is rendered with this theme. Use its names wherever one fits, so the page is right in light and dark and is one system with everything else drawn with it:
- a color is a theme color's name as the value ("color": "ink"), or ${{theme.colors.name}} in an expression
- a text's "style" is {{"from": "<text style>"}}, with overrides beside it when needed ({{"from": "body", "color": "inkSoft"}})
- a radius is "${{theme.radii.name}}", a shadow "${{theme.shadows.name}}", spacing ${{theme.spacing.n}}
colors: {', '.join(k for k, v in t['colors'].items())}
text styles:
{styles}
radii: {json.dumps(t.get('radii'))}
spacing: {json.dumps(t.get('spacing'))}
shadows: {', '.join(t.get('shadows', {}))}
How the names are written, in one of the system's own parts (for the syntax only: you have no components, and this part was drawn for a small card, not a page):
{example}

This theme was made for a chat card about 420 wide. Where it has no value that is right for a desktop page (a display size for a page's title, a lead paragraph, a section's spacing, a surface's corner on a page, a gray it lacks), do not bend the design to the theme: write the literal value, and after the document list each one under the heading MISSING TOKENS, a line each: the name you would give it, its value, and where the page uses it. Where a theme value is wrong for a desktop (too small, too round), say so there too."""
    return style, section


def system_prompt(width, narrow, style, theme=''):
    reference = '\n\n'.join(open(f'{API}/{p}.md').read() for p in PAGES)
    return [
        {'type': 'text', 'text': f"""You are a senior product designer who builds what you design. You write one screen as a Codelessly layout document (JSON, schema 3), directly at the API described below: there is no design system and there are no ready-made components, so every part is yours to compose from the node types, with literal colors, sizes and text styles.

It is a desktop screen: a window {width} wide. Design it as a desktop-native layout, not a phone layout made wider: a real grid, columns with reasons, a content width that reads well, fixed side panes where the screen is an app, density where an app needs it and air where a website needs it. It is also rendered {narrow} wide and must hold there (columns wrap or stack, nothing overflows).

Fonts available (no others): "Inter" (400, 500, 600, 700), "Inter Display" (600, 700, 800), "JetBrains Mono" (400, 500, 700). Icons are Material icon names. Pictures are drawn (gradients, shapes, customPaint), never image URLs.

STYLE
{style}{theme}

ANSWER FORMAT
Two or three sentences on the layout decisions (the grid, the hierarchy, what makes it desktop-native). Then the whole document in one ```json fence: one canvas, its design size {width} wide (a website page as tall as its content and scrolling; an app window as tall as the window, 800, with its panes scrolling by themselves), state and actions real (what the request says can be done works). Keep it under about 50,000 characters: repeat rows from a list variable (a listView or gridView over data) rather than writing each out.

THE API
"""},
        {'type': 'text', 'text': reference, 'cache_control': {'type': 'ephemeral'}},
    ]


def ask(model, system, messages):
    body = {'model': model, 'max_tokens': 32000, 'system': system, 'messages': messages}
    req = urllib.request.Request('https://api.anthropic.com/v1/messages', data=json.dumps(body).encode(), headers={
        'content-type': 'application/json', 'x-api-key': os.environ['ANTHROPIC_API_KEY'], 'anthropic-version': '2023-06-01'})
    t0 = time.time()
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=1500) as r:
                answer = json.loads(r.read())
            break
        except Exception as e:  # noqa: BLE001  (an overloaded or rate-limited call is asked again)
            if attempt == 3:
                raise
            time.sleep(20 * (attempt + 1))
    return ''.join(b.get('text', '') for b in answer['content']), round(time.time() - t0, 1), answer.get('usage', {})


def fenced_json(text):
    m = re.search(r'```json\n(.*?)```', text, re.S) or re.search(r'```\n?(\{.*?)```', text, re.S)
    return m.group(1) if m else None


def reported(log):
    lines = log.splitlines()
    return [l + ('\n' + lines[i + 1] if i + 1 < len(lines) and not lines[i + 1].startswith(('ERROR', 'WARNING')) else '')
            for i, l in enumerate(lines) if l.startswith(('ERROR', 'WARNING'))]


def check(d, text, width, narrow, app):
    """Renders the round's document; the problems reported."""
    os.makedirs(d, exist_ok=True)
    open(f'{d}/answer.txt', 'w').write(text)
    raw = fenced_json(text)
    if raw is None:
        return ['The answer holds no ```json fence with the document.']
    try:
        doc = json.loads(raw)
    except ValueError as e:
        return [f'The document is not valid JSON: {e}']
    json.dump(doc, open(f'{d}/doc.json', 'w'), indent=1)
    if not isinstance(doc.get('roots'), list) or not doc['roots'] or doc['roots'][0] not in doc.get('nodes', {}):
        return ['The document needs "roots": [<canvas id>] and that canvas under "nodes".']
    # A website is captured to its end; an app window at the window's size.
    whole = [] if app else ['--full-page']
    problems = []
    for name, w in (('light', width), ('narrow', narrow)):
        folder = f'{d}/raw-{name}'
        shutil.rmtree(folder, ignore_errors=True)
        code, log = run(['tool/render/render.sh', f'{d}/doc.json', '--out', folder, '--sizes', f'{w}x800'] + LOOKS + whole)
        found = reported(log)
        if code and not found:
            found = [f'The render stopped: {log[-400:]}']
        problems += [(f'At {narrow} wide: ' if name == 'narrow' else '') + l for l in found if l not in problems]
        shots = sorted(f for f in os.listdir(folder) if f.endswith('.png')) if os.path.isdir(folder) else []
        if shots:
            crop(f'{folder}/{shots[0]}', f'{d}/{name}.png')
        shutil.rmtree(folder, ignore_errors=True)
    open(f'{d}/problems.txt', 'w').write('\n'.join(problems) + '\n')
    return problems


def shown(path, limit=7000):
    """A picture for the model: a long page is cut at what a model's picture can hold."""
    from PIL import Image
    im = Image.open(path)
    if im.height > limit:
        im.crop((0, 0, im.width, limit)).save(path + '.cut.png')
        return image(path + '.cut.png')
    return image(path)


LOOK = ('Look at it as the art director of the best desktop product you know, at both widths. Name the five weakest things first, in a line each: the '
        'grid and alignment, the hierarchy, the rhythm of space, density and proportion for a desktop, anything broken, clipped, empty, overflowing or '
        'unfinished, and anything the request asked for that is missing or does not work. Then answer with the whole document again in a ```json fence, '
        'those things fixed and everything that was right kept. If nothing is reported and you would ship it as it is, answer with the one word SHIP.')


def design(name, request, out, model, rounds, width, narrow, system):
    d = f'{out}/{name}'
    messages = [{'role': 'user', 'content': request}]
    summary = {'name': name, 'model': model, 'rounds': []}
    for n in range(1, rounds + 1):
        text, seconds, usage = ask(model, system, messages)
        if n > 1 and text.strip().upper().startswith('SHIP') and '```' not in text:
            summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'shipped': n - 1})
            break
        problems = check(f'{d}/round{n}', text, width, narrow, name.startswith('app'))
        errors = sum(1 for p in problems if 'ERROR' in p or not p.startswith(('WARNING', 'At ')))
        summary['rounds'].append({'round': n, 'modelSeconds': seconds, 'problems': len(problems), 'errors': errors,
                                  'input_tokens': usage.get('input_tokens'), 'cached': usage.get('cache_read_input_tokens'), 'output_tokens': usage.get('output_tokens')})
        print(name, json.dumps(summary['rounds'][-1]), flush=True)
        if n == rounds:
            break
        back = [{'type': 'text', 'text': f'This is how it rendered: {width} wide, then {narrow} wide.'}]
        back += [shown(f'{d}/round{n}/{m}.png') for m in ('light', 'narrow') if os.path.exists(f'{d}/round{n}/{m}.png')]
        back.append({'type': 'text', 'text': ('Reported:\n' + '\n'.join(problems[:40]) + '\n\n' if problems else 'Nothing was reported.\n\n') + LOOK})
        # The earlier answers are kept as their decisions, not their documents: only the last document matters.
        messages = [messages[0], {'role': 'assistant', 'content': text}, {'role': 'user', 'content': back}]
    checked = [r for r in summary['rounds'] if 'problems' in r and os.path.exists(f"{d}/round{r['round']}/light.png")]
    if checked:
        best = min(checked, key=lambda r: (r['errors'], -r['round']))
        summary['final'], summary['errors'], summary['problems'] = best['round'], best['errors'], best['problems']
        f = f"{d}/round{best['round']}"
        shutil.copy(f'{f}/doc.json', f'{out}/{name}.json')
        shutil.copy(f'{f}/light.png', f'{out}/{name}.png')
        if os.path.exists(f'{f}/narrow.png'):
            shutil.copy(f'{f}/narrow.png', f'{out}/{name}-narrow.png')
    json.dump(summary, open(f'{d}/summary.json', 'w'), indent=1)
    return summary


def main():
    out = os.path.abspath(opt('--out', os.path.join(SDK, 'examples', 'showcase', 'desktop', 'native')))
    os.makedirs(out, exist_ok=True)
    width, narrow = int(opt('--width', '1280')), int(opt('--narrow', '768'))
    style, theme = open(opt('--style')).read().strip() if opt('--style') else STYLE, ''
    if opt('--theme-of'):
        ds = os.path.join(SDK, opt('--theme-of'))
        style, theme = theme_section(ds)
        LOOKS[:] = ['--design-system', ds]
    system = system_prompt(width, narrow, style, theme)
    open(f'{out}/prompt.txt', 'w').write(system[0]['text'] + f'(the reference pages: {", ".join(PAGES)})\n')
    requests = json.load(open(opt('--requests', os.path.join(SDK, 'examples', 'showcase', 'desktop', 'requests.json'))))
    only = opt('--only')
    todo = {k: v for k, v in requests.items() if not only or k in only.split(',')}
    model, rounds = opt('--model', 'claude-opus-5-5'), int(opt('--rounds', '3'))
    with concurrent.futures.ThreadPoolExecutor(int(opt('--parallel', '5'))) as pool:
        results = list(pool.map(lambda kv: design(kv[0], kv[1], out, model, rounds, width, narrow, system), todo.items()))
    all_ = json.load(open(f'{out}/summary.json')) if os.path.exists(f'{out}/summary.json') else {}
    all_.update({r['name']: r for r in results})
    json.dump(all_, open(f'{out}/summary.json', 'w'), indent=1)
    for r in results:
        print(r['name'], 'kept round', r.get('final'), 'errors', r.get('errors'), 'problems', r.get('problems'))


if __name__ == '__main__':
    main()

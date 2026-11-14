#!/usr/bin/env python3
"""The polish pass: a model looks at a rendered screen and rewrites its notation to a rubric.

  ANTHROPIC_API_KEY=... python3 tool/polish_pass.py <screen.txt> <render.png> --design-system skip \
      --out <dir> [--model claude-sonnet-5-5] [--blocks-only]

It sends the notation's instructions for the design system, the screen as written, the image of it as
drawn, and a rubric; the answer is the screen rewritten. The result is written to <dir>/<name>.txt with
<name>.pass.json (tokens, seconds, the critique). Expanding and rendering it is the caller's next step.
The key is read from the environment and never written anywhere.
"""
import base64, json, os, pathlib, subprocess, sys, time, urllib.request

here = pathlib.Path(__file__).resolve().parent.parent
sdk = here.parent.parent

RUBRIC = """You are the art director reviewing a generated app screen. The image is the screen as drawn; the notation below is how it was written.

Rewrite the screen so it looks designed, keeping everything it does (every state line, every action, every binding, the same data):
1. One focal point: the single most important thing is far larger than anything else and sits in its own strong surface.
2. Hierarchy in three steps only: the focal thing, supporting facts, quiet labels. Remove anything that repeats.
3. Use the design system's own surfaces and text styles before plain cards; use its color for the focal surface, not white cards on the page.
4. Primary action is one obvious button; secondary actions are quiet.
5. Spacing in a steady rhythm; no orphan buttons at odd widths.
6. Colors come from the design system. Do not write literal colors.

Answer in two parts: first a line starting CRITIQUE: with three short phrases naming what was weakest; then the whole screen in the notation, and nothing after it. Do not restate state the host declares (it is listed under HOST STATE)."""


def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main():
    txt, png = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    ds = opt('--design-system', 'skip')
    out = pathlib.Path(opt('--out', 'polished'))
    out.mkdir(parents=True, exist_ok=True)
    model = opt('--model', 'claude-sonnet-5-5')
    system = subprocess.run([str(sdk / 'tool/notation/notation.sh'), 'prompt', '--design-system', str(sdk / 'design_systems' / ds)],
                            capture_output=True, text=True, check=True).stdout
    if '--blocks-only' in sys.argv:
        # Keep the grammar and the app's blocks; drop the long list of base controls.
        head, _, rest = system.partition('COMPONENTS')
        keep = ('Screen', 'TopBar', 'HeroSession', 'StreakFlame', 'ProgressGoal', 'WeekStrip', 'SectionTitle', 'SessionRow', 'ChartCard',
                'StatTrio', 'RecordCard', 'EmptyState', 'Illustration')
        lines = rest.split('\n')
        comp = [l for l in lines if l.strip().split(' ')[0] in keep]
        tail = '\n'.join(lines[next((i for i, l in enumerate(lines) if l.startswith('FORMULAS') or l.startswith('BEYOND')), len(lines)):])
        system = head + 'COMPONENTS\n' + '\n'.join(comp) + '\n\n' + tail
    host = (here / 'screens' / 'contract.txt').read_text()
    body = {
        'model': model, 'max_tokens': 4000, 'system': system,
        'messages': [{'role': 'user', 'content': [
            {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/png', 'data': base64.b64encode(png.read_bytes()).decode()}},
            {'type': 'text', 'text': f"{RUBRIC}\n\nHOST STATE\n{host}\nTHE SCREEN AS WRITTEN\n{txt.read_text()}"},
        ]}],
    }
    req = urllib.request.Request('https://api.anthropic.com/v1/messages', data=json.dumps(body).encode(), headers={
        'content-type': 'application/json', 'x-api-key': os.environ['ANTHROPIC_API_KEY'], 'anthropic-version': '2023-06-01'})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=180) as r:
        answer = json.loads(r.read())
    seconds = round(time.time() - t0, 1)
    text = ''.join(b.get('text', '') for b in answer['content'])
    critique, _, notation = text.partition('\n')
    notation = notation.strip()
    if notation.startswith('```'):
        notation = '\n'.join(l for l in notation.split('\n') if not l.startswith('```'))
    name = txt.stem
    (out / f'{name}.txt').write_text(notation.rstrip('\n') + '\n')
    info = {'screen': name, 'model': model, 'seconds': seconds, 'critique': critique.replace('CRITIQUE:', '').strip(), **answer.get('usage', {})}
    (out / f'{name}.pass.json').write_text(json.dumps(info, indent=1))
    print(json.dumps({k: info[k] for k in ('screen', 'seconds', 'critique', 'input_tokens', 'output_tokens') if k in info}))


if __name__ == '__main__':
    main()

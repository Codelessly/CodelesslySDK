#!/usr/bin/env python3
"""Desktop pages: a model writes each request of examples/showcase/desktop/requests.json in the compact
notation with a design system, and each answer is expanded and rendered at a desktop width.

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/desktop.py write --arm <name> [--only a,b]
        [--model claude-sonnet-5-5] [--design-system design_systems/cards] [--width 1280]
        asks the model: desktop/<arm>/<id>.txt (its answer), <id>.json (seconds, tokens)
    python3 examples/showcase/tool/desktop.py render --arm <name> [--only a,b] [--theme dark]
        expands and renders them: desktop/<arm>/<id>.doc.json, <id>.png, issues.txt, render.txt, sheet.png

The key is read from the environment and never written."""
import concurrent.futures, json, os, re, shutil, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design_block import SDK, ask, opt, run  # noqa: E402

HOME = os.path.join(SDK, 'examples', 'showcase', 'desktop')


def requests():
    all_ = json.load(open(os.path.join(HOME, 'requests.json')))
    only = opt('--only')
    return {k: v for k, v in all_.items() if not only or k in only.split(',')}


def prompt(ds, width):
    code, out = run(['tool/notation/notation.sh', 'prompt', '--design-system', ds, '--width', str(width)])
    if code != 0:
        sys.exit(out)
    return out[out.index('You describe a UI'):]


def unfenced(text):
    m = re.search(r'```[a-z]*\n(.*?)```', text, re.S)
    return (m.group(1) if m else text).strip() + '\n'


def write(arm, ds, width, model):
    system = prompt(ds, width)
    os.makedirs(os.path.join(HOME, arm), exist_ok=True)
    open(os.path.join(HOME, arm, 'prompt.txt'), 'w').write(system)

    def one(item):
        name, request = item
        text, seconds, usage = ask(model, system, [{'role': 'user', 'content': f'{request}\n\nIt is shown in a window {width} wide.'}])
        open(os.path.join(HOME, arm, f'{name}.txt'), 'w').write(unfenced(text))
        json.dump({'model': model, 'seconds': seconds, 'output_tokens': usage.get('output_tokens')}, open(os.path.join(HOME, arm, f'{name}.json'), 'w'))
        return name, seconds, usage.get('output_tokens')

    with concurrent.futures.ThreadPoolExecutor(5) as pool:
        for name, seconds, tokens in pool.map(one, requests().items()):
            print(f'{name}: {seconds}s, {tokens} tokens')


def render(arm, ds, width, theme):
    d = os.path.join(HOME, arm)
    issues, reports = [], []
    for name in requests():
        src = os.path.join(d, f'{name}.txt')
        if not os.path.exists(src):
            continue
        doc = os.path.join(d, f'{name}.doc.json')
        code, out = run(['tool/notation/notation.sh', 'expand', src, '--design-system', ds, '--named', '--id', name, '--width', str(width), '--out', doc])
        issues += [f'{name}: {l.split(": ", 1)[-1]}' for l in out.splitlines() if 'line ' in l]
        tmp = tempfile.mkdtemp()
        # An app is as tall as its window; a page is captured to its end.
        height = json.load(open(doc))['nodes'][name]['layout']['height']
        whole = [] if isinstance(height, dict) and 'fill' in height else ['--full-page']
        code, out = run(['tool/render/render.sh', doc, '--out', tmp, '--sizes', f'{width}x800', '--design-system', ds] + whole + (['--theme', theme] if theme else []))
        reports += [l.replace('ERROR  ', f'ERROR   [{name}]', 1).replace('WARNING', f'WARNING [{name}]', 1) for l in out.splitlines() if l.startswith(('ERROR', 'WARNING'))]
        pngs = [os.path.join(r, f) for r, _, fs in os.walk(tmp) for f in fs if f.endswith('.png')]
        if pngs:
            shutil.copy(pngs[0], os.path.join(d, f'{name}{"-" + theme if theme else ""}.png'))
        else:
            reports.append(f'ERROR   [{name}] no picture: {out[-300:]}')
        shutil.rmtree(tmp)
    suffix = f'-{theme}' if theme else ''
    open(os.path.join(d, f'issues{suffix}.txt'), 'w').write('\n'.join(issues) + ('\n' if issues else ''))
    open(os.path.join(d, f'render{suffix}.txt'), 'w').write('\n'.join(reports) + ('\n' if reports else ''))
    errors = sum(l.startswith('ERROR') for l in reports)
    print(f'{arm}: {len(issues)} notation issues, {errors} render errors, {len(reports) - errors} warnings')


def main():
    arm, ds = opt('--arm'), opt('--design-system', 'design_systems/cards')
    width = int(opt('--width', '1280'))
    if not arm or len(sys.argv) < 2 or sys.argv[1] not in ('write', 'render'):
        sys.exit(__doc__)
    if sys.argv[1] == 'write':
        write(arm, ds, width, opt('--model', 'claude-sonnet-5-5'))
    else:
        render(arm, ds, width, opt('--theme'))


if __name__ == '__main__':
    main()

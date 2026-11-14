#!/usr/bin/env python3
"""Generates each screen of app.json for each persona, and renders them.

  ANTHROPIC_API_KEY=... python3 tool/generate.py [--model claude-sonnet-5-5] [--only home] [--persona kid]

A screen is written by the model in the compact notation from: the app's
brief, the data and action contract, the app's rules, the screen's own prompt,
and one person's memory. The key is read from the environment by the recorder
and is never written anywhere.
"""
import json, os, subprocess, sys, pathlib

here = pathlib.Path(__file__).resolve().parent.parent
sdk = here.parent.parent
recorder = sdk / 'examples' / 'stream_chat'


def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def brief(app, screen, persona):
    c = app['contract']
    m = persona['memory']
    return '\n'.join([
        f"APP: {app['name']}. {app['brief']}",
        '',
        f"SCREEN TO WRITE: {screen['prompt']}",
        '',
        'DATA (the contract). ' + c['note'],
        *[f"  {k} = {json.dumps(v, separators=(',', ':'))}" for k, v in c['variables'].items()],
        '',
        'ACTIONS (call with emit):',
        *[f"  {k}: {v}" for k, v in c['actions'].items()],
        '',
        'RULES:',
        *[f"  - {r}" for r in app['rules']],
        '',
        'THE PERSON THIS SCREEN IS FOR:',
        f"  Goal: {m['stated']['goal']}. Experience: {m['stated']['experience']}. Stage: {m['stage']}.",
        f"  Tone: {m['tone']}.",
        *[f"  - {n}" for n in m['notes']],
        '',
        'Shape the screen for this person: what comes first, how much is shown, the words used. Use only the data above.',
    ])


def main():
    app = json.loads((here / 'app.json').read_text())
    model = opt('--model', 'claude-sonnet-5-5')
    out = here / 'generated'
    for pf in sorted((here / 'personas').glob('*.json')):
        persona = json.loads(pf.read_text())
        if opt('--persona') not in (None, persona['id']):
            continue
        for screen in app['screens']:
            if opt('--only') not in (None, screen['id']):
                continue
            name = f"{screen['id']}.{persona['id']}"
            (out / f'{name}.brief.txt').write_text(brief(app, screen, persona))
            # The contract's state is the host's: it goes before whatever the model writes.
            (out / 'contract.txt').write_text(''.join(
                f"state {k}={json.dumps(v, separators=(',', ':'))}\n" for k, v in app['contract']['variables'].items()))
            r = subprocess.run([
                'dart', 'run', 'tool/record_notation.dart', '--ui', name, '--model', model,
                '--brief-file', str(out / f'{name}.brief.txt'), '--frame', 'one phone screen 390 wide',
                '--prelude-file', str(out / 'contract.txt'),
                '--design-system', str(sdk / 'design_systems' / persona['designSystem']),
                '--out', str(out / f'{name}.jsonl'),
            ], cwd=recorder, capture_output=True, text=True)
            try:
                s = json.loads((out / f'{name}.summary.json').read_text())
                t = s['turns'][-1]
                print(f"{name}: {len(s['turns'])} turn(s), {t['nodes']} nodes, {t['output_tokens']} tokens out, "
                      f"{t['totalMs'] / 1000:.1f} s, {len(t['notationIssues'])} not read, {len(t['errors'])} errors")
            except Exception as e:  # noqa: BLE001
                print(f'{name}: failed ({e})\n{r.stderr[-600:]}')


if __name__ == '__main__':
    main()

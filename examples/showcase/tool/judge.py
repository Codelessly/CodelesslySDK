#!/usr/bin/env python3
"""A blind judge for versions of one UI: each case's pictures are shown unlabeled and in shuffled order to one
or more models, which rank and score them.

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/judge.py --out <dir> --what "full mobile app screen" \
        --variants ssui,designed,pass --case <id>=<ssui.png>,<designed.png>,<pass.png> [--case ...] \
        [--models claude-opus-5-5,claude-sonnet-5-5] [--seed 7]

Writes <out>/judge.json: per case and model, the ranking (best first) by variant name, the 1 to 10 scores and
one sentence of why; and prints one line per judgment. The key is read from the environment and never written.
"""
import json, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design_block import ask, image, opt  # noqa: E402


def main():
    out, what = opt('--out'), opt('--what', 'UI')
    variants = opt('--variants').split(',')
    models = opt('--models', 'claude-opus-5-5,claude-sonnet-5-5').split(',')
    random.seed(int(opt('--seed', '7')))
    cases = [sys.argv[i + 1].split('=', 1) for i, a in enumerate(sys.argv) if a == '--case']
    letters = 'ABCDEFGH'[:len(variants)]
    results = []
    for case, files in cases:
        paths = dict(zip(variants, files.split(',')))
        for model in models:
            order = list(paths)
            random.shuffle(order)
            content = [{'type': 'text', 'text': f'{len(order)} renderings of the same {what}, {", ".join(letters)}, in that order. Same content; only the visual design differs.'}]
            content += [image(paths[k]) for k in order]
            content.append({'type': 'text', 'text': 'Judge as a senior product designer: hierarchy, spacing, consistency, polish, and whether it looks like a shipped product. '
                            'Answer with JSON only: {"rank": [letters, best first], "scores": {letter: 1-10}, "why": "one sentence"}'})
            text, _, _ = ask(model, 'You are a careful, critical judge of interface design.', [{'role': 'user', 'content': content}])
            try:
                j = json.loads(text[text.find('{'):text.rfind('}') + 1])
                named = dict(zip(letters, order))
                r = {'case': case, 'judge': model, 'rank': [named[x] for x in j['rank']], 'scores': {named[k]: v for k, v in j['scores'].items()}, 'why': j.get('why', '')}
            except Exception:
                r = {'case': case, 'judge': model, 'error': text[:200]}
            results.append(r)
            print(json.dumps({k: r.get(k) for k in ('case', 'judge', 'rank', 'scores', 'error') if k in r}), flush=True)
    os.makedirs(out, exist_ok=True)
    json.dump(results, open(f'{out}/judge.json', 'w'), indent=1)


if __name__ == '__main__':
    main()

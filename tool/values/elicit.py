#!/usr/bin/env python3
"""What does a model write for state, computed values, actions, conditions and repetition when the notation
does not tell it how? The answers are the evidence for a grammar that reads the way models already write.

    ANTHROPIC_API_KEY=... python3 tool/values/elicit.py <briefs dir> --design-system <folder> --out <dir>
        [--model claude-sonnet-5-5] [--blocks A,B,C]

For each <briefs dir>/*.txt: the notation's instructions with every rule and example about state, bindings,
formulas, actions, conditions and repetition taken out (layout, text, the blocks and their parameters stay), and
one sentence asking the model to write those parts as reads most naturally. Saves each answer as <out>/<id>.txt
and prints a tally of the spellings used (tool/values/tally.py reads the same folder). The key is read from the
environment and never written.
"""
import glob, json, os, re, subprocess, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SDK = os.path.dirname(os.path.dirname(HERE))
DROP = ('- @name is the variable itself','- What a node does is an event', '  After the text everything is key=value', '- drag=group','- state name=value', '- every 1000', '- if expression', '- each row in rows')


def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def stripped(prompt, blocks):
    cut = lambda s, a, b: s[:s.index(a)] + s[s.index(b):] if a in s and b in s[s.index(a):] else s
    prompt = cut(prompt, 'FORMULAS (', 'BEYOND THESE WORDS')
    for end in ('COMPONENTS (', '\x00'):
        if 'EXAMPLES\n' in prompt and end in prompt[prompt.index('EXAMPLES\n'):]:
            prompt = cut(prompt, 'EXAMPLES\n', end)
            break
    if 'PUTTING THEM TOGETHER' in prompt:
        prompt = prompt[:prompt.index('PUTTING THEM TOGETHER')]
    out = []
    for line in prompt.split('\n'):
        if line.startswith(DROP) or line.startswith('  Written like any node:'):
            continue
        m = re.match(r'  ([A-Z][A-Za-z]+) ', line)
        if m and ' : ' in line:  # a block's call line: its parameters stay, the notation's own marks go
            if blocks and m.group(1) not in blocks:
                continue
            call, doc = line.split(' : ', 1)
            call = re.sub(r' @(\w+)', r' \1', call)          # the value a use binds: @value
            call = re.sub(r' (\w+)=@(?=\s|$)', r' \1', call)  # a further one: direction=@
            call = re.sub(r' (on[A-Z]\w*)', r' \1(event)', call)
            # What the block is, without the examples its description gives in today's notation.
            doc = re.split(r'[:;(]', doc)[0].strip()
            line = f'{call} : {doc}.'
        out.append(line)
    text = '\n'.join(out)
    text = re.sub(r' A value that follows the state is an expression in braces:[^\n]*', '', text)
    text = re.sub(r'\(or Progress \{done\}\) ', '', text)
    text = '\n'.join(l for l in text.split('\n') if 'BEYOND THESE WORDS' not in l and not l.startswith('  The full vocabulary has more') and not l.startswith('  custom drawing and shapes'))
    return text


def main():
    briefs, out = sys.argv[1], opt('--out')
    ds, model = opt('--design-system'), opt('--model', 'claude-sonnet-5-5')
    blocks = set((opt('--blocks') or open(os.path.join(ds, 'BLOCKS.txt')).read().strip()).split(','))
    os.makedirs(out, exist_ok=True)
    prompt = subprocess.run(['tool/notation/notation.sh', 'prompt', '--design-system', ds], cwd=SDK, capture_output=True, text=True).stdout
    prompt = prompt[max(0, prompt.find('You describe a UI')):]
    system = stripped(prompt + '\x00', blocks).replace('\x00', '') + """

WHAT THIS NOTATION DOES NOT SAY YET
It has no agreed way to write what changes: values a card remembers, a value worked out from others, what happens when something is tapped or chosen, a part shown only sometimes, a part repeated for each item of a list, something that happens as time passes. The request below needs some of these. Write them in whatever way reads most naturally to you, as if the notation already had it, and be consistent within your answer. Write only the card."""
    open(f'{out}/_system.txt', 'w').write(system)
    for f in sorted(glob.glob(os.path.join(briefs, '*.txt'))):
        cid = os.path.basename(f)[:-4]
        body = {'model': model, 'max_tokens': 4000, 'system': system, 'messages': [{'role': 'user', 'content': open(f).read().strip()}]}
        req = urllib.request.Request('https://api.anthropic.com/v1/messages', data=json.dumps(body).encode(), headers={
            'content-type': 'application/json', 'x-api-key': os.environ['ANTHROPIC_API_KEY'], 'anthropic-version': '2023-06-01'})
        t0 = time.time()
        with urllib.request.urlopen(req, timeout=300) as r:
            answer = json.loads(r.read())
        text = ''.join(b.get('text', '') for b in answer['content'])
        open(f'{out}/{cid}.txt', 'w').write(text)
        print(cid, round(time.time() - t0, 1), 's', answer.get('usage', {}).get('output_tokens'), 'tokens out')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""One table over the arms of the head to head, from their recordings' summaries.

    python3 tool/stream/arms_table.py "A2UI=2026-11-14-a2ui-1" "Notation, generic parts=2026-11-14-notation-5" \
        "Notation, designed blocks=2026-11-14-blocks-1" [--per-brief] [--json out.json]

Each argument is label=folder under tool/stream/streams/live/. Per arm and model: cells, median instruction
(input) tokens, median output tokens, median seconds to first token and to the end, answers with a validation
error, answers with something the notation could not read, and answers that needed a retry.
"""
import glob
import json
import os
import statistics
import sys

LIVE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'streams', 'live')


def cells(folder):
    out = {}
    for f in sorted(glob.glob(os.path.join(LIVE, folder, '*.summary.json'))):
        s = json.load(open(f))
        first, last = s['turns'][0], s['turns'][-1]
        out[(s['ui'], s['model'])] = {
            'in': first['input_tokens'] + first.get('cache_read_input_tokens', 0) + first.get('cache_creation_input_tokens', 0),
            'out': sum(t['output_tokens'] for t in s['turns']),
            'ttft': first['ttftMs'] / 1000,
            'total': sum(t['totalMs'] for t in s['turns']) / 1000,
            'nodes': last.get('nodes', 0),
            'errors': len(last.get('errors', [])),
            'unread': len(last.get('notationIssues', [])),
            'retried': len(s['turns']) > 1,
        }
    return out


def main():
    args = [a for a in sys.argv[1:] if '=' in a and not a.startswith('--')]
    arms = [(a.split('=', 1)[0], cells(a.split('=', 1)[1])) for a in args]
    med = statistics.median
    rows, data = [], {}
    for label, c in arms:
        for model in sorted({m for _, m in c}):
            v = [x for (_, m), x in c.items() if m == model]
            r = {'cells': len(v), 'in': med(x['in'] for x in v), 'out': med(x['out'] for x in v), 'ttft': med(x['ttft'] for x in v),
                 'total': med(x['total'] for x in v), 'errors': sum(x['errors'] > 0 for x in v),
                 'unread': sum(x['unread'] > 0 for x in v), 'retried': sum(x['retried'] for x in v)}
            data.setdefault(label, {})[model] = r
            rows.append(f"| {label} | {model} | {r['cells']} | {r['in']:.0f} | {r['out']:.0f} | {r['ttft']:.1f} | {r['total']:.1f} | "
                        f"{r['errors']} | {r['unread']} | {r['retried']} |")
    print('| Arm | Model | Cells | Tokens in | Tokens out | First token (s) | Done (s) | With errors | With unread lines | Retried |')
    print('|---|---|---|---|---|---|---|---|---|---|')
    print('\n'.join(rows))
    if '--per-brief' in sys.argv:
        keys = sorted({k for _, c in arms for k in c})
        print('\n| Brief | Model | ' + ' | '.join(f'{l}: out / s' for l, _ in arms) + ' |')
        print('|---|---|' + '---|' * len(arms))
        for ui, model in keys:
            print(f'| {ui} | {model} | ' + ' | '.join(
                f"{c[(ui, model)]['out']} / {c[(ui, model)]['total']:.1f}" if (ui, model) in c else '' for _, c in arms) + ' |')
    if '--json' in sys.argv:
        json.dump(data, open(sys.argv[sys.argv.index('--json') + 1], 'w'), indent=1)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""The metrics of every replay under a directory, as a Markdown table."""
import json
import os
import sys

root = sys.argv[1]
rows = []
for name in sorted(os.listdir(root)):
    d = os.path.join(root, name)
    if not os.path.isdir(d):
        continue
    for size in sorted(os.listdir(d)):
        p = os.path.join(d, size, 'metrics.json')
        if os.path.exists(p):
            rows.append(json.load(open(p)))
print('| Stream | Size | Source | TTFT ms | First paint ms | First section ms | Complete ms | Output tokens | Ops applied / rejected | Re-applied boxes per op (min/med/p90/max) | Pumps > 16.7 ms | Render errors |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|')
for m in rows:
    r = m['reappliedBoxesPerOp']
    src = m.get('model') or f"synthetic {m.get('rateTokensPerSecond')} tok/s"
    tok = f"{m['outputTokens']}{'~' if m.get('tokensEstimated') else ''}"
    print(f"| {m['stream']} | {m['size']} | {src} | {m.get('ttftMs')} | {m.get('timeToFirstPaintMs')} | {m.get('timeToFirstSectionMs')} | "
          f"{m.get('timeToCompleteMs')} | {tok} | {m['opsApplied']} / {m['opsRejected']} | {r['min']}/{r['median']}/{r['p90']}/{r['max']} | "
          f"{m['pumpsOverBudget16ms']} of {m['pumps']} | {len(m['renderExceptions'])} |")
print()
print('~ estimated (characters / 4). Times are on the replay\'s virtual clock from the request: the stream file\'s delta times.')

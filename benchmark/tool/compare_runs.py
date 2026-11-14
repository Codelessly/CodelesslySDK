#!/usr/bin/env python3
"""Runs lib/compare.dart several times per side, alternating sides, and prints
the median of each number across the runs.

  python3 tool/compare_runs.py [baseUrl] [groups] [runs] [jsonl file to append raw results to]
"""
import json
import os
import statistics
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:5217/'
groups = int(sys.argv[2]) if len(sys.argv) > 2 else 20
runs = int(sys.argv[3]) if len(sys.argv) > 3 else 5
raw = sys.argv[4] if len(sys.argv) > 4 else None
tool = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'run_web.mjs')

results = {'sdk': [], 'flutter': []}
for i in range(runs):
    # Alternate which side goes first, too.
    for side in (('sdk', 'flutter') if i % 2 == 0 else ('flutter', 'sdk')):
        out = subprocess.run(['node', tool, base, f'side={side}&groups={groups}'], capture_output=True, text=True).stdout
        line = next((l for l in out.splitlines() if l.startswith('[bench-result] {')), None)
        if line is None:
            sys.exit(f'no result for {side} on run {i + 1}: {out.strip()}')
        r = json.loads(line[len('[bench-result] '):])
        results[side].append(r)
        if raw:
            with open(raw, 'a') as f:
                f.write(json.dumps(r) + '\n')
        print(f'run {i + 1} {side}: first {r["runAppToFirstFrameMs"]} ms, update {r["updateBuildMs"]["median"]} ms, '
              f'scroll {r["scrollBuildMs"]["median"]} ms', file=sys.stderr)


def get(r, path):
    for k in path.split('.'):
        r = r.get(k) if isinstance(r, dict) else None
    return r


rows = ['notationToDocumentMs', 'runAppToFirstFrameMs', 'firstFrameBuildMs', 'updateBuildMs.median', 'updateBuildMs.p90',
        'scrollBuildMs.median', 'scrollBuildMs.p90', 'scrollExtent']
print(f'groups={groups}, {runs} runs per side; median across runs (min-max)')
print(f'{"":26}{"sdk":>26}{"flutter":>26}')
for row in rows:
    cells = []
    for side in ('sdk', 'flutter'):
        xs = [get(r, row) for r in results[side]]
        xs = [x for x in xs if x is not None]
        cells.append(f'{statistics.median(xs):.1f} ({min(xs):.1f}-{max(xs):.1f})' if xs else '-')
    print(f'{row:26}{cells[0]:>26}{cells[1]:>26}')

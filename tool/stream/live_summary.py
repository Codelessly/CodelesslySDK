#!/usr/bin/env python3
"""The live matrix's one table: per recorded cell (record.dart's
<name>.summary.json and the replays' metrics.json), as Markdown and JSON.

Usage: live_summary.py <streams dir> <replays dir>  ->  <replays dir>/summary.md, summary.json"""
import glob
import json
import os
import sys

streams, outs = sys.argv[1], sys.argv[2]


def metrics(name):
    p = os.path.join(outs, name, '390x844', 'metrics.json')
    return json.load(open(p)) if os.path.exists(p) else {}


rows = []
for summary_path in sorted(glob.glob(os.path.join(streams, '*.summary.json'))):
    name = os.path.basename(summary_path)[:-len('.summary.json')]
    s = json.load(open(summary_path))
    gen = s.get('generate', {})
    retries = s.get('retries', [])
    final = s.get('final', gen)
    follow = s.get('followup')
    m_gen = metrics(name)
    last = name + ('.retry.jsonl' if len(retries) == 1 else f'.retry{len(retries)}.jsonl' if retries else '.jsonl')
    m_last = metrics(last[:-len('.jsonl')])
    lookups = gen.get('lookups', []) + [l for r in retries for l in r.get('lookups', [])]
    out_tokens = gen.get('outputTokens') or 0
    total_ms = gen.get('totalMs') or 0
    first_delta = gen.get('firstToolDeltaMs') or 0
    used = m_last.get('worksWhenUsed')
    ds = s.get('designSystem')
    rows.append({
        'cell': name,
        'ui': s.get('ui'), 'model': s.get('model'), 'prompt': s.get('promptVariant'), 'profile': s.get('profile'),
        # The design system the cell was made with, and how much of the final UI is its: nodes that call its components,
        # against nodes of the raw core controls it replaces (record.dart's counts of the last turn before the follow-up).
        'designSystem': f"{ds.get('id')}@{ds.get('version')}" if ds else None,
        'designSystemComponents': final.get('designSystemComponents') if ds else None,
        'replacedControls': final.get('replacedControls') if ds else None,
        'componentsNotRendered': (m_last.get('designSystem') or {}).get('componentsNotRendered') if ds else None,
        'systemPromptAndToolsTokens': s.get('systemPromptAndToolsTokens'),
        'ttftMs': gen.get('ttftMs'),
        'firstPaintMs': m_gen.get('timeToFirstPaintMs'), 'firstTextMs': m_gen.get('timeToFirstTextMs'),
        'completeMs': gen.get('totalMs'),
        'outputTokens': out_tokens,
        'tokensPerSecond': round(out_tokens / max(1, (total_ms - first_delta)) * 1000, 1) if total_ms else None,
        'ops': gen.get('ops'), 'opsApplied': gen.get('opsApplied'), 'opsRejected': gen.get('opsRejected'),
        'opsRecovered': gen.get('opsRecoveredFromMalformed'), 'jsonRepairs': gen.get('jsonRepairs'),
        'lookups': [l.get('input', {}).get('topic') or l.get('tool') for l in lookups],
        'lookupMs': sum(l.get('ms', 0) for l in lookups), 'lookupTokens': sum(l.get('outputTokens', 0) for l in lookups),
        'retries': len(retries),
        'finalErrors': final.get('errors', []), 'finalLints': final.get('lints', []), 'finalPending': final.get('pending'),
        # The cell's final UI is its last turn's (a retry's replay applies the turns before it): its frame, and what it
        # shows wrong (UiSession.shownDiagnostics after the last frame). The generation's own frame is <cell>/.
        'finalFrame': os.path.join(last[:-len('.jsonl')], '390x844', 'contact.png'),
        'finalShown': sorted({f"{d.get('code')} {d.get('nodeId') or d.get('path')}" for d in m_last.get('shownDiagnostics', [])}),
        'scripts': final.get('scripts'), 'scriptChars': final.get('scriptChars'),
        'scriptErrors': [e for e in m_last.get('renderExceptions', []) if 'script' in json.dumps(e).lower()],
        'worksWhenUsed': None if used is None else used.get('ok'),
        'followupTokens': follow.get('outputTokens') if follow else None,
        'followupMs': follow.get('totalMs') if follow else None,
        'inputTokens': gen.get('inputTokens'), 'cacheRead': gen.get('cacheReadInputTokens'), 'cacheWrite': gen.get('cacheCreationInputTokens'),
        'error': s.get('error'),
    })

for r in rows:
    if r['designSystem']:
        r['dsUse'] = f"{r['designSystemComponents']} / {r['replacedControls']}"
json.dump(rows, open(os.path.join(outs, 'summary.json'), 'w'), indent=1)
cols = [('cell', 'Cell'), ('designSystem', 'Design system'), ('dsUse', 'DS components / raw replaced'),
        ('componentsNotRendered', 'Components not rendered'), ('systemPromptAndToolsTokens', 'Prompt+tools tok'), ('ttftMs', 'TTFT ms'), ('firstPaintMs', 'First paint ms'),
        ('firstTextMs', 'First text ms'), ('completeMs', 'Complete ms'), ('outputTokens', 'Out tok'), ('tokensPerSecond', 'tok/s'),
        ('ops', 'Ops'), ('opsApplied', 'Applied'), ('opsRejected', 'Rejected'), ('opsRecovered', 'Recovered'), ('lookups', 'Lookups'),
        ('retries', 'Retries'), ('finalErrors', 'Final errors'), ('finalLints', 'Final lints'),
        ('finalShown', 'Final UI shows wrong'), ('finalFrame', 'Final frame'), ('scripts', 'Scripts'),
        ('worksWhenUsed', 'Works when used'), ('followupTokens', 'Follow-up tok'), ('followupMs', 'Follow-up ms'),
        ('inputTokens', 'In tok (uncached)'), ('cacheRead', 'Cache read'), ('cacheWrite', 'Cache write')]


def cell(v):
    if isinstance(v, list):
        return ', '.join(str(x) for x in v[:6]) + (f' +{len(v) - 6}' if len(v) > 6 else '') if v else '-'
    return '-' if v is None else str(v)


with open(os.path.join(outs, 'summary.md'), 'w') as f:
    f.write('| ' + ' | '.join(c[1] for c in cols) + ' |\n')
    f.write('|' + '---|' * len(cols) + '\n')
    for r in rows:
        f.write('| ' + ' | '.join(cell(r.get(k)).replace('|', '/') for k, _ in cols) + ' |\n')
    f.write('\nTimes are from the request (TTFT, complete: the API stream; first paint and first text: the replay of the '
            'generation on its recorded clock). Lookups are ui_docs topics (or ui_read) before ui_apply, in the generation '
            'and its retries. "Works when used": the scripted interaction of tool/stream/interactions/<ui>.json on the final UI. '
            '"DS components / raw replaced": for a cell made with a design system, the final UI\'s nodes that call its components '
            'against its nodes of a core control type the design system replaces (a raw filledButton where its Button was meant); '
            '"Components not rendered": calls the replay drew as something other than their definition. '
            '"Final errors" and "Final lints" are the last turn\'s check (record.dart); "Final UI shows wrong" and "Final frame" '
            'are the replay of that last turn (a retry applied over the turns before it): a cell\'s own directory shows its '
            'first generation only, which a retry may have fixed.\n')
print(open(os.path.join(outs, 'summary.md')).read())

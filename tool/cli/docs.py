#!/usr/bin/env python3
"""Look things up in codelessly_api's reference (docs/reference) from a shell.

    tool/codelessly docs                         the pages, with what each covers
    tool/codelessly docs <anchor | name>         one section: forms-validation-and-an-error-state, row, navigate
    tool/codelessly docs <words...>              search needs, topics and names; prints the best section
    tool/codelessly docs --list <words...>       only the matches, best first
    tool/codelessly docs --starter               the path of STARTER.md (the base an agent reads in full first)

The reference is generated from the API's declarations (CodelesslyAPI/tool/reference/generate.dart), so a
section printed here is what the validator and the renderer implement. Sections are cut at the next heading of
the same level; --full prints a long one whole (otherwise it stops after --max-lines lines and says so).

The reference folder is --ref <dir>, else $CODELESSLY_REFERENCE, else docs/reference of the codelessly_api
checkout beside the SDK, else of the codelessly_api the SDK resolved (.dart_tool/package_config.json).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

SDK = Path(__file__).resolve().parents[2]


def find_reference(explicit: str | None) -> Path:
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get('CODELESSLY_REFERENCE'):
        candidates.append(Path(os.environ['CODELESSLY_REFERENCE']))
    if os.environ.get('CODELESSLY_API'):
        candidates.append(Path(os.environ['CODELESSLY_API']) / 'docs' / 'reference')
    for sibling in ('CodelesslyAPI', 'codelessly_api'):
        candidates.append(SDK.parent / sibling / 'docs' / 'reference')
    config = SDK / '.dart_tool' / 'package_config.json'
    if config.exists():
        try:
            for p in json.loads(config.read_text())['packages']:
                if p['name'] == 'codelessly_api':
                    root = p['rootUri']
                    root = root[len('file://'):] if root.startswith('file://') else str((config.parent / root).resolve())
                    candidates.append(Path(root) / 'docs' / 'reference')
        except (KeyError, ValueError):
            pass
    for c in candidates:
        if (c / 'index.json').exists():
            return c.resolve()
    sys.exit('No codelessly_api reference found (looked for docs/reference/index.json in: '
             + ', '.join(str(c) for c in candidates) + '). Pass --ref <dir> or set CODELESSLY_API.')


class Reference:
    def __init__(self, root: Path):
        self.root = root
        self.index = json.loads((root / 'index.json').read_text())
        self._files: dict[str, list[str]] = {}
        # Every anchor of every page: anchor -> file.
        self.anchors: dict[str, str] = {}
        for f in sorted(root.glob('*.md')):
            if f.name in ('API_REFERENCE.md',) or f.name.startswith('_'):
                continue
            for m in re.finditer(r'<a id="([^"]+)"></a>', f.read_text()):
                self.anchors.setdefault(m.group(1), f.name)

    def lines(self, file: str) -> list[str]:
        if file not in self._files:
            self._files[file] = (self.root / file).read_text().splitlines()
        return self._files[file]

    def section(self, file: str, anchor: str) -> list[str]:
        lines = self.lines(file)
        marker = f'<a id="{anchor}"></a>'
        try:
            start = next(i for i, l in enumerate(lines) if l.strip() == marker)
        except StopIteration:
            return []
        level = None
        out: list[str] = []
        for i in range(start + 1, len(lines)):
            l = lines[i]
            m = re.match(r'^(#{1,6})\s', l)
            if m:
                if level is None:
                    level = len(m.group(1))
                elif len(m.group(1)) <= level:
                    break
            out.append(l)
        # Drop anchors that belong to the next section.
        while out and (not out[-1].strip() or out[-1].startswith('<a id=')):
            out.pop()
        return out

    # Everything a query can name: (kind, label, file, anchor, text searched).
    def entries(self):
        for t in self.index.get('topics', []):
            yield ('topic', t['topic'], t['file'], t['anchor'], f"{t['topic']} {t.get('title', '')} {t.get('summary', '')}")
        for t in self.index.get('tasks', []):
            yield ('need', t['need'], t['file'], t['anchor'], t['need'])
        for kind, names in self.index.get('items', {}).items():
            for name, ref in names.items():
                file, _, anchor = ref.partition('#')
                yield (kind, name, file, anchor, name)
        for anchor, file in self.anchors.items():
            yield ('anchor', anchor, file, anchor, anchor.replace('-', ' '))

    def exact(self, q: str):
        if q in self.anchors:
            return self.anchors[q], q
        for t in self.index.get('topics', []):
            if t['topic'] == q:
                return t['file'], t['anchor']
        for names in self.index.get('items', {}).values():
            for name, ref in names.items():
                if name == q or name.lower() == q.lower():
                    file, _, anchor = ref.partition('#')
                    return file, anchor
        return None

    def search(self, words: list[str], limit=12):
        terms = [w.lower() for w in re.findall(r'[A-Za-z0-9_]+', ' '.join(words)) if len(w) > 1]
        if not terms:
            return []
        scored = {}
        for kind, label, file, anchor, text in self.entries():
            hay = text.lower()
            tokens = set(re.findall(r'[a-z0-9_]+', hay))
            score = 0.0
            for t in terms:
                if t in tokens:
                    score += 2
                elif t in hay:
                    score += 1
            if not score:
                continue
            # Prefer labels made of the terms, needs (written as questions people ask), then topics.
            score += {'need': 1.5, 'topic': 1.0}.get(kind, 0)
            score -= len(tokens) * 0.01
            key = (file, anchor)
            if key not in scored or scored[key][0] < score:
                scored[key] = (score, kind, label)
        ranked = sorted(scored.items(), key=lambda kv: -kv[1][0])
        return [(s, kind, label, file, anchor) for (file, anchor), (s, kind, label) in ranked[:limit]]


def main(argv=None):
    p = argparse.ArgumentParser(prog='tool/codelessly docs', description=__doc__.split('\n\n')[0])
    p.add_argument('query', nargs='*')
    p.add_argument('--ref', help='the docs/reference folder')
    p.add_argument('--list', action='store_true', help='only list the matches')
    p.add_argument('--full', action='store_true', help='print a long section whole')
    p.add_argument('--max-lines', type=int, default=220)
    p.add_argument('--starter', action='store_true', help='print the path of STARTER.md')
    p.add_argument('--json', action='store_true', help='matches as JSON (with --list)')
    a = p.parse_args(argv)
    ref = Reference(find_reference(a.ref))

    if a.starter:
        print(ref.root / 'STARTER.md')
        return 0
    if not a.query:
        print(f"codelessly_api {ref.index.get('version')} reference at {ref.root}")
        print('Read STARTER.md in full first (the base); open a page or a section when you need it.\n')
        for t in ref.index['topics']:
            if t['anchor'].startswith('page-'):
                print(f"  {t['topic']:<14} {t['file']:<16} {t.get('summary', '')[:110]}")
        print('\n`tool/codelessly docs <words>` searches every need, topic and name.')
        return 0

    q = ' '.join(a.query)
    hit = None if a.list else ref.exact(q)
    matches = [] if hit else ref.search(a.query)
    if a.list:
        if a.json:
            print(json.dumps([{'kind': k, 'label': l, 'file': f, 'anchor': an, 'score': round(s, 2)}
                              for s, k, l, f, an in matches], indent=1))
        else:
            for s, k, l, f, an in matches:
                print(f'  {an:<52} {k:<10} {l[:80]}')
        return 0 if matches else 1
    if not hit:
        if not matches:
            print(f'Nothing in the reference matches "{q}". `tool/codelessly docs` lists the pages.', file=sys.stderr)
            return 1
        hit = (matches[0][3], matches[0][4])
    file, anchor = hit
    body = ref.section(file, anchor)
    print(f'<!-- {file}#{anchor} (tool/codelessly docs {anchor}) -->')
    if not a.full and len(body) > a.max_lines:
        print('\n'.join(body[:a.max_lines]))
        print(f'\n... {len(body) - a.max_lines} more lines: tool/codelessly docs {anchor} --full')
    else:
        print('\n'.join(body))
    if matches[1:6]:
        print('\nAlso matching:')
        for s, k, l, f, an in matches[1:6]:
            print(f'  tool/codelessly docs {an:<48} ({k}: {l[:60]})')
    return 0


if __name__ == '__main__':
    sys.exit(main())

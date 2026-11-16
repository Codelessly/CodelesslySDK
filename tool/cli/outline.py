#!/usr/bin/env python3
"""What a render drew, as text: every node's type, id, box and text, indented as the tree, with the render's
problems next to the node they are about.

    tool/codelessly outline <render out dir> <document.json | site dir>... [--capture name] [--depth n] [--json]
    tool/codelessly render <documents> --out <dir> --outline       (the same, right after rendering)

A PNG answers "does it look right"; this answers "where is everything and why": the box each node got
(`x,y wxh`), the text it shows, nodes that drew nothing (`empty`), and the warnings (`!`) and errors (`x`) of
`diagnostics*.json` tied to their node. It reads the `*.layout.json` files the render command writes with
`--dump-layout` (`render --outline` passes it) and the documents for the tree and the types. Read it before
the screenshot: most layout mistakes (a zero height, a text clipped, a child pushed off the screen) show here as
numbers.

    canvas home                       0,0 390x844
      column page                     0,0 390x844
        text title                    24,24 342x34  "Hello world"
        filledButton go               24,70 97x40   "Rename"
        ! layout_overflow: "b" (box, 150 wide) overflows its parent ...
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def load_documents(paths: list[str]) -> tuple[dict, dict]:
    """(types by id, parent by id) over every document: pages, components, a site's folder."""
    types: dict[str, str] = {}
    parents: dict[str, str] = {}
    files: list[Path] = []
    for p in paths:
        path = Path(p)
        if path.is_dir():
            files += [f for f in sorted(path.rglob('*.json'))
                      if not f.name.startswith(('_', 'diagnostics')) and '.layout' not in f.name
                      and not any(part.startswith('.') for part in f.relative_to(path).parts)]
        elif path.suffix == '.json' and path.exists():
            files.append(path)
    for f in files:
        try:
            doc = json.loads(f.read_text())
        except (ValueError, OSError):
            continue
        nodes = doc.get('nodes') if isinstance(doc, dict) else None
        if not isinstance(nodes, dict):
            continue
        for nid, n in nodes.items():
            if not isinstance(n, dict):
                continue
            types.setdefault(nid, n.get('type', '?'))
            kids = list(n.get('children') or [])
            kids += list((n.get('slots') or {}).values())
            for v in (n.get('props') or {}).get('variants') or []:
                if isinstance(v, dict):
                    kids += v.get('children') or []
            for k in kids:
                if isinstance(k, str):
                    parents.setdefault(k, nid)
    return types, parents


def base_id(layout_id: str) -> str:
    """`call/inner#2` -> `inner`: the id inside its own document."""
    return re.sub(r'#\d+$', '', layout_id.split('/')[-1])


def contains(a, b, slack=0.5) -> bool:
    return (a['x'] - slack <= b['x'] and a['y'] - slack <= b['y']
            and b['x'] + b['w'] <= a['x'] + a['w'] + slack and b['y'] + b['h'] <= a['y'] + a['h'] + slack)


def fmt(v) -> str:
    return str(int(v)) if float(v).is_integer() else f'{v:.1f}'


def outline_capture(entries: list[dict], types: dict, parents: dict, diags: list[dict], max_depth=None) -> list[str]:
    by_node: dict[str, list[dict]] = {}
    for d in diags:
        if d.get('nodeId'):
            by_node.setdefault(d['nodeId'], []).append(d)
    shown = set()
    stack: list[dict] = []
    lines = []
    for e in entries:
        lid = e['id']
        bid = base_id(lid)
        doc_parent = parents.get(bid)
        # The parent on screen: the nearest open entry that is this node's parent in the document, else the
        # nearest that contains its box (component instances, list copies).
        parent_open = bool(doc_parent) and any(base_id(s['id']) == doc_parent for s in stack)
        while stack:
            top = stack[-1]
            if parent_open:
                if base_id(top['id']) == doc_parent:
                    break
            elif contains(top, e):
                break
            stack.pop()
        depth = len(stack)
        stack.append(e)
        if max_depth is not None and depth > max_depth:
            continue
        kind = types.get(bid, '?')
        box = f"{fmt(e['x'])},{fmt(e['y'])} {fmt(e['w'])}x{fmt(e['h'])}"
        head = f"{'  ' * depth}{kind} {lid}"
        tail = ''
        if 'text' in e and e['text'] is not None:
            t = str(e['text']).replace('\n', '\\n')
            tail = f'  "{t[:70]}{"..." if len(t) > 70 else ""}"'
        if e['w'] == 0 or e['h'] == 0:
            tail += '  (empty: draws nothing)'
        lines.append(f'{head:<44} {box:<22}{tail}'.rstrip())
        for key in (lid, bid):
            if key in by_node and key not in shown:
                shown.add(key)
                for d in by_node[key]:
                    mark = 'x' if d.get('severity') == 'error' else '!'
                    msg = d.get('message', '').replace('\n', ' ')
                    lines.append(f"{'  ' * (depth + 1)}{mark} {d.get('code')}: {msg[:400]}")
    # Problems of nodes this capture did not draw. Validation problems (no size) of nodes that are not on this
    # capture at all (another breakpoint's canvas) belong to the capture that draws them.
    rest = [d for k, ds in by_node.items() if k not in shown for d in ds if d.get('size')]
    for d in rest:
        mark = 'x' if d.get('severity') == 'error' else '!'
        lines.append(f"{mark} {d.get('code')} (node {d.get('nodeId')}, not drawn): {d.get('message', '')[:400]}")
    return lines


def capture_diagnostics(out: Path, capture: str) -> list[dict]:
    """The diagnostics of one capture (`home@390x844`, `home-dark@390x844-saved`...)."""
    found = []
    for f in sorted(out.glob('diagnostics*.json')):
        try:
            data = json.loads(f.read_text())
        except ValueError:
            continue
        label = f.stem[len('diagnostics-'):] if f.stem.startswith('diagnostics-') else None
        if label and not capture.endswith(f'-{label}') and f'-{label}' not in capture:
            continue
        screen, _, size = capture.partition('@')
        size = size.split('-')[0]
        for d in data.get('diagnostics', []):
            if d.get('size') and d.get('size') != size:
                continue
            if d.get('screen') and not screen.startswith(str(d.get('screen'))):
                continue
            found.append(d)
    return found


def main(argv=None):
    p = argparse.ArgumentParser(prog='tool/codelessly outline', description=__doc__.split('\n\n')[0])
    p.add_argument('out', help="the render's --out directory")
    p.add_argument('documents', nargs='*', help='the documents or site folder that were rendered (for types and the tree)')
    p.add_argument('--capture', action='append', help='only captures whose name contains this (repeatable)')
    p.add_argument('--depth', type=int, help='hide nodes deeper than this')
    p.add_argument('--json', action='store_true', help='entries with type and depth as JSON')
    a = p.parse_args(argv)
    out = Path(a.out)
    layouts = sorted(out.glob('*.layout.json'))
    if not layouts:
        print(f'No *.layout.json in {out}: render with --dump-layout (or tool/codelessly render ... --outline).', file=sys.stderr)
        return 2
    types, parents = load_documents(a.documents)
    result = {}
    for f in layouts:
        capture = f.name[:-len('.png.layout.json')] if f.name.endswith('.png.layout.json') else f.name[:-len('.layout.json')]
        if a.capture and not any(c in capture for c in a.capture):
            continue
        entries = json.loads(f.read_text())
        diags = capture_diagnostics(out, capture)
        lines = outline_capture(entries, types, parents, diags, a.depth)
        result[capture] = lines
        if not a.json:
            errors = sum(1 for d in diags if d.get('severity') == 'error')
            warnings = len(diags) - errors
            print(f'== {capture}  ({len(entries)} nodes, {errors} errors, {warnings} warnings)')
            print('\n'.join(lines))
            print()
    if a.json:
        print(json.dumps(result, indent=1, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())

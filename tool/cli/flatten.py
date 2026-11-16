#!/usr/bin/env python3
"""Nested node trees to a flat layout document (schema 3), the form the validator and the renderer read.

    tool/codelessly flatten <tree.json> [--out doc.json] [--size 390x844] [--screen name]

Writing a screen as one nested tree is how a model (and the editor's `layouts.*` and `nodes.insertTree`
commands) naturally writes it; a layout document keeps every node in one flat `nodes` map. This turns one into
the other, so a tree written for the editor renders headless with `tool/codelessly render` first.

The input is any of:

* a **node tree**: `{"type": "column", "children": [{"type": "text", ...}, ...]}`; a root that is not a
  `canvas` is put in the `body` slot of one (`--size` gives its size, `--screen` its id);
* **trees per breakpoint**, as `layouts.createResponsive` takes them: `{"trees": {"mobile": tree, "tablet":
  tree, "desktop": tree}}` (optionally with `variables`, `conditions`, `scripts`, `canvasActions`): one canvas
  per breakpoint, all one screen (`props.screen`, `props.breakpoint`);
* a **document** whose nodes nest some children instead of naming their ids: those children are lifted out.

In a tree, a node's `key` (or `id`) names it: that becomes its id, and any string `"@key"` anywhere in the tree
(an action's target, a states patch, a variable's node) becomes that id, as the editor does. Nodes without one get
`<type><n>` ids. `children` lists and `slots` maps may hold node objects or ids.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

BREAKPOINT_SIZES = {'mobile': (390, 844), 'tablet': (834, 1112), 'desktop': (1440, 900)}


class Flattener:
    def __init__(self, taken=()):
        self.nodes: dict[str, dict] = {}
        self.taken = set(taken)
        self.counts: dict[str, int] = {}
        self.keys: dict[str, str] = {}

    def fresh(self, base: str) -> str:
        base = re.sub(r'[^A-Za-z0-9_-]', '_', base) or 'node'
        if base not in self.taken and base not in self.nodes:
            return base
        n = self.counts.get(base, 1)
        while f'{base}{n}' in self.taken or f'{base}{n}' in self.nodes:
            n += 1
        self.counts[base] = n + 1
        return f'{base}{n}'

    def add(self, tree: dict, prefer: str | None = None) -> str:
        n = dict(tree)
        key = n.pop('key', None)
        explicit = n.pop('id', None)
        nid = self.fresh(str(explicit or key or prefer or n.get('type', 'node')))
        if key:
            self.keys[str(key)] = nid
        if explicit and str(explicit) != nid:
            self.keys[str(explicit)] = nid
        self.nodes[nid] = n  # placed before its children: the document lists parents first
        if isinstance(n.get('children'), list):
            n['children'] = [self.add(c) if isinstance(c, dict) else c for c in n['children']]
        if isinstance(n.get('slots'), dict):
            n['slots'] = {s: self.add(c) if isinstance(c, dict) else c for s, c in n['slots'].items()}
        variants = (n.get('props') or {}).get('variants')
        if isinstance(variants, list):
            for v in variants:
                if isinstance(v, dict) and isinstance(v.get('children'), list):
                    v['children'] = [self.add(c) if isinstance(c, dict) else c for c in v['children']]
        return nid

    def resolve(self, value):
        """`"@key"` strings (and keys of maps, as states patches name nodes) become ids."""
        if isinstance(value, str):
            if value.startswith('@') and value[1:] in self.keys:
                return self.keys[value[1:]]
            return value
        if isinstance(value, list):
            return [self.resolve(v) for v in value]
        if isinstance(value, dict):
            return {self.resolve(k) if isinstance(k, str) else k: self.resolve(v) for k, v in value.items()}
        return value


def is_node_tree(x) -> bool:
    return isinstance(x, dict) and isinstance(x.get('type'), str) and 'nodes' not in x


def canvas_for(root_id: str, cid: str, size, f: Flattener, screen=None, breakpoint=None, actions=None) -> dict:
    c = {'type': 'canvas', 'name': screen or cid, 'slots': {'body': root_id}}
    if size:
        c['layout'] = {'width': size[0], 'height': size[1]}
    if screen and breakpoint:
        c['props'] = {'screen': screen, 'breakpoint': breakpoint}
    if actions:
        c['actions'] = actions
    return c


def flatten(data, size=None, screen=None) -> dict:
    # A document: lift nested children out of its nodes.
    if isinstance(data, dict) and isinstance(data.get('nodes'), dict) and 'type' not in data:
        doc = dict(data)
        f = Flattener(taken=data['nodes'].keys())
        out_nodes = {}
        for nid, node in data['nodes'].items():
            if not isinstance(node, dict):
                out_nodes[nid] = node
                continue
            f.nodes = {}
            n = dict(node)
            if isinstance(n.get('children'), list):
                n['children'] = [f.add(c) if isinstance(c, dict) else c for c in n['children']]
            if isinstance(n.get('slots'), dict):
                n['slots'] = {s: f.add(c) if isinstance(c, dict) else c for s, c in n['slots'].items()}
            out_nodes[nid] = n
            out_nodes.update(f.nodes)
            f.taken.update(f.nodes)
        doc['nodes'] = f.resolve(out_nodes)
        for k in ('variables', 'conditions', 'scripts'):
            if k in doc:
                doc[k] = f.resolve(doc[k])
        doc.setdefault('schema', 3)
        return doc

    f = Flattener()
    roots = []
    extra = {}
    if isinstance(data, dict) and isinstance(data.get('trees'), dict):
        name = screen or data.get('screen') or data.get('name') or 'screen'
        for bp, tree in data['trees'].items():
            # Each breakpoint's tree is one scope, as the editor reads it: its "@key" names a node of that tree
            # (the trees reuse keys: the mobile "retry" and the desktop "retry" are two nodes).
            f.keys = {}
            before = set(f.nodes)
            body = f.add(tree, prefer=f'{bp}_root')
            for nid in set(f.nodes) - before:
                f.nodes[nid] = f.resolve(f.nodes[nid])
            cid = f.fresh(f'{name}_{bp}')
            f.nodes[cid] = canvas_for(body, cid, BREAKPOINT_SIZES.get(bp, size), f, screen=name,
                                      breakpoint=bp, actions=data.get('canvasActions'))
            roots.append(cid)
        extra = {k: data[k] for k in ('variables', 'conditions', 'scripts', 'breakpoints') if k in data}
    elif is_node_tree(data):
        if data['type'] == 'canvas':
            roots.append(f.add(data, prefer=screen or 'screen'))
        else:
            body = f.add(data)
            cid = f.fresh(screen or 'screen')
            f.nodes[cid] = canvas_for(body, cid, size, f)
            roots.append(cid)
    else:
        raise SystemExit('Not a node tree, {"trees": {...}} or a document: see tool/codelessly flatten --help.')
    # Canvases first, as documents list them.
    nodes = {r: f.nodes[r] for r in roots}
    nodes.update({k: v for k, v in f.nodes.items() if k not in nodes})
    doc = {'schema': 3, 'roots': roots, 'nodes': f.resolve(nodes)}
    variables = extra.get('variables')
    if isinstance(variables, list):  # a list: page variables
        extra['variables'] = {'page_variables': variables}
    doc.update(f.resolve(extra))
    return doc


def main(argv=None):
    p = argparse.ArgumentParser(prog='tool/codelessly flatten', description=__doc__.split('\n\n')[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__.split('\n\n', 2)[2])
    p.add_argument('input', help='a .json file, or - for stdin')
    p.add_argument('--out', help='write the document here (default: stdout)')
    p.add_argument('--size', default=None, help='the canvas size for a tree that is not a canvas, WxH (default 390x844)')
    p.add_argument('--screen', help="the canvas's id (and the screen's name for trees per breakpoint)")
    a = p.parse_args(argv)
    text = sys.stdin.read() if a.input == '-' else Path(a.input).read_text()
    size = tuple(int(x) for x in (a.size or '390x844').lower().split('x'))
    doc = flatten(json.loads(text), size=size, screen=a.screen)
    out = json.dumps(doc, indent=1, ensure_ascii=False)
    if a.out:
        Path(a.out).write_text(out + '\n')
        print(f"wrote {a.out}: {len(doc['nodes'])} nodes, roots {', '.join(doc['roots'])}", file=sys.stderr)
    else:
        print(out)
    return 0


if __name__ == '__main__':
    sys.exit(main())

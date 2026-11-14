#!/usr/bin/env python3
"""Writes examples/catalog.json: every component at each of its previews, in alphabetical order.

The gallery (gallery.py) is hand-composed and shows the first components in all their variants;
this page is generated from the components' own `previews`, so it always holds every component.
"""
import glob
import json
import os

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
nodes, variables, tiles = {}, [], []

VAR_TYPES = {'string': 'text', 'number': 'decimal', 'integer': 'integer', 'boolean': 'boolean', 'list': 'list'}

for path in sorted(glob.glob(os.path.join(HERE, 'components', '*.json')), key=lambda p: os.path.basename(p).lower()):
    doc = json.load(open(path))
    spec = doc['widget']
    kinds = {p['key']: p['type'] for p in spec.get('props', [])}
    required = {p['key']: p.get('default') for p in spec.get('props', []) if p.get('required')}
    previews = doc.get('previews') or [{'name': '', 'size': [200, 40], 'props': {}}]
    for i, preview in enumerate(previews):
        tid = f"{spec['type']}{i}"
        props = {}
        for key, value in preview.get('props', {}).items():
            kind = kinds.get(key, {})
            if kind.get('kind') == 'variable':
                name = f'v{tid}{key.capitalize()}'
                variables.append({'name': name, 'type': VAR_TYPES.get(kind.get('of', {}).get('kind'), 'text'), 'value': value})
                props[key] = name
            else:
                props[key] = value
        # A preview leaves a required parameter at its default: a call must write it.
        for key, default in required.items():
            if key not in props and kinds[key].get('kind') != 'variable':
                props[key] = default
        # A variable parameter the preview leaves out still needs a variable to name.
        for key, kind in kinds.items():
            if kind.get('kind') == 'variable' and key not in props:
                name = f'v{tid}{key.capitalize()}'
                of = kind.get('of', {}).get('kind')
                variables.append({'name': name, 'type': VAR_TYPES.get(of, 'text'),
                                  'value': {'number': 0, 'integer': 0, 'boolean': False, 'list': []}.get(of, '')})
                props[key] = name
        width = min(max(preview.get('size', [200, 40])[0], 24), 560)
        height = preview.get('size', [200, 40])[1]
        # As the component's own root says: one that hugs is as big as its content, one that fills gets the preview's size.
        root = doc['nodes'][doc['roots'][0]].get('layout', {})
        hugs = lambda v: isinstance(v, dict) and 'hug' in v
        fills = lambda v: isinstance(v, dict) and 'fill' in v
        nodes[tid] = {'type': spec['type'], 'props': props,
                      'layout': {'width': {'hug': width} if hugs(root.get('width')) else width,
                                 'height': height if fills(root.get('height')) else {'hug': height}}}
        label = spec['type'] + (f" · {preview['name']}" if preview.get('name') else '')
        nodes[tid + 'L'] = {'type': 'text', 'props': {'text': label, 'style': 'caption'},
                            'layout': {'width': {'hug': 80}, 'height': {'hug': 14}}}
        nodes[tid + 'T'] = {'type': 'column', 'children': [tid + 'L', tid], 'props': {'spacing': 6, 'crossAxisAlignment': 'start'},
                            'layout': {'width': {'hug': width}, 'height': {'hug': 60}}}
        tiles.append(tid + 'T')

nodes['wrap'] = {'type': 'row', 'children': tiles, 'props': {'wrap': True, 'spacing': 28, 'runSpacing': 28, 'crossAxisAlignment': 'start'},
                 'layout': {'width': {'fill': 1160}, 'height': {'hug': 400}}}
nodes['title'] = {'type': 'text', 'props': {'text': f'Soft SaaS UI: {len(set(t[:-2].rstrip("0123456789") for t in tiles))} components', 'style': 'pageTitle'},
                  'layout': {'width': {'fill': 1160}, 'height': {'hug': 28}}}
nodes['col'] = {'type': 'column', 'children': ['title', 'wrap'], 'props': {'spacing': 24, 'crossAxisAlignment': 'start', 'scrollable': True},
                'layout': {'width': {'fill': 1200}, 'height': {'fill': 900}, 'padding': 20}}
nodes['catalog'] = {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 1200, 'height': 900},
                    'decoration': {'fills': [{'color': 'primaryBackground'}]}}

out = os.path.join(HERE, 'examples', 'catalog.json')
json.dump({'schema': 3, 'id': 'catalog', 'roots': ['catalog'], 'variables': {'catalog': variables}, 'nodes': nodes},
          open(out, 'w'), indent=1)
print(f'{out}: {len(tiles)} previews')

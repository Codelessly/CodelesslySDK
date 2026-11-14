"""Inlines component calls into plain nodes.

The "bar" screens are full documents with no component in them: every block a page calls is expanded here into
its nodes, with the call's arguments written into the expressions that read them. What comes out is what a
person writing the whole screen at the full API would write (and it renders with no design system at all).
"""
import copy
import json
import re

_SEGMENT = re.compile(r'\$\{((?:[^{}]|\{[^{}]*\})*)\}')
_PROP = re.compile(r'\bprops\.([A-Za-z_]\w*)')


def literal(v):
    """A JSON value as a formula literal."""
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return "'" + v.replace('\\', '\\\\').replace("'", "\\'") + "'"
    if isinstance(v, list):
        return '[' + ', '.join(literal(x) for x in v) + ']'
    if v is None:
        return "''"
    raise ValueError(f'no formula literal for {v!r}')


def as_formula(value):
    """A call's argument (a literal, or a string holding ${...}) as one formula."""
    if not isinstance(value, str) or '${' not in value:
        return literal(value)
    parts, at = [], 0
    for m in _SEGMENT.finditer(value):
        if m.start() > at:
            parts.append(literal(value[at:m.start()]))
        inner = m.group(1).strip()
        inner = inner[1:].strip() if inner.startswith('=') else inner
        parts.append(f'({inner})')
        at = m.end()
    if at < len(value):
        parts.append(literal(value[at:]))
    return parts[0] if len(parts) == 1 else '(' + ' + '.join(parts) + ')'


def substitute(value, args):
    """Every `props.x` in the expressions of a JSON value replaced by the argument's formula."""
    if isinstance(value, dict):
        return {k: substitute(v, args) for k, v in value.items()}
    if isinstance(value, list):
        return [substitute(v, args) for v in value]
    if not isinstance(value, str) or 'props.' not in value:
        return value

    def segment(m):
        inner = m.group(1).strip()
        if 'props.' not in inner:
            return m.group(0)
        inner = inner[1:].strip() if inner.startswith('=') else inner
        return '${= ' + _PROP.sub(lambda p: args[p.group(1)], inner) + '}'

    return _SEGMENT.sub(segment, value)


def call_args(component, call):
    """The formula of every parameter of `component` as this call sets it (its default when it does not)."""
    args = {}
    for p in component['widget'].get('props', []):
        key = p['key']
        if f'props.{key}' in call.get('bind', {}):
            args[key] = as_formula(call['bind'][f'props.{key}'])
        elif key in call.get('props', {}):
            args[key] = as_formula(call['props'][key])
        else:
            args[key] = literal(p.get('default', ''))
    return args


def inline(nodes, components):
    """`nodes` (a page's) with every call to one of `components` replaced by that component's nodes."""
    out = {}

    def expand(call_id, call, target):
        comp = components[call['type']]
        args = call_args(comp, call)
        root = comp['roots'][0]
        name = lambda i: call_id if i == root else f'{call_id}_{i}'
        handlers = {}
        for reaction in call.get('actions', []):
            if reaction.get('trigger', {}).get('type') == 'event':
                handlers.setdefault(reaction['trigger']['event'], []).extend(reaction['actions'])
        for nid, n in comp['nodes'].items():
            n = substitute(copy.deepcopy(n), args)
            if n['type'] == 'slot':
                continue
            kids = []
            for c in n.get('children', []):
                kids.extend(call.get('children', []) if comp['nodes'][c]['type'] == 'slot' else [name(c)])
            if 'children' in n:
                n['children'] = kids
            if 'states' in n:
                n['states'] = {state: {name(k): v for k, v in patch.items()} for state, patch in n['states'].items()}
            for reaction in n.get('actions', []):
                acts = []
                for a in reaction['actions']:
                    acts.extend(copy.deepcopy(handlers.get(a.get('event'), [])) if a.get('type') == 'componentEvent' else [a])
                reaction['actions'] = acts
            if 'actions' in n:
                n['actions'] = [r for r in n['actions'] if r['actions']]
                if not n['actions']:
                    del n['actions']
                    n.pop('states', None)
            if nid == root:
                layout = dict(n.get('layout', {}))
                layout.update(call.get('layout', {}))
                n['layout'] = layout
                for k in ('animations', 'opacity'):
                    if k in call:
                        n[k] = call[k]
                if 'visible' in call.get('bind', {}):
                    n.setdefault('bind', {})['visible'] = call['bind']['visible']
            if n['type'] in components:
                expand(name(nid), n, target)
            else:
                target[name(nid)] = n

    for nid, n in nodes.items():
        if n['type'] in components:
            expand(nid, n, out)
        else:
            out[nid] = n
    return out


def load_components(folder, names):
    return {n: json.load(open(f'{folder}/{n}.json')) for n in names}

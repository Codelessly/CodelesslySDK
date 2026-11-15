"""Helpers the card blocks are written with: nodes, text, icons, surfaces, taps, parameters, components.

Every color, radius, shadow and text style is named from the theme, so a token set restyles every block.
"""

HUG = {'hug': 0}
FILL = {'fill': 0}

STRING = {'kind': 'string', 'flutter': 'String'}
INT = {'kind': 'integer', 'flutter': 'int'}
NUM = {'kind': 'number', 'flutter': 'double'}
BOOL = {'kind': 'boolean', 'flutter': 'bool'}
STRINGS = {'kind': 'list', 'flutter': 'List<String>', 'item': STRING}
NUMBERS = {'kind': 'list', 'flutter': 'List<double>', 'item': NUM}
JSON = {'kind': 'json', 'flutter': 'dynamic'}
ROWS = {'kind': 'list', 'flutter': 'List<dynamic>', 'item': JSON}


def var(of):
    return {'kind': 'variable', 'of': of}


def enum(*values):
    return {'kind': 'enumeration', 'flutter': 'String', 'values': list(values)}


def P(key, kind, default, doc, required=False):
    p = {'key': key, 'type': kind, 'default': default, 'doc': doc}
    if required:
        p['required'] = True
    return p


def node(type_, layout=None, props=None, children=None, decoration=None, bind=None, **more):
    n = {'type': type_}
    if children is not None:
        n['children'] = children
    if props:
        n['props'] = props
    n['layout'] = layout or {'width': FILL, 'height': HUG}
    if decoration:
        n['decoration'] = decoration
    if bind:
        n['bind'] = bind
    n.update(more)
    return n


def col(children, spacing=0, cross='stretch', width=FILL, height=HUG, pad=None, main=None, **more):
    lay = {'width': width, 'height': height}
    if pad is not None:
        lay['padding'] = pad
    props = {'crossAxisAlignment': cross, 'spacing': spacing}
    if main:
        props['mainAxisAlignment'] = main
    return node('column', lay, props, children, **more)


def row(children, spacing=0, cross='center', width=FILL, height=HUG, pad=None, main=None, **more):
    lay = {'width': width, 'height': height}
    if pad is not None:
        lay['padding'] = pad
    props = {'crossAxisAlignment': cross, 'spacing': spacing}
    if main:
        props['mainAxisAlignment'] = main
    return node('row', lay, props, children, **more)


def text(value, style, width=HUG, color=None, bind=None, layout=None, **props):
    if color:
        style = {'from': style, 'color': color} if isinstance(style, str) else {**style, 'color': color}
    lay = {'width': width, 'height': HUG}
    lay.update(layout or {})
    more = {k: props.pop(k) for k in list(props) if k in ("actions", "states", "animations", "opacity", "transitions")}
    return node("text", lay, {"text": value, "style": style, **props}, bind=bind, **more)


def icon(name, size, color, bind=None, **more):
    return node('icon', {'width': size, 'height': size}, {'icon': name, 'size': size, 'color': color}, bind=bind, **more)


def spacer(w=None, h=None):
    return node('spacer', {'width': FILL if w is None else w, 'height': 1 if h is None else h})


def box(width, height, decoration=None, **more):
    return node('box', {'width': width, 'height': height}, decoration=decoration, **more)


def fills(color):
    return {'fills': [{'color': color}]}


def lin(a, b, begin='topLeft', end='bottomRight'):
    return {'type': 'linear', 'begin': begin, 'end': end, 'stops': [{'position': 0, 'color': a}, {'position': 1, 'color': b}]}


def surface(color='card', radius='panel', shadow=None, stroke=None, clip=False):
    """A surface: (decoration, bind). Radius and shadow come from the theme's scales by name."""
    deco = {'fills': [{'color': color}] if isinstance(color, str) else [color], 'radius': 16}
    bind = {'decoration.radius': '${theme.radii.%s}' % radius}
    if shadow:
        bind['decoration.effects'] = '${theme.shadows.%s}' % shadow
    if stroke:
        deco['strokes'] = [{'color': stroke}]
        deco['strokeWidth'] = 1
    if clip:
        deco['clip'] = 'antiAlias'
    return deco, bind


def tap(*actions, event='onPressed', value=None):
    """A click reaction: the given actions, then (unless event is None) the component's event."""
    acts = list(actions)
    if event:
        a = {'type': 'componentEvent', 'event': event}
        if value is not None:
            a['value'] = value
        acts.append(a)
    return [{'trigger': {'type': 'click'}, 'actions': acts}]


def setv(variable, expr):
    return {'type': 'setVariable', 'variable': variable, 'value': expr if expr.startswith('${') else '${= %s}' % expr}


def shown_if(expr):
    return '${= %s}' % expr


def enter(order=0, rise=10):
    """The entrance a block plays when it appears: a short fade and rise, later for blocks lower in a card."""
    return [{'id': 'enter', 'duration': 360, 'delay': 45 * order, 'curve': 'easeOutCubic',
             'tracks': [{'path': 'opacity', 'from': 0, 'to': 1}, {'path': 'motion.translateY', 'from': rise, 'to': 0}]}]


PRESS = {'opacity': 0.82}


def component(type_, doc, props, nodes, root, events=None, children=False, previews=None, variables=None):
    widget = {'type': type_, 'doc': doc, 'props': props}
    if events:
        widget['events'] = [{'key': k, 'doc': d} for k, d in events]
    if children:
        widget['children'] = 'list'
    doc_ = {'schema': 3, 'id': type_, 'roots': [root], 'widget': widget, 'previews': previews or [], 'nodes': nodes}
    if variables:
        doc_['variables'] = {root: variables}
    return doc_

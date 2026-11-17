"""The Cards blocks: the designed parts of an inline chat card, each a component a card calls with one line.

Every block reads its colors, radii, shadows and type from the theme by name, so a token set restyles it.
A block's root fills the width and hugs its height. Blocks that hold a choice or a quantity take the name of
the card's variable (a `variable` parameter) and change it themselves; every block has at most one event.
"""
import art
from kit import *  # noqa: F401,F403
from kit import FILL, HUG, STRING, INT, NUM, BOOL, STRINGS, NUMBERS, ROWS, JSON, P, PRESS

TONES = ('accent', 'good', 'warn', 'danger', 'neutral')
TONE = P('tone', enum(*TONES), 'accent', 'The color role: accent, good, warn, danger or neutral.')


def tone_vars(expr='props.tone'):
    """Three colors a block computes from its tone: the ink, the tint behind it and the tint's line."""
    def pick(a, g, w, d, n):
        return ("%s == 'good' ? theme.colors.%s : %s == 'warn' ? theme.colors.%s : %s == 'danger' ? theme.colors.%s : "
                "%s == 'neutral' ? theme.colors.%s : theme.colors.%s") % (expr, g, expr, w, expr, d, expr, n, a)
    return [
        {'name': 'toneInk', 'type': 'text', 'formula': pick('accent', 'good', 'warn', 'bad', 'inkSoft')},
        {'name': 'toneDeep', 'type': 'text', 'formula': pick('accentDeep', 'goodDeep', 'warnDeep', 'badDeep', 'ink')},
        {'name': 'toneTint', 'type': 'text', 'formula': pick('accentTint', 'goodTint', 'warnTint', 'badTint', 'tile')},
        {'name': 'toneLine', 'type': 'text', 'formula': pick('accentLine', 'goodLine', 'warnLine', 'badLine', 'lineStrong')},
    ]


def pill(nid, label, ink='inkSoft', fill='tile', pad=(9, 5, 9, 5), icon_name=None, style='chip', bind=None):
    """A small pill: {nid: row, nid+'T': text[, nid+'I': icon]}."""
    kids = ([nid + 'I'] if icon_name else []) + [nid + 'T']
    out = {nid: row(kids, 4, width=HUG, pad=list(pad), decoration={'fills': [{'color': fill}], 'radius': 999},
                    bind={'decoration.radius': '${theme.radii.chip}', **(bind or {})}),
           nid + 'T': text(label, style, color=ink)}
    if icon_name:
        out[nid + 'I'] = icon(icon_name, 13, ink)
    return out


# --- ChatCard: the shell ----------------------------------------------------------------------------------

def chat_card():
    deco, bind = surface('card', 'card', 'card', clip=True)
    nodes = {
        'shell': col(['card'], pad=[10, 10, 10, 16], decoration=fills('page')),
        'card': col(['head', 'content'], decoration=deco, bind=bind, animations=enter(0)),
        'head': row(['mark', 'titles', 'status'], 12, pad=[18, 18, 18, 0],
                    bind={'visible': "${= props.title != ''}"}),
        'mark': row(['markIcon'], width=40, height=40, main='center',
                    decoration={'fills': [{'color': 'accentTint'}], 'radius': 13},
                    bind={'decoration.fills[0].color': '${toneTint}', 'visible': "${= props.icon != ''}",
                          'decoration.radius': '${= min(13, theme.radii.tile)}'}),
        'markIcon': icon('auto_awesome_rounded', 21, 'accent', bind={'props.icon': '${props.icon}', 'props.color': '${toneInk}'}),
        'titles': col(['title', 'subtitle'], 2, cross='start'),
        'title': text('${props.title}', 'cardTitle', FILL, maxLines=2, overflow='ellipsis'),
        'subtitle': text('${props.subtitle}', 'meta', FILL, bind={'visible': "${= props.subtitle != ''}"}, maxLines=2, overflow='ellipsis'),
        'status': row(['statusDot', 'statusText'], 6, width=HUG, pad=[9, 6, 11, 6],
                      decoration={'fills': [{'color': 'tile'}], 'radius': 999},
                      bind={'decoration.fills[0].color': '${toneTint}', 'visible': "${= props.status != ''}",
                            'decoration.radius': '${theme.radii.chip}'}),
        'statusDot': box(6, 6, {'fills': [{'color': 'accent'}], 'radius': 3}, bind={'decoration.fills[0].color': '${toneInk}'}),
        'statusText': text('${props.status}', 'chip', bind={'props.style.color': '${toneDeep}'}),
        'content': col(['slot'], 14, pad=[18, 16, 18, 18]),
        'slot': {'type': 'slot'},
    }
    props = [
        P('title', STRING, '', 'The card title.'),
        P('subtitle', STRING, '', 'One quiet line under the title (empty: none).'),
        P('icon', STRING, '', 'A Material icon name for the tile before the title (empty: no tile).'),
        P('status', STRING, '', 'A small status pill at the right of the header, e.g. Draft or Step 1 of 3 (empty: none).'),
        TONE,
    ]
    return component('ChatCard', "The card itself: put it at the root and write the blocks indented under it (a white rounded card with a header: icon tile, title, subtitle and a status pill; tone colors the tile and pill: accent, good, warn, danger, neutral).",
                     props, nodes, 'shell', children=True, variables=tone_vars(),
                     previews=[{'name': 'Header', 'size': [420, 120], 'props': {'title': 'London to Lisbon', 'subtitle': 'Fri 20 Nov · 1 adult',
                                                                               'icon': 'flight_takeoff_rounded', 'status': '3 options'}}])


# --- ActionButton -----------------------------------------------------------------------------------------

def action_button():
    def fill_of():
        return ("${= props.tone == 'quiet' ? theme.colors.tile : props.tone == 'danger' ? theme.colors.bad : "
                "props.tone == 'good' ? theme.colors.goodDeep : props.tone == 'dark' ? theme.colors.bar : theme.colors.accent}")
    def ink_of():
        return "${= props.tone == 'quiet' ? theme.colors.ink : props.tone == 'dark' ? theme.colors.onBar : theme.colors.onAccent}"
    nodes = {
        'btn': row(['icon', 'label'], 8, height=46, main='center', pad=[16, 0, 16, 0],
                   decoration={'fills': [{'color': 'accent'}], 'radius': 14},
                   bind={'decoration.fills[0].color': fill_of(), 'decoration.radius': '${theme.radii.cta}',
                         'decoration.effects': "${= props.tone == 'primary' && props.enabled ? theme.shadows.cta : []}",
                         'opacity': '${= props.enabled ? 1 : 0.4}'},
                   states={'pressed': {'btn': PRESS}},
                   actions=[{'trigger': {'type': 'click'}, 'actions': [
                       {'type': 'if', 'condition': {'left': '${props.enabled}', 'op': 'isTrue'},
                        'then': [{'type': 'componentEvent', 'event': 'onPressed'}]}]}]),
        'icon': icon('check_rounded', 18, 'onAccent', bind={'props.icon': '${props.icon}', 'props.color': ink_of(),
                                                          'visible': "${= props.icon != ''}"}),
        'label': text('${props.label}', 'cta', bind={'props.style.color': ink_of()}, maxLines=1, overflow='ellipsis'),
    }
    props = [
        P('label', STRING, 'Continue', "The button's label.", True),
        P('tone', enum('primary', 'quiet', 'danger', 'good', 'dark'), 'primary', 'primary (the accent, one per card), quiet (grey), danger (red), good (green) or dark.'),
        P('icon', STRING, '', 'A Material icon before the label (empty: none).'),
        P('enabled', BOOL, True, 'False dims it and it does not fire.'),
    ]
    return component('ActionButton', "A full-width button that fires onPressed: tone is primary (one per card), quiet, danger, good or dark; enabled={condition} dims and blocks it; put two in a Row gap=10 for a pair such as Cancel and Confirm.",
                     props, nodes, 'btn', events=[('onPressed', 'The button was tapped while enabled.')],
                     previews=[{'name': 'Primary', 'size': [240, 46], 'props': {'label': 'Confirm flight'}},
                               {'name': 'Quiet', 'size': [240, 46], 'props': {'label': 'Cancel', 'tone': 'quiet'}}])


# --- TotalBar ---------------------------------------------------------------------------------------------

def total_bar():
    nodes = {
        'bar': row(['left', 'cta'], 12, pad=[18, 11, 11, 11], main='spaceBetween',
                   decoration={'fills': [lin('bar', 'barRaise', 'centerLeft', 'centerRight')], 'radius': 18},
                   bind={'decoration.radius': '${theme.radii.panel}', 'decoration.effects': '${theme.shadows.bar}'}),
        'left': col(['label', 'amountRow'], 1, cross='start'),
        'label': text('${props.label}', 'meta', FILL, color='onBarSoft', maxLines=1, overflow='ellipsis'),
        'amountRow': row(['amount', 'note'], 7, cross='end'),
        'amount': text('${props.amount}', 'number', color='onBar', maxLines=1),
        'note': text('${props.note}', 'meta', FILL, color='onBarSoft', layout={'padding': [0, 0, 0, 3]}, maxLines=1, overflow='ellipsis',
                     bind={'visible': "${= props.note != ''}"}),
        'cta': row(['ctaLabel', 'ctaIcon'], 6, width=HUG, height=46, pad=[16, 0, 12, 0],
                   decoration={'fills': [lin('accentBright', 'accent', 'topCenter', 'bottomCenter')], 'radius': 12},
                   bind={'decoration.radius': '${= max(0, theme.radii.panel - 6)}', 'opacity': '${= props.enabled ? 1 : 0.38}',
                         'visible': "${= props.cta != ''}"},
                   states={'pressed': {'cta': PRESS}},
                   actions=[{'trigger': {'type': 'click'}, 'actions': [
                       {'type': 'if', 'condition': {'left': '${props.enabled}', 'op': 'isTrue'},
                        'then': [{'type': 'componentEvent', 'event': 'onPressed'}]}]}]),
        'ctaLabel': text('${props.cta}', 'cta', color='onAccent', maxLines=1),
        'ctaIcon': icon('arrow_forward_rounded', 18, 'onAccent', bind={'props.icon': '${props.icon}'}),
    }
    props = [
        P('label', STRING, 'Total', 'What the amount is, small over it.', True),
        P('amount', STRING, '$0.00', 'The amount or headline value, large (text: format money yourself).', True),
        P('note', STRING, '', 'A quiet note after the amount (empty: none).'),
        P('cta', STRING, 'Confirm', "The button's label (empty: no button)."),
        P('icon', STRING, 'arrow_forward_rounded', "The icon after the button's label."),
        P('enabled', BOOL, True, 'False dims the button and it does not fire.'),
    ]
    return component('TotalBar', "The card's closing bar on dark: a label over a large amount (a total, a count, a chosen time) with a note, and one cta button at the right that fires onPressed; enabled={condition} dims and blocks the button.",
                     props, nodes, 'bar', events=[('onPressed', 'The button was tapped while enabled.')],
                     previews=[{'name': 'Total', 'size': [380, 70], 'props': {'label': 'Total', 'amount': '£128', 'note': '1 adult',
                                                                              'cta': 'Confirm flight'}}])


# --- Details ----------------------------------------------------------------------------------------------

def details():
    shown = "(length(item) > 1 && text(at(item, 1)) != '')"
    nodes = {
        'box': col(['list'], pad=[14, 3, 14, 3], decoration={'fills': [{'color': 'tile'}], 'radius': 14},
                   bind={'decoration.radius': '${theme.radii.tile}'}),
        'list': vlist(['item'], 0, '${props.rows}'),
        'item': row(['icon', 'label', 'value'], 9, pad=[0, 10, 0, 10], bind={'visible': E(shown)},
                    decoration={'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1, 'strokeSides': 'top'}),
        'icon': icon('circle', 16, 'inkFaint', bind={'visible': E('length(props.icons) > index'),
                                                     'props.icon': E("length(props.icons) > index ? at(props.icons, index) : 'circle'")}),
        'label': text('${= at(item, 0)}', {'from': 'lead', 'fontSize': 13.5}, FILL, maxLines=1, overflow='ellipsis'),
        'value': text("${= length(item) > 1 ? at(item, 1) : ''}", {'from': 'figure', 'fontWeight': 600}, textAlign='right', maxLines=2,
                      overflow='ellipsis', layout={'constraints': {'maxWidth': 210}}),
    }
    nodes['item']['bind']['decoration.strokeWidth'] = '${= index == 0 ? 0 : 1}'
    props = [
        P('rows', ROWS, [['Subtotal', '$25.95'], ['Delivery', '$4.99']], 'One [label, value] pair per row; a row whose value is empty is not shown.', True),
        P('icons', STRINGS, [], 'A Material icon per row, before its label (optional).'),
    ]
    return component('Details', "Labels and their values as rows in one quiet tile (a price breakdown, the facts of a request): rows={[[\"Subtotal\",money(sub,\"$\",2)],[\"Delivery\",\"$4.99\"]]}, each a [label, value] pair (a row with an empty value is hidden); icons is an optional list alongside.",
                     props, nodes, 'box',
                     previews=[{'name': 'Prices', 'size': [340, 90], 'props': {}}])


# --- FlightOption -----------------------------------------------------------------------------------------

def flight_option():
    sel = 'props.selected'
    path = {'painter': [
        {'op': 'line', 'p1': [6, '${= size.height / 2}'], 'p2': ['${= size.width - 6}', '${= size.height / 2}'],
         'paint': {'color': '${theme.colors.lineStrong}', 'style': 'stroke', 'strokeWidth': 1.5, 'strokeCap': 'round', 'dashPattern': [1, 5]}},
        {'op': 'circle', 'c': [4, '${= size.height / 2}'], 'radius': 3.5, 'paint': {'color': '${theme.colors.inkGhost}', 'style': 'stroke', 'strokeWidth': 1.5}},
        {'op': 'circle', 'c': ['${= size.width - 4}', '${= size.height / 2}'], 'radius': 3.5, 'paint': '${theme.colors.inkGhost}'},
    ]}
    nodes = {
        'wrap': col(['card'], pad=[0, 0, 0, 10]),
        'card': col(['top', 'rule', 'bottom'], 12, pad=[16, 14, 16, 12],
                    decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1.5, 'radius': 18},
                    bind={'decoration.radius': '${theme.radii.panel}',
                          'decoration.strokes[0].color': '${= %s ? theme.colors.accent : theme.colors.line}' % sel,
                          'decoration.fills[0].color': '${= %s ? theme.colors.accentTint : theme.colors.card}' % sel,
                          'decoration.effects': '${= %s ? theme.shadows.pick : []}' % sel},
                    states={'pressed': {'card': PRESS}}, actions=tap()),
        'top': row(['dep', 'mid', 'arr'], 12),
        'dep': col(['depTime', 'depCode'], 1, cross='start', width=HUG),
        'depTime': text('${props.depart}', 'number'),
        'depCode': text('${props.origin}', 'meta'),
        'mid': col(['dur', 'path', 'stops'], 3, cross='center'),
        'dur': text('${props.duration}', {'from': 'meta', 'fontWeight': 600}, color='inkSoft'),
        'path': node('stack', {'width': FILL, 'height': 18}, children=['plane'], customPaint=path),
        'plane': node('row', {'width': 26, 'height': 18, 'x': {'align': 0}, 'y': 0}, {'mainAxisAlignment': 'center'}, ['planeIcon'],
                      decoration={'fills': [{'color': 'card'}]},
                      bind={'decoration.fills[0].color': '${= %s ? theme.colors.accentTint : theme.colors.card}' % sel}),
        'planeIcon': icon('flight_rounded', 16, 'inkFaint', bind={'props.color': '${= %s ? theme.colors.accent : theme.colors.inkFaint}' % sel},
                          motion={'rotate': 90}),
        'stops': text('${props.stops}', 'meta'),
        'arr': col(['arrTime', 'arrCode'], 1, cross='end', width=HUG),
        'arrTime': text('${props.arrive}', 'number'),
        'arrCode': text('${props.destination}', 'meta'),
        'rule': box(FILL, 1, {'fills': [{'color': 'line'}]},
                    bind={'decoration.fills[0].color': '${= %s ? theme.colors.accentLine : theme.colors.line}' % sel}),
        'bottom': row(['logo', 'airline', 'tag', 'price', 'radio'], 9),
        'logo': row(['logoText'], width=26, height=26, main='center', decoration={'fills': [{'color': 'bar'}], 'radius': 8}),
        'logoText': text('${= upper(substring(props.name, 0, 1))}', {'from': 'chip', 'fontWeight': 700}, color='onBar'),
        'airline': text('${props.name}', {'from': 'meta', 'fontWeight': 600}, FILL, color='inkSoft', maxLines=1, overflow='ellipsis'),
        'tag': row(['tagText'], width=HUG, pad=[8, 4, 8, 4], decoration={'fills': [{'color': 'goodTint'}], 'radius': 999},
                   bind={'decoration.radius': '${theme.radii.chip}', 'visible': "${= props.tag != ''}",
                         'decoration.fills[0].color': "${= contains(lower(props.tag), 'cheap') ? theme.colors.goodTint : theme.colors.warnTint}"}),
        'tagText': text('${props.tag}', 'chip', bind={
            'props.style.color': "${= contains(lower(props.tag), 'cheap') ? theme.colors.goodDeep : theme.colors.warnDeep}"}),
        'price': text('${props.price}', 'number'),
        'radio': node('row', {'width': 22, 'height': 22}, {'mainAxisAlignment': 'center'}, ['radioIcon'],
                      decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1.5, 'radius': 11},
                      bind={'decoration.fills[0].color': '${= %s ? theme.colors.accent : theme.colors.card}' % sel,
                            'decoration.strokes[0].color': '${= %s ? theme.colors.accent : theme.colors.lineStrong}' % sel}),
        'radioIcon': icon('check_rounded', 15, 'onAccent', bind={'visible': '${%s}' % sel}),
    }
    props = [
        P('name', STRING, 'TAP Air Portugal', 'The airline.', True),
        P('depart', STRING, '07:15', 'Departure time.', True),
        P('arrive', STRING, '09:50', 'Arrival time.', True),
        P('origin', STRING, '', 'Where from, small under the departure time (LHR or London).'),
        P('destination', STRING, '', 'Where to, small under the arrival time.'),
        P('duration', STRING, '', 'The flight time, over the path (2h 35m).'),
        P('stops', STRING, 'Direct', 'Under the path: Direct, or 1 stop.'),
        P('price', STRING, '', 'The price, as text (£128).'),
        P('tag', STRING, '', 'A small tag such as Cheapest or Best time (empty: none).'),
        P('selected', BOOL, False, 'True draws it chosen: accent border, tint and a check.'),
    ]
    return component('FlightOption', "One flight as a selectable option: the airline name, depart and arrive times over origin and destination, the duration and stops on a drawn path, the price, a tag (Cheapest, Best time); selected={pick==f.id} marks it and a tap fires onPressed (-> pick=f.id).",
                     props, nodes, 'wrap', events=[('onPressed', 'The option was tapped.')],
                     previews=[{'name': 'Selected', 'size': [380, 130], 'props': {
                         'origin': 'LHR', 'destination': 'LIS', 'duration': '2h 35m', 'price': '£128', 'tag': 'Best time', 'selected': True}}])


# --- Media and WeatherGlyph: the drawn art ----------------------------------------------------------------

GLYPH_TONES = ('sand', 'rose', 'mint', 'sky', 'lilac', 'slate')
SCENE_TONES = ('dawn', 'day', 'dusk', 'night')


def _chain(expr, table, fallback):
    return ' : '.join("%s == '%s' ? %s" % (expr, k, v) for k, v in table) + ' : ' + fallback


def media_vars():
    tone = "(props.tone != 'auto' ? props.tone : %s)" % _chain('props.kind', [(k, "'%s'" % v) for k, v in {**art.GLYPH_TONE, **art.SCENE_TONE}.items()], "'sand'")
    out = []
    for name, suffix in (('A', 'A'), ('B', 'B'), ('M', 'Mid'), ('K', 'Ink')):
        out.append({'name': name, 'type': 'text',
                    'formula': _chain(tone, [(t, 'theme.colors.%s%s' % (t, suffix)) for t in GLYPH_TONES[1:]], 'theme.colors.sand%s' % suffix)})
    for name, suffix in (('s1', 'Sky1'), ('s2', 'Sky2'), ('orb', 'Orb'), ('far', 'Far'), ('mid', 'Mid'), ('near', 'Near'), ('lit', 'Light')):
        out.append({'name': name, 'type': 'text',
                    'formula': _chain(tone, [(t, 'theme.colors.%s%s' % (t, suffix)) for t in SCENE_TONES[1:]], 'theme.colors.dawn%s' % suffix)})
    return out


def media():
    whole = {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}
    is_glyph = ' || '.join("props.kind == '%s'" % k for k in art.GLYPHS)
    ground = {'painter': [
        {'op': 'rect', 'rect': [0, 0, '${size.width}', '${size.height}'], 'paint': art.grad([(0, 'A'), (1, 'B')], 'topLeft', 'bottomRight')},
        {'op': 'circle', 'c': ['${= size.width / 2}', '${= size.height * 0.48}'], 'radius': '${= min(size.width, size.height) * 0.4}',
         'paint': '${theme.colors.artShine}'},
    ]}
    nodes = {
        'media': node('stack', {'width': FILL, 'height': 150}, children=['ground'],
                      decoration={'radius': 14, 'clip': 'antiAlias'}, bind={'decoration.radius': '${= props.round ? theme.radii.tile : 0}'}),
        'ground': node('box', dict(whole), bind={'visible': '${= %s}' % is_glyph}, customPaint=ground),
    }
    # One paint node per family: each kind is a group drawn only when it is the kind asked for.
    nodes['glyphs'] = node('box', dict(whole), bind={'visible': '${= %s}' % is_glyph},
                           customPaint={'viewBox': [120, 120], 'fit': 'contain', 'painter': [
                               {'op': 'group', 'when': "${= props.kind == '%s'}" % k, 'ops': f()} for k, f in art.GLYPHS.items()]})
    nodes['scenes'] = node('box', dict(whole), bind={'visible': '${= !(%s)}' % is_glyph},
                           customPaint={'viewBox': [160, 120], 'fit': 'cover', 'painter': [
                               {'op': 'group', 'when': "${= props.kind == '%s'}" % k, 'ops': f()} for k, f in art.SCENES.items()]})
    nodes['media']['children'] += ['glyphs', 'scenes']
    props = [
        P('kind', enum(*art.GLYPHS, *art.SCENES), 'mountain', 'What is drawn. Products and food on a toned ground: %s. Travel scenes: %s.' % (
            ', '.join(art.GLYPHS), ', '.join(art.SCENES)), True),
        P('tone', enum('auto', *GLYPH_TONES, *SCENE_TONES), 'auto', 'The palette. For a product: sand, rose, mint, sky, lilac or slate. For a scene, the time of day: dawn, day, dusk or night. auto picks one per kind.'),
        P('round', BOOL, True, 'Rounded corners (false when a parent clips it).'),
    ]
    return component('Media', "A drawn picture where a photo would go (never use an image URL): kind is a product or food (%s) on a toned ground, or a travel scene (%s); tone recolors it (products: sand, rose, mint, sky, lilac, slate; scenes: dawn, day, dusk, night); size it with h (and w)." % (
        ', '.join(art.GLYPHS), ', '.join(art.SCENES)),
        props, nodes, 'media', variables=media_vars(),
        previews=[{'name': k, 'size': [200, 150], 'props': {'kind': k}} for k in ('shoe', 'mountain', 'harbor')])


def weather_glyph():
    whole = {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}
    nodes = {'glyph': node('box', {'width': 48, 'height': 48}, customPaint={'viewBox': [96, 96], 'fit': 'contain', 'painter': [
        {'op': 'group', 'when': "${= props.kind == '%s'}" % k, 'ops': list(f())} for k, f in art.WEATHER.items()]})}
    props = [P('kind', enum(*art.WEATHER), 'sun', 'The conditions: %s.' % ', '.join(art.WEATHER), True)]
    return component('WeatherGlyph', "A drawn weather glyph: kind is %s; size it with w and h." % ', '.join(art.WEATHER),
                     props, nodes, 'glyph', previews=[{'name': k, 'size': [96, 96], 'props': {'kind': k}} for k in art.WEATHER])


def E(expr):
    return '${= %s}' % expr


def click(*actions):
    return [{'trigger': {'type': 'click'}, 'actions': list(actions)}]


def fire(event, value=None):
    a = {'type': 'componentEvent', 'event': event}
    if value is not None:
        a['value'] = value
    return a


def grid(children, columns, gap, data, run_gap=None, **more):
    """A list laid out in equal columns, each row as tall as its tallest cell."""
    props = {'crossAxisCount': columns if isinstance(columns, int) else 1, 'crossAxisSpacing': gap,
             'mainAxisSpacing': gap if run_gap is None else run_gap, 'shrinkWrapRows': True, 'physics': 'never'}
    bind = {'data': data}
    if not isinstance(columns, int):
        bind['props.crossAxisCount'] = columns
    bind.update(more.pop('bind', {}))
    return node('gridView', {'width': FILL, 'height': HUG}, props, children, bind=bind, **more)


def vlist(children, gap, data, **more):
    bind = {'data': data}
    bind.update(more.pop('bind', {}))
    return node('listView', {'width': FILL, 'height': HUG}, {'scrollable': False, 'spacing': gap}, children, bind=bind, **more)


def round_button(nid, icon_name, size=34, fill='tile', ink='ink', actions=None, bind=None, icon_bind=None, icon_size=None):
    return {nid: node('row', {'width': size, 'height': size}, {'mainAxisAlignment': 'center'}, [nid + 'I'],
                      decoration={'fills': [{'color': fill}], 'radius': size / 2}, bind=bind,
                      states={'pressed': {nid: {'opacity': 0.6}}}, actions=actions or []),
            nid + 'I': icon(icon_name, icon_size or round(size * 0.56), ink, bind=icon_bind)}


# --- SectionLabel -----------------------------------------------------------------------------------------

def section_label():
    nodes = {
        'head': row(['label', 'note'], 8, pad=[0, 4, 0, 0], main='spaceBetween'),
        'label': text('${= upper(props.label)}', 'eyebrow', FILL, maxLines=1, overflow='ellipsis'),
        'note': text('${props.note}', 'meta', bind={'visible': "${= props.note != ''}"}),
    }
    props = [P('label', STRING, 'Section', 'The heading, shown in small caps.', True),
             P('note', STRING, '', 'A quiet note at the right, e.g. a count (empty: none).')]
    return component('SectionLabel', "A small caps heading over a group of blocks, with a quiet note at the right (a count, a unit).",
                     props, nodes, 'head', previews=[{'name': 'Label', 'size': [340, 24], 'props': {'label': 'Next 5 hours', 'note': 'Lisbon'}}])


# --- Paragraph --------------------------------------------------------------------------------------------

def paragraph():
    nodes = {'text': text('${props.text}', 'lead', FILL, bind={'props.style.color': "${= props.strong ? theme.colors.ink : theme.colors.inkSoft}"})}
    props = [P('text', STRING, '', 'The sentence or two.', True),
             P('strong', BOOL, False, 'True for the darker ink.')]
    return component('Paragraph', "A sentence or two of body text in the card's own type and color (what will happen, a description): use it instead of Text for prose.",
                     props, nodes, 'text', previews=[{'name': 'Text', 'size': [340, 44], 'props': {'text': 'Nothing is removed until you approve.'}}])


# --- Callout ----------------------------------------------------------------------------------------------

def callout():
    nodes = {
        'box': row(['icon', 'texts'], 11, cross='start', pad=[13, 12, 14, 12],
                   decoration={'fills': [{'color': 'warnTint'}], 'strokes': [{'color': 'warnLine'}], 'strokeWidth': 1, 'radius': 14},
                   bind={'decoration.fills[0].color': '${toneTint}', 'decoration.strokes[0].color': '${toneLine}',
                         'decoration.radius': '${theme.radii.tile}'}),
        'icon': icon('info_rounded', 19, 'warn', bind={'props.icon': '${props.icon}', 'props.color': '${toneInk}'}),
        'texts': col(['title', 'message'], 2, cross='start'),
        'title': text('${props.title}', 'rowTitle', FILL, bind={'props.style.color': '${toneDeep}', 'visible': "${= props.title != ''}"}),
        'message': text('${props.message}', {'from': 'lead', 'fontSize': 13.5}, FILL, bind={'visible': "${= props.message != ''}"}),
    }
    props = [
        P('title', STRING, '', 'The short point, bold (This cannot be undone).'),
        P('message', STRING, '', 'One or two sentences under it (empty: none).'),
        P('tone', enum(*TONES), 'warn', 'accent, good, warn, danger or neutral.'),
        P('icon', STRING, 'info_rounded', 'A Material icon.'),
    ]
    return component('Callout', "A tinted note inside a card: a bold title and a message with an icon; tone is warn (default), danger (a risk, cannot be undone), good, accent or neutral.",
                     props, nodes, 'box', variables=tone_vars(),
                     previews=[{'name': 'Risk', 'size': [340, 70], 'props': {'title': 'This cannot be undone', 'message': 'Deleted files skip the trash.',
                                                                           'tone': 'danger', 'icon': 'warning_rounded'}}])


# --- Disclosure -------------------------------------------------------------------------------------------

def disclosure():
    nodes = {
        'wrap': col(['head', 'body'], 8),
        'head': row(['chev', 'label', 'count'], 6, actions=click({'type': 'setVariable', 'variable': 'open', 'op': 'toggle'}),
                    states={'pressed': {'head': PRESS}}),
        'chev': icon('chevron_right_rounded', 20, 'accent', bind={'props.icon': "${= open ? 'expand_more_rounded' : 'chevron_right_rounded'}"}),
        'label': text('${props.label}', {'from': 'rowTitle', 'fontSize': 13.5}, FILL, color='accent'),
        'count': text('${= length(props.lines)}', 'meta', bind={'visible': '${= !open}'}),
        'body': col(['list', 'more'], 0, pad=[4, 4, 4, 4], decoration={'fills': [{'color': 'tile'}], 'radius': 14},
                    bind={'visible': '${open}', 'decoration.radius': '${theme.radii.tile}'}),
        'list': vlist(['line'], 0, '${props.lines}'),
        'line': row(['lineIcon', 'lineText'], 9, pad=[10, 7, 10, 7]),
        'lineIcon': icon('insert_drive_file_outlined', 15, 'inkFaint', bind={'props.icon': '${props.icon}'}),
        'lineText': text('${item}', {'from': 'code', 'fontSize': 12}, FILL, color='inkSoft', maxLines=1, overflow='ellipsis'),
        'more': text('${props.note}', 'meta', FILL, layout={'padding': [34, 4, 10, 8]}, bind={'visible': "${= props.note != ''}"}),
    }
    props = [
        P('label', STRING, 'Show details', 'The link that opens it.', True),
        P('lines', STRINGS, [], 'The lines it reveals (file names, items), in monospace.', True),
        P('note', STRING, '', 'A quiet last line, e.g. "and 209 more" (empty: none).'),
        P('icon', STRING, 'insert_drive_file_outlined', 'The icon before each line.'),
    ]
    return component('Disclosure', "A link that opens and closes a short list by itself (the first few file names, the fine print): label is the link, lines the list shown in monospace, note a quiet last line.",
                     props, nodes, 'wrap', variables=[{'name': 'open', 'type': 'boolean', 'value': False}],
                     previews=[{'name': 'Closed', 'size': [340, 30], 'props': {'label': 'Show the first 5 file names', 'lines': ['a.txt', 'b.txt']}}])


# --- Receipt ----------------------------------------------------------------------------------------------

def receipt():
    confetti = {'viewBox': [120, 84], 'fit': 'contain', 'painter': [
        art.circle(60, 42, 38, '${toneTint}'),
        art.faded(0.9, art.circle(18, 20, 3, '${toneInk}'), art.circle(104, 30, 2.4, '${theme.colors.gold}'),
                  art.circle(98, 66, 3, '${toneInk}'), art.circle(22, 62, 2.4, '${theme.colors.gold}'),
                  art.rrect(8, 40, 7, 3, 1.5, '${theme.colors.accentBright}'), art.rrect(106, 48, 7, 3, 1.5, '${theme.colors.accentBright}'),
                  art.rrect(36, 6, 3, 7, 1.5, '${theme.colors.gold}'), art.rrect(82, 74, 3, 7, 1.5, '${theme.colors.accentBright}')),
    ]}
    nodes = {
        'box': col(['badge', 'title', 'message', 'code'], 0, cross='center', pad=[20, 22, 20, 22],
                   decoration={'fills': [{'color': 'tile'}], 'radius': 18}, bind={'decoration.radius': '${theme.radii.panel}'},
                   animations=enter(0, 8)),
        'badge': node('row', {'width': 120, 'height': 84}, {'mainAxisAlignment': 'center'}, ['disc'], customPaint=confetti),
        'disc': node('row', {'width': 50, 'height': 50}, {'mainAxisAlignment': 'center'}, ['discIcon'],
                     decoration={'fills': [{'color': 'good'}], 'radius': 25},
                     bind={'decoration.fills[0].color': '${toneInk}', 'decoration.effects': '${theme.shadows.tile}'}),
        'discIcon': icon('check_rounded', 30, 'onAccent', bind={'props.icon': '${props.icon}'}),
        'title': text('${props.title}', 'cardTitle', FILL, textAlign='center', layout={'padding': [0, 10, 0, 0]}),
        'message': text('${props.message}', 'lead', FILL, textAlign='center', layout={'padding': [0, 5, 0, 0]},
                        bind={'visible': "${= props.message != ''}"}),
        'code': row(['codeLabel', 'codeText'], 8, width=HUG, pad=[12, 7, 12, 7],
                    decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1, 'dashPattern': [4, 3], 'radius': 10},
                    bind={'visible': "${= props.code != ''}"}),
        'codeLabel': text('${= upper(props.codeLabel)}', 'eyebrow'),
        'codeText': text('${props.code}', {'from': 'code', 'fontWeight': 700, 'fontSize': 13}),
    }
    nodes['code']['layout']['margin'] = [0, 14, 0, 0]
    props = [
        P('title', STRING, 'All done', 'What happened, e.g. Order confirmed.', True),
        P('message', STRING, '', 'One or two sentences under it.'),
        P('code', STRING, '', 'A reference to keep: an order or booking number (empty: none).'),
        P('codeLabel', STRING, 'Reference', 'What the code is.'),
        P('tone', enum(*TONES), 'good', 'good (done), danger (denied, deleted), neutral (cancelled), accent or warn.'),
        P('icon', STRING, 'check_rounded', 'The icon in the badge: check_rounded, close_rounded, send_rounded.'),
    ]
    return component('Receipt', "The card's end state after a decision: a drawn badge with an icon, a title, a message and an optional code (an order or booking number); tone good for done, danger for denied, neutral for cancelled; show it under an if line in place of the controls.",
                     props, nodes, 'box', variables=tone_vars(),
                     previews=[{'name': 'Done', 'size': [340, 230], 'props': {'title': 'Order confirmed', 'message': 'A receipt is on its way.',
                                                                            'code': 'CL-48213', 'codeLabel': 'Order'}}])


# --- Recommendation ---------------------------------------------------------------------------------------

def recommendation():
    nodes = {
        'card': col(['body'], decoration={'fills': [lin('heroA', 'heroB')], 'radius': 18, 'clip': 'antiAlias'},
                    bind={'decoration.radius': '${theme.radii.panel}', 'decoration.effects': '${theme.shadows.hero}'}),
        'body': col(['top', 'reasons'], 12, pad=[18, 16, 18, 18], customPaint={'painter': [
            {'op': 'circle', 'c': ['${= size.width - 40}', 30], 'radius': 110, 'paint': '${theme.colors.heroLine}'},
            {'op': 'circle', 'c': ['${= size.width - 40}', 30], 'radius': 70, 'paint': '${theme.colors.heroLine}'}]}),
        'top': row(['heads', 'art'], 14, cross='start'),
        'heads': col(['chip', 'title', 'why'], 8, cross='start'),
        'chip': row(['chipIcon', 'chipText'], 5, width=HUG, pad=[8, 5, 10, 5], decoration={'fills': [{'color': 'heroChip'}], 'radius': 999},
                    bind={'visible': "${= props.eyebrow != ''}"}),
        'chipIcon': icon('auto_awesome_rounded', 13, 'onHero'),
        'chipText': text('${props.eyebrow}', 'chip', color='onHero'),
        'title': text('${props.title}', {'from': 'cardTitle', 'fontSize': 21, 'letterSpacing': -0.4}, FILL, color='onHero',
                      layout={'padding': [0, 2, 0, 0]}),
        'art': node('Media', {'width': 84, 'height': 84}, {'kind': 'laptop'}, bind={'props.kind': "${= props.kind != '' ? props.kind : 'box'}",
                                                                                 'visible': "${= props.kind != ''}"}),
        'why': text('${props.why}', {'from': 'lead', 'fontSize': 13.5}, FILL, color='onHeroSoft', bind={'visible': "${= props.why != ''}"}),
        'reasons': vlist(['reason'], 7, '${props.reasons}', bind={'visible': '${= length(props.reasons) > 0}'}),
        'reason': row(['reasonIcon', 'reasonText'], 9, cross='start'),
        'reasonIcon': icon('check_circle_rounded', 17, 'onHero'),
        'reasonText': text('${item}', {'from': 'lead', 'fontSize': 13.5, 'fontWeight': 500, 'height': 1.3}, FILL, color='onHero'),
    }
    props = [
        P('title', STRING, 'Our pick', 'What is recommended.', True),
        P('why', STRING, '', 'One sentence of reasoning.'),
        P('reasons', STRINGS, [], 'Short reasons, each with a check (empty: none).'),
        P('eyebrow', STRING, 'Recommended', 'The small chip over the title.'),
        P('kind', STRING, '', 'A Media kind drawn at the right, e.g. laptop or shoe (empty: none).'),
    ]
    return component('Recommendation', "The one recommendation on the accent gradient: a title, why (one sentence), reasons (a list, each with a check), an eyebrow chip and an optional drawn picture (kind, as Media).",
                     props, nodes, 'card',
                     previews=[{'name': 'Pick', 'size': [340, 200], 'props': {'title': 'Max plan', 'why': 'Unlimited data and roaming for $20 more.',
                                                                            'reasons': ['Wins 5 of 6 rows', 'No contract']}}])


# --- Steps ------------------------------------------------------------------------------------------------

def steps():
    n = 'length(props.steps)'
    y = 13
    lines = {'painter': [
        {'op': 'line', 'p1': [0, y], 'p2': ['${= size.width / 2 - 18}', y], 'when': '${= index > 0}',
         'paint': {'color': '${= index < props.current ? theme.colors.accent : theme.colors.lineStrong}', 'style': 'stroke', 'strokeWidth': 2, 'strokeCap': 'round'}},
        {'op': 'line', 'p1': ['${= size.width / 2 + 18}', y], 'p2': ['${= size.width}', y], 'when': '${= index < %s - 1}' % n,
         'paint': {'color': '${= index + 1 < props.current ? theme.colors.accent : theme.colors.lineStrong}', 'style': 'stroke', 'strokeWidth': 2, 'strokeCap': 'round'}},
    ]}
    done, now = 'index + 1 < props.current', 'index + 1 == props.current'
    nodes = {
        'steps': grid(['cell'], E('max(1, %s)' % n), 0, '${props.steps}'),
        'cell': col(['dot', 'label'], 6, cross='center', customPaint=lines),
        'dot': node('row', {'width': 26, 'height': 26}, {'mainAxisAlignment': 'center'}, ['dotCheck', 'dotNum'],
                    decoration={'fills': [{'color': 'tile'}], 'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1.5, 'radius': 13},
                    bind={'decoration.fills[0].color': E('%s ? theme.colors.accent : %s ? theme.colors.accentTint : theme.colors.card' % (done, now)),
                          'decoration.strokes[0].color': E('%s || %s ? theme.colors.accent : theme.colors.lineStrong' % (done, now))}),
        'dotCheck': icon('check_rounded', 16, 'onAccent', bind={'visible': E(done)}),
        'dotNum': text('${= index + 1}', {'from': 'chip', 'fontWeight': 700}, bind={
            'visible': E('!(%s)' % done), 'props.style.color': E('%s ? theme.colors.accent : theme.colors.inkFaint' % now)}),
        'label': text('${item}', 'chip', FILL, textAlign='center', maxLines=1, overflow='ellipsis', bind={
            'props.style.color': E('%s ? theme.colors.ink : %s ? theme.colors.inkSoft : theme.colors.inkFaint' % (now, done))}),
    }
    props = [
        P('steps', STRINGS, ['Cart', 'Shipping', 'Payment'], 'The step names, in order.', True),
        P('current', INT, 1, 'The step the user is on, counted from 1; earlier steps show a check (one more than the count: all done).', True),
    ]
    return component('Steps', "Progress through named steps as numbered dots joined by a line: steps is the list of names, current the step the user is on counted from 1 (earlier ones are checked).",
                     props, nodes, 'steps', previews=[{'name': 'Second', 'size': [340, 54], 'props': {'current': 2}}])


# --- Tab-like controls ------------------------------------------------------------------------------------
# Three kinds, one rule. Tabs (and BrowserTabs): the views of a page, any number of them. Segments, TabToggle and
# SegmentedControl: a small switch in a track, two to four short options. ChipTabs and ChoiceChips: pills (a
# filter, a choice of slots). All but ChoiceChips stay on one line: when the options do not fit, the line scrolls
# sideways (every label at its own width, the line fading where it continues, the chosen option brought into
# view); it never wraps and never squeezes a label. A phone (a window under 700 wide) gets 44 high tap areas.

PHONE = 'screen.width < 700'
HOVER = {'decoration': {'foregroundFills': [{'color': 'hoverOverlay'}]}}
DOWN = {'decoration': {'foregroundFills': [{'color': 'pressedOverlay'}]}}
EASE = [{'property': 'decoration', 'duration': 150}]


def strip(children, gap=0, fade=24, width=FILL, pad=None, **more):
    """One line that scrolls sideways when its children do not fit, fading at the edge it continues past."""
    lay = {'width': width, 'height': HUG}
    if width is HUG:
        lay['squeezable'] = True  # as wide as its options, and no wider than its place
    if pad is not None:
        lay['padding'] = pad
    return node('row', lay, {'crossAxisAlignment': 'center', 'spacing': gap, 'scrollable': True, 'scrollDirection': 'horizontal',
                             'edgeFade': fade, 'fillViewport': width is not HUG}, children, **more)


def line_of(children, data, height, gap=0, bind=None, **more):
    """The options of a strip from a list: every one laid out, each as wide as its label."""
    return node('listView', {'width': HUG, 'height': height}, {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': gap},
                children, bind={'data': data, **(bind or {})}, **more)


def reveal(item, options):
    """Brings the chosen option of a list into view: when the strip appears and whenever the choice changes."""
    at_ = 'indexOf(%s, props.value)' % options
    go = {'type': 'scrollTo', 'node': item, 'item': E(at_), 'axis': 'horizontal', 'alignment': 0.5, 'curve': 'easeOutCubic'}
    return [{'trigger': {'type': 'load', 'when': '%s > 0' % at_}, 'actions': [{**go, 'durationMs': 0}]},
            {'trigger': {'type': 'valueChanged', 'variable': 'props.value', 'when': '%s >= 0' % at_}, 'actions': [{**go, 'durationMs': 240}]}]


def knob_cell(p, label, on, pick, width=HUG, height=FILL, pad_x=14, font=13, bind=None, text_bind=None, knob_bind=None, min_width=None):
    """One option of a track: its tap area as tall as the track, the knob inset in it (raised when chosen), its label."""
    return {
        p: node('row', {'width': width, 'height': height, 'padding': [1.5, 3, 1.5, 3], **({'constraints': {'minWidth': 0}} if min_width else {})},
                {'crossAxisAlignment': 'center'}, [p + 'Knob'],
                bind={**(bind or {}), **({'layout.constraints': E('{minWidth: %s}' % min_width)} if min_width else {})}, states={'hovered': {p + 'Knob': HOVER}, 'pressed': {p + 'Knob': DOWN}}, actions=click(*pick)),
        p + 'Knob': node('row', {'width': width, 'height': FILL, 'padding': [pad_x, 0, pad_x, 0], **({'constraints': {'minWidth': 0}} if min_width else {})},
                         {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'}, [p + 'Text'],
                         decoration={'fills': [{'color': '#00FFFFFF'}], 'radius': 9},
                         bind={'decoration.fills[0].color': E("%s ? theme.colors.raisedBackground : '#00FFFFFF'" % on),
                               'decoration.effects': E('%s ? theme.shadows.knob : []' % on),
                               'decoration.radius': E('max(0, theme.radii.control - 3)'), **(knob_bind or {}),
                               **({'layout.constraints': E('{minWidth: %s - 3}' % min_width)} if min_width else {})},
                         transitions=EASE),
        p + 'Text': text(label, {'from': 'chip', 'fontSize': font}, maxLines=1, bind={
            'props.style.color': E('%s ? theme.colors.ink : theme.colors.inkSoft' % on), **(text_bind or {})}),
    }


def track(children, width=FILL, bind=None):
    return node('row', {'width': width, 'height': HUG}, {'crossAxisAlignment': 'center'}, children,
                decoration={'fills': [{'color': 'subtleFill'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1, 'radius': 12, 'clip': 'antiAlias'},
                bind={'decoration.radius': '${theme.radii.control}', **(bind or {})})


SEGMENT_SLOTS = 5


def segments():
    """Equal segments, each at most 200 wide, while they fit; a line that scrolls where they do not.

    A list's items cannot share its width (a row's children can: in a row that scrolls with fillViewport a child
    that fills shares the viewport while the content fits, and is as wide as its content where it scrolls), so up
    to five options are cells of the row itself, each at least as wide as the longest label so that equal shares
    never cut one. More than five (not what this block is for) come from a list, each as wide as its label."""
    n = SEGMENT_SLOTS
    count = 'length(props.options)'
    high = E('%s ? 44 : 40' % PHONE)
    at_ = 'indexOf(props.options, props.value)'
    # The least a segment is wide: the longest label, counted at 7.1 px a character (13 px Inter semibold runs
    # near 7), with 14 px each side of it and the 3 px between knobs. The knob's own padding is 10, so a label of
    # wide letters has 8 px to spare before it would touch. All the segments at this width are what the track
    # needs to stay whole; with less room it scrolls.
    widest = '(first(sortByDesc(map(props.options, o => length(o)), n => n)) * 7.1 + 31)'

    def go(node_, ms, **more):
        return {'type': 'scrollTo', 'node': node_, 'axis': 'horizontal', 'alignment': 0.5, 'curve': 'easeOutCubic', 'durationMs': ms, **more}

    def shown(ms):
        return [{**go('cell%d' % i, ms), 'when': {'left': E('%s <= %d && %s == %d' % (count, n, at_, i)), 'op': 'isTrue'}} for i in range(n)] + [
            {**go('moreCell', ms, item=E(at_)), 'when': {'left': E('%s > %d' % (count, n)), 'op': 'isTrue'}}]
    nodes = {
        'place': node('row', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'center'}, ['track']),
        'track': track(['scroll'], bind={'layout.constraints': E('{maxWidth: 200 * max(2, %s) + 3}' % count)}),
        'scroll': strip(['cell%d' % i for i in range(n)] + ['more'], pad=[1.5, 0, 1.5, 0], actions=[
            {'trigger': {'type': 'load', 'when': '%s > 0' % at_}, 'actions': shown(0)},
            {'trigger': {'type': 'valueChanged', 'variable': 'props.value', 'when': '%s >= 0' % at_}, 'actions': shown(240)}]),
        'more': line_of(['moreCell'], E('%s > %d ? props.options : []' % (count, n)), 40,
                        bind={'visible': E('%s > %d' % (count, n)), 'layout.height': high}),
        **knob_cell('moreCell', '${item}', "(props.value == item || (props.value == '' && index == 0))", [setv('props.value', 'item'), fire('onChanged', '${item}')]),
    }
    nodes['track']['layout']['constraints'] = {'maxWidth': 603}
    for i in range(n):
        opt = "(%s > %d ? at(props.options, %d) : '')" % (count, i, i)
        on = '(props.value == %s%s)' % (opt, " || props.value == ''" if i == 0 else '')
        nodes.update(knob_cell('cell%d' % i, E(opt), on, [setv('props.value', opt), fire('onChanged', E(opt))], width=FILL, height=40, pad_x=10,
                               bind={'visible': E('%s > %d && %s <= %d' % (count, i, count, n)), 'layout.height': high}, min_width=widest))
    props = [
        P('value', var(STRING), '', 'The name of your text variable: it holds the chosen option (declare it with the starting option).'),
        P('options', STRINGS, ['7 days', '30 days', '90 days'], 'Two to four short options (a word or two each).', True),
    ]
    return component('Segments', "A small switch between two to four short options in one track, as wide as its place (a period, a tone, a status filter; not a page's tabs: those are Tabs): write Segments bind=range options=[\"7 days\",\"30 days\"] and it keeps the chosen option's text in your variable; onChanged fires with it. The segments are equally wide while they fit; where they do not, the track scrolls sideways on one line.",
                     props, nodes, 'place', events=[('onChanged', 'An option was chosen; the value is its text.')],
                     previews=[{'name': 'Period', 'size': [340, 40], 'props': {'value': '30 days'}}])


def pill_track(type_, doc, options, sizes, size_default, size_doc, preview):
    """A track as wide as its options (TabToggle, SegmentedControl): sizes maps a size's name to (height, side padding, font)."""
    def by_size(i):
        names = list(sizes)
        out = repr(sizes[names[-1]][i])
        for name in reversed(names[:-1]):
            out = "props.size == '%s' ? %r : (%s)" % (name, sizes[name][i], out)
        return out
    nodes = {
        'track': track(['scroll'], width=HUG),
        'scroll': strip(['list'], width=HUG, pad=[1.5, 0, 1.5, 0], actions=reveal('option', 'props.options')),
        'list': line_of(['option'], '${props.options}', sizes[size_default][0],
                        bind={'layout.height': E('%s ? 44 : (%s)' % (PHONE, by_size(0)))}),
        **knob_cell('option', '${item}', 'item == props.value', [setv('props.value', 'item'), fire('onChanged', '${item}')],
                    text_bind={'props.style.fontSize': E(by_size(2))},
                    knob_bind={'layout.padding': E('[%s, 0, %s, 0]' % (by_size(1), by_size(1)))}),
    }
    props = [
        P('options', STRINGS, options, 'Two to four short options.', True),
        P('value', var(STRING), '', 'The name of your text variable holding the choice.'),
        P('size', enum(*sizes), size_default, size_doc),
    ]
    return component(type_, doc, props, nodes, 'track', events=[('onChanged', 'An option was chosen; the value is its text.')], previews=[preview])


def tab_toggle():
    return pill_track('TabToggle', "A small switch between two to four views as a track only as wide as its options, the chosen one raised (List or Grid in a toolbar, Monthly or Yearly over prices); Segments is the same switch as wide as its place, and a page's tabs are Tabs. The choice is kept in your variable. Fires onChanged. Where its options do not fit it scrolls sideways on one line.",
                      ['List', 'Grid'], {'sm': (32, 10, 12.5), 'md': (36, 14, 13), 'lg': (44, 18, 14)}, 'md', 'sm, md or lg.',
                      {'name': 'Two', 'size': [160, 36], 'props': {'options': ['List', 'Grid'], 'value': 'List'}})


def segmented_control():
    return pill_track('SegmentedControl', "The same small switch as TabToggle with finer sizes: two to four short options in a track only as wide as they are (a view switch, a period), the choice in your variable. Fires onChanged. Where its options do not fit it scrolls sideways on one line.",
                      ['Day', 'Week', 'Month'],
                      {'xs': (28, 8, 11.5), 'compact': (32, 10, 12), 'small': (34, 12, 12.5), 'medium': (36, 12, 13), 'large': (44, 14, 15)},
                      'compact', 'xs, compact, small, medium or large.',
                      {'name': 'Week', 'size': [240, 32], 'props': {'options': ['Day', 'Week', 'Month'], 'value': 'Week'}})


def tabs():
    on = "(props.value == item || (props.value == '' && index == 0))"
    nodes = {
        'bar': node('stack', {'width': FILL, 'height': HUG}, None, ['rule', 'scroll']),
        'rule': node('box', {'width': FILL, 'height': 1, 'x': {'start': 0}, 'y': {'end': 0}}, decoration=fills('line')),
        'scroll': strip(['list'], actions=reveal('tab', 'props.tabs')),
        'list': line_of(['tab'], '${props.tabs}', 44, gap=4),
        'tab': node('column', {'width': HUG, 'height': FILL}, {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'spaceBetween'}, ['tabTop', 'tabBody', 'tabLine'],
                    states={'hovered': {'tabBody': HOVER}, 'pressed': {'tabBody': DOWN}},
                    actions=click(setv('props.value', 'item'), fire('onChanged', '${item}'))),
        'tabTop': node('box', {'width': 1, 'height': 2}),
        'tabBody': node('row', {'width': HUG, 'height': 32, 'padding': [12, 0, 12, 0]}, {'crossAxisAlignment': 'center'}, ['tabText'],
                        decoration={'radius': 8}, bind={'decoration.radius': E('max(0, theme.radii.control - 4)')}, transitions=EASE),
        'tabText': text('${item}', 'controlMedium', maxLines=1, bind={
            'props.style.color': E('%s ? theme.colors.ink : theme.colors.inkFaint' % on)}),
        'tabLine': node('box', {'width': FILL, 'height': 2}, decoration={'fills': [{'color': '#00FFFFFF'}], 'radius': [2, 2, 0, 0]},
                        bind={'decoration.fills[0].color': E("%s ? theme.colors.accent : '#00FFFFFF'" % on)}, transitions=EASE),
    }
    props = [
        P('tabs', STRINGS, ['Overview', 'Activity', 'Settings'], "The tabs' labels, any number.", True),
        P('value', var(STRING), '', "The name of your text variable: it holds the open tab's label (declare it with the tab to start on: state tab=\"Overview\"; left empty, the first tab shows as open)."),
    ]
    return component('Tabs', "The tabs of a page or a card: labels on a hairline, the open one underlined in the accent, switching what is shown under them. Write Tabs bind=tab tabs=[\"Overview\",\"Activity\",\"Settings\"] with state tab=\"Overview\", then one if tab==\"Overview\" block per tab under it. Any number of tabs: where they do not fit, the row scrolls sideways on one line and brings the open tab into view. For a small switch of two to four options use Segments, for filter pills ChipTabs. Fires onChanged with the label.",
                     props, nodes, 'bar', events=[('onChanged', 'A tab was opened; the value is its label.')],
                     previews=[{'name': 'Three', 'size': [360, 44], 'props': {'value': 'Activity'}}])


def chip_tabs():
    on = 'item == props.value'
    nodes = {
        'row': node('row', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'center', 'spacing': 8}, ['scroll', 'add']),
        'scroll': strip(['list'], width=HUG, actions=reveal('chip', 'props.tabs')),
        'list': line_of(['chip'], '${props.tabs}', 36, gap=8, bind={'layout.height': E('%s ? 44 : 36' % PHONE)}),
        'chip': node('row', {'width': HUG, 'height': FILL}, {'crossAxisAlignment': 'center'}, ['pill'],
                     states={'hovered': {'pill': HOVER}, 'pressed': {'pill': DOWN}},
                     actions=click(setv('props.value', 'item'), fire('onSelected', '${item}'))),
        'pill': node('row', {'width': HUG, 'height': 32, 'padding': [14, 0, 14, 0]}, {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'}, ['label'],
                     decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1, 'radius': 999},
                     bind={'decoration.fills[0].color': E('%s ? theme.colors.accentTint : theme.colors.card' % on),
                           'decoration.strokes[0].color': E('%s ? theme.colors.accent : theme.colors.line' % on),
                           'decoration.strokeWidth': E('%s ? 1.5 : 1' % on),
                           'decoration.radius': '${theme.radii.chip}'}, transitions=EASE),
        'label': text('${item}', {'from': 'chip', 'fontSize': 13}, maxLines=1, bind={
            'props.style.color': E('%s ? theme.colors.ink : theme.colors.inkSoft' % on)}),
        **round_button('add', 'add_rounded', 32, actions=click(fire('onAdd')), bind={'visible': '${props.showAdd}'}),
    }
    nodes['add']['states']['hovered'] = {'add': HOVER}
    props = [
        P('tabs', STRINGS, ['Draft', 'Review', 'Final'], "The pills' labels, any number.", True),
        P('value', var(STRING), '', 'The name of your text variable holding the chosen label.'),
        P('showAdd', BOOL, False, 'A round + after the pills.'),
    ]
    return component('ChipTabs', "A row of pills to filter a list or switch between a few open items (All, Open, Closed; Draft, Review, Final), the chosen one outlined in the accent; an optional round + after them. Any number of pills: where they do not fit, the row scrolls sideways on one line. A page's views are Tabs; a choice of slots or sizes in a grid is ChoiceChips. The chosen label is kept in your variable. Fires onSelected with the label and onAdd.",
                     props, nodes, 'row', events=[('onSelected', 'A pill was chosen; the value is its label.'), ('onAdd', 'The + was tapped.')],
                     previews=[{'name': 'Three', 'size': [300, 36], 'props': {'value': 'Review', 'showAdd': True}}])


def browser_tabs():
    on = 'item == props.value'
    has_icon = "(length(props.icons) > index && props.icons[index] != '')"
    nodes = {
        'bar': node('row', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'end', 'spacing': 4}, ['scroll', 'add'],
                    decoration={'strokes': [{'color': 'line'}], 'strokeSides': 'bottom'}),
        'scroll': strip(['list'], width=HUG, actions=reveal('tab', 'props.tabs')),
        'list': line_of(['tab'], '${props.tabs}', 36, gap=2, bind={'layout.height': E('%s ? 44 : 36' % PHONE)}),
        'tab': node('row', {'width': HUG, 'height': FILL, 'padding': [12, 0, 8, 0]}, {'crossAxisAlignment': 'center', 'spacing': 6}, ['glyph', 'label', 'close'],
                    decoration={'fills': [{'color': 'hoverOverlay'}], 'strokes': [{'color': 'line'}], 'strokeSides': 'top', 'radius': [10, 10, 0, 0]},
                    bind={'decoration.fills[0].color': E('%s ? theme.colors.primaryBackground : theme.colors.hoverOverlay' % on)},
                    states={'hovered': {'tab': HOVER}, 'pressed': {'tab': DOWN}}, transitions=EASE,
                    actions=click(setv('props.value', 'item'), fire('onChanged', '${item}'))),
        'glyph': icon('description', 15, 'inkFaint', bind={'visible': E(has_icon), 'props.icon': E("%s ? props.icons[index] : 'description'" % has_icon),
                                                         'props.color': E('%s ? theme.colors.ink : theme.colors.inkFaint' % on)}),
        'label': text('${item}', {'from': 'chip', 'fontSize': 13, 'fontWeight': 500}, maxLines=1, overflow='ellipsis',
                      layout={'constraints': {'maxWidth': 200}},
                      bind={'props.style.color': E('%s ? theme.colors.ink : theme.colors.inkFaint' % on)}),
        'close': node('row', {'width': 20, 'height': 20}, {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'}, ['x'],
                      decoration={'radius': 999}, bind={'visible': '${props.closable}'},
                      states={'hovered': {'close': {'decoration': {'fills': [{'color': 'pressedOverlay'}]}}}},
                      actions=click(fire('onClose', '${item}'))),
        'x': icon('close_rounded', 13, 'inkFaint'),
        'add': node('row', {'width': 28, 'height': 28, 'margin': [0, 0, 0, 4]}, {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'}, ['plus'],
                    decoration={'radius': 999}, bind={'visible': '${props.showAdd}'}, tooltip='New tab',
                    states={'hovered': {'add': HOVER}, 'pressed': {'add': DOWN}}, actions=click(fire('onAdd'))),
        'plus': icon('add_rounded', 16, 'inkSoft'),
    }
    props = [
        P('tabs', STRINGS, ['Overview', 'Report.pdf', 'Notes'], "The tabs' labels, any number.", True),
        P('icons', STRINGS, [], 'One icon per tab (empty: none).'),
        P('value', var(STRING), '', 'The name of your text variable holding the chosen label.'),
        P('closable', BOOL, True, 'An x on each tab.'),
        P('showAdd', BOOL, False, 'A + after the tabs.'),
    ]
    return component('BrowserTabs', "Open documents as tabs in a browser's or an editor's manner: each with an x to close it, an optional + to open another (files, reports, chats open side by side; a page's own views are Tabs). Any number: where they do not fit, the row scrolls sideways on one line. The chosen one is kept in your variable. Fires onChanged, onClose with the label, and onAdd.",
                     props, nodes, 'bar', events=[('onChanged', 'A tab was chosen; the value is its label.'), ('onClose', "A tab's x was tapped; the value is its label."), ('onAdd', 'The + was tapped.')],
                     previews=[{'name': 'Default', 'size': [340, 36], 'props': {'value': 'Report.pdf', 'showAdd': True}}])


# --- InputField -------------------------------------------------------------------------------------------

def input_field():
    none = {'type': 'none'}
    deco = {'isDense': True, 'filled': False, 'contentPadding': [0, 13, 0, 13],
            'hintStyle': {'from': 'field', 'color': 'inkFaint', 'fontWeight': 400},
            'border': none, 'enabledBorder': none, 'focusedBorder': none, 'errorBorder': none,
            'focusedErrorBorder': none, 'disabledBorder': none, 'hoverColor': '#00000000'}
    changed = [{'trigger': {'type': 'changed'}, 'actions': [setv('props.value', '${result}'), fire('onChanged', '${result}')]}]
    nodes = {
        'wrap': col(['label', 'box', 'error', 'note'], 6),
        'label': text('${props.label}', {'from': 'meta', 'fontWeight': 600}, FILL, color='inkSoft', bind={'visible': "${= props.label != ''}"}),
        'box': row(['icon', 'field', 'area'], 8, cross='start', pad=[13, 0, 12, 0],
                   decoration={'fills': [{'color': 'tile'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1.2, 'radius': 12},
                   bind={'decoration.radius': '${theme.radii.control}',
                         'decoration.strokes[0].color': "${= props.error != '' ? theme.colors.bad : props.success != '' ? theme.colors.good : theme.colors.line}",
                         'decoration.strokeWidth': "${= props.error != '' ? 1.6 : 1.2}"}),
        'icon': icon('search_rounded', 18, 'inkFaint', bind={'props.icon': '${props.icon}', 'visible': "${= props.icon != ''}"}),
        'field': node('textField', {'width': FILL, 'height': 46},
                      {'style': 'field', 'cursorColor': 'accent', 'maxLines': 1, 'decoration': deco},
                      bind={'props.initialValue': '${props.value}', 'props.decoration.hintText': '${props.placeholder}',
                            'props.keyboardType': '${props.keyboard}', 'visible': '${= props.lines <= 1}'},
                      actions=changed),
        'area': node('textField', {'width': FILL, 'height': HUG},
                     {'style': {'from': 'field', 'fontWeight': 400, 'height': 1.5}, 'cursorColor': 'accent', 'maxLines': 0, 'minLines': 3,
                      'keyboardType': 'multiline', 'textAlignVertical': 'top', 'decoration': deco},
                     bind={'props.initialValue': '${props.value}', 'props.decoration.hintText': '${props.placeholder}',
                           'props.minLines': '${= max(2, props.lines)}', 'visible': '${= props.lines > 1}'},
                     actions=changed),
        'error': row(['errorIcon', 'errorText'], 5, bind={'visible': "${= props.error != ''}"}),
        'errorIcon': icon('error_rounded', 14, 'bad'),
        'errorText': text('${props.error}', 'meta', FILL, color='bad'),
        'note': row(['noteIcon', 'noteText'], 5, bind={'visible': "${= props.success != '' && props.error == ''}"}),
        'noteIcon': icon('check_circle_rounded', 14, 'good'),
        'noteText': text('${props.success}', 'meta', FILL, color='goodDeep'),
    }
    nodes['icon']['layout']['margin'] = [0, 14, 0, 0]
    props = [
        P('value', var(STRING), '', 'The name of your text variable: the field shows it and writes it as the user types.'),
        P('label', STRING, '', 'The label over the field (empty: none).'),
        P('placeholder', STRING, '', 'Shown while the field is empty.'),
        P('lines', INT, 1, 'More than 1 makes it a multi-line box about that many lines tall (a message body).'),
        P('icon', STRING, '', 'A Material icon inside the field, e.g. search_rounded (empty: none).'),
        P('error', STRING, '', 'A message under the field, in red with a red border (empty: no error).'),
        P('success', STRING, '', 'A green confirmation under the field, e.g. "SAVE10 applied" (empty: none).'),
        P('keyboard', enum('text', 'emailAddress', 'number', 'phone', 'url'), 'text', 'The keyboard a phone shows.'),
    ]
    return component('InputField', "A labeled text field that keeps what is typed in your variable: InputField \"Email\" \"you@example.com\" bind=email; lines=6 makes a multi-line box, icon=\"search_rounded\" a search field, error={cond?\"message\":\"\"} shows a red message under it, success a green one.",
                     props, nodes, 'wrap', events=[('onChanged', 'The text changed; the value is the new text.')],
                     previews=[{'name': 'Field', 'size': [340, 72], 'props': {'label': 'Email', 'placeholder': 'you@example.com'}}])


# --- OptionList -------------------------------------------------------------------------------------------

def option_list():
    on = 'props.value == item'
    nodes = {
        'wrap': col(['title', 'list'], 12),
        'title': text('${props.title}', {'from': 'cardTitle', 'fontSize': 17}, FILL, layout={'padding': [0, 6, 0, 0]}, bind={'visible': "${= props.title != ''}"}),
        'list': vlist(['opt'], 8, '${props.options}'),
        'opt': row(['optIcon', 'texts', 'trail', 'radio'], 12, pad=[14, 12, 14, 12],
                   decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1.5, 'radius': 14},
                   bind={'decoration.radius': '${theme.radii.tile}',
                         'decoration.strokes[0].color': E('%s ? theme.colors.accent : theme.colors.line' % on),
                         'decoration.fills[0].color': E('%s ? theme.colors.accentTint : theme.colors.card' % on)},
                   states={'pressed': {'opt': PRESS}},
                   actions=click(setv('props.value', 'item'), fire('onChanged', '${item}'))),
        'optIcon': node('row', {'width': 36, 'height': 36}, {'mainAxisAlignment': 'center'}, ['optIconI'],
                        decoration={'fills': [{'color': 'tile'}], 'radius': 11},
                        bind={'visible': E('length(props.icons) > index'),
                              'decoration.fills[0].color': E('%s ? theme.colors.accent : theme.colors.tile' % on)}),
        'optIconI': icon('circle', 19, 'inkSoft', bind={'props.icon': E("length(props.icons) > index ? at(props.icons, index) : 'circle'"),
                                                      'props.color': E('%s ? theme.colors.onAccent : theme.colors.inkSoft' % on)}),
        'texts': col(['optTitle', 'optDetail'], 1, cross='start'),
        'optTitle': text('${item}', 'rowTitle', FILL),
        'optDetail': text("${= length(props.details) > index ? at(props.details, index) : ''}", 'meta', FILL,
                          bind={'visible': E('length(props.details) > index')}),
        'trail': text("${= length(props.prices) > index ? at(props.prices, index) : ''}", 'numberSmall',
                      bind={'visible': E('length(props.prices) > index')}),
        'radio': node('row', {'width': 22, 'height': 22}, {'mainAxisAlignment': 'center'}, ['radioIcon'],
                      decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1.5, 'radius': 11},
                      bind={'decoration.fills[0].color': E('%s ? theme.colors.accent : theme.colors.card' % on),
                            'decoration.strokes[0].color': E('%s ? theme.colors.accent : theme.colors.lineStrong' % on)}),
        'radioIcon': icon('check_rounded', 15, 'onAccent', bind={'visible': E(on)}),
    }
    props = [
        P('value', var(STRING), '', 'The name of your text variable: it holds the chosen option.'),
        P('title', STRING, '', 'The question, over the options (empty: none).'),
        P('options', STRINGS, ['Standard', 'Express'], 'The options, one row each.', True),
        P('details', STRINGS, [], 'A quiet second line per option (optional).'),
        P('icons', STRINGS, [], 'A Material icon per option (optional).'),
        P('prices', STRINGS, [], 'A figure at the right of each option, e.g. a price (optional).'),
    ]
    return component('OptionList', "A question and its answers as a list of rows with a radio (also a delivery method, a plan): OptionList \"What will you use it for?\" bind=answer options=[\"A\",\"B\"] keeps the chosen option's text in your variable; details, icons and prices are optional lists alongside; onChanged fires with the choice (-> step=2).",
                     props, nodes, 'wrap', events=[('onChanged', 'An option was chosen; the value is its text.')],
                     previews=[{'name': 'Delivery', 'size': [340, 130], 'props': {'value': 'Standard', 'details': ['3 to 5 days', 'Next day'],
                                                                                'prices': ['$4.00', '$12.00']}}])


# --- ChoiceChips ------------------------------------------------------------------------------------------

def choice_chips():
    on, off = 'props.value == item', 'contains(props.disabled, item)'
    # Equal chips, `columns` to a row, while the longest label fits a chip at a card's width (13.5 px Inter runs
    # near 7.5 px a character; a card's content is 364 wide, and so is a phone's); else chips as wide as their
    # labels that wrap, as chips do. Never fewer columns than asked for with the labels squeezed into them.
    longest = 'first(sortByDesc(map(props.options, o => length(o)), n => n))'
    fits = '(max(1, props.columns) * (%s * 7.5 + 24 + 8) - 8 <= min(screen.width, 420) - 56)' % longest

    def chip(p, width, pad=None):
        return {
            p: row([p + 'Text'], width=width, height=40, main='center', pad=pad,
                   decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1.2, 'radius': 12},
                   bind={'decoration.radius': '${theme.radii.control}',
                         'decoration.fills[0].color': E('%s ? theme.colors.tile : %s ? theme.colors.accent : theme.colors.card' % (off, on)),
                         'decoration.strokes[0].color': E('%s ? theme.colors.tile : %s ? theme.colors.accent : theme.colors.lineStrong' % (off, on)),
                         'decoration.effects': E('%s && !(%s) ? theme.shadows.pick : []' % (on, off))},
                   states={'pressed': {p: PRESS}},
                   actions=click({'type': 'if', 'condition': {'left': E(off), 'op': 'isFalse'},
                                  'then': [setv('props.value', 'item'), fire('onChanged', '${item}')]})),
            p + 'Text': text('${item}', {'from': 'figure', 'fontWeight': 600}, maxLines=1, bind={
                'props.style.color': E('%s ? theme.colors.inkGhost : %s ? theme.colors.onAccent : theme.colors.ink' % (off, on)),
                'props.style.decoration': E("%s ? 'lineThrough' : 'none'" % off)}),
        }
    nodes = {
        'chips': col(['grid', 'flow']),
        'grid': grid(['chip'], '${props.columns}', 8, E('%s ? props.options : []' % fits), bind={'visible': E(fits)}),
        **chip('chip', FILL),
        'flow': node('listView', {'width': FILL, 'height': HUG},
                     {'scrollDirection': 'horizontal', 'scrollable': False, 'wrap': True, 'wrapSpacing': 8, 'runSpacing': 8},
                     ['pill'], bind={'data': E('%s ? [] : props.options' % fits), 'visible': E('!%s' % fits)}),
        **chip('pill', HUG, pad=[16, 0, 16, 0]),
    }
    props = [
        P('value', var(STRING), '', 'The name of your text variable: it holds the chosen option.'),
        P('options', STRINGS, ['18:00', '18:30', '19:00', '19:30'], 'The options, one chip each: short (a time, a size, a word).', True),
        P('disabled', STRINGS, [], 'The options that cannot be chosen (full time slots, sizes out of stock): greyed and struck through.'),
        P('columns', INT, 4, 'Chips per row.'),
    ]
    return component('ChoiceChips', "A single choice as a grid of equal chips (time slots, sizes, a finish; not tabs or a filter: those are Tabs, Segments and ChipTabs): ChoiceChips bind=time options=[\"18:00\",\"18:30\"] disabled=[\"18:30\"] keeps the chosen chip's text in your variable; disabled lists the ones that are unavailable (full, sold out); columns sets chips per row. Labels too long for that many columns are not squeezed: the chips are then as wide as their labels and wrap.",
                     props, nodes, 'chips', events=[('onChanged', 'A chip was chosen; the value is its text.')],
                     previews=[{'name': 'Slots', 'size': [340, 40], 'props': {'value': '19:00', 'disabled': ['18:30']}}])


# --- DayPicker --------------------------------------------------------------------------------------------

def day_picker():
    on = "(props.value == item || (props.value == '' && index == 0))"
    nodes = {
        'days': grid(['day'], E('max(1, length(props.days))'), 6, '${props.days}'),
        'day': col(['dow', 'num'], 3, cross='center', pad=[0, 9, 0, 9],
                   decoration={'fills': [{'color': 'tile'}], 'radius': 13},
                   bind={'decoration.fills[0].color': E('%s ? theme.colors.accent : theme.colors.tile' % on),
                         'decoration.effects': E('%s ? theme.shadows.pick : []' % on),
                         'decoration.radius': '${theme.radii.tile}'},
                   states={'pressed': {'day': PRESS}},
                   actions=click(setv('props.value', 'item'), fire('onChanged', '${item}'))),
        'dow': text("${= upper(at(split(item, ' '), 0))}", {'from': 'eyebrow', 'fontSize': 9.5, 'letterSpacing': 0.6}, maxLines=1, bind={
            'props.style.color': E('%s ? theme.colors.onAccent : theme.colors.inkFaint' % on)}),
        'num': text("${= length(split(item, ' ')) > 1 ? at(split(item, ' '), 1) : ''}", 'number', maxLines=1, bind={
            'props.style.color': E('%s ? theme.colors.onAccent : theme.colors.ink' % on)}),
    }
    nodes['num']['props']['style'] = {'from': 'number', 'fontSize': 18}
    props = [
        P('value', var(STRING), '', 'The name of your text variable: it holds the chosen day as written in days.'),
        P('days', STRINGS, ['Sat 14', 'Sun 15', 'Mon 16', 'Tue 17', 'Wed 18', 'Thu 19', 'Fri 20'], 'The days as "Sat 14": a short weekday, a space, the day of the month.', True),
    ]
    return component('DayPicker', "A strip of days to pick one from: DayPicker bind=day days=[\"Sat 14\",\"Sun 15\",\"Mon 16\"] (each a short weekday, a space, the date) keeps the chosen day's text in your variable; onChanged fires with it.",
                     props, nodes, 'days', events=[('onChanged', 'A day was chosen; the value is its text.')],
                     previews=[{'name': 'Week', 'size': [340, 62], 'props': {'value': 'Sun 15'}}])


# --- Counter and CartLine ---------------------------------------------------------------------------------

def stepper_nodes(prefix, value_expr, minus_actions, plus_actions, minus_icon="'remove_rounded'", size=30, can_minus='true', can_plus='true'):
    out = {}
    out.update(round_button(prefix + 'Minus', 'remove_rounded', size, actions=click(*minus_actions),
                            bind={'opacity': E('%s ? 1 : 0.35' % can_minus)}, icon_bind={'props.icon': E(minus_icon)}))
    out.update(round_button(prefix + 'Plus', 'add_rounded', size, actions=click(*plus_actions), bind={'opacity': E('%s ? 1 : 0.35' % can_plus)}))
    out[prefix + 'Value'] = text(E(value_expr), 'numberSmall', textAlign='center', layout={'width': 26})
    out[prefix] = row([prefix + 'Minus', prefix + 'Value', prefix + 'Plus'], 4, width=HUG)
    return out


def counter():
    nodes = {
        'row': row(['icon', 'texts', 'step'], 12, pad=[14, 10, 10, 10],
                   decoration={'fills': [{'color': 'tile'}], 'radius': 14}, bind={'decoration.radius': '${theme.radii.tile}'}),
        'icon': icon('group_rounded', 20, 'inkSoft', bind={'props.icon': '${props.icon}', 'visible': "${= props.icon != ''}"}),
        'texts': col(['label', 'detail'], 1, cross='start'),
        'label': text('${props.label}', 'rowTitle', FILL),
        'detail': text('${props.detail}', 'meta', FILL, bind={'visible': "${= props.detail != ''}"}),
        **stepper_nodes('step', 'props.value',
                        [setv('props.value', 'max(props.min, props.value - props.step)'), fire('onChanged', '${props.value}')],
                        [setv('props.value', 'min(props.max, props.value + props.step)'), fire('onChanged', '${props.value}')],
                        size=34, can_minus='props.value > props.min', can_plus='props.value < props.max'),
    }
    for k in ('stepMinus', 'stepPlus'):
        nodes[k]['decoration']['fills'] = [{'color': 'card'}]
        nodes[k]['bind']['decoration.effects'] = '${theme.shadows.knob}'
    props = [
        P('value', var(NUM), '', 'The name of your number variable (declare it with its start: state party=2).'),
        P('label', STRING, 'Guests', 'What is counted.', True),
        P('detail', STRING, '', 'A quiet line under the label (empty: none).'),
        P('min', NUM, 1, 'The least.'), P('max', NUM, 8, 'The most.'), P('step', NUM, 1, 'How much one tap changes it.'),
        P('icon', STRING, 'group_rounded', 'A Material icon before the label (empty: none).'),
    ]
    return component('Counter', "A number raised and lowered with minus and plus (a party size, a count): Counter \"Guests\" bind=party min=1 max=8 keeps it in your number variable; onChanged fires with the new number.",
                     props, nodes, 'row', events=[('onChanged', 'The number changed; the value is the new number.')],
                     previews=[{'name': 'Guests', 'size': [340, 56], 'props': {'value': 2, 'detail': '1 to 8'}}])


def rating():
    nodes = {
        'stars': node('slider', {'width': 200, 'height': 44},
                      {'min': 0, 'max': 5, 'trackShape': 'stars', 'showThumb': False,
                       'activeTrackColor': 'accent', 'inactiveTrackColor': 'lineStrong',
                       'showValueIndicator': 'never'},
                      bind={'props.value': '${= props.value == null ? props.score : props.value}',
                            'props.divisions': '${= props.half ? 10 : 5}',
                            'props.label': '${props.label}',
                            'props.readOnly': '${props.readOnly}'},
                      actions=[{'trigger': {'type': 'changed'}, 'actions': [setv('props.value', '${result}'), fire('onChanged', '${result}')]}]),
    }
    props = [
        P('label', STRING, 'Rating', 'The name announced with the score.', True),
        P('value', var(NUM), '', 'A bound score variable, from 0 to 5.'),
        P('score', NUM, 0, 'A fixed score when readOnly is true.'),
        P('half', BOOL, False, 'True: half-star steps.'),
        P('readOnly', BOOL, False, 'True: display the score without allowing changes.'),
    ]
    return component('Rating', 'Five stars as one rating control. Rating "Your rating" =score half:true; Rating "Course score" score:4.7 readOnly:true displays one.',
                     props, nodes, 'stars', events=[('onChanged', 'The new score.')],
                     previews=[{'name': 'Choose a score', 'size': [200, 44], 'props': {'value': 3.5, 'half': True}},
                               {'name': 'Course score', 'size': [200, 44], 'props': {'score': 4.7, 'readOnly': True}}])


def cart_line():
    nodes = {
        'line': row(['thumb', 'texts', 'right'], 12, pad=[0, 9, 0, 9],
                    decoration={'strokes': [{'color': 'line'}], 'strokeWidth': 1, 'strokeSides': 'bottom'}),
        'thumb': node('Media', {'width': 58, 'height': 58}, {'kind': 'box'}, bind={'props.kind': '${props.kind}', 'props.tone': '${props.tone}'}),
        'texts': col(['title', 'detail', 'price'], 2, cross='start'),
        'title': text('${props.title}', 'rowTitle', FILL, maxLines=1, overflow='ellipsis'),
        'detail': text('${props.detail}', 'meta', FILL, maxLines=1, overflow='ellipsis', bind={'visible': "${= props.detail != ''}"}),
        'price': text('${props.price}', 'numberSmall', layout={'padding': [0, 2, 0, 0]}),
        'right': col(['step'], 0, cross='end', width=HUG),
        **stepper_nodes('step', 'props.qty', [fire('onChanged', '${= max(0, props.qty - 1)}')], [fire('onChanged', '${= props.qty + 1}')],
                        minus_icon="props.qty <= 1 ? 'delete_outline_rounded' : 'remove_rounded'"),
    }
    nodes['step']['decoration'] = {'fills': [{'color': 'tile'}], 'radius': 999}
    nodes['step']['layout']['padding'] = [3, 3, 3, 3]
    for k in ('stepMinus', 'stepPlus'):
        nodes[k]['decoration']['fills'] = [{'color': 'card'}]
        nodes[k]['bind']['decoration.effects'] = '${theme.shadows.knob}'
    props = [
        P('title', STRING, 'Item', "The item's name.", True),
        P('detail', STRING, '', 'A quiet second line: a size, a unit price.'),
        P('price', STRING, '', 'The price, as text ($4.75).'),
        P('qty', NUM, 1, 'The quantity shown between minus and plus.', True),
        P('kind', STRING, 'box', 'The drawn thumbnail, a Media kind: shoe, mug, tote, box, beans, laptop, banana, milk, bread, eggs, cheese, apple.'),
        P('tone', STRING, 'auto', "The thumbnail's tone (sand, rose, mint, sky, lilac, slate; auto picks one)."),
    ]
    return component('CartLine', "One line of a cart or order with a drawn thumbnail and a quantity stepper: the title, a detail, the price, kind (the picture, as Media) and qty; minus and plus fire onChanged with the new quantity as result (0 when the last one is removed), so write onChanged={items=updateWhere(items,x=>x.id==i.id,x=>with(x,\"qty\",result))}.",
                     props, nodes, 'line', events=[('onChanged', 'Minus or plus was tapped; the value is the new quantity.')],
                     previews=[{'name': 'Line', 'size': [340, 78], 'props': {'title': 'Ceramic mug', 'detail': 'Sand glaze, 350 ml', 'price': '$12.00',
                                                                           'qty': 2, 'kind': 'mug'}}])


def dots_nodes(prefix, count, current, on_tap):
    """Pagination dots: the current one long and in the accent; a tap runs on_tap(index expression)."""
    return {
        prefix: node('row', {'width': FILL, 'height': 22}, {'mainAxisAlignment': 'center'}, [prefix + 'List']),
        prefix + 'List': node('listView', {'width': HUG, 'height': 22}, {'scrollable': False, 'spacing': 0, 'scrollDirection': 'horizontal'},
                              [prefix + 'Hit'], bind={'data': '${= range(max(1, %s))}' % count}),
        prefix + 'Hit': node('row', {'width': HUG, 'height': FILL, 'padding': [3, 0, 3, 0]}, {'mainAxisAlignment': 'center'}, [prefix + 'Dot'],
                             actions=click(*on_tap('index'))),
        prefix + 'Dot': box(6, 6, {'fills': [{'color': 'lineStrong'}], 'radius': 3},
                            bind={'layout.width': '${= index == %s ? 20 : 6}' % current,
                                  'decoration.fills[0].color': '${= index == %s ? theme.colors.accent : theme.colors.lineStrong}' % current}),
    }


def page_dots():
    nodes = dots_nodes('dots', 'props.count', 'props.value', lambda i: [setv('props.value', i), fire('onChanged', '${index}')])
    props = [P('value', var(NUM), '', 'The name of your number variable: the page shown, from 0 (the same one Pages or Carousel keeps).'),
             P('count', INT, 3, 'How many pages there are.', True)]
    return component('PageDots', "Pagination dots for Pages, a Carousel or any paged content: PageDots bind=page count={length(items)} draws one dot per page, the current one long and in the accent, and a tap on a dot sets your variable to that page (from 0).",
                     props, nodes, 'dots', events=[('onChanged', 'A dot was tapped; the value is its page.')],
                     previews=[{'name': 'Dots', 'size': [200, 22], 'props': {'value': 1, 'count': 5}}])


def wide_scroll():
    nodes = {
        'frame': col(['scroller']),
        'scroller': node('row', {'width': FILL, 'height': HUG}, {'scrollable': True, 'scrollDirection': 'horizontal', 'crossAxisAlignment': 'start', 'edgeFade': 12}, ['inner'],
                         bind={'props.edgeFade': '${= props.fade ? 12 : 0}'}),
        'inner': node('column', {'width': 640, 'height': HUG}, {'crossAxisAlignment': 'stretch', 'spacing': 0}, ['slot'],
                      bind={'layout.width': '${props.width}'}),
        'slot': {'type': 'slot'},
    }
    props = [P('width', NUM, 640, 'How wide the content inside is laid out, in pixels (wider than the card).', True),
             P('fade', BOOL, True, 'The edges fade where there is more to scroll to (false: a hard edge).')]
    return component('WideScroll', "A frame that scrolls sideways for content wider than the card (a table with many columns): write WideScroll width=640 and the wide blocks indented under it (TableHeader, each row, TableRow) are laid out that wide and scroll together; its edges fade where there is more to scroll to (fade=false turns that off).",
                     props, nodes, 'frame', children=True, previews=[{'name': 'Frame', 'size': [340, 40], 'props': {}}])



# --- ProductTile, Carousel, Pager -------------------------------------------------------------------------

def product_tile():
    stars = {'painter': [{'op': 'repeat', 'count': 5, 'ops': [
        {'op': 'path', 'd': 'M7 0.8 L8.9 4.9 L13.3 5.4 L10 8.4 L10.9 12.8 L7 10.6 L3.1 12.8 L4 8.4 L0.7 5.4 L5.1 4.9 Z',
         'paint': '${= index < round(number(props.rating)) ? theme.colors.gold : theme.colors.lineStrong}'}], 'translate': ['${= index * 15}', 0]}]}
    stars = {'painter': [{'op': 'group', 'translate': [i * 15, 0], 'ops': [
        {'op': 'path', 'd': 'M7 0.8 L8.9 4.9 L13.3 5.4 L10 8.4 L10.9 12.8 L7 10.6 L3.1 12.8 L4 8.4 L0.7 5.4 L5.1 4.9 Z',
         'paint': '${= %d < round(number(props.rating)) ? theme.colors.gold : theme.colors.lineStrong}' % i}]} for i in range(5)]}
    nodes = {
        'tile': col(['frame', 'info'], 12, states={'pressed': {'tile': PRESS}}, actions=tap()),
        'frame': node('stack', {'width': FILL, 'height': 196}, children=['art', 'badge', 'open'],
                      bind={'layout.height': '${props.height}'}),
        'art': node('Media', {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}, {'kind': 'shoe'},
                    bind={'props.kind': '${props.kind}', 'props.tone': '${props.tone}'}),
        'badge': row(['badgeText'], width=HUG, pad=[9, 5, 9, 5], decoration={'fills': [{'color': 'card'}], 'radius': 999},
                     bind={'visible': "${= props.badge != ''}", 'decoration.effects': '${theme.shadows.knob}'}),
        'badgeText': text('${props.badge}', 'chip'),
        'open': row(['openText', 'openIcon'], 3, width=HUG, pad=[11, 6, 7, 6], decoration={'fills': [{'color': 'card'}], 'radius': 999},
                    bind={'visible': "${= props.cta != ''}", 'decoration.effects': '${theme.shadows.knob}'}),
        'openText': text('${props.cta}', 'chip'),
        'openIcon': icon('chevron_right_rounded', 16, 'ink'),
        'info': row(['texts', 'price'], 12, cross='start'),
        'texts': col(['name', 'detail', 'rating'], 3, cross='start'),
        'name': text('${props.name}', {'from': 'cardTitle', 'fontSize': 17}, FILL, maxLines=1, overflow='ellipsis'),
        'detail': text('${props.detail}', 'meta', FILL, maxLines=1, overflow='ellipsis', bind={'visible': "${= props.detail != ''}"}),
        'rating': row(['stars', 'ratingText'], 6, bind={'visible': "${= props.rating != ''}"}, pad=[0, 3, 0, 0]),
        'stars': node('box', {'width': 74, 'height': 14}, customPaint=stars),
        'ratingText': text('${props.rating}', {'from': 'figure', 'fontWeight': 600, 'fontSize': 12.5}, color='inkSoft'),
        'price': text('${props.price}', 'number'),
    }
    nodes['badge']['layout'].update({'x': {'start': 12}, 'y': {'start': 12}})
    nodes['open']['layout'].update({'x': {'end': 12}, 'y': {'end': 12}})
    props = [
        P('name', STRING, 'Aero Runner', "The product's name.", True),
        P('detail', STRING, '', 'A quiet line under the name (a category, a color).'),
        P('price', STRING, '', 'The price, as text ($120).'),
        P('rating', STRING, '', 'The rating out of 5, as text (4.8): drawn as stars with the number (empty: none).'),
        P('kind', STRING, 'shoe', 'The drawn picture, a Media kind: shoe, mug, tote, box, beans, laptop, banana, milk, bread, eggs, cheese, apple.'),
        P('tone', STRING, 'auto', "The picture's tone: sand, rose, mint, sky, lilac or slate (give each product its own)."),
        P('badge', STRING, '', 'A small label over the picture, e.g. New (empty: none).'),
        P('cta', STRING, '', 'A small pill at the bottom right of the picture that invites a tap, e.g. Details (empty: none).'),
        P('height', NUM, 196, "The picture's height."),
    ]
    return component('ProductTile', "A product with a large drawn picture: the name, a detail, the price, the rating as stars, kind (the picture, as Media: shoe, mug, tote...) and tone (its color: sand, rose, mint, sky, lilac, slate); a tap fires onPressed (open its details).",
                     props, nodes, 'tile', events=[('onPressed', 'The product was tapped.')],
                     previews=[{'name': 'Shoe', 'size': [340, 280], 'props': {'price': '$120', 'rating': '4.8', 'detail': 'Road running'}}])


def carousel():
    n = 'length(props.items)'
    go = lambda expr: [setv('props.value', expr), fire('onChanged', '${props.value}')]
    f = lambda key, fallback="''": "${= coalesce(item.%s, %s)}" % (key, fallback)
    nodes = {
        'wrap': col(['pages', 'thumbs', 'bar'], 10),
        'pages': node('pageView', {'width': FILL, 'height': 290}, {'viewportFraction': 0.86, 'scrollDirection': 'horizontal', 'padEnds': False, 'edgeFade': 12},
                      ['page'], bind={'props.initialPage': '${props.value}', 'data': '${props.items}', 'props.viewportFraction': '${props.peek}',
                                      'props.edgeFade': '${= props.fade && props.peek < 1 ? 12 : 0}',
                                      'layout.height': '${= props.height + 94}'},
                      actions=[{'trigger': {'type': 'changed'}, 'actions': [setv('props.value', '${result.index}'), fire('onChanged', '${result.index}')]}]),
        'page': node('column', {'width': FILL, 'height': FILL, 'padding': [0, 0, 10, 0]}, {'crossAxisAlignment': 'stretch'}, ['tile'],
                     bind={'layout.padding': '${= props.peek < 1 ? [0, 0, 10, 0] : [0, 0, 0, 0]}'}),
        'tile': node('ProductTile', {'width': FILL, 'height': HUG}, {'name': ''},
                     bind={'props.name': f('name'), 'props.detail': f('detail'), 'props.price': f('price'), 'props.rating': f('rating'),
                           'props.kind': "${= coalesce(item.kind, props.kind)}", 'props.tone': f('tone', "'auto'"), 'props.badge': f('badge'),
                           'props.cta': '${props.cta}', 'props.height': '${props.height}'},
                     actions=[{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [fire('onPressed', '${index}')]}]),
        'thumbs': grid(['thumb'], E('max(1, %s)' % n), 8, '${props.items}', bind={'visible': '${props.thumbs}'}),
        'thumb': node('stack', {'width': FILL, 'height': 48}, children=['thumbArt'],
                      decoration={'radius': 13, 'strokes': [{'color': 'accent'}], 'strokeWidth': 0, 'strokeAlign': 'outside'},
                      bind={'decoration.strokeWidth': '${= index == props.value ? 2.5 : 0}', 'opacity': '${= index == props.value ? 1 : 0.72}'},
                      actions=click(*go('index'))),
        'thumbArt': node('Media', {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}, {'kind': 'shoe'},
                         bind={'props.kind': "${= coalesce(item.kind, props.kind)}", 'props.tone': f('tone', "'auto'")}),
        'bar': row(['prev', 'mid', 'next'], 10, bind={'visible': '${= props.arrows || props.dots || props.counter}'}),
        **round_button('prev', 'arrow_back_rounded', 36, actions=click(*go('max(0, props.value - 1)')),
                       bind={'visible': '${props.arrows}', 'opacity': '${= props.value > 0 ? 1 : 0.35}'}),
        **round_button('next', 'arrow_forward_rounded', 36, actions=click(*go('min(%s - 1, props.value + 1)' % n)),
                       bind={'visible': '${props.arrows}', 'opacity': '${= props.value < %s - 1 ? 1 : 0.35}' % n}),
        'mid': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'center', 'spacing': 2}, ['dots', 'count']),
        **dots_nodes('dots', n, 'props.value', lambda i: go(i)),
        'count': text('${= props.value + 1} of ${= %s}' % n, {'from': 'meta', 'fontWeight': 600}, bind={'visible': '${props.counter}'}),
    }
    nodes['dots']['bind'] = {'visible': '${props.dots}'}
    props = [
        P('value', var(NUM), '', 'The name of your number variable: the item in view, from 0.'),
        P('items', ROWS, [{'name': 'Aero Runner', 'detail': 'Road', 'price': '$120', 'rating': '4.8', 'tone': 'lilac'},
                          {'name': 'Trail Scout', 'detail': 'Trail', 'price': '$135', 'rating': '4.6', 'tone': 'mint'}],
          'The items: records with name, detail, price, rating (texts) and optionally kind, tone and badge (as ProductTile).', True),
        P('kind', STRING, 'shoe', 'The Media kind drawn for an item that names none.'),
        P('peek', NUM, 0.86, 'The share of the width one item takes: under 1 shows the edge of the next (1: one full item).'),
        P('dots', BOOL, True, 'Pagination dots under the strip.'),
        P('arrows', BOOL, True, 'Previous and next buttons.'),
        P('counter', BOOL, False, 'A "2 of 6" count under the strip.'),
        P('thumbs', BOOL, False, 'A strip of small drawn thumbnails to tap.'),
        P('cta', STRING, '', 'A small pill on each picture that invites a tap, such as Details (empty: none).'),
        P('height', NUM, 196, "The pictures' height."),
        P('fade', BOOL, True, 'The peeking next item fades at the edge (false: a hard edge).'),
    ]
    return component('Carousel', "A real carousel of products: Carousel bind=i items={shoes} slides one ProductTile per record (name, detail, price, rating, kind, tone) sideways by swipe, showing the edge of the next (peek), and keeps the position (from 0) in your number variable; dots, arrows, counter (\"2 of 6\") and thumbs are switches; a tap on an item fires onPressed with its position (-> open=true), and Pager or PageDots on the same variable drive it too.",
                     props, nodes, 'wrap', events=[('onPressed', 'An item was tapped; the value is its position.'),
                                                   ('onChanged', 'The position changed; the value is the new position.')],
                     previews=[{'name': 'Strip', 'size': [360, 340], 'props': {'value': 0}}])


def pager():
    nodes = {
        'bar': row(['label', 'prev', 'next'], 8),
        'label': text("${= trim(props.label + ' ' + text(props.value + 1) + ' of ' + text(max(1, props.count)))}", 'meta', FILL),
        **round_button('prev', 'chevron_left_rounded', 34, actions=click(setv('props.value', 'max(0, props.value - 1)'), fire('onChanged', '${props.value}')),
                       bind={'opacity': '${= props.value > 0 ? 1 : 0.35}'}),
        **round_button('next', 'chevron_right_rounded', 34,
                       actions=click(setv('props.value', 'min(max(1, props.count) - 1, props.value + 1)'), fire('onChanged', '${props.value}')),
                       bind={'opacity': '${= props.value < props.count - 1 ? 1 : 0.35}'}),
    }
    props = [
        P('value', var(NUM), '', 'The name of your number variable: the page, from 0.'),
        P('count', INT, 1, 'How many pages there are (ceil(length(rows)/5)).', True),
        P('label', STRING, 'Page', 'The word before "1 of 3" (empty: the count alone, as under a carousel).'),
    ]
    return component('Pager', "Paging for a list or for pages of content: \"Page 1 of 3\" with previous and next buttons; Pager bind=page count={ceil(length(rows)/5)} keeps the page (from 0) in your number variable, so show slice(rows,page*5,page*5+5), or give it the variable of Pages or a Carousel to turn their pages.",
                     props, nodes, 'bar', events=[('onChanged', 'The page changed; the value is the new page.')],
                     previews=[{'name': 'Pages', 'size': [340, 36], 'props': {'count': 3}}])


# --- DiffHunk ---------------------------------------------------------------------------------------------

def diff_hunk():
    add, rem = "startsWith(item, '+')", "startsWith(item, '-')"
    old_no = "props.start + count(take(props.lines, index), x => !startsWith(x, '+'))"
    new_no = "props.start + count(take(props.lines, index), x => !startsWith(x, '-'))"
    kept, dropped = "props.value == 'keep'", "props.value == 'discard'"

    def choice(nid, label, icon_name, value, on, on_fill, on_ink):
        return {
            nid: row([nid + 'I', nid + 'T'], 5, width=HUG, height=32, pad=[10, 0, 12, 0],
                     decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1.2, 'radius': 10},
                     bind={'decoration.fills[0].color': E('%s ? theme.colors.%s : theme.colors.card' % (on, on_fill)),
                           'decoration.strokes[0].color': E('%s ? theme.colors.%s : theme.colors.lineStrong' % (on, on_fill))},
                     states={'pressed': {nid: PRESS}},
                     actions=click(setv('props.value', "'%s'" % value), fire('onChanged', value))),
            nid + 'I': icon(icon_name, 15, 'inkSoft', bind={'props.color': E('%s ? theme.colors.%s : theme.colors.inkSoft' % (on, on_ink))}),
            nid + 'T': text(label, 'chip', bind={'props.style.color': E('%s ? theme.colors.%s : theme.colors.ink' % (on, on_ink))}),
        }
    nodes = {
        'wrap': col(['card']),
        'card': col(['head', 'lines', 'foot'], 0,
                    decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1.2, 'radius': 14, 'clip': 'antiAlias'},
                    bind={'decoration.radius': '${theme.radii.tile}',
                          'decoration.strokes[0].color': E('%s ? theme.colors.goodLine : theme.colors.line' % kept)}),
        'head': row(['headIcon', 'title', 'range'], 8, pad=[12, 9, 12, 9], decoration={'fills': [{'color': 'tile'}]}),
        'headIcon': icon('difference_outlined', 15, 'inkFaint'),
        'title': text('${props.title}', {'from': 'rowTitle', 'fontSize': 13}, FILL, maxLines=1, overflow='ellipsis'),
        'range': text('${props.detail}', {'from': 'code', 'fontSize': 11}, color='inkFaint'),
        'lines': vlist(['line'], 0, '${props.lines}', bind={'opacity': E('%s ? 0.45 : 1' % dropped)}),
        'line': row(['bar', 'no', 'sign', 'code'], 0, height=25, decoration={'fills': [{'color': 'codeBg'}]},
                    bind={'decoration.fills[0].color': E('%s ? theme.colors.goodTint : %s ? theme.colors.badTint : theme.colors.codeBg' % (add, rem))}),
        'bar': box(3, FILL, {'fills': [{'color': 'codeBg'}]},
                   bind={'decoration.fills[0].color': E("%s ? theme.colors.good : %s ? theme.colors.bad : '#00FFFFFF'" % (add, rem))}),
        'no': text(E('%s ? %s : %s' % (add, new_no, old_no)), {'from': 'code', 'fontSize': 11}, color='codeGutter', textAlign='right',
                   layout={'width': 30}),
        'sign': text("${= %s ? '+' : %s ? '-' : ''}" % (add, rem), {'from': 'code', 'fontWeight': 700}, textAlign='center', layout={'width': 24},
                     bind={'props.style.color': E('%s ? theme.colors.goodDeep : theme.colors.badDeep' % add)}),
        'code': text("${= %s || %s ? substring(item, 1) : trim(item) == '' ? '' : substring(item, 1)}" % (add, rem), 'code', FILL, maxLines=1,
                     overflow='ellipsis', bind={
            'props.style.color': E('%s ? theme.colors.goodDeep : %s ? theme.colors.badDeep : theme.colors.inkSoft' % (add, rem)),
            'props.style.decoration': E("%s && %s ? 'lineThrough' : 'none'" % (add, dropped))}),
        'foot': row(['state', 'keep', 'discard'], 8, pad=[12, 9, 10, 9],
                    decoration={'strokes': [{'color': 'line'}], 'strokeWidth': 1, 'strokeSides': 'top'}),
        'state': text("${= %s ? 'Kept' : %s ? 'Discarded' : 'Not decided'}" % (kept, dropped), 'meta', FILL, bind={
            'props.style.color': E('%s ? theme.colors.goodDeep : theme.colors.inkFaint' % kept)}),
        **choice('keep', 'Keep', 'check_rounded', 'keep', kept, 'good', 'onAccent'),
        **choice('discard', 'Discard', 'close_rounded', 'discard', dropped, 'bar', 'onBar'),
    }
    props = [
        P('value', var(STRING), '', 'The name of your text variable: it becomes "keep" or "discard" (empty until decided).'),
        P('title', STRING, 'Change', 'What the hunk changes, in a few words.', True),
        P('detail', STRING, '', 'The range, e.g. @@ -4,2 +4,2 @@.'),
        P('start', INT, 1, 'The line number of the first line.', True),
        P('lines', STRINGS, ['-port: 8080', '+port: 9090', ' host: localhost'], 'The lines: each starts with - (removed, red), + (added, green) or a space (unchanged).', True),
    ]
    return component('DiffHunk', "One hunk of a diff with its own Keep and Discard buttons: DiffHunk \"Server port\" \"@@ -4,2 +4,2 @@\" bind=h1 start=4 lines=[\"-port: 8080\",\"+port: 9090\",\" host: localhost\"] (a line starts with -, + or a space; numbers count from start) sets your text variable to \"keep\" or \"discard\" (empty until decided).",
                     props, nodes, 'wrap', events=[('onChanged', 'Keep or Discard was tapped; the value is "keep" or "discard".')],
                     previews=[{'name': 'Hunk', 'size': [340, 170], 'props': {'title': 'Server port', 'detail': '@@ -4,2 +4,2 @@', 'start': 4}}])


# --- ComparisonTable --------------------------------------------------------------------------------------

COMPARE = 5


def comparison_table():
    n = 'length(props.names)'
    wide = '(%s > 2)' % n
    HEAD, CELL, FOOT, LABEL = 98, 46, 58, 84
    colw = '(%s ? props.columnWidth : 140)' % wide
    picked = lambda i: "(%s > %d && at(props.names, %d) == props.pick)" % (n, i, i)
    rule = {'strokes': [{'color': 'line'}], 'strokeWidth': 1, 'strokeSides': 'top'}
    nodes = {
        # The columns scroll under the label column, which is laid over them and stays in place.
        'table': node('stack', {'width': FILL, 'height': HUG}, children=['scrollCol', 'labels']),
        # The engine's edgeFade is set on the scroller, but with this content it neither fades nor clips (see NOTES,
        # limits): so the frame clips, and the trailing edge is also faded by a painted gradient in the card color.
        'scrollCol': col(['scroller'], decoration={'clip': 'hardEdge'}, customPaint={'foregroundPainter': [
            {'op': 'rect', 'rect': ['${= size.width - 12}', 0, 12, '${size.height}'], 'when': E('%s && props.fade' % wide),
             'paint': "${= {'shader': {'type': 'linear', 'begin': 'centerLeft', 'end': 'centerRight', 'stops': [{'position': 0, 'color': alpha(theme.colors.card, 0)}, {'position': 1, 'color': theme.colors.card}]}}}"}]}),
        'labels': node('column', {'width': LABEL + 14, 'height': HUG, 'x': 0, 'y': 0, 'padding': [0, 0, 14, 0]}, {'crossAxisAlignment': 'stretch'},
                       ['corner', 'labelRows', 'labelFoot'],
                       decoration={'fills': [{'type': 'linear', 'begin': 'centerLeft', 'end': 'centerRight', 'stops': [
                           {'position': 0, 'color': 'card'}, {'position': 0.857, 'color': 'card'}, {'position': 1, 'color': '#00FFFFFF'}]}]},
                       bind={'decoration.fills[0].stops[2].color': '${= alpha(theme.colors.card, 0)}'}),
        'corner': node('column', {'width': FILL, 'height': HEAD, 'padding': [0, 0, 0, 12]}, {'mainAxisAlignment': 'end', 'crossAxisAlignment': 'start'},
                       ['cornerText']),
        'cornerText': text('${props.corner}', 'eyebrow'),
        'labelFoot': node('spacer', {'width': 1, 'height': FOOT}),
        'labelRows': vlist(['rl'], 0, '${props.rows}'),
        'rl': node('row', {'width': FILL, 'height': CELL, 'padding': [0, 0, 6, 0]}, None, ['rlText'], decoration=dict(rule)),
        'rlText': text('${= at(item, 0)}', {'from': 'meta', 'fontWeight': 600}, FILL, color='inkSoft', maxLines=2, overflow='ellipsis'),
        'scroller': node('row', {'width': FILL, 'height': HUG},
                         {'scrollable': True, 'scrollDirection': 'horizontal', 'crossAxisAlignment': 'start', 'edgeFade': 12},
                         ['strip'], bind={'props.edgeFade': '${= props.fade ? 12 : 0}'}),
        'strip': node('row', {'width': HUG, 'height': HUG}, {'crossAxisAlignment': 'start'},
                      ['lead'] + ['k%d' % i for i in range(COMPARE)] + ['tail']),
        'lead': node('spacer', {'width': LABEL, 'height': 1}),
        'tail': node('spacer', {'width': 20, 'height': 1}, bind={'visible': E(wide)}),
    }
    for i in range(COMPARE):
        vis = E('%s > %d' % (n, i))
        win = '(at(item, length(item) - 1) == %d)' % (i + 1)
        nodes['k%d' % i] = node('column', {'width': 140, 'height': HUG}, {'crossAxisAlignment': 'stretch'},
                                ['h%d' % i, 'cells%d' % i, 'f%d' % i],
                                decoration={'fills': [{'color': '#00FFFFFF'}], 'radius': 14},
                                bind={'visible': vis, 'layout.width': E(colw),
                                      'decoration.fills[0].color': E("%s ? theme.colors.accentTint : '#00FFFFFF'" % picked(i)),
                                      'decoration.radius': '${theme.radii.tile}'})
        nodes['h%d' % i] = node('column', {'width': FILL, 'height': HEAD, 'padding': [10, 10, 8, 0]},
                                {'crossAxisAlignment': 'start', 'spacing': 2}, ['hc%d' % i, 'hn%d' % i, 'hp%d' % i, 'hs%d' % i])
        nodes['hc%d' % i] = row(['hcT%d' % i], width=HUG, pad=[7, 3, 7, 3], decoration={'fills': [{'color': 'accent'}], 'radius': 999},
                                bind={'opacity': E('%s ? 1 : 0' % picked(i))})
        nodes['hcT%d' % i] = text('${props.pickLabel}', {'from': 'eyebrow', 'fontSize': 9.5, 'letterSpacing': 0.5}, color='onAccent')
        nodes['hn%d' % i] = text('${= %s > %d ? at(props.names, %d) : ""}' % (n, i, i), 'blockTitle', FILL, maxLines=1, overflow='ellipsis',
                                 layout={'padding': [0, 3, 0, 0]})
        nodes['hp%d' % i] = text('${= length(props.prices) > %d ? at(props.prices, %d) : ""}' % (i, i), {'from': 'number', 'fontSize': 20}, FILL,
                                 maxLines=1, scaleDown=True,
                                 bind={'props.style.color': E('%s ? theme.colors.accent : theme.colors.ink' % picked(i))})
        nodes['hs%d' % i] = text('${= length(props.notes) > %d ? at(props.notes, %d) : ""}' % (i, i), 'meta', FILL, maxLines=1, overflow='ellipsis',
                                 bind={'visible': E('length(props.notes) > %d' % i)})
        nodes['cells%d' % i] = vlist(['c%d' % i], 0, '${props.rows}')
        nodes['c%d' % i] = node('row', {'width': FILL, 'height': CELL, 'padding': [10, 0, 6, 0]}, {'spacing': 5}, ['ct%d' % i, 'cw%d' % i],
                                decoration=dict(rule))
        nodes['ct%d' % i] = text('${= length(item) > %d ? at(item, %d) : ""}' % (i + 2, i + 1), {'from': 'figure', 'fontSize': 13, 'height': 1.25},
                                 FILL, maxLines=2, overflow='ellipsis', bind={
            'props.style.color': E('%s ? theme.colors.ink : theme.colors.inkSoft' % win),
            'props.style.fontWeight': E('%s ? 600 : 400' % win)})
        nodes['cw%d' % i] = icon('check_circle_rounded', 16, 'good', bind={'visible': E(win)})
        nodes['f%d' % i] = node('column', {'width': FILL, 'height': FOOT, 'padding': [8, 6, 8, 10]}, {'crossAxisAlignment': 'stretch'}, ['fb%d' % i])
        nodes['fb%d' % i] = row(['fbT%d' % i], height=40, main='center', decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'lineStrong'}],
                                                                                 'strokeWidth': 1.2, 'radius': 12},
                                bind={'decoration.fills[0].color': E('%s ? theme.colors.accent : theme.colors.card' % picked(i)),
                                      'decoration.strokes[0].color': E('%s ? theme.colors.accent : theme.colors.lineStrong' % picked(i)),
                                      'decoration.effects': E('%s ? theme.shadows.cta : []' % picked(i)),
                                      'decoration.radius': '${theme.radii.control}'},
                                states={'pressed': {'fb%d' % i: PRESS}},
                                actions=click(fire('onChoose', '${= at(props.names, %d)}' % i)))
        nodes['fbT%d' % i] = text('${props.cta}', {'from': 'cta', 'fontSize': 13.5}, maxLines=1, bind={
            'props.style.color': E('%s ? theme.colors.onAccent : theme.colors.ink' % picked(i))})
    props = [
        P('names', STRINGS, ['Lite', 'Max'], 'The two to five things compared, one column each.', True),
        P('prices', STRINGS, [], 'The headline figure under each name ($25/mo).'),
        P('notes', STRINGS, [], 'A quiet line under each figure (optional).'),
        P('rows', ROWS, [['Data', '10 GB', 'Unlimited', 2]], 'One list per row: the label, a value per column, then the winning column (1 to 5; 0 for a tie).', True),
        P('pick', STRING, '', 'The recommended name: its column is tinted and its button filled (empty: none).'),
        P('pickLabel', STRING, 'Best value', 'The small label over the recommended column.'),
        P('cta', STRING, 'Choose', 'The label of the button under each column.'),
        P('corner', STRING, '', 'A small caps label in the top-left corner (optional).'),
        P('columnWidth', NUM, 124, 'The width of a column when there are more than two (they then scroll sideways).'),
        P('fade', BOOL, True, 'The scrolling columns fade at the edge where there are more (false: a hard edge).'),
    ]
    return component('ComparisonTable', "Two to five options compared side by side: names and prices head the columns, rows is a list of [label, value per column..., winner] where winner is the winning column's number (1 to 5; 0 a tie) and gets a check; pick names the recommended column (tinted); with more than two options the columns scroll sideways while the labels stay in place; the Choose button under each column fires onChoose with that name as result.",
                     props, nodes, 'table', events=[('onChoose', "A column's button was tapped; the value is its name.")],
                     previews=[{'name': 'Plans', 'size': [384, 300], 'props': {'prices': ['$25/mo', '$45/mo'], 'pick': 'Max',
                                                                             'rows': [['Data', '10 GB', 'Unlimited', 2], ['Contract', 'Monthly', '24 months', 1]]}}])


# --- StatTile and ChartCard -------------------------------------------------------------------------------

def stat_tile():
    up = "!startsWith(props.delta, '-')"
    good = '(%s) != props.invert' % up
    nodes = {
        'tile': col(['top', 'value', 'bottom'], 0, pad=[14, 13, 14, 13],
                    decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1.2, 'radius': 18},
                    bind={'decoration.radius': '${theme.radii.panel}'}),
        'top': row(['mark', 'label'], 8),
        'mark': node('row', {'width': 26, 'height': 26}, {'mainAxisAlignment': 'center'}, ['markIcon'],
                     decoration={'fills': [{'color': 'accentTint'}], 'radius': 8}, bind={'visible': "${= props.icon != ''}"}),
        'markIcon': icon('payments_rounded', 15, 'accent', bind={'props.icon': '${props.icon}'}),
        'label': text('${props.label}', 'meta', FILL, color='inkSoft', maxLines=1, overflow='ellipsis'),
        'value': text('${props.value}', {'from': 'numberLarge', 'fontSize': 26}, FILL, maxLines=1, scaleDown=True, layout={'padding': [0, 10, 0, 6]}),
        'bottom': row(['delta', 'note'], 6),
        'delta': row(['deltaIcon', 'deltaText'], 2, width=HUG, pad=[5, 3, 7, 3], decoration={'fills': [{'color': 'goodTint'}], 'radius': 999},
                     bind={'visible': "${= props.delta != ''}",
                           'decoration.fills[0].color': E('%s ? theme.colors.goodTint : theme.colors.badTint' % good)}),
        'deltaIcon': icon('arrow_upward_rounded', 12, 'good', bind={
            'props.icon': E("%s ? 'arrow_upward_rounded' : 'arrow_downward_rounded'" % up),
            'props.color': E('%s ? theme.colors.goodDeep : theme.colors.badDeep' % good)}),
        'deltaText': text("${= replace(replace(props.delta, '+', ''), '-', '')}", {'from': 'chip', 'fontSize': 11.5}, bind={
            'props.style.color': E('%s ? theme.colors.goodDeep : theme.colors.badDeep' % good)}),
        'note': text('${props.note}', {'from': 'meta', 'fontSize': 11.5}, FILL, maxLines=1, overflow='ellipsis'),
    }
    props = [
        P('label', STRING, 'Revenue', 'What the figure is.', True),
        P('value', STRING, '$0', 'The figure, as text ($78.9k).', True),
        P('delta', STRING, '', 'Its change, starting with + or - (+8.5%): drawn as an up or down chip, green when good (empty: none).'),
        P('invert', BOOL, False, 'True when a fall is the good direction (churn, cost): the colors swap.'),
        P('note', STRING, '', 'A quiet note after the change (vs last month).'),
        P('icon', STRING, '', 'A Material icon in the small tile (empty: none).'),
    ]
    return component('StatTile', "A dashboard figure with its change: the label, value (text) and delta (+8.5% or -0.4%: an up or down chip, green when good; invert=true when a fall is good, as for churn); put four in a Grid cols=2 gap=10.",
                     props, nodes, 'tile',
                     previews=[{'name': 'Revenue', 'size': [170, 110], 'props': {'value': '$78.9k', 'delta': '+8.5%', 'icon': 'payments_rounded'}}])


def chart_card():
    n = 'max(1, length(props.values))'
    top = 'max(1, max(props.values) * 1.12)'
    low = "(props.kind == 'line' ? min(props.values) * 0.82 : 0)"
    H = 118
    x = '(%s > 1 ? index * size.width / (%s - 1) : size.width / 2)' % (n, n)
    yv = lambda v: '(%d - (%s - %s) / max(0.0001, %s - %s) * %d)' % (H, v, low, top, low, H)
    pts = "map(range(%s), i => [%s > 1 ? i * (size.width - 8) / (%s - 1) + 4 : size.width / 2, %s])" % (n, n, n, yv('at(props.values, i)'))
    lx = '(%s > 1 ? index * (size.width - 8) / (%s - 1) + 4 : size.width / 2)' % (n, n)
    area_paint = "${= {'shader': {'type': 'linear', 'begin': 'topCenter', 'end': 'bottomCenter', 'stops': [{'position': 0, 'color': theme.colors.accentGlow}, {'position': 1, 'color': '#00FFFFFF'}]}}}"
    grid_lines = [{'op': 'line', 'p1': [0, H * f], 'p2': ['${size.width}', H * f],
                   'paint': {'color': '${theme.colors.line}', 'style': 'stroke', 'strokeWidth': 1, 'dashPattern': [3, 4]}} for f in (0.0, 1 / 3, 2 / 3)]
    base = {'op': 'line', 'p1': [0, H], 'p2': ['${size.width}', H], 'paint': {'color': '${theme.colors.lineStrong}', 'style': 'stroke', 'strokeWidth': 1}}
    label_op = lambda xe, anchor='topCenter': {
        'op': 'paragraph', 'text': "${= index < length(props.labels) ? at(props.labels, index) : ''}",
        'offset': [xe, H + 8], 'anchor': anchor, 'style': {'fontSize': 10.5, 'fontWeight': 600, 'fontFamily': 'Inter'},
        'paint': '${theme.colors.inkFaint}'}
    skip = '(%s <= 7 || (index %% ceil(%s / 6) == 0 && %s - 1 - index >= ceil(%s / 6) * 0.6))' % (n, n, n, n)
    # The line is drawn a segment at a time, each an S-curve between two values, so it reads as one smooth line.
    px = lambda i: '(%s > 1 ? (%s) * (size.width - 8) / (%s - 1) + 4 : size.width / 2)' % (n, i, n)
    py = lambda i: yv('at(props.values, %s)' % i)
    dx = '((size.width - 8) / max(1, %s - 1) / 2)' % n
    curve = {'cubicTo': [E('%s + %s' % (px('index'), dx)), E(py('index')), E('%s - %s' % (px('index + 1'), dx)), E(py('index + 1')),
                         E(px('index + 1')), E(py('index + 1'))]}
    fade = ("${= {'shader': {'type': 'linear', 'begin': 'topCenter', 'end': 'bottomCenter', 'stops': [{'position': 0, 'color': "
            "alpha(theme.colors.card, 0)}, {'position': 1, 'color': theme.colors.card}]}}}")
    line_ops = {'op': 'group', 'when': "${= props.kind == 'line'}", 'ops': [
        {'op': 'repeat', 'count': E('max(0, %s - 1)' % n), 'ops': [
            {'op': 'path', 'commands': [{'moveTo': [E(px('index')), H]}, {'lineTo': [E(px('index')), E(py('index'))]}, curve,
                                        {'lineTo': [E('%s + 0.6' % px('index + 1')), E(py('index + 1'))]},
                                        {'lineTo': [E('%s + 0.6' % px('index + 1')), H]}, {'close': True}],
             'paint': '${theme.colors.accentLine}'},
        ]},
        {'op': 'rect', 'rect': [0, 0, '${size.width}', H], 'paint': fade},
        {'op': 'repeat', 'count': E('max(0, %s - 1)' % n), 'ops': [
            {'op': 'path', 'commands': [{'moveTo': [E(px('index')), E(py('index'))]}, curve],
             'paint': {'color': '${theme.colors.accent}', 'style': 'stroke', 'strokeWidth': 2.6, 'strokeCap': 'round', 'strokeJoin': 'round'}},
        ]},
        {'op': 'repeat', 'each': '${props.values}', 'ops': [
            {'op': 'circle', 'c': ['${= %s}' % lx, '${= %s}' % yv('item')], 'radius': 9, 'when': '${= index == %s - 1}' % n,
             'paint': '${theme.colors.accentGlow}'},
            {'op': 'circle', 'c': ['${= %s}' % lx, '${= %s}' % yv('item')], 'radius': 4.5, 'when': '${= index == %s - 1}' % n,
             'paint': ['${theme.colors.card}', {'color': '${theme.colors.accent}', 'style': 'stroke', 'strokeWidth': 2.6}]},
            {**label_op('${= %s}' % lx), 'when': '${= %s && index > 0 && index < %s - 1}' % (skip, n)},
            {**label_op(4, 'topLeft'), 'when': '${= index == 0}'},
            {**label_op('${= size.width - 4}', 'topRight'), 'when': '${= index == %s - 1 && %s > 1}' % (n, n)},
        ]},
    ]}
    gap = 10
    bw = '((size.width - %d * (%s - 1)) / %s)' % (gap, n, n)
    bx = '(index * (%s + %d))' % (bw, gap)
    bh = 'max(6, item / %s * %d)' % (top, H)
    hot = '(item == max(props.values))'
    bar_ops = {'op': 'group', 'when': "${= props.kind != 'line'}", 'ops': [
        {'op': 'repeat', 'each': '${props.values}', 'ops': [
            {'op': 'rrect', 'rect': ['${= %s}' % bx, '${= %d - %s}' % (H, bh), '${= %s}' % bw, '${= %s}' % bh],
             'radius': '${= min(8, %s / 2)}' % bw, 'when': '${= !%s}' % hot, 'paint': '${theme.colors.accentLine}'},
            {'op': 'rrect', 'rect': ['${= %s}' % bx, '${= %d - %s}' % (H, bh), '${= %s}' % bw, '${= %s}' % bh],
             'radius': '${= min(8, %s / 2)}' % bw, 'when': '${= %s}' % hot,
             'paint': "${= {'shader': {'type': 'linear', 'begin': 'topCenter', 'end': 'bottomCenter', 'stops': [{'position': 0, 'color': theme.colors.accentBright}, {'position': 1, 'color': theme.colors.accent}]}}}"},
            {'op': 'paragraph', 'text': '${= thousands(item)}', 'offset': ['${= %s + %s / 2}' % (bx, bw), '${= %d - %s - 6}' % (H, bh)],
             'anchor': 'bottomCenter', 'style': {'fontSize': 10.5, 'fontWeight': 700, 'fontFamily': 'Inter'},
             'paint': '${= %s ? theme.colors.accent : theme.colors.inkSoft}' % hot},
            label_op('${= %s + %s / 2}' % (bx, bw)),
        ]},
    ]}
    nodes = {
        'card': col(['head', 'plot'], 14, pad=[16, 14, 16, 12],
                    decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1.2, 'radius': 18},
                    bind={'decoration.radius': '${theme.radii.panel}'}),
        'head': row(['heads', 'delta'], 8, cross='start'),
        'heads': col(['title', 'value'], 3, cross='start'),
        'title': text('${props.title}', 'meta', FILL, color='inkSoft'),
        'value': text('${props.value}', 'number', FILL, bind={'visible': "${= props.value != ''}"}),
        'delta': row(['deltaText'], width=HUG, pad=[8, 4, 8, 4], decoration={'fills': [{'color': 'goodTint'}], 'radius': 999},
                     bind={'visible': "${= props.delta != ''}",
                           'decoration.fills[0].color': "${= startsWith(props.delta, '-') ? theme.colors.badTint : theme.colors.goodTint}"}),
        'deltaText': text('${props.delta}', 'chip', bind={
            'props.style.color': "${= startsWith(props.delta, '-') ? theme.colors.badDeep : theme.colors.goodDeep}"}),
        'plot': node('box', {'width': FILL, 'height': H + 24}, customPaint={'painter': [line_ops, *grid_lines, base, bar_ops]}),
    }
    props = [
        P('title', STRING, 'Revenue', 'What the chart shows.', True),
        P('value', STRING, '', 'The headline figure under the title, as text (empty: none).'),
        P('values', NUMBERS, [42, 48, 45, 56, 61, 58, 72], 'The numbers, in order.', True),
        P('labels', STRINGS, [], 'A label per value, under the axis (a line shows about six of them).'),
        P('kind', enum('line', 'bars'), 'line', 'line (an area line, for a trend over time) or bars (one rounded bar per value, the largest lit).'),
        P('delta', STRING, '', 'A change chip at the right (+12%; red when it starts with -).'),
    ]
    return component('ChartCard', "A designed chart in its own tile: kind=\"line\" draws values as an area line (a trend), kind=\"bars\" one rounded bar per value with its number (a breakdown); the title, a headline value, a delta chip and labels (one per value) complete it; never use BarChart or LineChart in a card.",
                     props, nodes, 'card',
                     previews=[{'name': 'Line', 'size': [360, 220], 'props': {'value': '$78.9k', 'delta': '+8.5%', 'labels': ['1', '5', '10', '15', '20', '25', '30']}},
                               {'name': 'Bars', 'size': [360, 220], 'props': {'kind': 'bars', 'title': 'Sign-ups by channel', 'values': [420, 310, 220, 160, 90],
                                                                             'labels': ['Organic', 'Paid', 'Referral', 'Social', 'Email']}}])


# --- TableHeader and TableRow -----------------------------------------------------------------------------

COLS = 7


def _flex(i):
    return E('length(props.widths) > %d ? at(props.widths, %d) : %d' % (i, i, 3 if i == 0 else 2))


def _tick(nid, on):
    return {nid: node('row', {'width': 20, 'height': 20}, {'mainAxisAlignment': 'center'}, [nid + 'I'],
                      decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1.5, 'radius': 6},
                      bind={'decoration.fills[0].color': E('%s ? theme.colors.accent : theme.colors.card' % on),
                            'decoration.strokes[0].color': E('%s ? theme.colors.accent : theme.colors.lineStrong' % on)}),
            nid + 'I': icon('check_rounded', 14, 'onAccent', bind={'visible': E(on)})}


def table_header():
    key = lambda i: "(length(props.keys) > %d ? at(props.keys, %d) : lower(at(props.columns, %d)))" % (i, i, i)
    nodes = {
        'head': row(['tickBox'] + ['h%d' % i for i in range(COLS)], 8, height=36, pad=[10, 0, 10, 0],
                    decoration={'fills': [{'color': 'tile'}], 'radius': 10}),
        'tickBox': node('row', {'width': 20, 'height': 36}, {'mainAxisAlignment': 'center'}, ['tick'], bind={'visible': '${props.selectable}'},
                        actions=click(fire('onToggleAll', '${= !props.checked}'))),
        **_tick('tick', 'props.checked'),
    }
    for i in range(COLS):
        on = '(props.value == %s)' % key(i)
        last = '(%d == length(props.columns) - 1 && %d > 0)' % (i, i)
        nodes['h%d' % i] = node('row', {'width': FILL, 'height': 36, 'flex': 2}, None, ['ht%d' % i],
                                bind={'visible': E('length(props.columns) > %d' % i), 'layout.flex': _flex(i)},
                                actions=click({'type': 'if', 'condition': {'left': E(on), 'op': 'isTrue'},
                                               'then': [{'type': 'setVariable', 'variable': 'props.desc', 'op': 'toggle'}],
                                               'else': [setv('props.value', key(i)), setv('props.desc', 'false')]},
                                              fire('onSort', E(key(i)))))
        nodes['ht%d' % i] = text("${= length(props.columns) > %d ? upper(at(props.columns, %d)) + (%s ? (props.desc ? ' ↓' : ' ↑') : '') : ''}" % (i, i, on),
                                 {'from': 'eyebrow', 'fontSize': 9.5, 'letterSpacing': 0.3}, FILL, maxLines=1, scaleDown=True,
                                 bind={'props.style.color': E('%s ? theme.colors.accent : theme.colors.inkFaint' % on),
                                       'props.textAlign': E("%s ? 'right' : 'left'" % last)})
    props = [
        P('value', var(STRING), '', 'The name of your text variable: the key of the column sorted by (empty: none).'),
        P('desc', var(BOOL), '', 'The name of your boolean variable: true when the sort is high to low. Declare it (state desc=false) and write desc:desc.'),
        P('columns', STRINGS, ['Plan', 'Subs', 'Revenue'], 'The column titles (up to seven).', True),
        P('keys', STRINGS, [], "The field each column sorts by, e.g. [\"plan\",\"subs\",\"revenue\"] (default: the title in lower case)."),
        P('widths', NUMBERS, [], 'Relative column widths, e.g. [3,2,2] (default: the first wider); give TableRow the same.'),
        P('selectable', BOOL, False, 'True shows a tick-all box before the titles.'),
        P('checked', BOOL, False, 'Whether the tick-all box is ticked.'),
    ]
    return component('TableHeader', "The header of a sortable table: columns are the titles, keys the fields they sort by; tapping a title sets your sort variable to its key and flips desc on a second tap, so write state desc=false, TableHeader bind=sort desc=desc columns=[...] keys=[...] and show sortBy or sortByDesc(rows,sort). selectable=true adds a tick-all box that fires onToggleAll.",
                     props, nodes, 'head', events=[('onToggleAll', 'The tick-all box was tapped; the value is the new state.'),
                                                   ('onSort', 'A title was tapped; the value is its key.')],
                     previews=[{'name': 'Header', 'size': [360, 36], 'props': {'value': 'revenue', 'desc': True}}])


def table_row():
    b = 'lower(props.badge)'
    tone = lambda g, w, d, n: ("${= contains(['paid', 'active', 'done', 'sent', 'ok', 'complete', 'completed'], %s) ? theme.colors.%s : "
                               "contains(['overdue', 'failed', 'late', 'error', 'cancelled'], %s) ? theme.colors.%s : "
                               "contains(['due', 'pending', 'draft', 'open', 'trial'], %s) ? theme.colors.%s : theme.colors.%s}") % (b, g, b, d, b, w, n)
    nodes = {
        'row': row(['tickBox'] + ['c%d' % i for i in range(COLS)] + ['badge'], 8, pad=[10, 11, 10, 11],
                   decoration={'fills': [{'color': '#00FFFFFF'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1, 'strokeSides': 'bottom'},
                   bind={'decoration.fills[0].color': "${= props.checked ? theme.colors.accentTint : '#00FFFFFF'}"},
                   states={'pressed': {'row': PRESS}}, actions=tap()),
        'tickBox': node('row', {'width': 20, 'height': 20}, {'mainAxisAlignment': 'center'}, ['tick'], bind={'visible': '${props.selectable}'}),
        **_tick('tick', 'props.checked'),
        'badge': node('row', {'width': FILL, 'height': HUG, 'flex': 2}, {'mainAxisAlignment': 'end'}, ['badgePill'],
                      bind={'visible': "${= props.badge != ''}", 'layout.flex': _flex_at('length(props.cells)')}),
        'badgePill': row(['badgeText'], width=FILL, pad=[4, 3, 4, 3], decoration={'fills': [{'color': 'tile'}], 'radius': 999},
                         bind={'decoration.fills[0].color': tone('goodTint', 'warnTint', 'badTint', 'tile')}),
        'badgeText': text('${props.badge}', {'from': 'chip', 'fontSize': 10.5}, FILL, textAlign='center', maxLines=1, overflow='ellipsis', bind={
            'props.style.color': tone('goodDeep', 'warnDeep', 'badDeep', 'inkSoft')}),
    }
    for i in range(COLS):
        last = "(%d == length(props.cells) - 1 && %d > 0 && props.badge == '')" % (i, i)
        nodes['c%d' % i] = text('${= length(props.cells) > %d ? at(props.cells, %d) : ""}' % (i, i), 'figure', FILL, maxLines=1, overflow='ellipsis',
                                layout={'flex': 2},
                                bind={'visible': E('length(props.cells) > %d' % i), 'layout.flex': _flex(i),
                                      'props.textAlign': E("%s ? 'right' : 'left'" % last),
                                      'props.style.fontWeight': 600 if i == 0 else 400,
                                      'props.style.color': E('theme.colors.ink' if i == 0 else 'theme.colors.inkSoft')})
        if i == 0:
            nodes['c0']['props']['style'] = {'from': 'figure', 'fontWeight': 600}
            del nodes['c0']['bind']['props.style.fontWeight']
        else:
            del nodes['c%d' % i]['bind']['props.style.fontWeight']
            nodes['c%d' % i]['props']['style'] = {'from': 'figure', 'fontSize': 13}
    props = [
        P('cells', STRINGS, ['Pro', '1,340', '$38.9k'], 'The cell texts, in column order (up to seven).', True),
        P('badge', STRING, '', 'A status pill in one more column at the end (Paid is green, Due amber, Overdue red; empty: none).'),
        P('widths', NUMBERS, [], "Relative column widths, as the TableHeader's."),
        P('selectable', BOOL, False, 'True shows a tick box before the cells.'),
        P('checked', BOOL, False, 'Whether its box is ticked (the row is tinted).'),
    ]
    return component('TableRow', "One row of a table under a TableHeader: cells={[r.plan,r.subs,money(r.revenue,\"$\",0)]} in column order, badge a status pill as a last column (Paid, Due, Overdue are colored); selectable=true with checked={contains(picked,r.id)} adds a tick box, and a tap fires onPressed (toggle the tick).",
                     props, nodes, 'row', events=[('onPressed', 'The row was tapped.')],
                     previews=[{'name': 'Row', 'size': [360, 44], 'props': {'badge': 'Paid'}}])


def _flex_at(expr):
    return E('length(props.widths) > %s ? at(props.widths, %s) : 2' % (expr, expr))


# --- PhotoGallery -----------------------------------------------------------------------------------------

def photo_gallery():
    n = 'length(props.photos)'
    shown = 'clamp(props.value - 1, 0, max(0, %s - 1))' % n
    cur = 'at(props.photos, %s)' % shown
    whole = {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}
    kind = {'props.kind': '${item.kind}', 'props.tone': "${= coalesce(item.tone, 'auto')}"}
    open_it = click(setv('props.value', 'index + 1'), fire('onChanged', '${= index + 1}'))
    swiped = [{'trigger': {'type': 'changed'}, 'actions': [setv('props.value', '${= result.index + 1}'), fire('onChanged', '${= result.index + 1}')]}]
    cap = lambda nid: text("${= coalesce(item.caption, '')}", {'from': 'meta', 'fontSize': 11.5, 'height': 1.25}, FILL, maxLines=1, overflow='ellipsis',
                           color='inkSoft')
    closed = "(props.value <= 0 || props.viewer == 'overlay')"
    nodes = {
        'gallery': col(['grid', 'strip', 'paged', 'veil'], 0),
        # a grid of thumbnails
        'grid': grid(['cell'], '${props.columns}', 8, '${props.photos}', run_gap=10,
                     bind={'visible': "${= props.layout == 'grid' && %s}" % closed}),
        'cell': col(['thumb', 'caption'], 6, states={'pressed': {'cell': PRESS}}, actions=open_it),
        'thumb': node('Media', {'width': FILL, 'height': 92}, {'kind': 'mountain'}, bind=dict(kind)),
        'caption': cap('caption'),
        # a strip that scrolls sideways
        'strip': node('row', {'width': FILL, 'height': 150}, {'scrollable': True, 'scrollDirection': 'horizontal', 'edgeFade': 12}, ['stripList'],
                      bind={'visible': "${= props.layout == 'strip' && %s}" % closed, 'props.edgeFade': '${= props.fade ? 12 : 0}'}),
        'stripList': node('listView', {'width': HUG, 'height': 150}, {'scrollable': False, 'spacing': 10, 'scrollDirection': 'horizontal'}, ['tile'],
                          bind={'data': '${props.photos}'}),
        'tile': col(['tileArt', 'tileCaption'], 6, width=168, height=FILL, states={'pressed': {'tile': PRESS}}, actions=open_it),
        'tileArt': node('Media', {'width': FILL, 'height': 124}, {'kind': 'mountain'}, bind=dict(kind)),
        'tileCaption': cap('tileCaption'),
        # full-width pages with dots
        'paged': col(['pages', 'pagedFoot'], 8, bind={'visible': "${= props.layout == 'pages'}"}),
        'pages': node('pageView', {'width': FILL, 'height': 250}, {'viewportFraction': 1, 'scrollDirection': 'horizontal', 'padEnds': False},
                      ['pg'], bind={'props.initialPage': E(shown), 'data': '${props.photos}'}, actions=swiped),
        'pg': node('stack', {'width': FILL, 'height': FILL}, children=['pgArt', 'pgShade', 'pgCaption', 'pgCount']),
        'pgArt': node('Media', dict(whole), {'kind': 'mountain'}, bind=dict(kind)),
        'pgShade': node('box', {'width': FILL, 'height': 84, 'x': {'start': 0, 'end': 0}, 'y': {'end': 0}},
                        decoration={'radius': [0, 0, 14, 14], 'fills': [{'type': 'linear', 'begin': 'topCenter', 'end': 'bottomCenter', 'stops': [
                            {'position': 0, 'color': '#00000000'}, {'position': 1, 'color': '#A6000000'}]}]}),
        'pgCaption': text("${= coalesce(item.caption, '')}", 'blockTitle', color='#FFFFFFFF', maxLines=1, overflow='ellipsis',
                          layout={'x': {'start': 14, 'end': 14}, 'y': {'end': 12}}),
        'pgCount': row(['pgCountText'], width=HUG, pad=[9, 5, 9, 5], decoration={'fills': [{'color': '#8C000000'}], 'radius': 999}),
        'pgCountText': text('${= index + 1} of ${= %s}' % n, 'chip', color='#FFFFFFFF'),
        'pagedFoot': col(['pdots'], bind={'visible': '${props.dots}'}),
        **dots_nodes('pdots', n, shown, lambda i: [setv('props.value', '%s + 1' % i), fire('onChanged', '${= index + 1}')]),
        # the large view, in place of the grid or strip, paged by swipe
        'veil': col(['bar', 'stage', 'foot', 'vdots'], 10, pad=[12, 12, 12, 12],
                    decoration={'fills': [{'color': 'bar'}], 'radius': 14},
                    bind={'visible': "${= props.layout != 'pages' && props.value > 0 && props.viewer != 'overlay'}", 'decoration.radius': '${theme.radii.tile}'}),
        'bar': row(['count', 'close'], 8, main='spaceBetween'),
        'count': row(['countText'], width=HUG, pad=[10, 6, 10, 6], decoration={'fills': [{'color': 'barRaise'}], 'radius': 999}),
        'countText': text('${= %s + 1} of ${= %s}' % (shown, n), 'chip', color='onBar'),
        **round_button('close', 'close_rounded', 34, fill='barRaise', ink='onBar', actions=click(setv('props.value', '0'), fire('onChanged', '0'))),
        'stage': node('stack', {'width': FILL, 'height': 252}, children=['big', 'prev', 'next']),
        'big': node('pageView', dict(whole), {'viewportFraction': 1, 'scrollDirection': 'horizontal', 'padEnds': False}, ['bigArt'],
                    bind={'props.initialPage': E(shown), 'data': '${props.photos}'}, actions=swiped),
        'bigArt': node('Media', {'width': FILL, 'height': FILL}, {'kind': 'mountain'}, bind=dict(kind)),
        **round_button('prev', 'chevron_left_rounded', 38, fill='card', ink='ink',
                       actions=click(setv('props.value', '(props.value - 2 + %s) %% %s + 1' % (n, n)), fire('onChanged', '${props.value}'))),
        **round_button('next', 'chevron_right_rounded', 38, fill='card', ink='ink',
                       actions=click(setv('props.value', 'props.value %% %s + 1' % n), fire('onChanged', '${props.value}'))),
        'foot': text("${= coalesce(%s.caption, '')}" % cur, 'blockTitle', FILL, color='onBar', textAlign='center', maxLines=2, overflow='ellipsis'),
        **dots_nodes('vdots', n, shown, lambda i: [setv('props.value', '%s + 1' % i), fire('onChanged', '${= index + 1}')]),
    }
    nodes['pgCount']['layout'].update({'x': {'end': 12}, 'y': {'start': 12}})
    nodes['prev']['layout'].update({'x': {'start': 10}, 'y': {'align': 0}})
    nodes['next']['layout'].update({'x': {'end': 10}, 'y': {'align': 0}})
    for k in ('prev', 'next'):
        nodes[k]['bind'] = {'decoration.effects': '${theme.shadows.knob}'}
    nodes['vdots']['bind'] = {'visible': '${props.dots}'}
    nodes['vdotsDot']['bind']['decoration.fills[0].color'] = '${= index == %s ? theme.colors.onBar : theme.colors.onBarSoft}' % shown
    scenes = ', '.join(art.SCENES)
    props = [
        P('value', var(NUM), '', 'The name of your number variable: 0 while the grid or strip shows, else the number of the photo in view (from 1).'),
        P('photos', ROWS, [{'kind': 'harbor', 'caption': 'Harbour at sunrise'}, {'kind': 'mountain', 'caption': 'Mountain hut'},
                           {'kind': 'skyline', 'caption': 'Evening skyline'}],
          'The photos: records with kind (a Media scene: %s), caption and optionally tone (dawn, day, dusk, night).' % scenes, True),
        P('layout', enum('grid', 'strip', 'pages'), 'grid', 'grid (rows of thumbnails), strip (one row that scrolls sideways) or pages (one full-width photo at a time, swiped, with dots).'),
        P('dots', BOOL, True, 'Pagination dots under the paged and the large view.'),
        P('columns', INT, 3, 'Thumbnails per row of the grid.'),
        P('fade', BOOL, True, 'The strip fades at the edge where there are more photos (false: a hard edge).'),
        P('viewer', enum('inline', 'overlay'), 'inline', 'inline shows the large view in place of the grid or strip (a card in a chat); overlay leaves the grid as it is and only fires onChanged with the photo tapped, for a viewer shown over the window (on a page the notation opens its Lightbox there by itself).'),
    ]
    return component('PhotoGallery', "A photo gallery with a built-in large view: PhotoGallery bind=open photos=[{\"kind\":\"harbor\",\"caption\":\"Harbour at sunrise\"},...] draws each photo as a scene (kind: %s; optional tone: dawn, day, dusk, night); layout is grid, strip (one row that scrolls sideways) or pages (full-width photos swiped one at a time, with dots); tapping a photo opens it large with its caption, a \"3 of 9\" counter, dots, arrows and a close button, and a swipe there goes to the next (on a page it opens over the window, where it also zooms: a pinch, the wheel, a double tap); your variable holds the photo in view (0: none open)." % scenes,
                     props, nodes, 'gallery', events=[('onChanged', 'A photo was opened, changed or closed; the value is its number (0: closed).')],
                     previews=[{'name': 'Grid', 'size': [360, 130], 'props': {}}, {'name': 'Strip', 'size': [360, 150], 'props': {'layout': 'strip'}},
                               {'name': 'Pages', 'size': [360, 290], 'props': {'layout': 'pages'}}])


# --- DayHeader, ItineraryStop, Checklist ------------------------------------------------------------------

def day_header():
    whole = {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}
    nodes = {
        'day': col(['head', 'stops'], 14),
        'head': node('stack', {'width': FILL, 'height': 92}, children=['art', 'scrim', 'texts', 'tag'],
                     decoration={'radius': 16, 'clip': 'antiAlias'}, bind={'decoration.radius': '${theme.radii.panel}'}),
        'art': node('Media', dict(whole), {'kind': 'temple', 'round': False}, bind={'props.kind': '${props.kind}', 'props.tone': '${props.tone}'}),
        'scrim': node('box', dict(whole), decoration={'fills': [{'type': 'linear', 'begin': 'centerLeft', 'end': 'centerRight', 'stops': [
            {'position': 0, 'color': '#C2000000'}, {'position': 0.6, 'color': '#59000000'}, {'position': 1, 'color': '#00000000'}]}]}),
        'texts': node('column', dict(whole, padding=[16, 0, 90, 0]), {'crossAxisAlignment': 'start', 'mainAxisAlignment': 'center', 'spacing': 4},
                      ['eyebrow', 'title']),
        'eyebrow': text('${= upper(props.title)}', {'from': 'eyebrow', 'letterSpacing': 1.2}, color='#D9FFFFFF'),
        'title': text('${props.subtitle}', {'from': 'cardTitle', 'fontSize': 18, 'letterSpacing': -0.2}, FILL, color='#FFFFFFFF', maxLines=1,
                      overflow='ellipsis'),
        'tag': row(['tagText'], width=HUG, pad=[9, 5, 9, 5], decoration={'fills': [{'color': '#E6FFFFFF'}], 'radius': 999},
                   bind={'visible': "${= props.tag != ''}"}),
        'tagText': text('${props.tag}', 'chip', color='#FF111827'),
        'stops': col(['slot'], 0, bind={'visible': '${slots.children}'}),
        'slot': {'type': 'slot'},
    }
    nodes['tag']['layout'].update({'x': {'end': 12}, 'y': {'start': 12}})
    props = [
        P('title', STRING, 'Day 1', 'The small line: Day 1, Saturday.', True),
        P('subtitle', STRING, '', 'The large line: where the day goes.'),
        P('kind', STRING, 'temple', 'The scene drawn behind, a Media scene: %s.' % ', '.join(art.SCENES)),
        P('tone', STRING, 'auto', 'Its time of day: dawn, day, dusk or night.'),
        P('tag', STRING, '', 'A small pill at the top right (empty: none).'),
    ]
    return component('DayHeader', "One day of a trip: a banner drawn as a travel scene (the title, such as Day 1, over the subtitle, where it goes; kind the scene: %s; tone its time of day; tag a pill), with that day's ItineraryStop lines indented under it as its timeline." % ', '.join(art.SCENES),
                     props, nodes, 'day', children=True,
                     previews=[{'name': 'Day', 'size': [360, 92], 'props': {'subtitle': 'Higashiyama and Gion', 'tag': '3 to book'}}])


def itinerary_stop():
    rail = {'painter': [
        {'op': 'line', 'p1': [59, 26], 'p2': [59, '${= size.height + 2}'], 'when': '${= !props.last}',
         'paint': {'color': '${theme.colors.lineStrong}', 'style': 'stroke', 'strokeWidth': 1.6, 'strokeCap': 'round', 'dashPattern': [1, 5]}},
        {'op': 'circle', 'c': [59, 13], 'radius': 6.5, 'paint': '${theme.colors.accentTint}'},
        {'op': 'circle', 'c': [59, 13], 'radius': 3.5, 'paint': '${theme.colors.accent}'},
    ]}
    t = 'lower(props.travel)'
    travel_icon = ("${= contains(%s, 'walk') ? 'directions_walk_rounded' : contains(%s, 'bus') ? 'directions_bus_rounded' : "
                   "contains(%s, 'taxi') || contains(%s, 'car') ? 'local_taxi_rounded' : contains(%s, 'bike') || contains(%s, 'cycle') ? "
                   "'directions_bike_rounded' : 'train_rounded'}") % (t, t, t, t, t, t)
    nodes = {
        'stop': row(['time', 'gap', 'body'], 0, cross='start', customPaint=rail),
        'time': text('${props.time}', {'from': 'figure', 'fontWeight': 600}, layout={'width': 44, 'padding': [0, 4, 0, 0]}),
        'gap': node('spacer', {'width': 30, 'height': 1}),
        'body': col(['head', 'detail', 'travel'], 6, pad=[0, 3, 0, 16], bind={'layout.padding': '${= props.last ? [0, 3, 0, 2] : [0, 3, 0, 16]}'}),
        'head': row(['title', 'chev'], 6, actions=click({'type': 'setVariable', 'variable': 'open', 'op': 'toggle'}),
                    states={'pressed': {'head': PRESS}}),
        'title': text('${props.title}', 'rowTitle', FILL),
        'chev': icon('expand_more_rounded', 20, 'inkFaint', bind={'props.icon': "${= open ? 'expand_less_rounded' : 'expand_more_rounded'}",
                                                               'visible': "${= props.detail != ''}"}),
        'detail': text('${props.detail}', {'from': 'lead', 'fontSize': 13.5}, FILL, bind={'visible': "${= open && props.detail != ''}"}),
        'travel': row(['travelIcon', 'travelText'], 6, width=HUG, pad=[8, 5, 10, 5], decoration={'fills': [{'color': 'tile'}], 'radius': 999},
                      bind={'visible': "${= props.travel != ''}"}),
        'travelIcon': icon('train_rounded', 14, 'inkSoft', bind={'props.icon': travel_icon}),
        'travelText': text('${props.travel}', {'from': 'meta', 'fontSize': 12}, color='inkSoft', maxLines=1, overflow='ellipsis',
                           layout={'constraints': {'maxWidth': 230}}),
    }
    props = [
        P('title', STRING, 'Fushimi Inari Shrine', 'The place.', True),
        P('detail', STRING, '', 'The details a tap on the stop reveals (empty: nothing to open).'),
        P('time', STRING, '08:00', 'When, at the left of the timeline.', True),
        P('travel', STRING, '', 'How to get to the next stop and how long: "Walk to Gion, 15 min" (drawn as a pill with a walk, bus, taxi or train icon; empty: none).'),
        P('last', BOOL, False, 'True for the last stop of a day: the line ends here.'),
        P('open', BOOL, False, 'True starts it expanded.'),
    ]
    return component('ItineraryStop', "One stop on a day's timeline: the place (title), time at the left, a detail the stop reveals when tapped (it opens and closes by itself), and travel, how to reach the next stop and how long (\"Walk to Gion, 15 min\"); last=true ends the line. Write the stops one under another.",
                     props, nodes, 'stop', variables=[{'name': 'open', 'type': 'boolean', 'value': False}],
                     previews=[{'name': 'Stop', 'size': [360, 70], 'props': {'detail': 'Thousands of gates.', 'travel': 'JR Nara Line, 5 min'}}])


def checklist():
    on = 'contains(props.value, item)'
    nodes = {
        'box': col(['head', 'list'], 4, pad=[14, 12, 14, 8], decoration={'fills': [{'color': 'tile'}], 'radius': 14},
                   bind={'decoration.radius': '${theme.radii.tile}'}),
        'head': row(['title', 'count'], 8, pad=[0, 0, 0, 4]),
        'title': text('${= upper(props.title)}', 'eyebrow', FILL),
        'count': text('${= length(props.value)} of ${= length(props.items)}', {'from': 'meta', 'fontSize': 11.5, 'fontWeight': 600}, bind={
            'props.style.color': E('length(props.value) >= length(props.items) ? theme.colors.goodDeep : theme.colors.inkFaint')}),
        'list': vlist(['item'], 0, '${props.items}'),
        'item': row(['tick', 'itemText'], 10, pad=[0, 7, 0, 7], states={'pressed': {'item': PRESS}},
                    actions=click(setv('props.value', '%s ? without(props.value, item) : append(props.value, item)' % on),
                                  fire('onChanged', '${props.value}'))),
        **_tick('tick', on),
        'itemText': text('${item}', {'from': 'lead', 'fontSize': 13.5}, FILL, bind={
            'props.style.color': E('%s ? theme.colors.inkFaint : theme.colors.ink' % on),
            'props.style.decoration': E("%s ? 'lineThrough' : 'none'" % on)}),
    }
    props = [
        P('value', var({'kind': 'list', 'flutter': 'List<String>', 'item': STRING}), '', 'The name of your list variable: it holds the ticked items.'),
        P('title', STRING, 'To do', 'The heading, in small caps.'),
        P('items', STRINGS, ['First', 'Second'], 'The things to tick off.', True),
    ]
    return component('Checklist', "A titled list of things to tick off: Checklist \"Book ahead\" bind=booked items=[\"Dinner in Gion\",\"Tea ceremony\"] keeps the ticked items in your list variable, so what is left is length(items)-length(booked); it shows its own count.",
                     props, nodes, 'box', events=[('onChanged', 'An item was ticked or cleared; the value is the list of ticked items.')],
                     previews=[{'name': 'List', 'size': [360, 110], 'props': {'title': 'Book ahead'}}])


# --- MapPanel and PlaceRow --------------------------------------------------------------------------------

PIN_AT = [(-0.74, -0.42), (0.36, -0.7), (-0.44, 0.34), (0.78, 0.2), (-0.7, 0.72), (0.34, 0.74), (-0.2, -0.78), (0.86, -0.62)]


def map_panel():
    c = lambda name: '${theme.colors.%s}' % name
    road = lambda d, w: [art.path(d, {'color': c('mapRoadLine'), 'style': 'stroke', 'strokeWidth': w + 2, 'strokeCap': 'round'}),
                         art.path(d, {'color': c('mapRoad'), 'style': 'stroke', 'strokeWidth': w, 'strokeCap': 'round'})]
    blocks = [(14, 12, 44, 26), (84, 10, 54, 30), (164, 8, 60, 22), (252, 12, 46, 30), (322, 8, 40, 34),
              (10, 64, 50, 36), (84, 70, 30, 30), (252, 62, 46, 40), (322, 66, 44, 36),
              (16, 128, 44, 40), (84, 126, 54, 44), (164, 134, 60, 40), (252, 128, 46, 44)]
    draw = [
        art.rect(-20, -20, 400, 240, c('mapLand')),
        *[art.rrect(x, y, w, h, 5, c('mapBlock')) for x, y, w, h in blocks],
        art.rrect(126, 58, 104, 58, 12, c('mapPark')),
        art.faded(0.7, art.circle(150, 80, 7, c('good')), art.circle(168, 96, 9, c('good')), art.circle(204, 78, 8, c('good')),
                  art.circle(190, 100, 6, c('good'))),
        art.path('M300 190 C316 150 350 140 384 120 L384 190 Z', c('mapWater')),
        *road('M-10 50 L380 50', 9), *road('M-10 118 L380 118', 9),
        *road('M72 -10 L72 190', 8), *road('M150 -10 L150 56', 7), *road('M150 118 L150 190', 7), *road('M240 -10 L240 190', 8),
        *road('M310 -10 L310 190', 7),
        *road('M-10 176 C80 150 180 110 240 84 C290 62 330 40 380 22', 11),
        art.faded(0.9, art.path('M-10 176 C80 150 180 110 240 84 C290 62 330 40 380 22',
                                {'color': c('mapRoadLine'), 'style': 'stroke', 'strokeWidth': 1.2, 'dashPattern': [6, 7]})),
        # you are here
        art.faded(0.25, art.circle(196, 104, 20, c('accent'))),
        art.circle(196, 104, 8, c('card')), art.circle(196, 104, 5.5, c('accent')),
    ]
    nodes = {
        'map': node('stack', {'width': FILL, 'height': 178}, children=['draw'] + ['p%d' % i for i in range(len(PIN_AT))],
                    decoration={'fills': [{'color': 'mapLand'}], 'radius': 16, 'clip': 'antiAlias', 'strokes': [{'color': 'line'}], 'strokeWidth': 1},
                    bind={'decoration.radius': '${theme.radii.panel}'}),
        'draw': node('box', {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}},
                     customPaint={'viewBox': [360, 180], 'fit': 'cover', 'painter': draw}),
    }
    for i, (ax, ay) in enumerate(PIN_AT):
        on = 'props.value == %d' % (i + 1)
        nodes['p%d' % i] = node('stack', {'width': 34, 'height': 42, 'x': {'align': ax}, 'y': {'align': ay}}, children=['pt%d' % i, 'pd%d' % i],
                                bind={'visible': E('props.count > %d' % i)},
                                actions=click(setv('props.value', '%s ? 0 : %d' % (on, i + 1)), fire('onChanged', '${props.value}')))
        nodes['pd%d' % i] = node('row', {'width': 30, 'height': 30, 'x': 2, 'y': 0}, {'mainAxisAlignment': 'center'}, ['pn%d' % i],
                                 decoration={'fills': [{'color': 'mapPin'}], 'strokes': [{'color': 'card'}], 'strokeWidth': 2.5, 'radius': 15,
                                             'strokeAlign': 'outside'},
                                 bind={'decoration.fills[0].color': E('%s ? theme.colors.accent : theme.colors.mapPin' % on),
                                       'decoration.effects': E('%s ? theme.shadows.cta : theme.shadows.knob' % on),
                                       'motion.scale': E('%s ? 1.18 : 1' % on)})
        nodes['pn%d' % i] = text(str(i + 1), {'from': 'chip', 'fontWeight': 700, 'fontSize': 13}, bind={
            'props.style.color': E('%s ? theme.colors.onAccent : theme.colors.onMapPin' % on)})
        nodes['pt%d' % i] = node('box', {'width': 10, 'height': 10, 'x': 12, 'y': 25}, decoration={'fills': [{'color': 'mapPin'}], 'radius': 2},
                                 bind={'decoration.fills[0].color': E('%s ? theme.colors.accent : theme.colors.mapPin' % on)},
                                 motion={'rotate': 45})
    props = [
        P('value', var(NUM), '', 'The name of your number variable: the number of the pin chosen (0: none).'),
        P('count', INT, 5, 'How many numbered pins (up to %d).' % len(PIN_AT), True),
    ]
    return component('MapPanel', "A drawn map (an illustration: blocks, streets, a park, water, a dot for you) with numbered pins: MapPanel bind=pick count=5 shows pins 1 to 5 and keeps the tapped pin's number in your variable (0: none), the same variable the PlaceRow lines use.",
                     props, nodes, 'map', events=[('onChanged', 'A pin was tapped; the value is its number (0: cleared).')],
                     previews=[{'name': 'Map', 'size': [360, 178], 'props': {'value': 2}}])


def place_row():
    on = 'props.selected'

    def fact(nid, icon_name, key):
        return {nid: col([nid + 'L', nid + 'V'], 2, cross='start'),
                nid + 'L': row([nid + 'I', nid + 'T'], 4),
                nid + 'I': icon(icon_name, 13, 'inkFaint'),
                nid + 'T': text(key.upper(), {'from': 'eyebrow', 'fontSize': 9.5}),
                nid + 'V': text('${props.%s}' % key, {'from': 'figure', 'fontWeight': 600, 'fontSize': 13}, FILL, maxLines=1, overflow='ellipsis')}
    nodes = {
        'wrap': col(['card'], pad=[0, 0, 0, 8]),
        'card': col(['top', 'facts'], 12, pad=[12, 11, 14, 11],
                    decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'line'}], 'strokeWidth': 1.5, 'radius': 14},
                    bind={'decoration.radius': '${theme.radii.tile}',
                          'decoration.strokes[0].color': E('%s ? theme.colors.accent : theme.colors.line' % on),
                          'decoration.fills[0].color': E('%s ? theme.colors.accentTint : theme.colors.card' % on)},
                    states={'pressed': {'card': PRESS}}, actions=tap()),
        'top': row(['num', 'texts', 'rate'], 10),
        'rate': row(['star', 'score'], 3, width=HUG, bind={'visible': "${= props.rating != ''}"}),
        'num': node('row', {'width': 28, 'height': 28}, {'mainAxisAlignment': 'center'}, ['numText'],
                    decoration={'fills': [{'color': 'mapPin'}], 'radius': 14},
                    bind={'decoration.fills[0].color': E('%s ? theme.colors.accent : theme.colors.mapPin' % on)}),
        'numText': text('${props.index}', {'from': 'chip', 'fontWeight': 700, 'fontSize': 13}, bind={
            'props.style.color': E('%s ? theme.colors.onAccent : theme.colors.onMapPin' % on)}),
        'texts': col(['name', 'detail'], 1, cross='start'),
        'name': text('${props.name}', 'rowTitle', FILL, maxLines=1, overflow='ellipsis'),
        'detail': text('${props.detail}', 'meta', FILL, maxLines=1, overflow='ellipsis', bind={'visible': "${= props.detail != ''}"}),
        'star': icon('star_rounded', 16, 'gold', bind={'visible': "${= props.rating != ''}"}),
        'score': text('${props.rating}', {'from': 'figure', 'fontWeight': 600}, bind={'visible': "${= props.rating != ''}"}),
        'facts': row(['fRating', 'fDistance', 'fHours'], 10, cross='start', pad=[12, 10, 12, 10],
                     decoration={'fills': [{'color': 'card'}], 'radius': 10}, bind={'visible': E(on)}),
        **fact('fRating', 'star_outline_rounded', 'rating'),
        **fact('fDistance', 'near_me_outlined', 'distance'),
        **fact('fHours', 'schedule_rounded', 'hours'),
    }
    nodes['fHours']['layout']['flex'] = 2
    props = [
        P('name', STRING, 'Bean There', "The place's name.", True),
        P('detail', STRING, '', 'A quiet second line (what it is, the street).'),
        P('index', INT, 1, 'Its number, the same as its pin on the MapPanel.', True),
        P('rating', STRING, '', 'The rating, as text (4.7).'),
        P('distance', STRING, '', 'How far, as text (0.2 mi).'),
        P('hours', STRING, '', 'Opening hours, as text (7:00 to 18:00).'),
        P('selected', BOOL, False, 'True highlights it and shows rating, distance and hours.'),
    ]
    return component('PlaceRow', "A numbered place in a list beside a MapPanel: the name, a detail, index (its pin number), rating, distance and hours; selected={pick==1} highlights it and reveals the three facts, and a tap fires onPressed (-> pick=1).",
                     props, nodes, 'wrap', events=[('onPressed', 'The place was tapped.')],
                     previews=[{'name': 'Selected', 'size': [360, 120], 'props': {'detail': 'Specialty coffee', 'rating': '4.7', 'distance': '0.2 mi',
                                                                                'hours': '7:00 to 18:00', 'selected': True}}])


# --- PlanStep and ProgressLine ----------------------------------------------------------------------------

def plan_step():
    done = 'props.index < props.current'
    run = '(props.index == props.current && props.running)'
    rail = {'painter': [{'op': 'line', 'p1': [13, 30], 'p2': [13, '${= size.height + 12}'], 'when': '${= !props.last}',
                         'paint': {'color': E('%s ? theme.colors.good : theme.colors.lineStrong' % done), 'style': 'stroke', 'strokeWidth': 2,
                                   'strokeCap': 'round'}}]}
    nodes = {
        'step': row(['mark', 'texts', 'state'], 12, cross='start', customPaint=rail),
        'mark': node('stack', {'width': 26, 'height': 26}, children=['ring', 'spin', 'check']),
        'ring': node('row', {'width': 26, 'height': 26, 'x': 0, 'y': 0}, {'mainAxisAlignment': 'center'}, ['num'],
                     decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'lineStrong'}], 'strokeWidth': 1.5, 'radius': 13},
                     bind={'decoration.fills[0].color': E('%s ? theme.colors.accentTint : theme.colors.card' % run),
                           'decoration.strokes[0].color': E("%s ? '#00FFFFFF' : theme.colors.lineStrong" % run),
                           'visible': E('!(%s)' % done)}),
        'num': text('${= props.index + 1}', {'from': 'chip', 'fontWeight': 700}, color='inkFaint', bind={'visible': E('!%s' % run)}),
        'spin': node('circularProgressIndicator', {'width': 26, 'height': 26, 'x': 0, 'y': 0}, {'strokeWidth': 2.6, 'color': 'accent'},
                     bind={'visible': E(run)}),
        'check': node('row', {'width': 26, 'height': 26, 'x': 0, 'y': 0}, {'mainAxisAlignment': 'center'}, ['checkIcon'],
                      decoration={'fills': [{'color': 'good'}], 'radius': 13}, bind={'visible': E(done)}),
        'checkIcon': icon('check_rounded', 16, 'onAccent'),
        'texts': col(['title', 'detail'], 2, cross='start', pad=[0, 3, 0, 16]),
        'title': text('${props.title}', 'rowTitle', FILL, bind={
            'props.style.color': E('%s || %s ? theme.colors.ink : theme.colors.inkSoft' % (done, run))}),
        'detail': text('${props.detail}', {'from': 'meta', 'fontWeight': 400, 'fontSize': 13}, FILL, bind={'visible': "${= props.detail != ''}"}),
        'state': text("${= %s ? 'Done' : %s ? 'Running' : ''}" % (done, run), {'from': 'chip', 'fontSize': 11.5}, layout={'padding': [0, 5, 0, 0]}, bind={
            'props.style.color': E('%s ? theme.colors.goodDeep : theme.colors.accent' % done)}),
    }
    props = [
        P('title', STRING, 'Back up your content', 'The step.', True),
        P('detail', STRING, '', 'A short description under it.'),
        P('index', INT, 0, 'Its position, from 0.', True),
        P('current', NUM, 0, 'How many steps are finished (the position of the step now running).', True),
        P('running', BOOL, False, 'True while the plan runs: the current step shows a spinner.'),
        P('last', BOOL, False, 'True for the last step: the line ends here.'),
    ]
    return component('PlanStep', "One step of a plan that runs: the title and a detail, index (its position from 0), current={done} (how many steps are finished) and running={running}; it draws a tick when finished, a spinner when it is the running one, a number while it waits. Write the steps one under another; last=true ends the line.",
                     props, nodes, 'step', previews=[{'name': 'Running', 'size': [360, 60], 'props': {
                         'detail': 'Export posts, pages and settings.', 'index': 1, 'current': 1, 'running': True}}])


def progress_line():
    v = 'clamp(props.value, 0, 1)'
    bar = {'painter': [
        {'op': 'rrect', 'rect': [0, 0, '${size.width}', 8], 'radius': 4, 'paint': '${theme.colors.tileDeep}'},
        {'op': 'rrect', 'rect': [0, 0, '${= max(8, size.width * %s)}' % v, 8], 'radius': 4, 'when': '${= %s > 0}' % v,
         'paint': "${= {'shader': {'type': 'linear', 'begin': 'centerLeft', 'end': 'centerRight', 'stops': [{'position': 0, 'color': %s ? theme.colors.good : theme.colors.accentBright}, {'position': 1, 'color': %s ? theme.colors.good : theme.colors.accent}]}}}" % (v + ' >= 1', v + ' >= 1')},
    ]}
    nodes = {
        'wrap': col(['head', 'bar'], 9),
        'head': row(['label', 'detail'], 8, cross='end'),
        'label': text('${props.label}', 'rowTitle', FILL),
        'detail': text('${props.detail}', 'meta'),
        'bar': node('box', {'width': FILL, 'height': 8}, customPaint=bar),
    }
    props = [
        P('label', STRING, '3 of 6 steps', 'What is counted, at the left.', True),
        P('detail', STRING, '', 'A quiet note at the right (the time elapsed, how many are left).'),
        P('value', NUM, 0, 'The share done, 0 to 1 (green at 1).', True),
    ]
    return component('ProgressLine', "A progress bar with its words: the label at the left (\"3 of 6 steps\"), a detail at the right (\"12 s elapsed\"), and value={done/total} from 0 to 1 (it turns green when full).",
                     props, nodes, 'wrap', previews=[{'name': 'Half', 'size': [360, 40], 'props': {'detail': '12 s elapsed', 'value': 0.5}}])


# --- Weather ----------------------------------------------------------------------------------------------

def _sky(kind_expr):
    def pick(sun, cloud, rain, night):
        return ("%s == 'night' ? theme.colors.%s : %s == 'rain' || %s == 'storm' ? theme.colors.%s : %s == 'cloud' ? theme.colors.%s : "
                "theme.colors.%s") % (kind_expr, night, kind_expr, kind_expr, rain, kind_expr, cloud, sun)
    return ("${= {'shader': {'type': 'linear', 'begin': 'topLeft', 'end': 'bottomRight', 'stops': [{'position': 0, 'color': %s}, "
            "{'position': 1, 'color': %s}]}}}") % (pick('skySunA', 'skyCloudA', 'skyRainA', 'skyNightA'), pick('skySunB', 'skyCloudB', 'skyRainB', 'skyNightB'))


def weather_now():
    sky = {'painter': [
        {'op': 'rrect', 'rect': [0, 0, '${size.width}', '${size.height}'], 'radius': '${theme.radii.panel}', 'paint': _sky('props.kind')},
        {'op': 'group', 'clipRRect': {'rect': [0, 0, '${size.width}', '${size.height}'], 'radius': 18}, 'ops': [
            {'op': 'circle', 'c': ['${= size.width - 60}', 54], 'radius': 96, 'paint': '#14FFFFFF'},
            {'op': 'circle', 'c': ['${= size.width - 60}', 54], 'radius': 66, 'paint': '#14FFFFFF'},
        ]},
    ]}
    chip = lambda nid, label, key: {
        nid: row([nid + 'L', nid + 'V'], 4, width=HUG, pad=[8, 4, 9, 4], decoration={'fills': [{'color': 'heroChip'}], 'radius': 999}),
        nid + 'L': text(label, {'from': 'chip', 'fontSize': 11}, color='onHeroSoft'),
        nid + 'V': text('${props.%s}°' % key, {'from': 'chip', 'fontSize': 12}, color='onHero')}
    nodes = {
        'now': row(['left', 'glyph'], 8, cross='center', pad=[18, 16, 14, 16], customPaint=sky,
                   bind={'decoration.effects': '${theme.shadows.tile}'}, decoration={'radius': 18}),
        'left': col(['place', 'temp', 'cond', 'range'], 0, cross='start'),
        'place': row(['placeIcon', 'placeText'], 4),
        'placeIcon': icon('near_me_rounded', 14, 'onHeroSoft'),
        'placeText': text('${props.title}', {'from': 'rowTitle', 'fontSize': 13.5}, FILL, color='onHero'),
        'temp': text('${props.temp}°', 'numberHero', color='onHero', layout={'padding': [0, 6, 0, 0]}),
        'cond': text('${props.detail}', {'from': 'blockTitle', 'fontWeight': 500}, FILL, color='onHero', layout={'padding': [0, 2, 0, 10]}),
        'range': row(['hi', 'lo'], 6),
        **chip('hi', 'High', 'high'), **chip('lo', 'Low', 'low'),
        'glyph': node('WeatherGlyph', {'width': 112, 'height': 112}, {'kind': 'sun'}, bind={'props.kind': '${props.kind}'}),
    }
    props = [
        P('title', STRING, 'Lisbon', 'The place.', True),
        P('detail', STRING, 'Mostly sunny', 'The conditions, in words.'),
        P('temp', STRING, '22', 'The temperature now, the number only.', True),
        P('high', STRING, '24', "Today's high, the number only."),
        P('low', STRING, '15', "Today's low, the number only."),
        P('kind', enum(*art.WEATHER), 'sun', 'The conditions, for the drawn glyph and the sky: %s.' % ', '.join(art.WEATHER)),
    ]
    return component('WeatherNow', "The weather now as the card's hero on a sky that follows the conditions: the place (title), the conditions in words (detail), temp, high and low (numbers only) and kind (%s) for the drawn glyph." % ', '.join(art.WEATHER),
                     props, nodes, 'now', previews=[{'name': 'Sunny', 'size': [360, 170], 'props': {}}])


def weather_hours():
    n = 'max(1, length(props.hours))'
    nodes = {
        'strip': col(['cells'], pad=[6, 10, 6, 10], decoration={'fills': [{'color': 'tile'}], 'radius': 16},
                     bind={'decoration.radius': '${theme.radii.panel}'}),
        'cells': grid(['cell'], E(n), 0, '${props.hours}'),
        'cell': col(['hour', 'glyph', 'temp'], 4, cross='center'),
        'hour': text('${item}', {'from': 'meta', 'fontSize': 11.5}, maxLines=1),
        'glyph': node('WeatherGlyph', {'width': 34, 'height': 34}, {'kind': 'sun'},
                      bind={'props.kind': "${= length(props.kinds) > index ? at(props.kinds, index) : 'sun'}"}),
        'temp': text("${= length(props.temps) > index ? at(props.temps, index) + '°' : ''}", 'numberSmall', maxLines=1),
    }
    props = [
        P('hours', STRINGS, ['1 PM', '2 PM', '3 PM', '4 PM', '5 PM'], 'The hour labels.', True),
        P('temps', NUMBERS, [23, 24, 24, 23, 21], 'The temperature at each hour.', True),
        P('kinds', STRINGS, ['sun', 'sun', 'partly', 'cloud', 'rain'], 'The conditions at each hour: %s.' % ', '.join(art.WEATHER)),
    ]
    return component('WeatherHours', "The next hours as a strip of small forecasts: hours (labels), temps (numbers) and kinds (%s), three lists of the same length." % ', '.join(art.WEATHER),
                     props, nodes, 'strip', previews=[{'name': 'Five', 'size': [360, 100], 'props': {}}])


def weather_day():
    span = 'max(1, props.max - props.min)'
    a, b = '((props.low - props.min) / %s)' % span, '((props.high - props.min) / %s)' % span
    bar = {'painter': [
        {'op': 'rrect', 'rect': [0, '${= size.height / 2 - 3}', '${size.width}', 6], 'radius': 3, 'paint': '${theme.colors.tileDeep}'},
        {'op': 'rrect', 'rect': ['${= size.width * %s}' % a, '${= size.height / 2 - 3}', '${= max(8, size.width * (%s - %s))}' % (b, a), 6], 'radius': 3,
         'paint': "${= {'shader': {'type': 'linear', 'begin': 'centerLeft', 'end': 'centerRight', 'stops': [{'position': 0, 'color': theme.colors.skyMid}, {'position': 1, 'color': theme.colors.sunDeep}]}}}"},
    ]}
    nodes = {
        'day': row(['name', 'glyph', 'low', 'bar', 'high'], 10, height=30),
        'name': text('${props.label}', 'rowTitle', layout={'width': 44}, maxLines=1),
        'glyph': node('WeatherGlyph', {'width': 28, 'height': 28}, {'kind': 'sun'}, bind={'props.kind': '${props.kind}'}),
        'low': text('${props.low}°', 'figure', color='inkFaint', textAlign='right', layout={'width': 30}),
        'bar': node('box', {'width': FILL, 'height': 18}, customPaint=bar),
        'high': text('${props.high}°', {'from': 'figure', 'fontWeight': 600}, textAlign='right', layout={'width': 30}),
    }
    props = [
        P('label', STRING, 'Tue', 'The day.', True),
        P('low', NUM, 14, "The day's low.", True),
        P('high', NUM, 20, "The day's high.", True),
        P('kind', enum(*art.WEATHER), 'sun', 'The conditions: %s.' % ', '.join(art.WEATHER)),
        P('min', NUM, 10, 'The lowest low of all the days shown (where every bar starts from).'),
        P('max', NUM, 28, 'The highest high of all the days shown.'),
    ]
    return component('WeatherDay', "One day of a forecast with a temperature range bar: the day (label), kind (%s), low and high; min and max are the lowest low and highest high of all the days shown, so the bars line up." % ', '.join(art.WEATHER),
                     props, nodes, 'day', previews=[{'name': 'Tue', 'size': [360, 40], 'props': {'kind': 'rain', 'min': 13, 'max': 25}}])


def all_components():
    return [chat_card(), section_label(), paragraph(), action_button(), total_bar(), details(), callout(), disclosure(), receipt(), recommendation(),
            steps(), segments(), tabs(), tab_toggle(), segmented_control(), chip_tabs(), browser_tabs(), input_field(), option_list(), choice_chips(), day_picker(), counter(), rating(),
            flight_option(), product_tile(), carousel(), page_dots(), pager(), wide_scroll(), cart_line(),
            diff_hunk(), comparison_table(), stat_tile(), chart_card(), table_header(), table_row(),
            photo_gallery(), day_header(), itinerary_stop(), checklist(), map_panel(), place_row(),
            plan_step(), progress_line(), weather_now(), weather_hours(), weather_day(), media(), weather_glyph()]

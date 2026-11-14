"""Skip's blocks: the sections of a designed screen, each a component a page calls with one line.

Every block reads its colors, radii, shadows and type from the theme by name, so a token set restyles it.
A block's root fills the width and hugs its height (or has a fixed height where two sit side by side); it
carries its own entrance animation (a fade and a rise, staggered by the block's usual place on a screen).
"""
import art
from art import T, fill, stroke, grad

# --- small helpers -------------------------------------------------------------------------------------

HUG = {'hug': 0}
FILL = {'fill': 0}

STRING = {'kind': 'string', 'flutter': 'String'}
INT = {'kind': 'integer', 'flutter': 'int'}
NUM = {'kind': 'number', 'flutter': 'double'}
BOOL = {'kind': 'boolean', 'flutter': 'bool'}
STRINGS = {'kind': 'list', 'flutter': 'List<String>', 'item': STRING}
NUMBERS = {'kind': 'list', 'flutter': 'List<double>', 'item': NUM}


def enum(*values):
    return {'kind': 'enumeration', 'flutter': 'String', 'values': list(values)}


def P(key, kind, default, doc, required=False):
    p = {'key': key, 'type': kind, 'default': default, 'doc': doc}
    if required:
        p['required'] = True
    return p


AUDIENCE = P('audience', enum('adult', 'kid'), 'adult', 'Who the drawing is for: adult (lean, calm) or kid (rounder, playful, with confetti).')


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


def text(value, style, width=HUG, color=None, bind=None, layout=None, **props):
    if color:
        style = {'from': style, 'color': color} if isinstance(style, str) else {**style, 'color': color}
    lay = {'width': width, 'height': HUG}
    lay.update(layout or {})
    return node('text', lay, {'text': value, 'style': style, **props}, bind=bind)


def icon(name, size, color, bind=None):
    return node('icon', {'width': size, 'height': size}, {'icon': name, 'size': size, 'color': color}, bind=bind)


def enter(order, rise=22):
    """The entrance every block plays when it appears: a fade and a rise, later for blocks lower on a screen."""
    return [{'id': 'enter', 'duration': 520, 'delay': 70 * order, 'curve': 'easeOutCubic',
             'tracks': [{'path': 'opacity', 'from': 0, 'to': 1}, {'path': 'motion.translateY', 'from': rise, 'to': 0}]}]


def tap(event='onPressed', value=None):
    a = {'type': 'componentEvent', 'event': event}
    if value is not None:
        a['value'] = value
    return [{'trigger': {'type': 'click'}, 'actions': [a]}]


def card_deco(color='card', radius='card', shadow='card'):
    """A surface: (decoration, bind). Radius and shadow come from the theme's scales."""
    bind = {'decoration.radius': '${theme.radii.%s}' % radius}
    if shadow:
        bind['decoration.effects'] = '${theme.shadows.%s}' % shadow
    return {'fills': [{'color': color}], 'radius': 24}, bind


def shown(expr):
    """A figure as text: a plain number gets thousands separators, anything else is shown as written."""
    return "${= matches(text(%s), '^[0-9.]+$') ? thousands(number(%s)) : text(%s)}" % (expr, expr, expr)


GRAIN = {'type': 'noise', 'noise': {'baseFrequency': 0.9, 'numOctaves': 2, 'seed': 7}, 'color': '#FFFFFFFF', 'opacity': 0.08,
         'blendMode': 'overlay'}


def component(type_, doc, props, nodes, root, events=None, children=False, previews=None):
    widget = {'type': type_, 'doc': doc, 'props': props}
    if events:
        widget['events'] = [{'key': k, 'doc': d} for k, d in events]
    if children:
        widget['children'] = 'list'
    return {'schema': 3, 'id': type_, 'roots': [root], 'widget': widget, 'previews': previews or [], 'nodes': nodes}


# --- Screen ---------------------------------------------------------------------------------------------

def screen():
    nodes = {
        'screen': node('column', {'width': FILL, 'height': FILL, 'padding': [20, 28, 20, 36]},
                       {'scrollable': True, 'spacing': 18, 'crossAxisAlignment': 'stretch'}, ['content'],
                       decoration={'fills': [{'color': 'page'}]}),
        'content': {'type': 'slot'},
    }
    return component('Screen', "The page: put it at the root and write the blocks under it (a scrolling column on the page color, with the screen margins and the gap between blocks).", [], nodes, 'screen', children=True,
                     previews=[{'name': 'Empty page', 'size': [390, 200], 'props': {}}])


# --- Illustration ---------------------------------------------------------------------------------------

def illustration():
    nodes = {'art': node('stack', {'width': 160, 'height': 160}, children=[])}
    for role, by_audience in art.ART.items():
        for audience in by_audience:
            nid = f'{role}_{audience}'
            nodes[nid] = node('box', {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}},
                              bind={'visible': "${= props.role == '%s' && props.audience == '%s'}" % (role, audience)},
                              customPaint=art.paint(role, audience))
            nodes['art']['children'].append(nid)
    props = [
        P('role', enum('hero', 'streak', 'empty', 'record'), 'hero',
          'What the drawing is for: hero (a person mid-jump under the rope), streak (a flame), empty (a rope at rest), record (a medal).'),
        AUDIENCE,
    ]
    return component('Illustration', "A drawn illustration, colored by the theme: role is hero (a person mid-jump under the rope), streak (a flame), empty (a rope at rest) or record (a medal); audience is adult or kid; size it with w and h.",
                     props, nodes, 'art',
                     previews=[{'name': f'{r} {a}', 'size': [200, 200], 'props': {'role': r, 'audience': a}}
                               for r in ('hero', 'streak', 'empty') for a in ('adult', 'kid')])


# --- TopBar ---------------------------------------------------------------------------------------------

def top_bar():
    mark = {'viewBox': [28, 28], 'painter': [
        {'op': 'rrect', 'rect': [0, 0, 28, 28], 'radius': 9, 'paint': grad([(0, 'brandBright'), (1, 'brand')], 'topLeft', 'bottomRight')},
        art.path('M7 17 C 7 5, 21 5, 21 17', stroke('accent', 2.6)),
        art.circle(14, 18.5, 2.6, fill('onBrand')),
    ]}
    deco, bind = card_deco('card', 'chip', 'card')
    nodes = {
        'bar': node('column', {'width': FILL, 'height': HUG, 'padding': [0, 4, 0, 2]}, {'crossAxisAlignment': 'stretch', 'spacing': 16},
                    ['topRow', 'titles'], animations=enter(0, 14)),
        'topRow': node('row', {'width': FILL, 'height': HUG}, {'spacing': 12}, ['back', 'brandRow', 'topGap', 'badge'],
                       bind={'visible': "${= props.back || props.eyebrow != '' || props.badge != ''}"}),
        'back': node('row', {'width': 44, 'height': 44}, {'mainAxisAlignment': 'center'}, ['backIcon'],
                     decoration={**deco, 'radius': 22}, bind={'decoration.radius': '${= min(22, theme.radii.cta)}',
                                                              'decoration.effects': '${theme.shadows.card}', 'visible': '${props.back}'},
                     states={'pressed': {'back': {'opacity': 0.8}}}, actions=tap()),
        'backIcon': icon('arrow_back_rounded', 22, 'ink'),
        'brandRow': node('row', {'width': HUG, 'height': HUG}, {'spacing': 9}, ['mark', 'eyebrow'],
                         bind={'visible': "${= props.eyebrow != ''}"}),
        'mark': node('box', {'width': 30, 'height': 30}, customPaint=mark),
        'eyebrow': text('${= upper(props.eyebrow)}', {'from': 'eyebrow', 'fontSize': 12.5, 'letterSpacing': 1.8}, color='ink'),
        'topGap': node('spacer', {'width': FILL, 'height': 1}),
        'titles': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'start', 'spacing': 6}, ['title', 'subtitle']),
        'title': text('${props.title}', 'screenTitle', FILL),
        'subtitle': text('${props.subtitle}', 'lead', FILL, bind={'visible': "${= props.subtitle != ''}"}),
        'badge': node('row', {'width': HUG, 'height': HUG, 'padding': [10, 7, 13, 7]}, {'spacing': 5}, ['badgeIcon', 'badgeText'],
                      decoration={'fills': [{'color': 'flameTint'}], 'radius': 999},
                      bind={'decoration.radius': '${theme.radii.chip}', 'visible': "${= props.badge != ''}"}),
        'badgeIcon': icon('local_fire_department', 17, 'flame', bind={'props.icon': '${props.badgeIcon}'}),
        'badgeText': text('${props.badge}', 'chip'),
    }
    props = [
        P('title', STRING, 'Ready to jump?', 'The screen title, large.', True),
        P('subtitle', STRING, '', 'One friendly line under the title (empty: none).'),
        P('eyebrow', STRING, '', 'A small caps line over the title with the brand mark, e.g. the app name (empty: none).'),
        P('back', BOOL, False, 'Shows a round back button before the title; a tap fires onPressed.'),
        P('badge', STRING, '', 'A small pill at the right, e.g. the streak count (empty: none).'),
        P('badgeIcon', STRING, 'local_fire_department', 'The icon in the badge.'),
    ]
    return component('TopBar', "The top of a screen: a large title, an optional subtitle, eyebrow (a brand line with the mark), back:true (a round back button that fires onPressed) and badge (a small pill at the right).",
                     props, nodes, 'bar', events=[('onPressed', 'The back button was tapped.')],
                     previews=[{'name': 'Home', 'size': [350, 150], 'props': {'title': 'Ready to jump?', 'eyebrow': 'Skip',
                                                                               'subtitle': 'Today takes just 8 minutes.'}},
                               {'name': 'Inner page', 'size': [350, 130], 'props': {'title': 'Your progress', 'back': True}}])


# --- HeroSession ----------------------------------------------------------------------------------------

def hero_session():
    rings = {'painter': [
        {'op': 'circle', 'c': ['${= size.width - 78}', 118], 'radius': 158, 'paint': stroke('heroLine', 1.2)},
        {'op': 'circle', 'c': ['${= size.width - 78}', 118], 'radius': 206, 'paint': stroke('heroLine', 1.2)},
        {'op': 'circle', 'c': ['${= size.width - 78}', 118], 'radius': 258, 'paint': stroke('heroLine', 1.2)},
    ]}
    nodes = {
        'hero': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'stretch'}, ['stage', 'body'],
                     decoration={'fills': [{'type': 'linear', 'begin': 'topLeft', 'end': 'bottomRight',
                                            'stops': [{'position': 0, 'color': 'heroA'}, {'position': 1, 'color': 'heroB'}]}, GRAIN],
                                 'radius': 32, 'clip': 'antiAlias'},
                     bind={'decoration.radius': '${theme.radii.hero}', 'decoration.effects': '${theme.shadows.hero}'},
                     animations=enter(1)),
        'stage': node('stack', {'width': FILL, 'height': 244}, children=['glow', 'rings', 'figure', 'chipA', 'titleBox']),
        'glow': node('box', {'width': 260, 'height': 260, 'x': {'end': -40}, 'y': {'start': -60}},
                     decoration={'fills': [{'color': 'heroGlow'}], 'shape': 'circle',
                                 'effects': [{'type': 'layerBlur', 'blurRadius': 46}]}, opacity=0.55),
        'rings': node('box', {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}, customPaint=rings),
        'figure': node('Illustration', {'width': 236, 'height': 236, 'x': {'end': -40}, 'y': {'start': 0}},
                       {'role': 'hero'}, bind={'props.audience': '${props.audience}'},
                       animations=[{'id': 'bob', 'duration': 640, 'curve': 'easeInOutSine', 'repeat': {'reverse': True},
                                    'tracks': [{'path': 'motion.translateY', 'from': 3, 'to': -5}]}]),
        'chipA': node('row', {'width': HUG, 'height': HUG, 'padding': [11, 7, 11, 7], 'x': {'start': 20}, 'y': {'start': 20}}, None, ['chipAText'],
                      decoration={'fills': [{'color': 'heroChip'}], 'radius': 999},
                      bind={'decoration.radius': '${theme.radii.chip}', 'visible': "${= props.eyebrow != ''}"}),
        'chipAText': text('${= upper(props.eyebrow)}', {'from': 'eyebrow', 'letterSpacing': 1.1}, color='onHero'),
        'chipB': node('row', {'width': HUG, 'height': HUG, 'padding': [9, 6, 12, 6]}, {'spacing': 5}, ['chipBIcon', 'chipBText'],
                      decoration={'fills': [{'color': 'accent'}], 'radius': 999},
                      bind={'decoration.radius': '${theme.radii.chip}', 'visible': "${= props.minutes != ''}"}),
        'chipBIcon': icon('timer_outlined', 15, 'onAccent'),
        'chipBText': text('${props.minutes} min', 'chip', color='onAccent'),
        'titleBox': node('column', {'width': FILL, 'height': HUG, 'x': {'start': 22, 'end': 126}, 'y': {'end': 2}},
                         {'crossAxisAlignment': 'start', 'spacing': 12}, ['chipB', 'title']),
        'title': text('${props.title}', 'display', FILL, color='onHero', maxLines=2, overflow='ellipsis'),
        'body': node('column', {'width': FILL, 'height': HUG, 'padding': [22, 8, 22, 22]}, {'crossAxisAlignment': 'stretch', 'spacing': 18},
                     ['detail', 'cta']),
        'detail': text('${props.detail}', 'lead', FILL, color='onHeroSoft', bind={'visible': "${= props.detail != ''}"}),
        'cta': node('row', {'width': FILL, 'height': 60, 'padding': [9, 0, 20, 0]}, {'spacing': 14}, ['ctaMark', 'ctaLabel', 'ctaArrow'],
                    decoration={'fills': [{'color': 'heroCta'}], 'radius': 999},
                    bind={'decoration.radius': '${theme.radii.cta}', 'decoration.effects': '${theme.shadows.cta}'},
                    states={'pressed': {'cta': {'opacity': 0.88}}}, actions=tap()),
        'ctaMark': node('row', {'width': 42, 'height': 42}, {'mainAxisAlignment': 'center'}, ['ctaPlay'],
                        decoration={'fills': [{'color': 'heroCtaMark'}], 'radius': 21},
                        bind={'decoration.radius': '${= min(21, theme.radii.cta - 3)}'}),
        'ctaPlay': icon('play_arrow_rounded', 26, 'onHeroCtaMark'),
        'ctaLabel': text('${props.cta}', 'cta', FILL, color='onHeroCta'),
        'ctaArrow': icon('arrow_forward_rounded', 22, 'onHeroCta'),
    }
    props = [
        P('title', STRING, 'Intervals', "The session's name, in display type.", True),
        P('detail', STRING, '', 'One or two plain sentences on what the session is (empty: none).'),
        P('eyebrow', STRING, 'Today', 'A small chip over the art, e.g. Today.'),
        P('minutes', STRING, '', 'How long it takes, shown as an accent chip "N min" (empty: none).'),
        P('cta', STRING, 'Start session', "The button's label."),
        AUDIENCE,
    ]
    return component('HeroSession', "The screen's one focal point: today's session on the brand gradient with the jumper illustration, minutes as a chip, the detail sentence and one big cta button that fires onPressed; audience:\"kid\" draws the child.", props, nodes, 'hero',
                     events=[('onPressed', 'The start button was tapped.')],
                     previews=[{'name': 'Intervals', 'size': [350, 400], 'props': {
                         'title': 'Intervals', 'minutes': '8', 'detail': '8 easy rounds: jump for 40 seconds, rest for 20.'}}])


# --- StreakFlame and ProgressGoal: the twin tiles ---------------------------------------------------------

TILE_H = 176


def tile_root(children, order):
    deco, bind = card_deco('card', 'tile', 'card')
    return node('column', {'width': FILL, 'height': TILE_H, 'padding': [16, 16, 16, 14]},
                {'crossAxisAlignment': 'start', 'mainAxisAlignment': 'spaceBetween'}, children, decoration=deco, bind=bind,
                animations=enter(order))


def streak_flame():
    nodes = {
        'tile': tile_root(['top', 'texts'], 2),
        'top': node('row', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'end', 'spacing': 10}, ['flame', 'count']),
        'flame': node('Illustration', {'width': 52, 'height': 64}, {'role': 'streak'}, bind={'props.audience': '${props.audience}'}),
        'count': text('${props.count}', 'numberLarge', layout={'padding': [0, 0, 0, 0]}),
        'texts': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'start', 'spacing': 3}, ['label', 'note']),
        'label': text('${props.label}', 'cardTitle', FILL, maxLines=1, overflow='ellipsis'),
        'note': text('${props.note}', 'meta', FILL, maxLines=2, overflow='ellipsis', bind={'visible': "${= props.note != ''}"}),
    }
    props = [
        P('count', INT, 4, 'The streak: how many in a row.', True),
        P('label', STRING, 'day streak', 'What is counted, after the number: "day streak", "sessions in a row".'),
        P('note', STRING, '', 'A short nudge under it (empty: none).'),
        AUDIENCE,
    ]
    return component('StreakFlame', "The streak as a tile: a drawn flame, count in display type, then the label (what is counted) and a note; put it in a Row with ProgressGoal.", props, nodes, 'tile',
                     previews=[{'name': 'Four', 'size': [169, TILE_H], 'props': {'count': 4, 'label': 'sessions in a row',
                                                                                'note': 'Jump today to make it 5.'}}])


def progress_goal():
    # A ring cut into one segment per unit of the goal; the done ones take the brand color.
    seg = '(2 * pi() / max(1, props.goal))'
    gap = '(props.goal > 1 ? 0.34 : 0)'
    ring = {'viewBox': [64, 64], 'painter': [
        {'op': 'repeat', 'count': '${= max(1, props.goal)}', 'ops': [
            {'op': 'arc', 'rect': [6, 6, 52, 52],
             'startAngle': '${= -pi() / 2 + index * %s + %s / 2}' % (seg, gap),
             'sweepAngle': '${= %s - %s}' % (seg, gap),
             'paint': {'color': '${= index < props.done ? theme.colors.brand : theme.colors.track}', 'style': 'stroke',
                       'strokeWidth': 8, 'strokeCap': 'round'}},
        ]},
    ]}
    nodes = {
        'tile': tile_root(['top', 'texts'], 3),
        'top': node('row', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'end', 'spacing': 10}, ['ring', 'done', 'of']),
        'ring': node('row', {'width': 64, 'height': 64}, {'mainAxisAlignment': 'center'}, ['ringIcon'], customPaint=ring),
        'ringIcon': icon('bolt_rounded', 24, 'brand', bind={'props.icon': '${props.icon}'}),
        'done': text('${props.done}', 'numberLarge'),
        'of': text('/${props.goal}', 'numberSmall', color='inkFaint', layout={'padding': [0, 0, 0, 7]}),
        'texts': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'start', 'spacing': 3}, ['title', 'note']),
        'title': text('${props.title}', 'cardTitle', FILL, maxLines=1, overflow='ellipsis'),
        'note': text('${props.note}', 'meta', FILL, maxLines=2, overflow='ellipsis', bind={'visible': "${= props.note != ''}"}),
    }
    props = [
        P('title', STRING, 'This week', 'What the goal is, e.g. This week.', True),
        P('note', STRING, '', 'A short line under it, e.g. how many are left (empty: none).'),
        P('done', INT, 3, 'How many are done.', True),
        P('goal', INT, 5, 'The goal: the ring has one segment per unit.', True),
        P('icon', STRING, 'bolt_rounded', 'The icon inside the ring.'),
    ]
    return component('ProgressGoal', "Progress toward a small goal as a tile: a ring with one segment per unit of goal, done/goal in display type, a title and a note; put it in a Row with StreakFlame.", props, nodes, 'tile',
                     previews=[{'name': 'Three of five', 'size': [169, TILE_H], 'props': {
                         'title': 'This week', 'done': 3, 'goal': 5, 'note': '2 more to reach your goal.'}}])


# --- WeekStrip ------------------------------------------------------------------------------------------

DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']


def week_strip():
    deco, bind = card_deco('card', 'tile', 'card')
    nodes = {'strip': node('row', {'width': FILL, 'height': HUG, 'padding': [16, 14, 16, 16]},
                           {'mainAxisAlignment': 'spaceBetween'}, [f'd{d}' for d in DAYS], decoration=deco, bind=bind,
                           animations=enter(4))}
    for d in DAYS:
        done = "any(props.done, x => startsWith(lower(x), '%s'))" % d.lower()
        today = "startsWith(lower(props.today), '%s')" % d.lower()
        nodes[f'd{d}'] = node('column', {'width': 36, 'height': HUG}, {'spacing': 8}, [f'l{d}', f's{d}'])
        nodes[f'l{d}'] = text(d[0], {'from': 'eyebrow', 'letterSpacing': 0.4},
                              bind={'props.style.color': '${= %s ? theme.colors.brand : theme.colors.inkFaint}' % today})
        nodes[f's{d}'] = node('stack', {'width': 36, 'height': 36}, children=[f'o{d}', f'n{d}', f'c{d}'])
        whole = {'width': 36, 'height': 36, 'x': 0, 'y': 0}
        nodes[f'o{d}'] = node('box', whole, decoration={'fills': [{'color': 'track'}], 'radius': 18},
                              bind={'decoration.radius': '${= min(18, theme.radii.tile)}'})
        nodes[f'n{d}'] = node('row', whole, {'mainAxisAlignment': 'center'}, [f'nd{d}'],
                              decoration={'fills': [{'color': 'card'}], 'strokes': [{'color': 'brand'}], 'strokeWidth': 2.5, 'radius': 18},
                              bind={'decoration.radius': '${= min(18, theme.radii.tile)}', 'visible': '${= %s && !%s}' % (today, done)})
        nodes[f'nd{d}'] = node('box', {'width': 8, 'height': 8}, decoration={'fills': [{'color': 'brand'}], 'radius': 4})
        nodes[f'c{d}'] = node('row', whole, {'mainAxisAlignment': 'center'}, [f'ci{d}'],
                              decoration={'fills': [{'type': 'linear', 'begin': 'topLeft', 'end': 'bottomRight',
                                                     'stops': [{'position': 0, 'color': 'brandBright'}, {'position': 1, 'color': 'brand'}]}],
                                          'radius': 18},
                              bind={'decoration.radius': '${= min(18, theme.radii.tile)}', 'visible': '${= %s}' % done})
        nodes[f'ci{d}'] = icon('check_rounded', 20, 'onBrand')
    props = [
        P('done', STRINGS, ['Mon', 'Wed'], 'The days done this week: weekday names, or dates that start with one ("Fri 13 Nov").', True),
        P('today', STRING, '', 'Today, as a weekday name: it gets a ring until it is done (empty: none).'),
    ]
    return component('WeekStrip', "The week as seven day marks, Monday to Sunday: done lists the days done (weekday names, or dates that start with one such as \"Fri 13 Nov\") and today (a weekday name) gets a ring.", props, nodes, 'strip',
                     previews=[{'name': 'Mid-week', 'size': [350, 96], 'props': {'done': ['Mon', 'Wed', 'Fri'], 'today': 'Sat'}}])


# --- SectionTitle ---------------------------------------------------------------------------------------

def section_title():
    nodes = {
        'head': node('row', {'width': FILL, 'height': HUG, 'padding': [2, 8, 0, 0]}, {'mainAxisAlignment': 'spaceBetween'},
                     ['title', 'action'], animations=enter(5)),
        'title': text('${props.title}', 'blockTitle', FILL),
        'action': node('row', {'width': HUG, 'height': HUG, 'padding': [12, 7, 8, 7]}, {'spacing': 2}, ['actionText', 'actionIcon'],
                       decoration={'fills': [{'color': 'brandTint'}], 'radius': 999},
                       bind={'decoration.radius': '${theme.radii.chip}', 'visible': "${= props.action != ''}"}, actions=tap()),
        'actionText': text('${props.action}', 'chip', color='brand'),
        'actionIcon': icon('chevron_right_rounded', 18, 'brand'),
    }
    props = [
        P('title', STRING, 'Last session', 'The section heading.', True),
        P('action', STRING, '', 'A small link pill at the right, e.g. See all (empty: none); a tap fires onPressed.'),
    ]
    return component('SectionTitle', "A heading over a section, with action as an optional link pill at the right that fires onPressed.", props, nodes, 'head',
                     events=[('onPressed', 'The link was tapped.')],
                     previews=[{'name': 'With a link', 'size': [350, 44], 'props': {'title': 'Last session', 'action': 'See all'}}])


# --- SessionRow -----------------------------------------------------------------------------------------

def session_row():
    deco, bind = card_deco('card', 'tile', 'card')
    gauge = {'viewBox': [48, 48], 'painter': [
        {'op': 'circle', 'c': [24, 24], 'radius': 19, 'paint': stroke('track', 4.5)},
        {'op': 'arc', 'rect': [5, 5, 38, 38], 'startAngle': -1.5708,
         'sweepAngle': '${= clamp(props.share, 0, 1) * 2 * pi()}', 'when': '${= props.share > 0}',
         'paint': stroke('brand', 4.5)},
    ]}
    nodes = {
        'row': node('row', {'width': FILL, 'height': HUG, 'padding': [14, 14, 12, 14]}, {'spacing': 14},
                    ['lead', 'texts', 'figures', 'chev'], decoration=deco, bind=bind, animations=enter(6),
                    states={'pressed': {'row': {'opacity': 0.85}}}, actions=tap()),
        'lead': node('row', {'width': 48, 'height': 48}, {'mainAxisAlignment': 'center'}, ['leadIcon'], customPaint=gauge),
        'leadIcon': icon('bolt_rounded', 20, 'brand', bind={'props.icon': "${= props.icon != '' ? props.icon : contains(lower(props.title), 'interval') ? 'timer_outlined' : contains(lower(props.title), 'endur') ? 'favorite_rounded' : contains(lower(props.title), 'foot') ? 'directions_run_rounded' : 'bolt_rounded'}"}),
        'texts': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'start', 'spacing': 3}, ['title', 'detail']),
        'title': text('${props.title}', 'cardTitle', FILL, maxLines=1, overflow='ellipsis'),
        'detail': text('${props.detail}', 'meta', FILL, maxLines=1, overflow='ellipsis'),
        'figures': node('column', {'width': HUG, 'height': HUG}, {'crossAxisAlignment': 'end', 'spacing': 2}, ['value', 'unit'],
                        bind={'visible': "${= props.value != ''}"}),
        'value': text(shown('props.value'), 'numberSmall'),
        'unit': text('${props.unit}', 'meta'),
        'chev': icon('chevron_right_rounded', 22, 'inkFaint'),
    }
    props = [
        P('title', STRING, 'Intervals', "The session's name.", True),
        P('detail', STRING, '', 'A quiet second line: the date and the duration.'),
        P('value', STRING, '', 'The headline figure at the right, e.g. the jumps (empty: none).'),
        P('unit', STRING, '', 'What the figure counts, under it.'),
        P('share', NUM, 0, 'From 0 to 1: how this session compares with the best one, drawn as a small ring (0: no ring).'),
        P('icon', STRING, '', 'The icon inside the ring (empty: picked from the name: a timer for intervals, a heart for endurance, a runner for footwork, else a bolt).'),
    ]
    return component('SessionRow', "One past session as a card row: the name, a detail line (date and duration), value and unit at the right, and share (0 to 1, against the best session) as a small ring; a tap fires onPressed.", props, nodes, 'row',
                     events=[('onPressed', 'The row was tapped.')],
                     previews=[{'name': 'A session', 'size': [350, 80], 'props': {
                         'title': 'Intervals', 'detail': 'Fri 13 Nov · 8 min', 'value': '912', 'unit': 'jumps', 'share': 0.7}}])


# --- ChartCard ------------------------------------------------------------------------------------------

def chart_card():
    n = 'max(1, length(props.values))'
    top = 'max(1, max(props.values))'
    gap = 12
    plot_h = 148
    bw = f'((size.width - {gap} * ({n} - 1)) / {n})'
    x = f'(index * ({bw} + {gap}))'
    h = f'max(26, item / {top} * {plot_h})'
    hot = f'(index == {n} - 1)'
    r = f'min(theme.radii.tile, {bw} / 2)'
    chart = {'painter': [
        {'op': 'repeat', 'each': '${props.values}', 'ops': [
            {'op': 'rrect', 'rect': ['${= %s}' % x, 0, '${= %s}' % bw, plot_h], 'radius': '${= %s}' % r, 'paint': fill('panelTrack')},
            {'op': 'rrect', 'rect': ['${= %s}' % x, '${= %d - %s}' % (plot_h, h), '${= %s}' % bw, '${= %s}' % h],
             'radius': '${= %s}' % r, 'when': '${= !%s}' % hot, 'paint': fill('panelBar')},
            {'op': 'rrect', 'rect': ['${= %s}' % x, '${= %d - %s}' % (plot_h, h), '${= %s}' % bw, '${= %s}' % h],
             'radius': '${= %s}' % r, 'when': '${= %s}' % hot, 'paint': grad([(0, 'accent'), (1, 'accentDeep')])},
            {'op': 'paragraph', 'text': '${= thousands(item)}', 'offset': ['${= %s + %s / 2}' % (x, bw), '${= %d - %s + 9}' % (plot_h, h)],
             'anchor': 'topCenter', 'style': {'fontSize': 12, 'fontWeight': 700},
             'paint': '${= %s ? theme.colors.onAccent : theme.colors.onPanelSoft}' % hot},
            {'op': 'paragraph', 'text': '${= at(props.labels, index)}', 'when': '${= index < length(props.labels)}',
             'offset': ['${= %s + %s / 2}' % (x, bw), plot_h + 11],
             'anchor': 'topCenter', 'style': {'fontSize': 12, 'fontWeight': 700, 'letterSpacing': 0.6},
             'paint': '${= %s ? theme.colors.onPanel : theme.colors.onPanelSoft}' % hot},
        ]},
    ]}
    last = 'last(props.values)'
    prev = f'at(props.values, max(0, {n} - 2))'
    nodes = {
        'card': node('stack', {'width': FILL, 'height': 356}, children=['glow', 'content'],
                     decoration={'fills': [{'color': 'panel'}], 'radius': 28, 'clip': 'antiAlias'},
                     bind={'decoration.radius': '${theme.radii.hero}', 'decoration.effects': '${theme.shadows.panel}'},
                     animations=enter(1)),
        'glow': node('box', {'width': 280, 'height': 280, 'x': {'end': -90}, 'y': {'start': -130}},
                     decoration={'fills': [{'color': 'panelGlow'}], 'shape': 'circle',
                                 'effects': [{'type': 'layerBlur', 'blurRadius': 50}]}, opacity=0.9),
        'content': node('column', {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0},
                                   'padding': [22, 22, 22, 18]}, {'crossAxisAlignment': 'stretch'}, ['head', 'figure', 'gapA', 'plot']),
        'head': node('row', {'width': FILL, 'height': HUG}, {'mainAxisAlignment': 'spaceBetween'}, ['title', 'delta']),
        'title': text('${= upper(props.title)}', 'eyebrow', FILL, color='onPanelSoft'),
        'delta': node('row', {'width': HUG, 'height': HUG, 'padding': [8, 6, 11, 6]}, {'spacing': 3}, ['deltaIcon', 'deltaText'],
                      decoration={'fills': [{'color': 'accent'}], 'radius': 999},
                      bind={'decoration.radius': '${theme.radii.chip}', 'visible': '${= length(props.values) > 1}'}),
        'deltaIcon': icon('north_east_rounded', 15, 'onAccent',
                          bind={'props.icon': "${= %s >= %s ? 'north_east_rounded' : 'south_east_rounded'}" % (last, prev)}),
        'deltaText': text("${= (%s >= %s ? '+' : '-') + thousands(abs(%s - %s))} ${props.deltaLabel}" % (last, prev, last, prev),
                          'chip', color='onAccent'),
        'figure': node('row', {'width': FILL, 'height': HUG, 'padding': [0, 10, 0, 0]}, {'crossAxisAlignment': 'end', 'spacing': 8},
                       ['value', 'unit']),
        'value': text('${= thousands(%s)}' % last, 'numberLarge', color='onPanel'),
        'unit': text('${props.unit}', 'lead', color='onPanelSoft', layout={'padding': [0, 0, 0, 7]}),
        'gapA': node('spacer', {'width': 1, 'height': 22}),
        'plot': node('box', {'width': FILL, 'height': plot_h + 30}, customPaint=chart),
    }
    props = [
        P('title', STRING, 'Jumps this week', 'What the chart counts, shown small over the big figure.', True),
        P('values', NUMBERS, [2100, 2650, 2400, 3180], 'One bar per value, oldest first; the last one is the headline figure and the bright bar.', True),
        P('labels', STRINGS, ['W39', 'W40', 'W41', 'W42'], 'One label per bar.'),
        P('unit', STRING, 'jumps', 'The unit after the big figure.'),
        P('deltaLabel', STRING, 'vs last', 'What the change chip compares with: it shows last minus previous, then this.'),
    ]
    return component('ChartCard', "A progress chart as the screen's focal point, on a dark panel: one rounded bar per value (oldest first) with its label, the latest value in display type with its unit, and a chip with the change since the one before (deltaLabel says against what).",
                     props, nodes, 'card',
                     previews=[{'name': 'Four weeks', 'size': [350, 356], 'props': {}}])


# --- StatTrio -------------------------------------------------------------------------------------------

def stat_trio():
    nodes = {'trio': node('row', {'width': FILL, 'height': HUG}, {'spacing': 10, 'crossAxisAlignment': 'start'},
                          [f't{i}' for i in range(3)], animations=enter(2))}
    for i in range(3):
        deco, bind = card_deco('card', 'tile', 'card')
        v = f'at(props.values, {i})'
        nodes[f't{i}'] = node('column', {'width': FILL, 'height': HUG, 'padding': [14, 14, 12, 14]},
                              {'crossAxisAlignment': 'start', 'spacing': 4}, [f'i{i}', f'g{i}', f'v{i}', f'l{i}'], decoration=deco,
                              bind={**bind, 'visible': '${= length(props.values) > %d}' % i})
        nodes[f'i{i}'] = node('row', {'width': 32, 'height': 32}, {'mainAxisAlignment': 'center'}, [f'ic{i}'],
                              decoration={'fills': [{'color': 'brandTint'}], 'radius': 11},
                              bind={'decoration.radius': '${= min(11, theme.radii.tile)}'})
        nodes[f'ic{i}'] = icon('bolt_rounded', 18, 'brand',
                               bind={'props.icon': "${= length(props.icons) > %d ? at(props.icons, %d) : 'bolt_rounded'}" % (i, i)})
        nodes[f'g{i}'] = node('spacer', {'width': 1, 'height': 6})
        nodes[f'v{i}'] = text(shown(v), 'numberSmall', FILL,
                              maxLines=1, scaleDown=True)
        nodes[f'l{i}'] = text("${= length(props.labels) > %d ? at(props.labels, %d) : ''}" % (i, i), 'meta', FILL, maxLines=1,
                              overflow='ellipsis')
    props = [
        P('values', STRINGS, ['3736', '34', '4'], 'Three figures (numbers get thousands separators; text is shown as written).', True),
        P('labels', STRINGS, ['Total jumps', 'Minutes', 'Sessions'], 'What each figure counts.', True),
        P('icons', STRINGS, ['bolt_rounded', 'timer_outlined', 'event_available_rounded'], 'A Material icon per figure.'),
    ]
    return component('StatTrio', "Three small figures side by side as tiles: values and labels are lists of three, icons an optional list of Material icon names.",
                     props, nodes, 'trio', previews=[{'name': 'Totals', 'size': [350, 124], 'props': {}}])


# --- RecordCard -----------------------------------------------------------------------------------------

def record_card():
    nodes = {
        'card': node('row', {'width': FILL, 'height': HUG, 'padding': [16, 16, 18, 16]}, {'spacing': 16},
                     ['medal', 'texts'], decoration={'fills': [{'color': 'goldTint'}], 'radius': 24},
                     bind={'decoration.radius': '${theme.radii.card}'}, animations=enter(3),
                     states={'pressed': {'card': {'opacity': 0.85}}}, actions=tap()),
        'medal': node('Illustration', {'width': 60, 'height': 72}, {'role': 'record'}),
        'texts': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'start', 'spacing': 4}, ['title', 'figure', 'detail']),
        'title': text('${= upper(props.title)}', 'eyebrow', FILL, color='onGold'),
        'figure': node('row', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'end', 'spacing': 7}, ['value', 'unit']),
        'value': text(shown('props.value'), 'number'),
        'unit': text('${props.unit}', 'lead', FILL, color='inkSoft', layout={'padding': [0, 0, 0, 4]}, maxLines=1, overflow='ellipsis'),
        'detail': text('${props.detail}', 'meta', FILL, color='inkSoft', bind={'visible': "${= props.detail != ''}"}),
    }
    props = [
        P('title', STRING, 'Personal best', 'What the record is, small caps.', True),
        P('detail', STRING, '', 'Where it was set: the session and the date (empty: none).'),
        P('value', STRING, '210', 'The record, in display type.', True),
        P('unit', STRING, '', 'What it counts, after the number.'),
    ]
    return component('RecordCard', "A personal record as a warm highlight card: a drawn medal, the value in display type with its unit, and where it was set as the detail; a tap fires onPressed.", props, nodes, 'card',
                     events=[('onPressed', 'The card was tapped.')],
                     previews=[{'name': 'Best run', 'size': [350, 110], 'props': {
                         'title': 'Best run without a miss', 'value': '210', 'unit': 'jumps', 'detail': 'Endurance · Wed 11 Nov'}}])


# --- EmptyState -----------------------------------------------------------------------------------------

def empty_state():
    deco, bind = card_deco('card', 'card', 'card')
    nodes = {
        'empty': node('column', {'width': FILL, 'height': HUG, 'padding': [24, 22, 24, 26]}, {'spacing': 6}, ['art', 'gap', 'title', 'message', 'gapB', 'cta'],
                      decoration=deco, bind=bind, animations=enter(2)),
        'art': node('Illustration', {'width': 200, 'height': 160}, {'role': 'empty'}, bind={'props.audience': '${props.audience}'}),
        'gap': node('spacer', {'width': 1, 'height': 4}),
        'title': text('${props.title}', 'blockTitle', FILL, textAlign='center'),
        'message': text('${props.message}', 'lead', FILL, textAlign='center', bind={'visible': "${= props.message != ''}"}),
        'gapB': node('spacer', {'width': 1, 'height': 10}, bind={'visible': "${= props.cta != ''}"}),
        'cta': node('row', {'width': HUG, 'height': 50, 'padding': [24, 0, 18, 0]}, {'spacing': 8}, ['ctaLabel', 'ctaIcon'],
                    decoration={'fills': [{'color': 'brand'}], 'radius': 999},
                    bind={'decoration.radius': '${theme.radii.cta}', 'decoration.effects': '${theme.shadows.cta}',
                          'visible': "${= props.cta != ''}"},
                    states={'pressed': {'cta': {'opacity': 0.88}}}, actions=tap()),
        'ctaLabel': text('${props.cta}', 'cta', color='onBrand'),
        'ctaIcon': icon('arrow_forward_rounded', 20, 'onBrand'),
    }
    props = [
        P('title', STRING, 'No sessions yet', 'What is missing, said kindly.', True),
        P('message', STRING, '', 'One line on what to do next (empty: none).'),
        P('cta', STRING, '', "The button's label (empty: no button); a tap fires onPressed."),
        AUDIENCE,
    ]
    return component('EmptyState', "What a screen or a list shows when there is nothing yet: a drawn rope at rest, a title, a message and a cta button that fires onPressed; audience:\"kid\" draws the playful one.", props, nodes, 'empty', events=[('onPressed', 'The button was tapped.')],
                     previews=[{'name': 'No sessions', 'size': [350, 360], 'props': {
                         'title': 'No sessions yet', 'message': 'Your first one takes five minutes.', 'cta': 'Start a session'}}])


def all_components():
    return [screen(), top_bar(), hero_session(), streak_flame(), progress_goal(), week_strip(), section_title(), session_row(),
            chart_card(), stat_trio(), record_card(), empty_state(), illustration()]

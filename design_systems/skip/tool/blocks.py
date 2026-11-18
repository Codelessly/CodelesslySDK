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
        P('role', enum('hero', 'streak', 'empty', 'record', 'cheer'), 'hero',
          'What the drawing is for: hero (a person mid-jump under the rope), streak (a flame), empty (a rope at rest), record (a medal), cheer (the jumper with both arms up, for a finished session).'),
        AUDIENCE,
    ]
    return component('Illustration', "A drawn illustration, colored by the theme: role is hero (a person mid-jump under the rope), streak (a flame), empty (a rope at rest), record (a medal) or cheer (arms up, for a finished session); audience is adult or kid; size it with w and h.",
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
    return component('TopBar', "The top of a screen: a large title, an optional subtitle, eyebrow (a brand line with the mark), back=true (a round back button that fires onPressed) and badge (a small pill at the right).",
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
    return component('HeroSession', "The screen's one focal point: today's session on the brand gradient with the jumper illustration, minutes as a chip, the detail sentence and one big cta button that fires onPressed; audience=\"kid\" draws the child.", props, nodes, 'hero',
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
    return component('EmptyState', "What a screen or a list shows when there is nothing yet: a drawn rope at rest, a title, a message and a cta button that fires onPressed; audience=\"kid\" draws the playful one.", props, nodes, 'empty', events=[('onPressed', 'The button was tapped.')],
                     previews=[{'name': 'No sessions', 'size': [350, 360], 'props': {
                         'title': 'No sessions yet', 'message': 'Your first one takes five minutes.', 'cta': 'Start a session'}}])


# --- The session screen: SessionBar, SessionDial, TapPad, SessionControls, BigButton, SessionSummary -----------
#
# A session screen keeps its own clock (the notation's `every 1s`), so these blocks draw what they are given.
# The dial takes the phase (ready, set, work, rest), the seconds left and the round; TapPad and SessionControls
# share one page variable each (`=count`, `=paused`) and change it themselves, so their line needs no action
# for the common case.

WHOLE = {'width': FILL, 'height': FILL, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}


def by_phase(paused, rest, work, ready=None):
    """A theme color chosen by the dial's state, as a formula."""
    c = lambda n: 'theme.colors.%s' % n
    return "(props.paused ? %s : props.phase == 'rest' ? %s : props.phase == 'ready' ? %s : %s)" % (
        c(paused), c(rest), c(ready or work), c(work))


DIAL_ON = by_phase('onPanel', 'onRest', 'onWork', 'onHero')
DIAL_SOFT = by_phase('onPanelSoft', 'onRestSoft', 'onWorkSoft', 'onHeroSoft')
DIAL_ARC = by_phase('onPanelSoft', 'restArc', 'workArc')
DIAL_TRACK = by_phase('panelBar', 'restTrack', 'workTrack', 'heroChip')


def mmss(seconds):
    return "text(floor((%s) / 60)) + ':' + padLeft(floor((%s) %% 60), 2)" % (seconds, seconds)


def session_bar():
    deco, bind = card_deco('card', 'chip', 'card')
    nodes = {
        'bar': node('row', {'width': FILL, 'height': 48}, {'spacing': 12}, ['close', 'titles', 'side'], animations=enter(0, 14)),
        'close': node('row', {'width': 44, 'height': 44}, {'mainAxisAlignment': 'center'}, ['closeIcon'],
                      decoration={**deco, 'radius': 22},
                      bind={'decoration.radius': '${= min(22, theme.radii.cta)}', 'decoration.effects': '${theme.shadows.card}'},
                      states={'pressed': {'close': {'opacity': 0.8}}}, actions=tap()),
        'closeIcon': icon('close_rounded', 22, 'ink', bind={'props.icon': '${props.icon}'}),
        'titles': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'center', 'spacing': 1}, ['title', 'detail']),
        'title': text('${props.title}', 'cardTitle', FILL, textAlign='center', maxLines=1, overflow='ellipsis'),
        'detail': text('${props.detail}', 'meta', FILL, textAlign='center', maxLines=1, overflow='ellipsis',
                       bind={'visible': "${= props.detail != ''}"}),
        'side': node('row', {'width': 44, 'height': 44}, {'mainAxisAlignment': 'center'}, ['sideIcon']),
        'sideIcon': icon('volume_up_rounded', 22, 'inkFaint', bind={'props.icon': '${props.sideIcon}', 'visible': "${= props.sideIcon != ''}"}),
    }
    props = [
        P('title', STRING, 'Intervals', "The session's name, centered.", True),
        P('detail', STRING, '', 'A quiet line under it, e.g. the plan in short (empty: none).'),
        P('icon', STRING, 'close_rounded', 'The icon of the round button at the left.'),
        P('sideIcon', STRING, '', 'A quiet icon at the right, for balance (empty: none).'),
    ]
    return component('SessionBar', "The slim top of a session screen: a round close button at the left that fires onPressed, the session's title centered and a quiet detail line under it.",
                     props, nodes, 'bar', events=[('onPressed', 'The close button was tapped.')],
                     previews=[{'name': 'Intervals', 'size': [350, 48], 'props': {'title': 'Intervals', 'detail': '8 rounds · 8 min'}}])


DIAL_H = 428
RING = 264


def session_dial():
    total = "(props.phase == 'work' ? props.work : props.phase == 'rest' ? props.rest : 3)"
    frac = "(props.phase == 'ready' ? 1 : clamp(props.left / max(1, %s), 0, 1))" % total
    cycle = 'max(1, props.work + props.rest)'
    n = 'max(1, props.rounds)'
    # seconds of the whole session still to go
    remaining = ("(props.phase == 'ready' || props.phase == 'set' ? props.rounds * (props.work + props.rest) - props.rest"
                 " : props.left + (props.rounds - props.round) * (props.work + props.rest) - (props.phase == 'rest' ? props.rest : 0))")
    running = "(props.phase == 'work' || props.phase == 'rest')"
    c, r, sw = RING / 2, 112, 18
    arc_paint = lambda w: {'color': '${= %s}' % DIAL_ARC, 'style': 'stroke', 'strokeWidth': w, 'strokeCap': 'round'}
    ring = {'painter': [
        # ready: the hero's hairlines behind the jumper
        {'op': 'circle', 'c': [c, c], 'radius': 104, 'when': "${= props.phase == 'ready'}", 'paint': stroke('heroLine', 1.2)},
        {'op': 'circle', 'c': [c, c], 'radius': 130, 'when': "${= props.phase == 'ready'}", 'paint': stroke('heroLine', 1.2)},
        # sixty fine ticks inside the ring, every fifth longer
        {'op': 'repeat', 'count': 60, 'when': "${= props.phase != 'ready'}", 'ops': [
            {'op': 'line',
             'p1': ['${= %g + (index %% 5 == 0 ? 86 : 90) * cos(index * pi() / 30)}' % c, '${= %g + (index %% 5 == 0 ? 86 : 90) * sin(index * pi() / 30)}' % c],
             'p2': ['${= %g + 94 * cos(index * pi() / 30)}' % c, '${= %g + 94 * sin(index * pi() / 30)}' % c],
             'paint': {'color': '${= %s}' % DIAL_TRACK, 'style': 'stroke', 'strokeWidth': 2, 'strokeCap': 'round'}},
        ]},
        {'op': 'circle', 'c': [c, c], 'radius': r, 'when': "${= props.phase != 'ready'}",
         'paint': {'color': '${= %s}' % DIAL_TRACK, 'style': 'stroke', 'strokeWidth': sw}},
        # what is left: it drains clockwise from the top, with a soft halo like the rope's
        {'op': 'group', 'opacity': 0.2, 'when': "${= props.phase != 'ready' && %s > 0}" % frac, 'ops': [
            {'op': 'arc', 'rect': [c - r, c - r, 2 * r, 2 * r], 'startAngle': '${= -pi() / 2 + (1 - %s) * 2 * pi()}' % frac,
             'sweepAngle': '${= %s * 2 * pi()}' % frac, 'paint': arc_paint(sw + 14)}]},
        {'op': 'arc', 'rect': [c - r, c - r, 2 * r, 2 * r], 'startAngle': '${= -pi() / 2 + (1 - %s) * 2 * pi()}' % frac,
         'sweepAngle': '${= %s * 2 * pi()}' % frac, 'when': "${= props.phase != 'ready' && %s > 0}" % frac, 'paint': arc_paint(sw)},
    ]}
    gap = '(%s > 12 ? 3 : 6)' % n
    w = '((size.width - %s * (%s - 1)) / %s)' % (gap, n, n)
    x = '(index * (%s + %s))' % (w, gap)
    part = "(props.phase == 'work' ? (props.work - props.left) / %s : props.phase == 'rest' ? (props.work + props.rest - props.left) / %s : 0)" % (cycle, cycle)
    filled = '(index < props.round - 1 ? 1 : index == props.round - 1 ? max(0.14, %s) : 0)' % part
    segs = {'painter': [{'op': 'repeat', 'count': '${= %s}' % n, 'ops': [
        {'op': 'rrect', 'rect': ['${= %s}' % x, 0, '${= %s}' % w, 8], 'radius': 4, 'paint': '${= %s}' % DIAL_TRACK},
        {'op': 'rrect', 'rect': ['${= %s}' % x, 0, '${= %s * %s}' % (w, filled), 8], 'radius': 4,
         'when': '${= %s > 0}' % filled, 'paint': '${= %s}' % DIAL_ON},
    ]}]}
    label = ("(props.paused ? 'Paused' : props.phase == 'work' ? props.workLabel : props.phase == 'rest' ? props.restLabel"
             " : props.phase == 'set' ? props.setLabel : props.readyLabel)")
    note = ("(props.note != '' ? props.note : props.paused ? 'Take your time. Resume when you are ready.'"
            " : props.phase == 'ready' ? 'Rope in hand? Start when you are set.'"
            " : props.phase == 'set' ? 'Rope in hand. Round 1 is next.'"
            " : props.phase == 'rest' ? 'Next: round ' + text(props.round + 1) + ' of ' + text(props.rounds)"
            " : props.round >= props.rounds ? 'Last round. Finish strong.' : 'Next: rest for ' + text(props.rest) + ' s')")
    layer = lambda a, b, shown: node(
        'box', dict(WHOLE), decoration={'fills': [{'type': 'linear', 'begin': 'topLeft', 'end': 'bottomRight',
                                                   'stops': [{'position': 0, 'color': a}, {'position': 1, 'color': b}]}, GRAIN]},
        bind={'opacity': '${= %s ? (props.paused ? 0.18 : 1) : 0}' % shown},
        transitions=[{'property': 'opacity', 'duration': 420, 'curve': 'easeOutCubic'}])
    color = lambda expr: {'props.style.color': '${= %s}' % expr}
    chip = lambda kids, **more: node('row', {'width': HUG, 'height': 30, 'padding': [11, 0, 12, 0]}, {'spacing': 5}, kids,
                                     decoration={'fills': [{'color': 'heroChip'}], 'radius': 999},
                                     bind={'decoration.radius': '${theme.radii.chip}', 'decoration.fills[0].color': '${= %s}' % DIAL_TRACK, **more})
    nodes = {
        'dial': node('stack', {'width': FILL, 'height': DIAL_H}, children=['bgReady', 'bgWork', 'bgRest', 'glow', 'content'],
                     decoration={'fills': [{'color': 'panel'}], 'radius': 32, 'clip': 'antiAlias'},
                     bind={'decoration.radius': '${theme.radii.hero}', 'decoration.effects': '${theme.shadows.hero}'},
                     animations=enter(1)),
        'bgReady': layer('heroA', 'heroB', "props.phase == 'ready'"),
        'bgWork': layer('workA', 'workB', "(props.phase == 'set' || props.phase == 'work')"),
        'bgRest': layer('restA', 'restB', "props.phase == 'rest'"),
        'glow': node('box', {'width': 280, 'height': 280, 'x': {'end': -70}, 'y': {'start': -90}},
                     decoration={'fills': [{'color': 'heroGlow'}], 'shape': 'circle', 'effects': [{'type': 'layerBlur', 'blurRadius': 50}]},
                     bind={'decoration.fills[0].color': "${= props.phase == 'rest' ? theme.colors.restGlow : props.phase == 'ready' ? theme.colors.heroGlow : theme.colors.workGlow}",
                           'opacity': '${= props.paused ? 0.12 : 0.5}'}),
        'content': node('column', {**WHOLE, 'padding': [20, 18, 20, 20]}, {'crossAxisAlignment': 'stretch', 'mainAxisAlignment': 'spaceBetween'},
                        ['topRow', 'ringRow', 'foot']),
        'topRow': node('row', {'width': FILL, 'height': HUG}, {'mainAxisAlignment': 'spaceBetween'}, ['roundChip', 'timeChip']),
        'roundChip': chip(['roundText']),
        'roundText': text("${= upper(props.phase == 'ready' ? props.readyLabel : props.phase == 'set' ? text(props.rounds) + ' rounds' : 'Round ' + text(props.round) + ' of ' + text(props.rounds))}",
                          {'from': 'eyebrow', 'letterSpacing': 1.1}, bind=color(DIAL_ON)),
        'timeChip': chip(['timeIcon', 'timeText']),
        'timeIcon': icon('timer_outlined', 15, 'onHero', bind={'props.color': '${= %s}' % DIAL_ON}),
        'timeText': text('${= %s}' % mmss(remaining), 'chip', bind=color(DIAL_ON)),
        'ringRow': node('row', {'width': FILL, 'height': HUG}, {'mainAxisAlignment': 'center'}, ['ring']),
        'ring': node('stack', {'width': RING, 'height': RING}, children=['figure', 'center'], customPaint=ring),
        'figure': node('Illustration', {'width': 252, 'height': 252, 'x': {'start': 6}, 'y': {'start': 8}}, {'role': 'hero'},
                       bind={'props.audience': '${props.audience}', 'visible': "${= props.phase == 'ready'}"},
                       animations=[{'id': 'bob', 'duration': 640, 'curve': 'easeInOutSine', 'repeat': {'reverse': True},
                                    'tracks': [{'path': 'motion.translateY', 'from': 3, 'to': -5}]}]),
        'center': node('column', dict(WHOLE), {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center', 'spacing': 0},
                       ['label', 'digits', 'unit'], bind={'visible': "${= props.phase != 'ready'}"}),
        'label': text('${= upper(%s)}' % label, {'from': 'eyebrow', 'fontSize': 17, 'fontWeight': 900, 'letterSpacing': 3.2},
                      bind=color('(props.paused ? theme.colors.onPanel : %s)' % DIAL_ARC)),
        'digits': text('${props.left}', {'from': 'numberLarge', 'fontSize': 116, 'letterSpacing': -5, 'height': 1.04},
                       bind=color(DIAL_ON)),
        'unit': text("${= props.paused ? 'on hold' : props.left == 1 ? 'second' : 'seconds'}", {'from': 'meta', 'fontSize': 14, 'fontWeight': 700}, bind=color(DIAL_SOFT)),
        'foot': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'stretch', 'spacing': 12}, ['segs', 'note']),
        'segs': node('box', {'width': FILL, 'height': 8}, customPaint=segs),
        'note': text('${= %s}' % note, {'from': 'lead', 'fontSize': 14.5, 'fontWeight': 500}, FILL, textAlign='center', maxLines=1,
                     overflow='ellipsis', bind=color(DIAL_SOFT)),
    }
    props = [
        P('note', STRING, '', 'The line under the round marks (empty: written from the phase, e.g. "Next: rest for 20 s").'),
        P('left', INT, 40, 'Seconds left in this phase: the big number and the arc.', True),
        P('phase', enum('ready', 'set', 'work', 'rest'), 'work', 'ready (before the start: the jumper, no clock), set (the short count-in from 3), work or rest.', True),
        P('round', INT, 1, 'The round in progress, from 1 (0 before the first).', True),
        P('rounds', INT, 8, 'The planned rounds: one mark each.', True),
        P('work', INT, 40, 'Seconds of a work phase.', True),
        P('rest', INT, 20, 'Seconds of a rest phase.', True),
        P('paused', BOOL, False, 'Dims the dial and says Paused.'),
        P('workLabel', STRING, 'Jump', 'The word over the number while working.'),
        P('restLabel', STRING, 'Rest', 'The word over the number while resting.'),
        P('setLabel', STRING, 'Get set', 'The word over the number during the count-in.'),
        P('readyLabel', STRING, 'Ready', 'The chip over the jumper before the start.'),
        AUDIENCE,
    ]
    return component('SessionDial', "The session screen's one focal point: a big countdown ring that drains with left (seconds) on a surface that changes with phase (\"ready\" shows the jumper, \"set\" the count-in, \"work\" the bright surface, \"rest\" the calm one), with the round marks (round of rounds), the time to go, and paused=true dimming it; pass work and rest (the phase lengths in seconds).",
                     props, nodes, 'dial',
                     previews=[{'name': 'Work', 'size': [350, DIAL_H], 'props': {'left': 28, 'phase': 'work', 'round': 3}},
                               {'name': 'Rest', 'size': [350, DIAL_H], 'props': {'left': 12, 'phase': 'rest', 'round': 3}},
                               {'name': 'Ready', 'size': [350, DIAL_H], 'props': {'left': 3, 'phase': 'ready', 'round': 0}},
                               {'name': 'Paused', 'size': [350, DIAL_H], 'props': {'left': 28, 'phase': 'work', 'round': 3, 'paused': True}}])


PAD_H = 172


def tap_pad():
    deco, bind = card_deco('card', 'card', 'card')
    count_var = {'kind': 'variable', 'of': INT}
    step = lambda expr: {'type': 'setVariable', 'variable': 'props.count', 'value': '${= %s}' % expr}
    nudge = lambda nid, kids, expr: node(
        'row', {'width': 64, 'height': 40}, {'mainAxisAlignment': 'center'}, kids,
        decoration={'fills': [{'color': 'track'}], 'radius': 999}, bind={'decoration.radius': '${theme.radii.chip}'},
        states={'pressed': {nid: {'opacity': 0.6}}},
        actions=[{'trigger': {'type': 'click'}, 'actions': [step(expr), {'type': 'componentEvent', 'event': 'onChanged', 'value': '${props.count}'}]}])
    nodes = {
        'pad': node('row', {'width': FILL, 'height': PAD_H, 'padding': [22, 16, 18, 16]}, {'spacing': 12}, ['left', 'target'],
                    decoration=deco, bind=bind, animations=enter(2),
                    states={'pressed': {'pad': {'motion': {'scale': 0.975}}, 'disc': {'motion': {'scale': 0.9}}}},
                    transitions=[{'property': 'motion', 'duration': 110, 'curve': 'easeOut'}],
                    actions=[{'trigger': {'type': 'click'}, 'actions': [
                        step('props.count + 1'), {'type': 'haptic', 'kind': 'light'},
                        {'type': 'componentEvent', 'event': 'onChanged', 'value': '${props.count}'}]}]),
        'left': node('column', {'width': FILL, 'height': FILL}, {'crossAxisAlignment': 'start', 'mainAxisAlignment': 'spaceBetween'},
                     ['figures', 'nudges']),
        'figures': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'start', 'spacing': 2}, ['eyebrow', 'count']),
        'eyebrow': text('${= upper(props.label)}', 'eyebrow', FILL, maxLines=1, overflow='ellipsis'),
        'count': text(shown('props.count'), {'from': 'numberLarge', 'fontSize': 72, 'letterSpacing': -2.8}, FILL, maxLines=1, scaleDown=True),
        'nudges': node('row', {'width': HUG, 'height': HUG}, {'spacing': 8}, ['minus', 'plus']),
        'minus': nudge('minus', ['minusText'], 'max(0, props.count - 1)'),
        'minusText': text('−1', 'chip', color='inkSoft'),
        'plus': nudge('plus', ['plusText'], 'props.count + 10'),
        'plusText': text('+10', 'chip', color='inkSoft'),
        'target': node('stack', {'width': 140, 'height': 140}, children=['halo', 'pulse', 'disc']),
        'halo': node('box', {'width': 140, 'height': 140, 'x': 0, 'y': 0}, decoration={'fills': [{'color': 'accent'}], 'shape': 'circle'},
                     opacity=0.22),
        'pulse': node('box', {'width': 140, 'height': 140, 'x': 0, 'y': 0},
                      decoration={'fills': [{'color': 'accentDeep'}], 'shape': 'circle'}, opacity=0,
                      bind={'animations[0].playKey': '${props.count}'},
                      animations=[{'id': 'pulse', 'duration': 420, 'curve': 'easeOutCubic', 'autoplay': False,
                                   'tracks': [{'path': 'opacity', 'from': 0.5, 'to': 0}, {'path': 'motion.scale', 'from': 0.8, 'to': 1.12}]}]),
        'disc': node('column', {'width': 114, 'height': 114, 'x': 13, 'y': 13}, {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center', 'spacing': 0},
                     ['discIcon', 'discText'],
                     decoration={'fills': [{'type': 'linear', 'begin': 'topCenter', 'end': 'bottomCenter',
                                            'stops': [{'position': 0, 'color': 'accent'}, {'position': 1, 'color': 'accentDeep'}]}],
                                 'shape': 'circle'},
                     bind={'decoration.effects': '${theme.shadows.cta}'},
                     transitions=[{'property': 'motion', 'duration': 110, 'curve': 'easeOut'}]),
        'discIcon': icon('touch_app_rounded', 38, 'onAccent'),
        'discText': text('${= upper(props.hint)}', {'from': 'eyebrow', 'fontSize': 12.5, 'fontWeight': 900, 'letterSpacing': 1.6}, color='onAccent'),
    }
    props = [
        P('count', count_var, '', 'The name of your number variable holding the jump count: a tap adds 1, the small chips take 1 off or add 10.'),
        P('label', STRING, 'Jumps', 'What is counted, small caps over the number.'),
        P('hint', STRING, 'Tap', 'The word on the round target.'),
    ]
    return component('TapPad', "The jump counter as one enormous tap target: write TapPad @count and every tap anywhere on it adds 1 to your count variable, shown in display type; its two quiet chips take 1 off or add 10 (onChanged fires with the new count).",
                     props, nodes, 'pad', events=[('onChanged', 'The count changed; the value is the new count.')],
                     previews=[{'name': 'Counting', 'size': [350, PAD_H], 'props': {}}])


def session_controls():
    paused_var = {'kind': 'variable', 'of': BOOL}
    nodes = {
        'controls': node('row', {'width': FILL, 'height': 64}, {'spacing': 12}, ['toggle', 'finish'], animations=enter(3)),
        'toggle': node('row', {'width': FILL, 'height': 64}, {'mainAxisAlignment': 'center', 'spacing': 8}, ['toggleIcon', 'toggleText'],
                       decoration={'fills': [{'color': 'ink'}], 'radius': 999},
                       bind={'decoration.radius': '${theme.radii.cta}', 'decoration.effects': '${theme.shadows.cta}',
                             'decoration.fills[0].color': '${= props.paused ? theme.colors.brand : theme.colors.ink}'},
                       states={'pressed': {'toggle': {'opacity': 0.85}}},
                       actions=[{'trigger': {'type': 'click'}, 'actions': [
                           {'type': 'setVariable', 'variable': 'props.paused', 'value': '${= !props.paused}'}, {'type': 'haptic', 'kind': 'medium'}]}]),
        'toggleIcon': icon('pause_rounded', 26, 'card',
                           bind={'props.icon': "${= props.paused ? 'play_arrow_rounded' : 'pause_rounded'}",
                                 'props.color': '${= props.paused ? theme.colors.onBrand : theme.colors.card}'}),
        'toggleText': text('${= props.paused ? props.resume : props.pause}', 'cta',
                           bind={'props.style.color': '${= props.paused ? theme.colors.onBrand : theme.colors.card}'}),
        'finish': node('row', {'width': 124, 'height': 64}, {'mainAxisAlignment': 'center', 'spacing': 7}, ['finishIcon', 'finishText'],
                       decoration={'fills': [{'color': 'track'}], 'radius': 999}, bind={'decoration.radius': '${theme.radii.cta}'},
                       states={'pressed': {'finish': {'opacity': 0.7}}}, actions=tap()),
        'finishIcon': icon('flag_rounded', 20, 'inkSoft'),
        'finishText': text('${props.finish}', 'cta', color='inkSoft'),
    }
    props = [
        P('paused', paused_var, '', 'The name of your boolean variable that is true while the session is paused: the big button toggles it.'),
        P('pause', STRING, 'Pause', "The big button's label while running."),
        P('resume', STRING, 'Resume', "The big button's label while paused."),
        P('finish', STRING, 'Finish', "The quiet button's label."),
    ]
    return component('SessionControls', "The session's control bar: write SessionControls @paused and its big button pauses and resumes by toggling your paused variable itself, while the quiet Finish button fires onPressed (write -> for what finishing does).",
                     props, nodes, 'controls', events=[('onPressed', 'Finish was tapped.')],
                     previews=[{'name': 'Running', 'size': [350, 64], 'props': {}}])


def big_button():
    quiet = "props.tone == 'quiet'"
    nodes = {
        'btn': node('row', {'width': FILL, 'height': 64, 'padding': [10, 0, 22, 0]}, {'spacing': 14}, ['mark', 'label', 'arrow'],
                    decoration={'fills': [{'color': 'brand'}], 'radius': 999},
                    bind={'decoration.radius': '${theme.radii.cta}',
                          'decoration.effects': '${= %s ? [] : theme.shadows.cta}' % quiet,
                          'decoration.fills[0].color': '${= %s ? theme.colors.track : theme.colors.brand}' % quiet},
                    states={'pressed': {'btn': {'opacity': 0.86}}}, animations=enter(3), actions=tap()),
        'mark': node('row', {'width': 44, 'height': 44}, {'mainAxisAlignment': 'center'}, ['markIcon'],
                     decoration={'fills': [{'color': 'onBrand'}], 'radius': 22},
                     bind={'decoration.radius': '${= min(22, theme.radii.cta - 3)}',
                           'decoration.fills[0].color': '${= %s ? theme.colors.card : theme.colors.onBrand}' % quiet}),
        'markIcon': icon('play_arrow_rounded', 26, 'brand',
                         bind={'props.icon': '${props.icon}', 'props.color': '${= %s ? theme.colors.ink : theme.colors.brand}' % quiet}),
        'label': text('${props.label}', 'cta', FILL, maxLines=1, overflow='ellipsis',
                      bind={'props.style.color': '${= %s ? theme.colors.ink : theme.colors.onBrand}' % quiet}),
        'arrow': icon('arrow_forward_rounded', 22, 'onBrand',
                      bind={'props.color': '${= %s ? theme.colors.inkSoft : theme.colors.onBrand}' % quiet}),
    }
    props = [
        P('label', STRING, 'Start', "The button's label.", True),
        P('icon', STRING, 'play_arrow_rounded', 'The icon in the round mark at the left.'),
        P('tone', enum('primary', 'quiet'), 'primary', 'primary (filled with the brand, the one main action) or quiet (a soft second action).'),
    ]
    return component('BigButton', "A full-width, thumb-sized button for a screen's main action below its focal block (Start, Done): the label with icon in a round mark, firing onPressed; tone=\"quiet\" is the soft second action.",
                     props, nodes, 'btn', events=[('onPressed', 'The button was tapped.')],
                     previews=[{'name': 'Start', 'size': [350, 64], 'props': {'label': 'Start'}},
                               {'name': 'Quiet', 'size': [350, 64], 'props': {'label': 'See your progress', 'tone': 'quiet', 'icon': 'bar_chart_rounded'}}])


def session_summary():
    record = '(props.best > 0 && props.jumps > props.best)'
    cell = lambda i, kids: node('column', {'width': FILL, 'height': HUG, 'padding': [8, 12, 8, 11]}, {'crossAxisAlignment': 'center', 'spacing': 3}, kids,
                                decoration={'fills': [{'color': 'heroChip'}], 'radius': 18},
                                bind={'decoration.radius': '${= min(18, theme.radii.tile)}'})
    figure = lambda value: text(value, 'numberSmall', color='onHero', maxLines=1)
    caption = lambda value: text(value, {'from': 'meta', 'fontSize': 12}, color='onHeroSoft', maxLines=1)
    rings = {'painter': [
        {'op': 'circle', 'c': ['${= size.width / 2}', 112], 'radius': 96, 'paint': stroke('heroLine', 1.2)},
        {'op': 'circle', 'c': ['${= size.width / 2}', 112], 'radius': 140, 'paint': stroke('heroLine', 1.2)},
        {'op': 'circle', 'c': ['${= size.width / 2}', 112], 'radius': 190, 'paint': stroke('heroLine', 1.2)},
    ]}
    nodes = {
        'summary': node('column', {'width': FILL, 'height': HUG}, {'crossAxisAlignment': 'stretch'}, ['stage', 'body'],
                        decoration={'fills': [{'type': 'linear', 'begin': 'topLeft', 'end': 'bottomRight',
                                               'stops': [{'position': 0, 'color': 'heroA'}, {'position': 1, 'color': 'heroB'}]}, GRAIN],
                                    'radius': 32, 'clip': 'antiAlias'},
                        bind={'decoration.radius': '${theme.radii.hero}', 'decoration.effects': '${theme.shadows.hero}'},
                        animations=enter(0)),
        'stage': node('stack', {'width': FILL, 'height': 212}, children=['glow', 'rings', 'figureRow', 'chip']),
        'glow': node('box', {'width': 260, 'height': 260, 'x': {'start': 45}, 'y': {'start': -40}},
                     decoration={'fills': [{'color': 'heroGlow'}], 'shape': 'circle', 'effects': [{'type': 'layerBlur', 'blurRadius': 46}]},
                     opacity=0.55),
        'rings': node('box', dict(WHOLE), customPaint=rings),
        'figureRow': node('row', {'width': FILL, 'height': 212, 'x': {'start': 0, 'end': 0}, 'y': {'start': 6}}, {'mainAxisAlignment': 'center'}, ['figure']),
        'figure': node('Illustration', {'width': 212, 'height': 212}, {'role': 'cheer'}, bind={'props.audience': '${props.audience}'},
                       animations=[{'id': 'bob', 'duration': 640, 'curve': 'easeInOutSine', 'repeat': {'reverse': True},
                                    'tracks': [{'path': 'motion.translateY', 'from': 3, 'to': -5}]}]),
        'chip': node('row', {'width': HUG, 'height': HUG, 'padding': [11, 7, 11, 7], 'x': {'start': 20}, 'y': {'start': 20}}, None, ['chipText'],
                     decoration={'fills': [{'color': 'heroChip'}], 'radius': 999},
                     bind={'decoration.radius': '${theme.radii.chip}', 'visible': "${= props.eyebrow != ''}"}),
        'chipText': text('${= upper(props.eyebrow)}', {'from': 'eyebrow', 'letterSpacing': 1.1}, color='onHero'),
        'body': node('column', {'width': FILL, 'height': HUG, 'padding': [20, 6, 20, 22]}, {'crossAxisAlignment': 'center', 'spacing': 0},
                     ['title', 'gapA', 'figures', 'gapB', 'badge', 'gapC', 'cells', 'gapD', 'detail']),
        'title': text('${props.title}', 'blockTitle', FILL, color='onHeroSoft', textAlign='center', maxLines=1, overflow='ellipsis'),
        'gapA': node('spacer', {'width': 1, 'height': 4}),
        'figures': node('row', {'width': HUG, 'height': HUG}, {'crossAxisAlignment': 'end', 'spacing': 8}, ['jumps', 'unit']),
        'jumps': text(shown('props.jumps'), {'from': 'numberLarge', 'fontSize': 76, 'letterSpacing': -3}, color='onHero'),
        'unit': text('${props.unit}', 'lead', color='onHeroSoft', layout={'padding': [0, 0, 0, 12]}),
        'gapB': node('spacer', {'width': 1, 'height': 10}),
        'badge': node('row', {'width': HUG, 'height': 34, 'padding': [10, 0, 14, 0]}, {'spacing': 6}, ['badgeIcon', 'badgeText'],
                      decoration={'fills': [{'color': 'heroChip'}], 'radius': 999},
                      bind={'decoration.radius': '${theme.radii.chip}', 'visible': '${= props.best > 0}',
                            'decoration.fills[0].color': '${= %s ? theme.colors.gold : theme.colors.heroChip}' % record}),
        'badgeIcon': icon('emoji_events_rounded', 18, 'onHero',
                          bind={'props.color': '${= %s ? theme.colors.onAccent : theme.colors.onHero}' % record}),
        'badgeText': text("${= %s ? 'New record, ' + thousands(props.jumps - props.best) + ' more than your best' : 'Your best is ' + thousands(props.best) + '. It will keep.'}" % record,
                          'chip', bind={'props.style.color': '${= %s ? theme.colors.onAccent : theme.colors.onHero}' % record}),
        'gapC': node('spacer', {'width': 1, 'height': 18}),
        'cells': node('row', {'width': FILL, 'height': HUG}, {'spacing': 8, 'crossAxisAlignment': 'start'}, ['cellA', 'cellB', 'cellC']),
        'cellA': cell(0, ['roundsValue', 'roundsLabel']),
        'roundsValue': figure("${= props.of > 0 ? text(props.rounds) + '/' + text(props.of) : text(props.rounds)}"),
        'roundsLabel': caption('rounds'),
        'cellB': cell(1, ['timeValue', 'timeLabel']),
        'timeValue': figure('${= %s}' % mmss('props.seconds')),
        'timeLabel': caption('moving time'),
        'cellC': cell(2, ['streakRow', 'streakLabel']),
        'streakRow': node('row', {'width': HUG, 'height': HUG}, {'spacing': 4}, ['streakIcon', 'streakValue']),
        'streakIcon': icon('local_fire_department_rounded', 20, 'onHero'),
        'streakValue': figure('${props.streak}'),
        'streakLabel': caption('${props.streakLabel}'),
        'gapD': node('spacer', {'width': 1, 'height': 16}, bind={'visible': "${= props.detail != ''}"}),
        'detail': text('${props.detail}', {'from': 'lead', 'fontSize': 14.5}, FILL, color='onHeroSoft', textAlign='center',
                       bind={'visible': "${= props.detail != ''}"}),
    }
    props = [
        P('title', STRING, 'Session complete', 'The headline over the number, e.g. Session complete.', True),
        P('detail', STRING, '', 'One warm line at the bottom: what it means, what comes next (empty: none).'),
        P('jumps', INT, 0, 'The jumps counted: the big number.', True),
        P('best', INT, 0, 'The most jumps in a past session: over it the badge says New record, under it how far short (0: no badge).'),
        P('rounds', INT, 0, 'Rounds reached.'),
        P('of', INT, 0, 'Rounds planned (0: show only the rounds reached).'),
        P('seconds', INT, 0, 'Seconds the session ran, shown as m:ss.'),
        P('streak', INT, 0, 'The streak including this session.'),
        P('streakLabel', STRING, 'day streak', 'What the streak counts.'),
        P('unit', STRING, 'jumps', 'The unit after the big number.'),
        P('eyebrow', STRING, 'Done', 'A small chip over the art.'),
        AUDIENCE,
    ]
    return component('SessionSummary', "The finished session as a celebration on the brand gradient: the cheering jumper, jumps in display type, a badge that says whether best (the past record) fell, then rounds of planned rounds, seconds as time and the streak, and a detail line on what comes next; follow it with BigButton lines.",
                     props, nodes, 'summary',
                     previews=[{'name': 'Record', 'size': [350, 520], 'props': {'jumps': 940, 'best': 912, 'rounds': 8, 'of': 8, 'seconds': 460, 'streak': 5,
                                                                              'detail': 'That is five in a row. Rest up and come back tomorrow.'}}])


def all_components():
    return [screen(), top_bar(), hero_session(), streak_flame(), progress_goal(), week_strip(), section_title(), session_row(),
            chart_card(), stat_trio(), record_card(), empty_state(), illustration(),
            session_bar(), session_dial(), tap_pad(), session_controls(), big_button(), session_summary()]

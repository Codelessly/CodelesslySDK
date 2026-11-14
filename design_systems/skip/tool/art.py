"""Skip's illustrations, as customPaint draw lists colored by theme tokens.

Every color is read from the theme when it draws (`${theme.colors.<name>}`), so a token set recolors the art.
A theme color's bare name does not work inside a customPaint paint (it draws nothing), and a gradient's stops
take no expression unless the whole paint is one expression: hence `T`, `stroke` and `grad` below.
"""


def T(name):
    """A theme color, read when the list draws; a literal '#AARRGGBB' is kept."""
    return name if name.startswith('#') else '${theme.colors.%s}' % name


def _f(name):
    return "'%s'" % name if name.startswith('#') else 'theme.colors.%s' % name


def fill(color):
    return T(color)


def stroke(color, width, cap='round', join='round', dash=None):
    p = {'color': T(color), 'style': 'stroke', 'strokeWidth': width, 'strokeCap': cap, 'strokeJoin': join}
    if dash:
        p['dashPattern'] = dash
    return p


def grad(stops, begin='topCenter', end='bottomCenter', kind='linear', extra=''):
    """A gradient paint whose stops are theme colors: the whole paint is one expression."""
    s = ', '.join("{'position': %g, 'color': %s}" % (p, _f(c)) for p, c in stops)
    geo = "'begin': '%s', 'end': '%s'" % (begin, end) if kind == 'linear' else extra
    return "${= {'shader': {'type': '%s', %s, 'stops': [%s]}}}" % (kind, geo, s)


def path(d, paint, **k):
    return {'op': 'path', 'd': d, 'paint': paint, **k}


def circle(x, y, r, paint):
    return {'op': 'circle', 'c': [x, y], 'radius': r, 'paint': paint}


def oval(x, y, w, h, paint):
    return {'op': 'oval', 'rect': [x, y, w, h], 'paint': paint}


def line(x1, y1, x2, y2, paint):
    return {'op': 'line', 'p1': [x1, y1], 'p2': [x2, y2], 'paint': paint}


def group(ops, **k):
    return {'op': 'group', 'ops': ops, **k}


def star4(x, y, r, color):
    """A four-point sparkle."""
    q = r * 0.22
    d = (f'M{x} {y - r} Q{x + q} {y - q} {x + r} {y} Q{x + q} {y + q} {x} {y + r} '
         f'Q{x - q} {y + q} {x - r} {y} Q{x - q} {y - q} {x} {y - r} Z')
    return path(d, fill(color))


def limb(points, color, width):
    d = 'M' + ' L'.join(f'{x} {y}' for x, y in points)
    return path(d, stroke(color, width))


# --- hero: a person mid-jump, the rope overhead ---------------------------------------------------------

def hero_adult():
    """240 x 240. A jumper in the air, knees soft, the rope a wide arc overhead and its echo underfoot."""
    ops = []
    # the rope's path through the turn: a faint full loop behind, the live arc in front
    ops.append(group([path('M48 122 C 18 176, 66 232, 120 232 C 174 232, 222 176, 192 122',
                           stroke('artRope', 3, dash=[1, 9]))], opacity=0.55))
    ops.append(group([path('M48 122 C 4 44, 62 4, 120 4 C 178 4, 236 44, 192 122', stroke('artRope', 12))], opacity=0.16))
    # ground shadow and lift marks
    ops.append(oval(80, 220, 80, 10, fill('artShadow')))
    # ponytail, flying up on the way down
    ops.append(path('M128 40 C 140 30, 150 34, 155 26 C 159 19, 166 17, 171 21 C 165 24, 165 33, 159 41 C 153 49, 141 52, 133 51 Z', fill('artHair')))
    # legs: one knee a little higher
    ops.append(limb([(111, 150), (102, 176), (108, 200)], 'artSkin', 12))
    ops.append(limb([(129, 150), (141, 172), (132, 194)], 'artSkin', 12))
    # shoes
    ops.append(group([path('M-13 -5 C -13 -9, 6 -10, 13 -2 C 16 2, 14 7, 9 7 L -10 7 C -14 7, -14 0, -13 -5 Z', fill('artShoe')),
                      path('M-11 7 L10 7', stroke('artRope', 2.5))], translate=[109, 205], rotate=0.12))
    ops.append(group([path('M-13 -5 C -13 -9, 6 -10, 13 -2 C 16 2, 14 7, 9 7 L -10 7 C -14 7, -14 0, -13 -5 Z', fill('artShoe')),
                      path('M-11 7 L10 7', stroke('artRope', 2.5))], translate=[133, 199], rotate=0.42))
    # shorts
    ops.append(path('M102 134 L138 134 L142 160 C 136 164, 126 164, 122 160 L120 152 L118 160 C 114 164, 104 164, 98 160 Z',
                    [fill('artBottom'), stroke('artBottom', 3)]))
    # arms: elbows in, forearms out to the handles
    ops.append(limb([(103, 94), (88, 118), (64, 124)], 'artSkin', 9.5))
    ops.append(limb([(137, 94), (152, 118), (176, 124)], 'artSkin', 9.5))
    # top, with short sleeves
    ops.append(limb([(104, 92), (95, 106)], 'artTop', 14))
    ops.append(limb([(136, 92), (145, 106)], 'artTop', 14))
    ops.append(path('M100 92 C 100 85, 106 82, 112 82 L128 82 C 134 82, 140 85, 140 92 L138 138 L102 138 Z',
                    [fill('artTop'), stroke('artTop', 2)]))
    # neck, head, hair
    ops.append(limb([(120, 70), (120, 84)], 'artSkinShade', 10))
    ops.append(circle(120, 54, 18, fill('artSkin')))
    ops.append(path('M101 56 C 97 30, 143 28, 139 56 C 136 46, 128 42, 118 43 C 110 44, 104 49, 101 56 Z', fill('artHair')))
    # handles, then the rope
    ops.append(limb([(66, 126), (50, 116)], 'artHandle', 7))
    ops.append(limb([(174, 126), (190, 116)], 'artHandle', 7))
    ops.append(path('M48 114 C 8 44, 62 6, 120 6 C 178 6, 232 44, 192 114', stroke('artRope', 5)))
    # sparks
    ops.append(star4(30, 160, 8, 'artSpark'))
    ops.append(star4(212, 168, 6, 'artSpark'))
    ops.append(circle(206, 206, 3, fill('artRope')))
    ops.append(circle(40, 196, 2.5, fill('artSpark')))
    return ops


def hero_kid():
    """240 x 240. Rounder and louder: a big head with buns and a smile, short limbs, confetti."""
    ops = []
    ops.append(group([path('M52 132 C 24 182, 68 232, 120 232 C 172 232, 216 182, 188 132',
                           stroke('artRope', 3.5, dash=[1, 10]))], opacity=0.6))
    ops.append(group([path('M52 132 C 6 54, 60 8, 120 8 C 180 8, 234 54, 188 132', stroke('artRope', 14))], opacity=0.16))
    ops.append(oval(84, 222, 72, 10, fill('artShadow')))
    # buns behind the head
    ops.append(circle(94, 44, 12, fill('artHair')))
    ops.append(circle(146, 44, 12, fill('artHair')))
    # legs, short, feet apart
    ops.append(limb([(111, 164), (104, 184), (102, 200)], 'artSkin', 13))
    ops.append(limb([(129, 164), (138, 182), (140, 196)], 'artSkin', 13))
    # shoes, big
    ops.append(group([path('M-15 -6 C -15 -11, 6 -12, 14 -3 C 18 2, 16 8, 10 8 L -11 8 C -16 8, -16 0, -15 -6 Z', fill('artShoe')),
                      path('M-12 8 L11 8', stroke('artRope', 3))], translate=[102, 208], rotate=-0.1))
    ops.append(group([path('M-15 -6 C -15 -11, 6 -12, 14 -3 C 18 2, 16 8, 10 8 L -11 8 C -16 8, -16 0, -15 -6 Z', fill('artShoe')),
                      path('M-12 8 L11 8', stroke('artRope', 3))], translate=[142, 203], rotate=0.3))
    # shorts
    ops.append(path('M101 150 L139 150 L143 172 C 137 176, 127 176, 122 172 L120 166 L118 172 C 113 176, 103 176, 97 172 Z',
                    [fill('artBottom'), stroke('artBottom', 3)]))
    # arms
    ops.append(limb([(102, 116), (86, 134), (68, 134)], 'artSkin', 10.5))
    ops.append(limb([(138, 116), (154, 134), (172, 134)], 'artSkin', 10.5))
    # top: a round tee
    ops.append(limb([(103, 114), (94, 126)], 'artTop', 15))
    ops.append(limb([(137, 114), (146, 126)], 'artTop', 15))
    ops.append(path('M98 114 C 98 106, 105 103, 112 103 L128 103 C 135 103, 142 106, 142 114 L140 154 L100 154 Z',
                    [fill('artTop'), stroke('artTop', 2)]))
    ops.append(star4(120, 130, 9, 'artBottom'))
    # head, hair, face
    ops.append(circle(120, 66, 30, fill('artSkin')))
    ops.append(path('M90 66 C 84 22, 156 22, 150 66 C 146 50, 134 42, 120 44 C 106 42, 94 50, 90 66 Z', fill('artHair')))
    ops.append(circle(109, 72, 3, fill('artHair')))
    ops.append(circle(131, 72, 3, fill('artHair')))
    ops.append(path('M110 82 Q120 92 130 82', stroke('artHair', 3)))
    ops.append(group([circle(101, 81, 5, fill('flame')), circle(139, 81, 5, fill('flame'))], opacity=0.35))
    # handles and rope
    ops.append(limb([(70, 135), (54, 124)], 'artHandle', 8))
    ops.append(limb([(170, 135), (186, 124)], 'artHandle', 8))
    ops.append(path('M52 122 C 10 54, 60 10, 120 10 C 180 10, 230 54, 188 122', stroke('artRope', 6)))
    # confetti
    ops.append(star4(30, 190, 10, 'artSpark'))
    ops.append(star4(214, 160, 8, 'artRope'))
    ops.append(circle(210, 204, 4, fill('flameLight')))
    ops.append(circle(24, 140, 3.5, fill('artSpark')))
    ops.append(group([{'op': 'rrect', 'rect': [-4, -4, 8, 8], 'radius': 2, 'paint': fill('flameLight')}], translate=[40, 96], rotate=0.5))
    ops.append(group([{'op': 'rrect', 'rect': [-4, -4, 8, 8], 'radius': 2, 'paint': fill('artSpark')}], translate=[204, 108], rotate=-0.4))
    return ops


# --- streak: a flame -------------------------------------------------------------------------------------

FLAME_OUT = ('M52 6 C 60 30, 90 44, 90 78 C 90 102, 73 118, 50 118 C 27 118, 10 102, 10 78 '
             'C 10 62, 17 51, 26 42 C 28 53, 33 58, 39 58 C 34 38, 40 18, 52 6 Z')
FLAME_IN = 'M50 64 C 58 76, 70 82, 70 96 C 70 108, 61 114, 50 114 C 39 114, 30 108, 30 96 C 30 84, 42 78, 50 64 Z'


def streak_adult():
    """100 x 124. A flame in two tones with its sparks."""
    return [
        group([oval(22, 112, 56, 10, fill('flame'))], opacity=0.18),
        path(FLAME_OUT, grad([(0, 'flame'), (1, 'flameDeep')])),
        path(FLAME_IN, grad([(0, 'flameLight'), (1, 'flame')])),
        group([path('M56 20 C 60 32, 74 42, 80 58', stroke('#FFFFFFFF', 3))], opacity=0.35),
        circle(88, 30, 3, fill('flameLight')),
        circle(12, 34, 2.2, fill('flame')),
        star4(84, 12, 5, 'flameLight'),
    ]


def streak_kid():
    """100 x 124. The same flame, rounder, with a face."""
    out = ('M52 10 C 62 30, 92 46, 92 80 C 92 104, 74 120, 50 120 C 26 120, 8 104, 8 80 '
           'C 8 64, 15 54, 24 46 C 27 56, 33 60, 39 58 C 35 42, 41 24, 52 10 Z')
    return [
        group([oval(20, 114, 60, 10, fill('flame'))], opacity=0.18),
        path(out, grad([(0, 'flameLight'), (0.55, 'flame'), (1, 'flameDeep')])),
        oval(26, 70, 48, 44, grad([(0, 'flameLight'), (1, 'flame')])),
        circle(40, 88, 3.4, fill('artHair')),
        circle(60, 88, 3.4, fill('artHair')),
        path('M42 97 Q50 105 58 97', stroke('artHair', 3)),
        group([circle(33, 97, 4.5, fill('flameDeep')), circle(67, 97, 4.5, fill('flameDeep'))], opacity=0.35),
        star4(88, 22, 7, 'flameLight'),
        star4(10, 30, 5, 'flame'),
        circle(92, 44, 3, fill('flameLight')),
    ]


# --- empty: a rope at rest ---------------------------------------------------------------------------------

def empty_adult():
    """200 x 160. A rope at rest in a loose loop on a soft shape, waiting."""
    return [
        path('M30 92 C 24 48, 70 18, 112 22 C 160 26, 190 62, 178 100 C 168 134, 118 148, 76 140 C 48 134, 34 118, 30 92 Z',
             fill('artBlob')),
        oval(52, 122, 100, 12, fill('artBlobDeep')),
        # the rope, one easy loop
        path('M58 112 C 40 70, 78 40, 104 58 C 126 74, 110 104, 92 96 C 76 88, 96 56, 126 60 C 152 64, 158 92, 146 112',
             stroke('brand', 6)),
        # handles
        group([{'op': 'rrect', 'rect': [-6, -17, 12, 34], 'radius': 6, 'paint': fill('ink')},
               {'op': 'rrect', 'rect': [-6, -17, 12, 9], 'radius': 4, 'paint': fill('accent')}], translate=[55, 122], rotate=-0.5),
        group([{'op': 'rrect', 'rect': [-6, -17, 12, 34], 'radius': 6, 'paint': fill('ink')},
               {'op': 'rrect', 'rect': [-6, -17, 12, 9], 'radius': 4, 'paint': fill('accent')}], translate=[150, 122], rotate=0.55),
        star4(160, 40, 8, 'brand'),
        star4(38, 50, 5, 'brandBright'),
        circle(176, 70, 3, fill('accentDeep')),
        circle(26, 108, 2.5, fill('brandBright')),
    ]


def empty_kid():
    """200 x 160. The rope as a smile under two bright eyes."""
    return [
        path('M30 92 C 24 48, 70 18, 112 22 C 160 26, 190 62, 178 100 C 168 134, 118 148, 76 140 C 48 134, 34 118, 30 92 Z',
             fill('artBlob')),
        circle(80, 66, 7, fill('ink')),
        circle(122, 66, 7, fill('ink')),
        circle(82.5, 63.5, 2.2, fill('card')),
        circle(124.5, 63.5, 2.2, fill('card')),
        path('M56 92 C 70 126, 132 126, 146 92', stroke('brand', 7)),
        group([{'op': 'rrect', 'rect': [-6.5, -16, 13, 32], 'radius': 6.5, 'paint': fill('ink')},
               {'op': 'rrect', 'rect': [-6.5, -16, 13, 9], 'radius': 4, 'paint': fill('accent')}], translate=[52, 84], rotate=-0.35),
        group([{'op': 'rrect', 'rect': [-6.5, -16, 13, 32], 'radius': 6.5, 'paint': fill('ink')},
               {'op': 'rrect', 'rect': [-6.5, -16, 13, 9], 'radius': 4, 'paint': fill('accent')}], translate=[150, 84], rotate=0.35),
        group([circle(62, 104, 7, fill('flame')), circle(140, 104, 7, fill('flame'))], opacity=0.3),
        star4(164, 36, 10, 'brand'),
        star4(36, 44, 7, 'flameLight'),
        circle(180, 72, 4, fill('accentDeep')),
        circle(22, 100, 3, fill('brandBright')),
    ]


# --- record: a medal ----------------------------------------------------------------------------------------

def record_any():
    """100 x 120. A medal on its ribbon."""
    star = 'M50 56 L55.6 68.2 L69 69.8 L59.1 78.9 L61.8 92.2 L50 85.6 L38.2 92.2 L40.9 78.9 L31 69.8 L44.4 68.2 Z'
    return [
        path('M30 4 L48 4 L58 44 L40 44 Z', fill('brand')),
        path('M70 4 L52 4 L42 44 L60 44 Z', fill('brandBright')),
        group([oval(24, 106, 52, 8, fill('goldDeep'))], opacity=0.25),
        circle(50, 74, 34, grad([(0, 'gold'), (1, 'goldDeep')])),
        circle(50, 74, 26, stroke('#FFFFFFFF', 2.5)),
        path(star, [fill('#FFFFFFFF'), stroke('#FFFFFFFF', 2)]),
        star4(88, 40, 6, 'gold'),
        star4(10, 56, 4.5, 'goldDeep'),
    ]


# role -> audience -> (viewBox, ops)
ART = {
    'hero': {'adult': ([240, 240], hero_adult), 'kid': ([240, 240], hero_kid)},
    'streak': {'adult': ([100, 124], streak_adult), 'kid': ([100, 124], streak_kid)},
    'empty': {'adult': ([200, 160], empty_adult), 'kid': ([200, 160], empty_kid)},
    'record': {'adult': ([100, 120], record_any), 'kid': ([100, 120], record_any)},
}


def paint(role, audience):
    view, fn = ART[role][audience]
    return {'viewBox': view, 'fit': 'contain', 'painter': fn()}

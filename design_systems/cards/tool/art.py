"""The Cards media, drawn: customPaint draw lists colored by theme tokens (no image files).

Three families, each a dict of name -> list of draw ops:

- GLYPHS (view box 120 x 120): products and food on a soft toned ground: shoe, mug, tote, box, beans, laptop,
  banana, milk, bread, eggs, cheese, apple.
- SCENES (view box 160 x 120, drawn to cover): travel scenes in a time-of-day palette: mountain, harbor, skyline,
  dunes, forest, lagoon, market, festival, train, temple, bamboo.
- WEATHER (view box 96 x 96): sun, partly, cloud, rain, storm, night.

A color is a theme token read when the list draws (`${theme.colors.<name>}`), or one of the palette variables
the Media block computes from its tone: A, B (the ground), M (mid), K (deep ink) for glyphs; s1, s2 (sky), orb,
far, mid, near, lit for scenes. A theme color's bare name draws nothing inside a customPaint paint, and a
gradient's stops take no expression unless the whole paint is one expression: hence `T`, `stroke` and `grad`.
"""

VARS = {'A', 'B', 'M', 'K', 's1', 's2', 'orb', 'far', 'mid', 'near', 'lit'}


def _f(name):
    """A color inside a formula."""
    if name.startswith('#'):
        return "'%s'" % name
    return name if name in VARS else 'theme.colors.%s' % name


def T(name):
    """A color as a paint."""
    return name if name.startswith('#') else '${%s}' % _f(name)


def fill(color):
    return T(color)


def stroke(color, width, cap='round', join='round', dash=None):
    p = {'color': T(color), 'style': 'stroke', 'strokeWidth': width, 'strokeCap': cap, 'strokeJoin': join}
    if dash:
        p['dashPattern'] = dash
    return p


def grad(stops, begin='topCenter', end='bottomCenter'):
    """A linear gradient paint whose stops are theme colors or palette variables: the whole paint is one expression."""
    s = ', '.join("{'position': %g, 'color': %s}" % (p, _f(c)) for p, c in stops)
    return "${= {'shader': {'type': 'linear', 'begin': '%s', 'end': '%s', 'stops': [%s]}}}" % (begin, end, s)


def path(d, paint, **k):
    return {'op': 'path', 'd': d, 'paint': paint, **k}


def circle(x, y, r, paint):
    return {'op': 'circle', 'c': [x, y], 'radius': r, 'paint': paint}


def oval(x, y, w, h, paint):
    return {'op': 'oval', 'rect': [x, y, w, h], 'paint': paint}


def rect(x, y, w, h, paint):
    return {'op': 'rect', 'rect': [x, y, w, h], 'paint': paint}


def rrect(x, y, w, h, r, paint):
    return {'op': 'rrect', 'rect': [x, y, w, h], 'radius': r, 'paint': paint}


def line(x1, y1, x2, y2, paint):
    return {'op': 'line', 'p1': [x1, y1], 'p2': [x2, y2], 'paint': paint}


def group(ops, **k):
    return {'op': 'group', 'ops': ops, **k}


def faded(opacity, *ops):
    return group(list(ops), opacity=opacity)


def poly(points, paint):
    return path('M' + ' L'.join('%g %g' % p for p in points) + ' Z', paint)


# --- glyphs: 120 x 120 ------------------------------------------------------------------------------------

def _ground(y=96, w=76):
    return oval(60 - w / 2, y, w, 9, fill('artShadow'))


def shoe():
    return [
        _ground(93, 96),
        # sole
        path('M12 80 L108 80 Q112 80 112 84 Q112 92 102 92 L22 92 Q12 92 12 84 Z', fill('artWhite')),
        line(20, 86.5, 104, 86.5, stroke('M', 2)),
        # upper
        path('M14 80 L14 58 C14 46 20 38 30 38 C35 38 37 43 39 48 C42 56 50 59 57 56 L64 51 C72 60 86 67 98 70 '
             'C105 72 110 76 110 80 Z', fill('M')),
        # heel counter and toe cap
        path('M14 80 L14 58 C14 46 20 38 30 38 L31 50 C25 53 23 60 24 68 L28 80 Z', fill('K')),
        faded(0.32, path('M90 67 C100 70 110 75 110 80 L86 80 C86 75 87 70 90 67 Z', fill('K'))),
        # the stripe
        path('M30 76 C50 77 68 70 82 60 L86 64 C72 76 52 81 30 80 Z', fill('artWhite')),
        # collar lining
        path('M30 38 C35 38 37 43 39 48 C42 56 50 59 57 56 L60 54 C52 62 40 60 36 52 C34 48 33 43 30 42 Z', fill('artWhite')),
        # laces
        line(66, 54, 60, 61, stroke('artWhite', 3)), line(74, 59, 68, 66, stroke('artWhite', 3)),
        line(82, 63, 76, 70, stroke('artWhite', 3)),
    ]


def mug():
    return [
        _ground(96, 70),
        path('M80 50 C100 50 100 80 80 80', stroke('K', 8)),
        path('M34 40 L84 40 L84 78 C84 90 76 96 66 96 L52 96 C42 96 34 90 34 78 Z', fill('M')),
        faded(0.28, path('M70 40 L84 40 L84 78 C84 90 76 96 66 96 L60 96 C68 92 70 84 70 76 Z', fill('K'))),
        oval(34, 33, 50, 14, fill('artWhite')),
        oval(38, 35.5, 42, 9, fill('K')),
        faded(0.55, rrect(41, 52, 6, 30, 3, fill('artWhite'))),
        faded(0.5, path('M50 26 C45 20 55 16 50 9', stroke('K', 3.2)), path('M66 26 C61 20 71 16 66 9', stroke('K', 3.2))),
    ]


def tote():
    return [
        _ground(101, 80),
        path('M44 48 C44 18 76 18 76 48', stroke('K', 5.5)),
        path('M28 44 L92 44 L98 96 C98 101 95 104 90 104 L30 104 C25 104 22 101 22 96 Z', fill('M')),
        faded(0.25, path('M28 44 L92 44 L93 54 L27 54 Z', fill('K'))),
        faded(0.22, path('M80 44 L92 44 L98 96 C98 101 95 104 90 104 L82 104 Z', fill('K'))),
        rrect(46, 66, 28, 20, 5, fill('artWhite')),
        line(52, 73, 68, 73, stroke('M', 2.5)), line(52, 79, 62, 79, stroke('M', 2.5)),
        circle(44, 49, 2.6, fill('artWhite')), circle(76, 49, 2.6, fill('artWhite')),
    ]


def parcel():
    return [
        _ground(100, 84),
        rrect(24, 46, 72, 54, 6, fill('M')),
        faded(0.2, path('M76 46 L90 46 Q96 46 96 52 L96 94 Q96 100 90 100 L76 100 Z', fill('K'))),
        path('M20 34 L100 34 Q104 34 103 38 L100 48 L20 48 L17 38 Q16 34 20 34 Z', fill('K')),
        rect(53, 34, 14, 66, fill('artShine')),
        rrect(32, 76, 22, 14, 3, fill('artWhite')),
        line(36, 81, 50, 81, stroke('M', 2)), line(36, 86, 45, 86, stroke('M', 2)),
    ]


def beans():
    bean = [oval(-7, -10, 14, 20, fill('K')), path('M-1 -8 C4 -3 -4 3 1 8', stroke('artWhite', 1.8))]
    return [
        _ground(101, 66),
        path('M36 30 L84 30 L89 98 C89 102 87 104 84 104 L36 104 C33 104 31 102 31 98 Z', fill('M')),
        faded(0.2, path('M72 30 L84 30 L89 98 C89 102 87 104 84 104 L76 104 Z', fill('K'))),
        rrect(34, 20, 52, 13, 3, fill('K')),
        line(40, 26.5, 80, 26.5, stroke('M', 1.6, dash=[3, 4])),
        circle(60, 68, 19, fill('artWhite')),
        group(bean, translate=[60, 68], rotate=0.5),
    ]


def laptop():
    return [
        _ground(96, 96),
        rrect(26, 30, 68, 50, 6, fill('K')),
        rrect(30, 34, 60, 42, 3, grad([(0, 'M'), (1, 'B')], 'topLeft', 'bottomRight')),
        faded(0.5, poly([(30, 76), (58, 34), (72, 34), (44, 76)], fill('artShine'))),
        rrect(38, 44, 22, 5, 2.5, fill('artWhite')), rrect(38, 54, 34, 4, 2, fill('artShine')),
        rrect(38, 62, 26, 4, 2, fill('artShine')),
        path('M14 82 L106 82 L102 91 C101 93 99 94 96 94 L24 94 C21 94 19 93 18 91 Z', fill('slateMid')),
        rrect(50, 82, 20, 4, 2, fill('slateInk')),
    ]


def banana():
    return [
        _ground(98, 80),
        path('M22 46 C24 80 60 104 100 82 C97 95 80 108 58 104 C34 100 18 74 18 50 Z', fill('sunDeep')),
        path('M24 40 C30 76 66 96 102 76 C100 84 96 88 92 90 C62 100 32 84 22 46 Z', fill('sun')),
        path('M24 40 L20 30 L27 28 L29 39 Z', fill('sandInk')),
        circle(101, 79, 3, fill('sandInk')),
        faded(0.6, path('M33 58 C42 76 62 86 82 84', stroke('artWhite', 3))),
    ]


def milk():
    return [
        _ground(101, 56),
        rect(40, 46, 40, 56, fill('artWhite')),
        rect(68, 46, 12, 56, fill('cloudShade')),
        poly([(40, 46), (50, 30), (72, 30), (80, 46)], fill('cloudShade')),
        poly([(40, 46), (50, 30), (60, 30), (68, 46)], fill('artWhite')),
        rrect(48, 22, 26, 9, 2, fill('skyMid')),
        rect(40, 62, 40, 24, fill('skyMid')),
        rect(68, 62, 12, 24, fill('skyInk')),
        path('M54 68 C50 74 49 77 49 79 C49 82 51 84 54 84 C57 84 59 82 59 79 C59 77 58 74 54 68 Z', fill('artWhite')),
    ]


def bread():
    return [
        _ground(99, 84),
        path('M22 62 C22 46 38 38 60 38 C82 38 98 46 98 62 C98 68 95 71 92 72 L92 94 C92 98 90 100 86 100 L34 100 '
             'C30 100 28 98 28 94 L28 72 C25 71 22 68 22 62 Z', fill('sandMid')),
        path('M28 84 L92 84 L92 94 C92 98 90 100 86 100 L34 100 C30 100 28 98 28 94 Z', fill('sandInk')),
        faded(0.85, line(44, 50, 52, 62, stroke('sandA', 4)), line(58, 48, 66, 60, stroke('sandA', 4)),
              line(72, 50, 80, 62, stroke('sandA', 4))),
        faded(0.35, path('M30 60 C32 50 44 44 58 44', stroke('artWhite', 3))),
    ]


def eggs():
    def egg(x, y):
        return [path('M%g %g C%g %g %g %g %g %g C%g %g %g %g %g %g C%g %g %g %g %g %g C%g %g %g %g %g %g Z' % (
            x, y - 15, x + 7, y - 15, x + 11, y - 4, x + 11, y + 3, x + 11, y + 10, x + 6, y + 14, x, y + 14,
            x - 6, y + 14, x - 11, y + 10, x - 11, y + 3, x - 11, y - 4, x - 7, y - 15, x, y - 15), fill('artWhite')),
                faded(0.55, path('M%g %g C%g %g %g %g %g %g' % (x - 5, y - 6, x - 4, y - 9, x - 2, y - 11, x, y - 11), stroke('sandB', 2.2)))]
    return [
        _ground(99, 90),
        *egg(34, 54), *egg(60, 51), *egg(86, 54),
        path('M14 62 L106 62 L101 92 C100 97 97 100 92 100 L28 100 C23 100 20 97 19 92 Z', fill('M')),
        faded(0.22, path('M14 62 L106 62 L104 72 L16 72 Z', fill('K'))),
        *[faded(0.9, path('M%g 62 C%g 72 %g 72 %g 62 Z' % (x - 12, x - 10, x + 10, x + 12), fill('artWhite'))) for x in (34, 60, 86)],
        faded(0.35, line(26, 88, 94, 88, stroke('artWhite', 2.5))),
    ]


def cheese():
    return [
        _ground(97, 88),
        poly([(18, 74), (92, 48), (104, 60), (30, 82)], fill('sandA')),
        path('M18 74 L30 82 L104 60 L104 92 Q104 96 100 96 L22 96 Q18 96 18 92 Z', fill('sun')),
        poly([(18, 74), (30, 82), (30, 96), (22, 96), (18, 92)], fill('sunDeep')),
        circle(48, 87, 5, fill('sunDeep')), circle(72, 80, 6.5, fill('sunDeep')), circle(92, 86, 4, fill('sunDeep')),
        circle(60, 70, 3, fill('sandB')), circle(84, 60, 3.5, fill('sandB')),
    ]


def apple():
    return [
        _ground(99, 64),
        path('M60 46 C50 36 28 40 28 64 C28 84 42 102 52 102 C56 102 58 100 60 100 C62 100 64 102 68 102 '
             'C78 102 92 84 92 64 C92 40 70 36 60 46 Z', fill('bad')),
        faded(0.3, path('M60 46 C70 36 92 40 92 64 C92 84 78 102 68 102 C76 92 82 78 80 62 C79 52 70 46 60 46 Z', fill('badDeep'))),
        path('M60 46 C60 38 62 32 66 28', stroke('sandInk', 3.5)),
        path('M66 34 C72 24 84 24 88 28 C84 38 72 40 66 34 Z', fill('good')),
        faded(0.55, path('M38 60 C40 52 46 48 52 48', stroke('artWhite', 3.5))),
    ]


GLYPHS = {'shoe': shoe, 'mug': mug, 'tote': tote, 'box': parcel, 'beans': beans, 'laptop': laptop,
          'banana': banana, 'milk': milk, 'bread': bread, 'eggs': eggs, 'cheese': cheese, 'apple': apple}
GLYPH_TONE = {'shoe': 'lilac', 'mug': 'rose', 'tote': 'mint', 'box': 'sand', 'beans': 'sand', 'laptop': 'sky',
              'banana': 'sand', 'milk': 'sky', 'bread': 'rose', 'eggs': 'mint', 'cheese': 'lilac', 'apple': 'mint'}


# --- scenes: 160 x 120, drawn to cover ----------------------------------------------------------------------

def _sky():
    return rect(-40, -40, 240, 200, grad([(0.2, 's1'), (0.75, 's2')]))


def _orb(x, y, r, glow=True):
    ops = []
    if glow:
        ops.append(faded(0.22, circle(x, y, r * 2.1, fill('orb'))))
        ops.append(faded(0.3, circle(x, y, r * 1.5, fill('orb'))))
    ops.append(circle(x, y, r, fill('orb')))
    return ops


def _pine(x, base, h, color):
    w = h * 0.42
    return [poly([(x, base - h), (x + w * 0.55, base - h * 0.52), (x - w * 0.55, base - h * 0.52)], fill(color)),
            poly([(x, base - h * 0.74), (x + w * 0.8, base - h * 0.22), (x - w * 0.8, base - h * 0.22)], fill(color)),
            poly([(x, base - h * 0.46), (x + w, base), (x - w, base)], fill(color))]


def _stars(points):
    return faded(0.8, *[circle(x, y, r, fill('lit')) for x, y, r in points])


def mountain():
    return [
        _sky(), *_orb(116, 38, 12),
        faded(0.55, path('M0 74 L22 56 L40 66 L62 44 L86 68 L110 52 L132 66 L160 50 L160 120 L0 120 Z', fill('far'))),
        path('M-10 96 L34 50 L52 70 L84 30 L118 72 L134 60 L170 96 L170 120 L-10 120 Z', fill('far')),
        path('M84 30 L96 45 L90 42 L85 49 L79 43 L72 46 Z', fill('lit')),
        path('M34 50 L42 59 L37 57 L33 62 L28 57 Z', fill('lit')),
        path('M0 92 C30 80 58 86 88 94 C118 102 140 90 160 86 L160 120 L0 120 Z', fill('mid')),
        *_pine(22, 108, 26, 'near'), *_pine(38, 110, 20, 'near'), *_pine(134, 106, 24, 'near'), *_pine(148, 108, 30, 'near'),
        path('M0 106 C40 98 100 112 160 102 L160 120 L0 120 Z', fill('near')),
    ]


def harbor():
    return [
        _sky(), *_orb(76, 66, 15),
        faded(0.7, path('M0 70 L0 58 C18 52 40 58 58 70 Z', fill('far')), path('M112 70 C128 60 148 58 160 62 L160 70 Z', fill('far'))),
        rect(-10, 70, 180, 60, grad([(0, 'far'), (0.9, 'mid')])),
        faded(0.75, line(62, 76, 90, 76, stroke('orb', 2)), line(56, 83, 96, 83, stroke('orb', 2)),
              line(66, 90, 86, 90, stroke('orb', 2)), line(70, 97, 82, 97, stroke('orb', 2))),
        # the boat
        line(116, 50, 116, 86, stroke('near', 1.8)),
        poly([(118, 54), (118, 82), (136, 82)], fill('lit')),
        poly([(114, 60), (114, 82), (102, 82)], fill('artWhite')),
        path('M98 86 L138 86 L132 96 C131 97 130 98 128 98 L106 98 C104 98 103 97 102 96 Z', fill('near')),
        faded(0.4, line(100, 102, 136, 102, stroke('near', 2))),
        # the quay
        path('M0 104 L46 104 L46 108 L42 108 L42 120 L0 120 Z', fill('near')),
        rect(12, 96, 4, 10, fill('near')), rect(30, 96, 4, 10, fill('near')),
        faded(0.8, circle(14, 94, 2.5, fill('lit')), circle(32, 94, 2.5, fill('lit'))),
    ]


def skyline():
    far = [(4, 60, 16), (22, 48, 14), (38, 66, 12), (52, 40, 16), (70, 58, 14), (86, 34, 12), (100, 52, 18), (120, 44, 14), (136, 62, 22)]
    near = [(-4, 84, 22), (20, 72, 18), (40, 90, 16), (58, 66, 20), (80, 82, 18), (100, 70, 16), (118, 88, 20), (140, 76, 24)]
    wins = [(24, 78), (30, 78), (24, 86), (62, 72), (70, 72), (62, 80), (70, 88), (104, 76), (110, 84), (146, 82), (152, 82),
            (146, 92), (84, 90), (4, 92), (10, 100), (124, 96)]
    return [
        _sky(), *_orb(124, 28, 9), _stars([(20, 18, 1), (44, 30, 0.8), (70, 14, 1), (96, 26, 0.8), (150, 14, 1), (58, 24, 0.7)]),
        *[rect(x, y, w, 120 - y, fill('far')) for x, y, w in far],
        rect(91, 24, 2, 12, fill('far')), poly([(52, 40), (60, 30), (68, 40)], fill('far')),
        faded(0.6, rect(-10, 100, 180, 20, fill('mid'))),
        *[rect(x, y, w, 120 - y, fill('near')) for x, y, w in near],
        faded(0.9, *[rrect(x, y, 3, 4, 0.6, fill('lit')) for x, y in wins]),
    ]


def dunes():
    return [
        _sky(), *_orb(40, 36, 13),
        faded(0.6, path('M0 78 C30 60 60 62 92 76 C116 66 140 62 160 70 L160 120 L0 120 Z', fill('far'))),
        path('M0 90 C36 70 70 66 104 86 C124 78 144 76 160 82 L160 120 L0 120 Z', fill('far')),
        faded(0.5, path('M40 78 C66 66 86 72 104 86 C82 82 62 80 40 78 Z', fill('lit'))),
        path('M0 104 C30 84 70 80 112 100 C132 92 148 92 160 96 L160 120 L0 120 Z', fill('mid')),
        faded(0.35, path('M50 88 C76 82 96 90 112 100 C90 96 70 92 50 88 Z', fill('lit'))),
        path('M0 116 C40 100 90 100 130 112 C142 110 152 110 160 112 L160 120 L0 120 Z', fill('near')),
        # a caravan on the crest
        *[g for x in (118, 128, 138) for g in (rrect(x, 88 - (x - 118) * 0.25, 6, 3.4, 1.4, fill('near')),
                                              line(x + 1, 91 - (x - 118) * 0.25, x + 1, 95 - (x - 118) * 0.25, stroke('near', 1)),
                                              line(x + 5, 91 - (x - 118) * 0.25, x + 5, 95 - (x - 118) * 0.25, stroke('near', 1)),
                                              line(x + 6, 89 - (x - 118) * 0.25, x + 8, 86 - (x - 118) * 0.25, stroke('near', 1.2)))],
    ]


def forest():
    return [
        _sky(), *_orb(118, 30, 11),
        faded(0.55, path('M0 70 C30 56 60 60 88 68 C116 76 140 62 160 58 L160 120 L0 120 Z', fill('far'))),
        *[g for x, h in ((10, 30), (26, 38), (44, 30), (62, 40), (82, 32), (100, 40), (120, 34), (140, 40), (156, 30))
          for g in _pine(x, 92, h, 'far')],
        rect(-10, 90, 180, 40, fill('far')),
        *[g for x, h in ((0, 44), (20, 54), (46, 46), (112, 50), (134, 58), (156, 46)) for g in _pine(x, 108, h, 'mid')],
        path('M0 104 C40 98 60 102 80 106 C100 102 130 98 160 104 L160 120 L0 120 Z', fill('mid')),
        faded(0.55, path('M66 120 C70 110 76 104 80 98 C84 104 90 110 96 120 Z', fill('lit'))),
        *_pine(8, 124, 60, 'near'), *_pine(150, 126, 66, 'near'),
    ]


def lagoon():
    frond = lambda d: path(d, stroke('near', 3.2))
    return [
        _sky(), *_orb(110, 34, 13),
        faded(0.7, path('M96 72 C112 60 140 60 160 68 L160 74 L96 74 Z', fill('far'))),
        rect(-10, 72, 180, 50, grad([(0, 'far'), (1, 'mid')])),
        faded(0.6, line(96, 80, 124, 80, stroke('lit', 1.6)), line(88, 88, 130, 88, stroke('lit', 1.6)),
              line(102, 96, 118, 96, stroke('lit', 1.6))),
        faded(0.9, path('M0 98 C30 88 70 92 96 108 C110 116 120 118 130 120 L0 120 Z', fill('lit'))),
        faded(0.5, path('M0 106 C26 98 60 102 84 114 C90 117 96 119 100 120 L0 120 Z', fill('orb'))),
        # the palm
        path('M34 106 C36 84 42 66 52 50', stroke('near', 4.5)),
        frond('M52 50 C40 42 28 44 20 52'), frond('M52 50 C46 36 34 30 24 32'), frond('M52 50 C56 36 68 30 80 34'),
        frond('M52 50 C64 44 76 48 84 58'), frond('M52 50 C54 60 50 70 44 76'),
        circle(51, 53, 2.6, fill('near')), circle(55, 54, 2.2, fill('near')),
    ]


def market():
    houses = [(-6, 50, 30, 'far'), (24, 42, 26, 'mid'), (50, 54, 28, 'far'), (78, 40, 28, 'mid'), (106, 52, 26, 'far'), (132, 44, 34, 'mid')]
    ops = [_sky(), *_orb(132, 24, 9)]
    for x, y, w, c in houses:
        ops.append(poly([(x, y), (x + w / 2, y - 14), (x + w, y)], fill('near')))
        ops.append(rect(x, y, w, 120 - y, fill(c)))
        for wx in (x + w * 0.22, x + w * 0.62):
            ops.append(rrect(wx, y + 8, w * 0.17, 9, 1.5, fill('lit')))
            ops.append(rrect(wx, y + 24, w * 0.17, 9, 1.5, fill('lit')))
    # awnings and stalls
    for x, c in ((2, 'lit'), (40, 'artWhite'), (80, 'lit'), (120, 'artWhite')):
        ops.append(path('M%g 84 L%g 84 L%g 94 Q%g 98 %g 94 Q%g 98 %g 94 Q%g 98 %g 94 Z' % (
            x, x + 36, x + 36, x + 30, x + 24, x + 18, x + 12, x + 6, x), fill(c)))
        ops.append(rect(x + 3, 94, 2, 16, fill('near')))
        ops.append(rect(x + 31, 94, 2, 16, fill('near')))
        ops.append(rrect(x + 6, 100, 24, 8, 2, fill('near')))
    ops.append(rect(-10, 108, 180, 14, fill('near')))
    return ops


def festival():
    def burst(x, y, r, color):
        import math
        return faded(0.9, *[line(x + math.cos(a) * r * 0.35, y + math.sin(a) * r * 0.35, x + math.cos(a) * r, y + math.sin(a) * r,
                                 stroke(color, 1.6)) for a in [i * math.pi / 5 for i in range(10)]], circle(x, y, 1.6, fill(color)))
    lights = [(8 + i * 13, 58 + 9 * (1 - abs((i % 6) - 2.5) / 2.5)) for i in range(12)]
    return [
        _sky(), _stars([(14, 12, 0.9), (66, 8, 0.8), (150, 24, 0.9), (98, 16, 0.7)]),
        burst(44, 30, 16, 'lit'), burst(112, 24, 20, 'orb'), burst(84, 46, 10, 'far'),
        path('M0 56 Q39 76 78 56 Q117 76 160 54', stroke('near', 1.2)),
        *[circle(x, y, 2.4, fill('lit')) for x, y in lights],
        # tents
        poly([(8, 104), (34, 70), (60, 104)], fill('far')), poly([(34, 70), (44, 104), (24, 104)], fill('mid')),
        poly([(96, 104), (124, 66), (152, 104)], fill('far')), poly([(124, 66), (136, 104), (112, 104)], fill('mid')),
        line(34, 70, 34, 62, stroke('near', 1.4)), poly([(34, 62), (42, 65), (34, 68)], fill('lit')),
        line(124, 66, 124, 58, stroke('near', 1.4)), poly([(124, 58), (132, 61), (124, 64)], fill('lit')),
        rect(-10, 104, 180, 20, fill('near')),
        # the crowd
        *[g for x in (66, 74, 82, 90) for g in (circle(x, 98, 2.6, fill('near')), rrect(x - 2.6, 100, 5.2, 8, 2, fill('near')))],
    ]


def train():
    return [
        _sky(), *_orb(30, 26, 8), _stars([(60, 14, 0.9), (88, 26, 0.7), (120, 12, 1), (146, 30, 0.8), (104, 40, 0.6)]),
        faded(0.6, path('M0 78 L30 52 L54 72 L86 44 L116 70 L138 56 L160 72 L160 120 L0 120 Z', fill('far'))),
        path('M0 96 C40 82 70 86 100 92 C126 98 146 90 160 88 L160 120 L0 120 Z', fill('mid')),
        # the viaduct
        rect(-10, 78, 180, 7, fill('near')),
        *[path('M%g 85 L%g 120 L%g 120 L%g 100 Q%g 88 %g 100 L%g 120 L%g 120 L%g 85 Z' % (
            x, x, x + 6, x + 6, x + 20, x + 34, x + 34, x + 40, x + 40), fill('near')) for x in (-14, 26, 66, 106, 146)],
        # the train
        rrect(46, 66, 44, 12, 3, fill('far')), rrect(92, 66, 44, 12, 3, fill('far')),
        path('M138 78 L138 66 L150 66 C156 66 160 72 160 78 Z', fill('far')),
        *[rrect(x, 69, 6, 4.5, 1, fill('lit')) for x in (50, 59, 68, 77, 96, 105, 114, 123, 141)],
        faded(0.5, path('M150 60 C146 54 152 50 148 44', stroke('artWhite', 2.2))),
    ]


def temple():
    def roof(y, w):
        return path('M%g %g Q%g %g %g %g L%g %g Q%g %g %g %g Z' % (
            104 - w, y, 104 - w * 0.5, y - 2, 104 - w * 0.42, y - 9, 104 + w * 0.42, y - 9, 104 + w * 0.5, y - 2, 104 + w, y), fill('near'))
    return [
        _sky(), *_orb(46, 40, 14),
        faded(0.55, path('M0 82 C26 64 50 66 76 78 C104 66 130 62 160 74 L160 120 L0 120 Z', fill('far'))),
        path('M0 98 C36 86 64 88 92 96 C120 90 142 90 160 94 L160 120 L0 120 Z', fill('mid')),
        # the pagoda
        line(104, 22, 104, 34, stroke('near', 1.8)),
        roof(44, 16), rect(95, 44, 18, 10, fill('far')),
        roof(64, 21), rect(92, 64, 24, 10, fill('far')),
        roof(84, 26), rect(89, 84, 30, 14, fill('far')),
        rect(101, 88, 6, 10, fill('lit')),
        # a torii
        rect(22, 86, 3.5, 24, fill('bad')), rect(44, 86, 3.5, 24, fill('bad')),
        path('M14 80 Q35 85 56 80 L55 86 Q35 90 15 86 Z', fill('bad')), rect(19, 91, 32, 3, fill('bad')),
        path('M0 108 C50 100 110 104 160 108 L160 120 L0 120 Z', fill('near')),
        *_pine(140, 110, 26, 'near'), *_pine(152, 112, 20, 'near'),
    ]


def bamboo():
    stalks = [(10, 6, 'far'), (26, 5, 'far'), (48, 7, 'mid'), (70, 5, 'far'), (92, 8, 'mid'), (116, 5, 'far'), (134, 7, 'mid'), (152, 6, 'far')]
    ops = [_sky(), faded(0.5, circle(80, 30, 46, fill('orb')))]
    for x, w, c in stalks:
        ops.append(rrect(x - w / 2, -6, w, 132, 1.5, fill(c)))
        for y in (18, 46, 74, 102):
            ops.append(faded(0.5, line(x - w / 2, y + (x % 9), x + w / 2, y + (x % 9), stroke('lit', 1.2))))
    for x, y, r in ((34, 24, -0.5), (60, 40, 0.4), (104, 20, -0.4), (126, 44, 0.5), (18, 60, 0.3), (146, 70, -0.5)):
        ops.append(group([path('M0 0 C6 -5 14 -5 20 0 C14 3 6 3 0 0 Z', fill('near'))], translate=[x, y], rotate=r))
    ops.append(faded(0.5, path('M54 120 C62 100 72 88 80 80 C88 88 98 100 106 120 Z', fill('lit'))))
    ops.append(path('M0 112 C40 106 60 110 80 112 C100 110 120 106 160 112 L160 120 L0 120 Z', fill('near')))
    return ops


SCENES = {'mountain': mountain, 'harbor': harbor, 'skyline': skyline, 'dunes': dunes, 'forest': forest, 'lagoon': lagoon,
          'market': market, 'festival': festival, 'train': train, 'temple': temple, 'bamboo': bamboo}
SCENE_TONE = {'mountain': 'dawn', 'harbor': 'dawn', 'skyline': 'dusk', 'dunes': 'dusk', 'forest': 'day', 'lagoon': 'day',
              'market': 'dawn', 'festival': 'night', 'train': 'night', 'temple': 'dawn', 'bamboo': 'day'}


# --- weather: 96 x 96 -------------------------------------------------------------------------------------

CLOUD = 'M28 70 C17 70 10 62 10 53 C10 44 17 37 26 37 C28 27 37 20 48 20 C60 20 70 28 72 40 C81 40 88 47 88 56 C88 64 82 70 73 70 Z'


def _sun(x=48, y=48, r=17, rays=True):
    import math
    ops = [faded(0.5, circle(x, y, r * 2.05, fill('sunGlow'))), faded(0.8, circle(x, y, r * 1.5, fill('sunGlow')))]
    if rays:
        ops += [line(x + math.cos(a) * r * 1.5, y + math.sin(a) * r * 1.5, x + math.cos(a) * r * 1.95, y + math.sin(a) * r * 1.95,
                     stroke('sun', 3.4)) for a in [i * math.pi / 4 for i in range(8)]]
    ops.append(circle(x, y, r, grad([(0, 'sun'), (1, 'sunDeep')], 'topLeft', 'bottomRight')))
    return ops


def _cloud(dx=0, dy=0, s=1.0, dark=False):
    top, bottom = ('cloudShade', 'cloudDark') if dark else ('cloud', 'cloudShade')
    return group([faded(0.25, path(CLOUD, fill('artShadow'), )), ], translate=[dx, dy + 4 * s], scale=s), \
        group([path(CLOUD, grad([(0.3, top), (1, bottom)]))], translate=[dx, dy], scale=s)


def w_sun():
    return _sun()


def w_partly():
    return [*_sun(62, 34, 14), *_cloud(2, 16, 0.86)]


def w_cloud():
    return [group([path(CLOUD, fill('cloudDark'))], translate=[30, 4], scale=0.62, opacity=0.8), *_cloud(0, 12, 0.92)]


def w_rain():
    return [*_cloud(4, -2, 0.9, dark=True),
            line(30, 72, 25, 84, stroke('rain', 4)), line(48, 72, 43, 88, stroke('rain', 4)), line(66, 72, 61, 84, stroke('rain', 4))]


def w_storm():
    return [*_cloud(4, -2, 0.9, dark=True),
            poly([(50, 62), (38, 80), (47, 80), (42, 94), (60, 74), (50, 74), (56, 62)], fill('sun')),
            line(26, 72, 22, 82, stroke('rain', 4)), line(70, 72, 66, 82, stroke('rain', 4))]


def w_night():
    return [faded(0.35, circle(52, 44, 30, fill('sunGlow'))),
            path('M62 20 C46 22 36 36 38 52 C40 66 52 76 66 76 C74 76 80 73 84 68 C68 70 56 60 56 44 C56 34 58 26 62 20 Z', fill('moon')),
            circle(24, 28, 2, fill('moon')), circle(76, 30, 1.6, fill('moon')), circle(30, 66, 1.4, fill('moon'))]


WEATHER = {'sun': w_sun, 'partly': w_partly, 'cloud': w_cloud, 'rain': w_rain, 'storm': w_storm, 'night': w_night}


def weather_paint(kind):
    return {'viewBox': [96, 96], 'fit': 'contain', 'painter': WEATHER[kind]()}


def glyph_paint(kind):
    return {'viewBox': [120, 120], 'fit': 'contain', 'painter': GLYPHS[kind]()}


def scene_paint(kind):
    return {'viewBox': [160, 120], 'fit': 'cover', 'painter': SCENES[kind]()}

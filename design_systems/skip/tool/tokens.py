"""Skip's tokens: the default set and the two variants (pink, athlete).

One dict per set. `build.py` merges the default into design_system.json's theme (over the SSUI-derived base) and
writes the variants as theme overrides (themes/<id>.json) a site puts in its `theme`.
"""

# What a set must give: every color the blocks and illustrations name, the roles the standard controls read,
# and (optionally) radii, shadows and text style changes.

DEFAULT = {
    'brand': {'primary': '#5B3DF5', 'ink': '#15122E', 'surface': '#FFFFFF'},
    'colors': {
        # surfaces and ink
        'page': '#FFF4F3FB', 'card': '#FFFFFFFF', 'ink': '#FF15122E', 'inkSoft': '#FF5E5A7A', 'inkFaint': '#FF9793B0',
        'line': '#FFE9E7F5', 'track': '#FFE8E5F7',
        # the brand and its accent
        'brand': '#FF5B3DF5', 'brandDeep': '#FF3A1FC4', 'brandBright': '#FF8468FF', 'brandTint': '#FFECE8FF',
        'onBrand': '#FFFFFFFF', 'accent': '#FFD6FF3F', 'accentDeep': '#FFA8E000', 'onAccent': '#FF15122E',
        # the hero surface (a gradient from heroA to heroB with a glow) and what sits on it
        'heroA': '#FF7352FF', 'heroB': '#FF3A1FCB', 'heroGlow': '#FFA791FF', 'heroLine': '#33FFFFFF',
        'onHero': '#FFFFFFFF', 'onHeroSoft': '#FFDCD5FF', 'heroChip': '#29FFFFFF',
        'heroCta': '#FFFFFFFF', 'onHeroCta': '#FF15122E', 'heroCtaMark': '#FFD6FF3F', 'onHeroCtaMark': '#FF15122E',
        # the streak
        'flame': '#FFFF6B2C', 'flameDeep': '#FFF0381B', 'flameLight': '#FFFFC53D', 'flameTint': '#FFFFF0E6',
        # the dark panel a chart sits on
        'panel': '#FF17132F', 'panelGlow': '#FF3A2A8F', 'onPanel': '#FFFFFFFF', 'onPanelSoft': '#FFA9A4C9',
        'panelBar': '#FF3A3466', 'panelTrack': '#801F1A3B',
        # illustration inks
        'artSkin': '#FFF6B48F', 'artSkinShade': '#FFE39A74', 'artHair': '#FF1C1638', 'artTop': '#FFD6FF3F',
        'artBottom': '#FF15122E', 'artShoe': '#FFFFFFFF', 'artRope': '#FFD6FF3F', 'artHandle': '#FF15122E',
        'artSpark': '#FFFFFFFF', 'artShadow': '#3D0B0540', 'artBlob': '#FFECE8FF', 'artBlobDeep': '#FFDAD2FF',
        'gold': '#FFFFC53D', 'goldDeep': '#FFF59E0B', 'goldTint': '#FFFFF6DC', 'onGold': '#FF4A2E00',
    },
    'radii': {'hero': 32, 'card': 24, 'tile': 22, 'chip': 999, 'cta': 999},
    'shadows': {
        'card': [{'type': 'dropShadow', 'color': '#12261A66', 'offset': [0, 12], 'blurRadius': 28, 'spreadRadius': -10},
                 {'type': 'dropShadow', 'color': '#0A261A66', 'offset': [0, 2], 'blurRadius': 6}],
        'hero': [{'type': 'dropShadow', 'color': '#735B3DF5', 'offset': [0, 22], 'blurRadius': 40, 'spreadRadius': -16}],
        'cta': [{'type': 'dropShadow', 'color': '#40120A40', 'offset': [0, 8], 'blurRadius': 18, 'spreadRadius': -6}],
        'panel': [{'type': 'dropShadow', 'color': '#5917132F', 'offset': [0, 20], 'blurRadius': 36, 'spreadRadius': -16}],
    },
    'display': {},  # changes merged into every display style (a weight, an italic)
}

PINK = {
    'brand': {'primary': '#F0286E', 'ink': '#2B1220', 'surface': '#FFFFFF'},
    'colors': {
        'page': '#FFFFF4F0', 'card': '#FFFFFFFF', 'ink': '#FF2B1220', 'inkSoft': '#FF7A5566', 'inkFaint': '#FFB497A5',
        'line': '#FFF7E4E0', 'track': '#FFF9E2E4',
        'brand': '#FFF0286E', 'brandDeep': '#FFC2185B', 'brandBright': '#FFFF6B9A', 'brandTint': '#FFFFE4EC',
        'onBrand': '#FFFFFFFF', 'accent': '#FFFFE066', 'accentDeep': '#FFFFB800', 'onAccent': '#FF2B1220',
        'heroA': '#FFFF4F93', 'heroB': '#FFFF8442', 'heroGlow': '#FFFFC98A', 'heroLine': '#40FFFFFF',
        'onHero': '#FFFFFFFF', 'onHeroSoft': '#FFFFECEF', 'heroChip': '#33FFFFFF',
        'heroCta': '#FFFFFFFF', 'onHeroCta': '#FF2B1220', 'heroCtaMark': '#FFF0286E', 'onHeroCtaMark': '#FFFFFFFF',
        'flame': '#FFFF6B2C', 'flameDeep': '#FFF0381B', 'flameLight': '#FFFFC53D', 'flameTint': '#FFFFEEE3',
        'panel': '#FF3A1230', 'panelGlow': '#FF8A1F5C', 'onPanel': '#FFFFFFFF', 'onPanelSoft': '#FFE0B4CB',
        'panelBar': '#FF6B2D55', 'panelTrack': '#80471739',
        'artSkin': '#FFFFD2B0', 'artSkinShade': '#FFF2B48C', 'artHair': '#FF4A1D2F', 'artTop': '#FFFFE066',
        'artBottom': '#FF2B1220', 'artShoe': '#FFFFFFFF', 'artRope': '#FFFFE066', 'artHandle': '#FF2B1220',
        'artSpark': '#FFFFFFFF', 'artShadow': '#3D6B0F1E', 'artBlob': '#FFFFE4EC', 'artBlobDeep': '#FFFFD0DD',
        'gold': '#FFFFC53D', 'goldDeep': '#FFF59E0B', 'goldTint': '#FFFFF3D6', 'onGold': '#FF4A2E00',
    },
    'radii': {'hero': 40, 'card': 30, 'tile': 28, 'chip': 999, 'cta': 999},
    'shadows': {
        'card': [{'type': 'dropShadow', 'color': '#14C2185B', 'offset': [0, 12], 'blurRadius': 28, 'spreadRadius': -10},
                 {'type': 'dropShadow', 'color': '#0A5B1230', 'offset': [0, 2], 'blurRadius': 6}],
        'hero': [{'type': 'dropShadow', 'color': '#73FF5A7A', 'offset': [0, 22], 'blurRadius': 40, 'spreadRadius': -16}],
        'cta': [{'type': 'dropShadow', 'color': '#405B1230', 'offset': [0, 8], 'blurRadius': 18, 'spreadRadius': -6}],
        'panel': [{'type': 'dropShadow', 'color': '#593A1230', 'offset': [0, 20], 'blurRadius': 36, 'spreadRadius': -16}],
    },
    'display': {},
}

ATHLETE = {
    'brand': {'primary': '#C8FF00', 'ink': '#FFFFFF', 'surface': '#0A0A0B'},
    'colors': {
        'page': '#FF0A0A0B', 'card': '#FF18181B', 'ink': '#FFFFFFFF', 'inkSoft': '#FFA9A9B2', 'inkFaint': '#FF6F6F7A',
        'line': '#FF27272C', 'track': '#FF2B2B31',
        'brand': '#FFC8FF00', 'brandDeep': '#FF9BD100', 'brandBright': '#FFE2FF66', 'brandTint': '#FF222A0A',
        'onBrand': '#FF0A0A0B', 'accent': '#FFC8FF00', 'accentDeep': '#FF9BD100', 'onAccent': '#FF0A0A0B',
        'heroA': '#FF2A2A30', 'heroB': '#FF121214', 'heroGlow': '#FF4A5A12', 'heroLine': '#24FFFFFF',
        'onHero': '#FFFFFFFF', 'onHeroSoft': '#FFB9B9C2', 'heroChip': '#1FFFFFFF',
        'heroCta': '#FFC8FF00', 'onHeroCta': '#FF0A0A0B', 'heroCtaMark': '#FF0A0A0B', 'onHeroCtaMark': '#FFC8FF00',
        'flame': '#FFFF5A1F', 'flameDeep': '#FFE0320F', 'flameLight': '#FFFFB830', 'flameTint': '#FF2A1710',
        'panel': '#FF18181B', 'panelGlow': '#FF2F3A0C', 'onPanel': '#FFFFFFFF', 'onPanelSoft': '#FF8E8E99',
        'panelBar': '#FF3A3A42', 'panelTrack': '#80202024',
        'artSkin': '#FFE9A681', 'artSkinShade': '#FFCB8662', 'artHair': '#FF52525C', 'artTop': '#FFC8FF00',
        'artBottom': '#FFF4F4F5', 'artShoe': '#FFC8FF00', 'artRope': '#FFC8FF00', 'artHandle': '#FFF4F4F5',
        'artSpark': '#FFFFFFFF', 'artShadow': '#66000000', 'artBlob': '#FF222226', 'artBlobDeep': '#FF2E2E34',
        'gold': '#FFFFC53D', 'goldDeep': '#FFF59E0B', 'goldTint': '#FF2A2210', 'onGold': '#FFFFE9A8',
    },
    'radii': {'hero': 18, 'card': 14, 'tile': 12, 'chip': 6, 'cta': 12},
    'shadows': {
        'card': [],
        'hero': [{'type': 'dropShadow', 'color': '#33C8FF00', 'offset': [0, 18], 'blurRadius': 44, 'spreadRadius': -22}],
        'cta': [],
        'panel': [],
    },
    'display': {'fontStyle': 'italic'},
}

SETS = {'default': DEFAULT, 'pink': PINK, 'athlete': ATHLETE}

# The type scale the blocks name. Roboto only: the weights the platform ships (400, 500, 700, 900).
TEXT_STYLES = {
    'display': {'fontSize': 42, 'fontWeight': 900, 'height': 1.02, 'letterSpacing': -0.9, 'color': 'ink', '_display': True},
    'screenTitle': {'fontSize': 32, 'fontWeight': 900, 'height': 1.08, 'letterSpacing': -1.0, 'color': 'ink', '_display': True},
    'number': {'fontSize': 40, 'fontWeight': 900, 'height': 1.0, 'letterSpacing': -1.2, 'color': 'ink', '_display': True},
    'numberLarge': {'fontSize': 56, 'fontWeight': 900, 'height': 1.0, 'letterSpacing': -2.0, 'color': 'ink', '_display': True},
    'numberSmall': {'fontSize': 22, 'fontWeight': 900, 'height': 1.05, 'letterSpacing': -0.5, 'color': 'ink', '_display': True},
    'blockTitle': {'fontSize': 21, 'fontWeight': 900, 'height': 1.2, 'letterSpacing': -0.5, 'color': 'ink', '_display': True},
    'cardTitle': {'fontSize': 17, 'fontWeight': 700, 'height': 1.25, 'letterSpacing': -0.2, 'color': 'ink'},
    'eyebrow': {'fontSize': 11.5, 'fontWeight': 700, 'height': 1.2, 'letterSpacing': 1.3, 'color': 'inkFaint'},
    'lead': {'fontSize': 15, 'fontWeight': 400, 'height': 1.45, 'color': 'inkSoft'},
    'meta': {'fontSize': 13, 'fontWeight': 500, 'height': 1.35, 'color': 'inkFaint'},
    'cta': {'fontSize': 16.5, 'fontWeight': 700, 'height': 1.2, 'letterSpacing': -0.1, 'color': 'ink'},
    'chip': {'fontSize': 12.5, 'fontWeight': 700, 'height': 1.2, 'letterSpacing': 0.2, 'color': 'ink'},
}


def text_styles(token_set):
    out = {}
    for name, s in TEXT_STYLES.items():
        s = dict(s)
        s['leadingDistribution'] = 'even'
        if s.pop('_display', False):
            s.update(token_set.get('display', {}))
        out[name] = s
    return out

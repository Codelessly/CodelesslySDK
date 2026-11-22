"""The Cards tokens: the light set (default) and the dark set.

`build.py` merges LIGHT into design_system.json's theme (over the SSUI-derived base), DARK into its `dark`, and
writes both as theme overrides (themes/light.json, themes/dark.json) a site can put in its `theme`.
"""

LIGHT = {
    'brand': {'primary': '#2563EB', 'ink': '#111827', 'surface': '#FFFFFF'},
    'colors': {
        # surfaces and ink
        'page': '#FFF3F4F6', 'card': '#FFFFFFFF', 'tile': '#FFF9FAFB', 'tileDeep': '#FFF3F4F6', 'line': '#FFE5E7EB',
        'lineStrong': '#FFD1D5DB', 'ink': '#FF111827', 'inkSoft': '#FF4B5563', 'inkFaint': '#FF6B7280', 'inkGhost': '#FF9CA3AF',
        # the accent: selection, progress, the one thing to do
        'accent': '#FF2563EB', 'accentDeep': '#FF1D4ED8', 'accentBright': '#FF3B82F6', 'accentTint': '#FFF3F4F6',
        'accentLine': '#FFD1D5DB', 'onAccent': '#FFFFFFFF', 'accentGlow': '#332563EB',
        # status
        'good': '#FF16A34A', 'goodDeep': '#FF15803D', 'goodTint': '#1A16A34A', 'goodLine': '#4716A34A',
        'bad': '#FFDC2626', 'badDeep': '#FFB91C1C', 'badTint': '#1ADC2626', 'badLine': '#47DC2626',
        'warn': '#FFEA580C', 'warnDeep': '#FFC2410C', 'warnTint': '#1AEA580C', 'warnLine': '#47EA580C',
        # the dark bar a total and its button sit on
        'bar': '#FF111827', 'barRaise': '#FF1F2937', 'onBar': '#FFFFFFFF', 'onBarSoft': '#99FFFFFF', 'barGlow': '#33000000',
        # the hero surface (a gradient) and what sits on it
        'heroA': '#FF111827', 'heroB': '#FF1F2937', 'heroGlow': '#FF374151', 'onHero': '#FFFFFFFF', 'onHeroSoft': '#B3FFFFFF',
        'heroChip': '#24FFFFFF', 'heroLine': '#14FFFFFF',
        # weather skies (top to bottom) and glyph inks
        'skySunA': '#FF2F7CF6', 'skySunB': '#FF6CC3FF', 'skyCloudA': '#FF5F7DA8', 'skyCloudB': '#FFA9BFDB',
        'skyRainA': '#FF3D4E7A', 'skyRainB': '#FF7A8FB8', 'skyNightA': '#FF171B45', 'skyNightB': '#FF3B3F8C',
        'sun': '#FFFFC83D', 'sunDeep': '#FFFF9D1F', 'sunGlow': '#66FFE08A', 'cloud': '#FFFFFFFF', 'cloudShade': '#FFDCE6F5',
        'cloudDark': '#FFB8C5DC', 'rain': '#FF4BA3FF', 'moon': '#FFF5F0D8',
        # media tones: a soft two-stop ground, a mid and a deep ink for the drawing on it
        'sandA': '#FFFFF1DF', 'sandB': '#FFFFDDB5', 'sandMid': '#FFF3A65A', 'sandInk': '#FF8A4B14',
        'roseA': '#FFFFE9EC', 'roseB': '#FFFFCAD3', 'roseMid': '#FFF2708A', 'roseInk': '#FF93203B',
        'mintA': '#FFE4F8EE', 'mintB': '#FFBDECD5', 'mintMid': '#FF3DBE8B', 'mintInk': '#FF0B5E43',
        'skyA': '#FFE5F2FF', 'skyB': '#FFBEDCFF', 'skyMid': '#FF4C9BF5', 'skyInk': '#FF114A8F',
        'lilacA': '#FFEFEBFF', 'lilacB': '#FFD6CCFF', 'lilacMid': '#FF8469F2', 'lilacInk': '#FF37228F',
        'slateA': '#FFF9FAFB', 'slateB': '#FFE5E7EB', 'slateMid': '#FF6B7280', 'slateInk': '#FF1F2937',
        'artWhite': '#FFFFFFFF', 'artShadow': '#1F000000', 'artShine': '#99FFFFFF',
        # scenes: four times of day, each a sky (top, bottom), an orb, three depths and a light
        'dawnSky1': '#FFFFB39A', 'dawnSky2': '#FFFFE3B8', 'dawnOrb': '#FFFFF4D6', 'dawnFar': '#FFE79AA0', 'dawnMid': '#FFB86A94',
        'dawnNear': '#FF6B3F7E', 'dawnLight': '#FFFFE9A8',
        'daySky1': '#FF58B4F5', 'daySky2': '#FFCDEBFF', 'dayOrb': '#FFFFE27A', 'dayFar': '#FF9CCFE8', 'dayMid': '#FF4FAE9A',
        'dayNear': '#FF1F6F6B', 'dayLight': '#FFFFFFFF',
        'duskSky1': '#FF5B3FA8', 'duskSky2': '#FFFF9A76', 'duskOrb': '#FFFFD27A', 'duskFar': '#FFC0668F', 'duskMid': '#FF6E3C86',
        'duskNear': '#FF2C1B55', 'duskLight': '#FFFFD98A',
        'nightSky1': '#FF10143A', 'nightSky2': '#FF3A3F92', 'nightOrb': '#FFF6F1DC', 'nightFar': '#FF4A4FA6', 'nightMid': '#FF2A2E72',
        'nightNear': '#FF12153F', 'nightLight': '#FFFFD66B',
        # the drawn map
        'mapLand': '#FFF3F4F6', 'mapBlock': '#FFE5E7EB', 'mapRoad': '#FFFFFFFF', 'mapRoadLine': '#FFD1D5DB', 'mapPark': '#FFCDEED9',
        'mapWater': '#FFC5E1FF', 'mapPin': '#FF111827', 'onMapPin': '#FFFFFFFF',
        # code
        'codeBg': '#FFF9FAFB', 'codeGutter': '#FF9CA3AF',
        'gold': '#FFFFB020',
    },
    'radii': {'card': 26, 'panel': 18, 'tile': 14, 'control': 12, 'chip': 999, 'cta': 14},
    'shadows': {
        'card': [{'type': 'dropShadow', 'color': '#14000000', 'offset': [0, 18], 'blurRadius': 40, 'spreadRadius': -14},
                 {'type': 'dropShadow', 'color': '#0D000000', 'offset': [0, 2], 'blurRadius': 6}],
        'tile': [{'type': 'dropShadow', 'color': '#0F000000', 'offset': [0, 6], 'blurRadius': 16, 'spreadRadius': -6},
                 {'type': 'dropShadow', 'color': '#0A000000', 'offset': [0, 1], 'blurRadius': 2}],
        'pick': [{'type': 'dropShadow', 'color': '#1F000000', 'offset': [0, 10], 'blurRadius': 22, 'spreadRadius': -10}],
        'cta': [{'type': 'dropShadow', 'color': '#29000000', 'offset': [0, 8], 'blurRadius': 18, 'spreadRadius': -8}],
        'bar': [{'type': 'dropShadow', 'color': '#33000000', 'offset': [0, 14], 'blurRadius': 26, 'spreadRadius': -12}],
        'hero': [{'type': 'dropShadow', 'color': '#33000000', 'offset': [0, 16], 'blurRadius': 30, 'spreadRadius': -14}],
        'knob': [{'type': 'dropShadow', 'color': '#1F000000', 'offset': [0, 2], 'blurRadius': 6, 'spreadRadius': -1}],
    },
}

DARK = {
    'brand': {'primary': '#3B82F6', 'ink': '#FFFFFF', 'surface': '#141414'},
    'colors': {
        'page': '#FF141414', 'card': '#FF1C1C1C', 'tile': '#FF232323', 'tileDeep': '#FF383838', 'line': '#FF383838',
        'lineStrong': '#FF4A4A4A', 'ink': '#FFFFFFFF', 'inkSoft': '#99FFFFFF', 'inkFaint': '#66FFFFFF', 'inkGhost': '#FF4A4A4A',
        'accent': '#FF3B82F6', 'accentDeep': '#FF60A5FA', 'accentBright': '#FF60A5FA', 'accentTint': '#FF262626',
        'accentLine': '#FF4A4A4A', 'onAccent': '#FFFFFFFF', 'accentGlow': '#523B82F6',
        'good': '#FF22C55E', 'goodDeep': '#FF4ADE80', 'goodTint': '#2922C55E', 'goodLine': '#5C22C55E',
        'bad': '#FFEF4444', 'badDeep': '#FFFCA5A5', 'badTint': '#29EF4444', 'badLine': '#5CEF4444',
        'warn': '#FFFB923C', 'warnDeep': '#FFFDBA74', 'warnTint': '#29FB923C', 'warnLine': '#5CFB923C',
        'bar': '#FF262626', 'barRaise': '#FF383838', 'onBar': '#FFFFFFFF', 'onBarSoft': '#99FFFFFF', 'barGlow': '#66000000',
        'heroA': '#FF383838', 'heroB': '#FF262626', 'heroGlow': '#FF4A4A4A', 'onHero': '#FFFFFFFF', 'onHeroSoft': '#B3FFFFFF',
        'heroChip': '#24FFFFFF', 'heroLine': '#14FFFFFF',
        'skySunA': '#FF1D4ED8', 'skySunB': '#FF3B82F6', 'skyCloudA': '#FF383838', 'skyCloudB': '#FF4A4A4A',
        'skyRainA': '#FF262626', 'skyRainB': '#FF4A4A4A', 'skyNightA': '#FF141414', 'skyNightB': '#FF383838',
        'sun': '#FFFFC83D', 'sunDeep': '#FFFF9D1F', 'sunGlow': '#66FFE08A', 'cloud': '#FFF1F4FB', 'cloudShade': '#FFC9D5EA',
        'cloudDark': '#FF9FAEC9', 'rain': '#FF6BB5FF', 'moon': '#FFF5F0D8',
        'sandA': '#FF262626', 'sandB': '#FF383838', 'sandMid': '#FFF3A65A', 'sandInk': '#FF8A4B14',
        'roseA': '#FF262626', 'roseB': '#FF383838', 'roseMid': '#FFF2708A', 'roseInk': '#FF93203B',
        'mintA': '#FF262626', 'mintB': '#FF383838', 'mintMid': '#FF3DBE8B', 'mintInk': '#FF0B5E43',
        'skyA': '#FF262626', 'skyB': '#FF383838', 'skyMid': '#FF4C9BF5', 'skyInk': '#FF114A8F',
        'lilacA': '#FF262626', 'lilacB': '#FF383838', 'lilacMid': '#FF8F78FF', 'lilacInk': '#FF37228F',
        'slateA': '#FF262626', 'slateB': '#FF383838', 'slateMid': '#FF9CA3AF', 'slateInk': '#FFF3F4F6',
        'artWhite': '#FFF9FAFB', 'artShadow': '#52000000', 'artShine': '#59FFFFFF',
        'dawnSky1': '#FFE08C7A', 'dawnSky2': '#FFF2C79A', 'dawnOrb': '#FFFFF4D6', 'dawnFar': '#FFC97C88', 'dawnMid': '#FF99557D',
        'dawnNear': '#FF54306A', 'dawnLight': '#FFFFE9A8',
        'daySky1': '#FF3E93D6', 'daySky2': '#FFA9D4EE', 'dayOrb': '#FFFFE27A', 'dayFar': '#FF7FB4CE', 'dayMid': '#FF3E927F',
        'dayNear': '#FF175955', 'dayLight': '#FFFFFFFF',
        'duskSky1': '#FF46308A', 'duskSky2': '#FFE07F60', 'duskOrb': '#FFFFD27A', 'duskFar': '#FFA35479', 'duskMid': '#FF5A3070',
        'duskNear': '#FF221446', 'duskLight': '#FFFFD98A',
        'nightSky1': '#FF0A0D2A', 'nightSky2': '#FF2A2F78', 'nightOrb': '#FFF6F1DC', 'nightFar': '#FF3B4090', 'nightMid': '#FF20245E',
        'nightNear': '#FF0C0F30', 'nightLight': '#FFFFD66B',
        'mapLand': '#FF1C1C1C', 'mapBlock': '#FF262626', 'mapRoad': '#FF383838', 'mapRoadLine': '#FF4A4A4A', 'mapPark': '#FF1D4438',
        'mapWater': '#FF1E3D66', 'mapPin': '#FFFFFFFF', 'onMapPin': '#FF141414',
        'codeBg': '#FF141414', 'codeGutter': '#66FFFFFF',
        'gold': '#FFFFB020',
    },
    'radii': {'card': 26, 'panel': 18, 'tile': 14, 'control': 12, 'chip': 999, 'cta': 14},
    'shadows': {
        'card': [{'type': 'dropShadow', 'color': '#66000000', 'offset': [0, 18], 'blurRadius': 40, 'spreadRadius': -14}],
        'tile': [{'type': 'dropShadow', 'color': '#4D000000', 'offset': [0, 6], 'blurRadius': 16, 'spreadRadius': -6}],
        'pick': [{'type': 'dropShadow', 'color': '#66000000', 'offset': [0, 10], 'blurRadius': 22, 'spreadRadius': -10}],
        'cta': [{'type': 'dropShadow', 'color': '#66000000', 'offset': [0, 8], 'blurRadius': 18, 'spreadRadius': -8}],
        'bar': [{'type': 'dropShadow', 'color': '#80000000', 'offset': [0, 14], 'blurRadius': 26, 'spreadRadius': -12}],
        'hero': [{'type': 'dropShadow', 'color': '#66000000', 'offset': [0, 16], 'blurRadius': 30, 'spreadRadius': -14}],
        'knob': [{'type': 'dropShadow', 'color': '#66000000', 'offset': [0, 2], 'blurRadius': 6, 'spreadRadius': -1}],
    },
}

SETS = {'light': LIGHT, 'dark': DARK}

TEXT = 'Inter'
DISPLAY = 'Inter Display'
MONO = 'JetBrains Mono'

# The type scale the blocks name: Inter for text, Inter Display for titles and figures (tabular digits),
# JetBrains Mono for code. All three ship in fonts/.
TEXT_STYLES = {
    'cardTitle': {'fontFamily': DISPLAY, 'fontSize': 19, 'fontWeight': 700, 'height': 1.2, 'letterSpacing': -0.3, 'color': 'ink'},
    'blockTitle': {'fontFamily': TEXT, 'fontSize': 15, 'fontWeight': 600, 'height': 1.3, 'letterSpacing': -0.1, 'color': 'ink'},
    'rowTitle': {'fontFamily': TEXT, 'fontSize': 14.5, 'fontWeight': 600, 'height': 1.3, 'letterSpacing': -0.1, 'color': 'ink'},
    'lead': {'fontFamily': TEXT, 'fontSize': 14, 'fontWeight': 400, 'height': 1.45, 'color': 'inkSoft'},
    'meta': {'fontFamily': TEXT, 'fontSize': 12.5, 'fontWeight': 500, 'height': 1.35, 'color': 'inkFaint'},
    'eyebrow': {'fontFamily': TEXT, 'fontSize': 10.5, 'fontWeight': 700, 'height': 1.2, 'letterSpacing': 0.9, 'color': 'inkFaint'},
    'chip': {'fontFamily': TEXT, 'fontSize': 12, 'fontWeight': 600, 'height': 1.2, 'letterSpacing': 0.05, 'color': 'ink'},
    'cta': {'fontFamily': TEXT, 'fontSize': 14.5, 'fontWeight': 600, 'height': 1.2, 'letterSpacing': -0.1, 'color': 'ink'},
    'field': {'fontFamily': TEXT, 'fontSize': 14.5, 'fontWeight': 500, 'height': 1.4, 'color': 'ink'},
    'numberHero': {'fontFamily': DISPLAY, 'fontSize': 56, 'fontWeight': 800, 'height': 1.0, 'letterSpacing': -2.4, 'color': 'ink',
                   'fontFeatures': ['tnum']},
    'numberLarge': {'fontFamily': DISPLAY, 'fontSize': 30, 'fontWeight': 800, 'height': 1.05, 'letterSpacing': -1.0, 'color': 'ink',
                    'fontFeatures': ['tnum']},
    'number': {'fontFamily': DISPLAY, 'fontSize': 22, 'fontWeight': 700, 'height': 1.1, 'letterSpacing': -0.6, 'color': 'ink',
               'fontFeatures': ['tnum']},
    'numberSmall': {'fontFamily': DISPLAY, 'fontSize': 16, 'fontWeight': 700, 'height': 1.15, 'letterSpacing': -0.3, 'color': 'ink',
                    'fontFeatures': ['tnum']},
    'figure': {'fontFamily': TEXT, 'fontSize': 13.5, 'fontWeight': 500, 'height': 1.3, 'color': 'ink', 'fontFeatures': ['tnum']},
    'code': {'fontFamily': MONO, 'fontSize': 12, 'fontWeight': 400, 'height': 1.5, 'color': 'ink'},
}

# The look of plain parts (Card, Text.title, Badge, Button...) when an answer is written without blocks: what
# NotationOptions.fromTheme reads (codelessly_api notation.dart) and the controls' per-step radii (the SDK's
# lib/src/render/controls/tokens.dart). build.py merges these into the theme.
PLAIN_TEXT_STYLES = {
    # The short words an answer writes, on the Cards scale (title as a card title, heading as a block title).
    'title': {'fontFamily': DISPLAY, 'fontSize': 20, 'fontWeight': 700, 'height': 1.2, 'letterSpacing': -0.3, 'color': 'primaryText'},
    'heading': {'fontFamily': TEXT, 'fontSize': 15, 'fontWeight': 600, 'height': 1.3, 'letterSpacing': -0.1, 'color': 'primaryText'},
    # Three follow what the design pass changed them to on 31 cards and pages (design 16): strong as a row title,
    # muted and caption as the meta line (caption was 11 in the faintest gray: too small and too faint on a phone).
    'strong': {'fontFamily': TEXT, 'fontSize': 14.5, 'fontWeight': 600, 'height': 1.3, 'letterSpacing': -0.1, 'color': 'primaryText'},
    'muted': {'fontFamily': TEXT, 'fontSize': 12.5, 'fontWeight': 500, 'height': 1.4, 'color': 'secondaryText'},
    'caption': {'fontFamily': TEXT, 'fontSize': 12, 'fontWeight': 500, 'height': 1.35, 'color': 'inkFaint'},
    'small': {'fontFamily': TEXT, 'fontSize': 12.5, 'fontWeight': 400, 'height': 1.4, 'color': 'secondaryText'},
    # The title of a wide page (sizes.wide and up): Text.title and Text.pageTitle there. 20 read as a section
    # heading at 1280 (run 10); judged blind over 20 on six desktop screens, 12 of 12 (design 16).
    # A Gauge's figure and its unit, as the design pass restyles them (design 16): the hero number, the meta line.
    'gaugeValue': {'fontFamily': DISPLAY, 'fontSize': 46, 'fontWeight': 800, 'height': 1.05, 'letterSpacing': -1.2, 'color': 'primaryText'},
    'gaugeUnit': {'fontFamily': TEXT, 'fontSize': 12.5, 'fontWeight': 500, 'height': 1.4, 'color': 'secondaryText'},
    'titleWide': {'fontFamily': DISPLAY, 'fontSize': 28, 'fontWeight': 700, 'height': 1.15, 'letterSpacing': -0.6, 'color': 'primaryText'},
}
PLAIN = {
    # A card: radii.card, shadows.card, spacing.card (its padding), colors.card, on colors.page.
    # A card in a card: radii.tile, spacing.tile, no shadow. A badge: a pill 22 high, 9 at its sides. A button alone
    # on its line in a column: full width, 46 high. A bar chart: rounded bars at most 28 wide, 10 apart.
    # A control's corner by its height (a 28-high button 8, not the 12 of the 44-high action button).
    # What floats (dialogs, sheets, pickers, toasts): radii.popup, shadows.popup. A menu that opens by its
    # button (a popover) is of the control family, not a small dialog: radii.menu.
    'radii': {'popup': 20, 'menu': 10, 'badge': 999, 'progress': 999, 'bar': 6, 'controlXs': 6, 'controlCompact': 8, 'controlSmall': 9, 'controlMedium': 10, 'controlLarge': 12},
    'sizes': {'cta': 46, 'badge': 22, 'bar': 28, 'progress': 8, 'wide': 900, 'ring': 11},
    'spacing': {'card': 18, 'tile': 14, 'badge': 9, 'bar': 10, 'cardGap': 12},
    'shadows': {'popup': [{'type': 'dropShadow', 'color': '#24000000', 'offset': [0, 16], 'blurRadius': 40, 'spreadRadius': -8},
                          {'type': 'dropShadow', 'color': '#0F000000', 'offset': [0, 2], 'blurRadius': 6}]},
}
# The page tier: what the same names are on a wide canvas (a website page or an app window, `sizes.wide` and
# up). A name ending in `Wide` takes the place of the name before it there (NotationOptions.fromTheme), so one
# theme serves a chat card and a page with nothing switched by hand: a card is written at its own width and
# keeps the card tier even inside a desktop app. A window-size rule in the theme would not do that (it reads the
# window, not the card). The values are what ten pages designed from scratch agreed on (examples/showcase/
# desktop/native): 15 px running text, 16 px corners on a page's surfaces, 24 px inside them, a soft wide shadow.
PAGE_TEXT_STYLES = {
    # A website's headline, its section titles and the title of a card on a page.
    'heading1Wide': {'fontFamily': DISPLAY, 'fontSize': 56, 'fontWeight': 800, 'height': 1.05, 'letterSpacing': -1.8, 'color': 'primaryText'},
    'heading2Wide': {'fontFamily': DISPLAY, 'fontSize': 36, 'fontWeight': 700, 'height': 1.12, 'letterSpacing': -0.9, 'color': 'primaryText'},
    'heading3Wide': {'fontFamily': DISPLAY, 'fontSize': 20, 'fontWeight': 700, 'height': 1.25, 'letterSpacing': -0.3, 'color': 'primaryText'},
    'headingWide': {'fontFamily': TEXT, 'fontSize': 17, 'fontWeight': 600, 'height': 1.3, 'letterSpacing': -0.2, 'color': 'primaryText'},
    'strongWide': {'fontFamily': TEXT, 'fontSize': 15, 'fontWeight': 600, 'height': 1.35, 'letterSpacing': -0.1, 'color': 'primaryText'},
    'bodyWide': {'fontFamily': TEXT, 'fontSize': 15, 'fontWeight': 400, 'height': 1.55, 'color': 'primaryText'},
    'leadWide': {'fontFamily': TEXT, 'fontSize': 18, 'fontWeight': 400, 'height': 1.55, 'color': 'secondaryText'},
    'mutedWide': {'fontFamily': TEXT, 'fontSize': 14, 'fontWeight': 400, 'height': 1.5, 'color': 'secondaryText'},
    'smallWide': {'fontFamily': TEXT, 'fontSize': 13.5, 'fontWeight': 400, 'height': 1.45, 'color': 'secondaryText'},
    'captionWide': {'fontFamily': TEXT, 'fontSize': 12.5, 'fontWeight': 500, 'height': 1.4, 'color': 'inkFaint'},
    # The small label over a title: in the accent, not the faint gray capitals of a card.
    'eyebrowWide': {'fontFamily': TEXT, 'fontSize': 12.5, 'fontWeight': 700, 'height': 1.2, 'letterSpacing': 0.9, 'color': 'accent'},
    # A 36-high control's label (a page's buttons): 14, where SSUI's is 13.
    'controlMedium': {'fontFamily': TEXT, 'fontSize': 14, 'fontWeight': 600, 'height': 1.2, 'color': 'primaryText'},
    'controlLarge': {'fontFamily': TEXT, 'fontSize': 15, 'fontWeight': 600, 'height': 1.2, 'color': 'primaryText'},
    # A field on a page: its label and its text.
    'fieldLabelWide': {'fontFamily': TEXT, 'fontSize': 13, 'fontWeight': 600, 'height': 1.2, 'color': 'primaryText'},
    'inputTextWide': {'fontFamily': TEXT, 'fontSize': 14, 'fontWeight': 400, 'height': 1.4, 'color': 'primaryText'},
    # A table's header cell.
    'columnHead': {'fontFamily': TEXT, 'fontSize': 12, 'fontWeight': 600, 'height': 1.2, 'letterSpacing': 0.4, 'color': 'inkFaint'},
}
PAGE = {
    'radii': {'cardWide': 16, 'panelWide': 14, 'tileWide': 12, 'ctaWide': 10},
    # sizes.ctaWide 0: a button alone on its line is as big as its label on a page, not as wide as the page.
    # sizes.rail: an app's sidebar at a tablet's width, where the sidebar's words (NavItem, NavSection, Brand,
    # Account, SideButton) fold to their icons; on a phone it is the drawer.
    'sizes': {'content': 1120, 'narrow': 720, 'sidebar': 248, 'rail': 64, 'topBarWide': 64, 'tableRowWide': 52, 'ctaWide': 0, 'controlWide': 40},
    'spacing': {'cardWide': 24, 'tileWide': 18, 'cardGapWide': 14, 'section': 88, 'gutter': 32},
    'shadows': {'cardWide': [{'type': 'dropShadow', 'color': '#12000000', 'offset': [0, 12], 'blurRadius': 32, 'spreadRadius': -16},
                             {'type': 'dropShadow', 'color': '#0A000000', 'offset': [0, 1], 'blurRadius': 2}]},
}
PAGE_DARK_SHADOWS = {'cardWide': [{'type': 'dropShadow', 'color': '#59000000', 'offset': [0, 12], 'blurRadius': 32, 'spreadRadius': -16}]}
# A page's alternate band (a website's tinted section) and the tile an icon sits on.
PAGE_COLORS = {'band': '#FFF8FAFC', 'iconTile': '#1A2563EB'}
PAGE_DARK_COLORS = {'band': '#FF1A1A1A', 'iconTile': '#293B82F6'}

# A series chart's series colors, in turn (the SDK's indicator_theme.dart reads colors.chart1...).
# A neutral fill written on the page (not in a card): the card's white, where the theme's neutral fill is the page's own gray.
PLAIN_COLORS = {'pageFill': '#FFFFFFFF', 'chart1': '#FF2563EB', 'chart2': '#FF0891B2', 'chart3': '#FF9333EA', 'chart4': '#FF16A34A', 'chart5': '#FFEA580C'}
PLAIN_DARK_COLORS = {'pageFill': '#FF262626', 'chart1': '#FF3B82F6', 'chart2': '#FF06B6D4', 'chart3': '#FFA855F7', 'chart4': '#FF22C55E', 'chart5': '#FFFB923C'}
PLAIN_DARK_SHADOWS = {'popup': [{'type': 'dropShadow', 'color': '#80000000', 'offset': [0, 16], 'blurRadius': 40, 'spreadRadius': -8}]}

FONTS = [
    {'family': TEXT, 'fonts': [{'asset': 'fonts/Inter-Regular.otf'}, {'asset': 'fonts/Inter-Medium.otf', 'weight': 500},
                               {'asset': 'fonts/Inter-SemiBold.otf', 'weight': 600}, {'asset': 'fonts/Inter-Bold.otf', 'weight': 700}]},
    {'family': DISPLAY, 'fonts': [{'asset': 'fonts/InterDisplay-SemiBold.otf', 'weight': 600},
                                  {'asset': 'fonts/InterDisplay-Bold.otf', 'weight': 700},
                                  {'asset': 'fonts/InterDisplay-ExtraBold.otf', 'weight': 800}]},
    {'family': MONO, 'fonts': [{'asset': 'fonts/JetBrainsMono-Regular.ttf'}, {'asset': 'fonts/JetBrainsMono-Medium.ttf', 'weight': 500},
                               {'asset': 'fonts/JetBrainsMono-Bold.ttf', 'weight': 700}]},
]


def text_styles():
    return {name: {**s, 'leadingDistribution': 'even'} for name, s in TEXT_STYLES.items()}

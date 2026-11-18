"""Desk: writes design_systems/desk/design_system.json from the tokens below.

    python3 design_systems/desk/tool/build.py

The tokens are Desk's own (a pointer, a large window, long sessions): see DESIGN.md
for why each is what it is. The color *names* are the ones the SDK's controls and the
notation read (primaryText, primaryBorder, focusBorder...), so plain `Button`,
`Input`, `Select`, `Checkbox` lines take Desk's values with nothing written.

The components are written in the notation (components/src/*.txt) and expanded by
`tool/notation/notation.sh expand design_systems/desk/components/src`, which writes
components/*.json; this script lists every components/*.json in the manifest.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

FONT = "Inter"
MONO = "JetBrains Mono"

# --- colour -------------------------------------------------------------------------------------------------------
# A cool zinc neutral ramp and one indigo accent. Light: the work surface is white, the chrome (sidebar, bars,
# table heads) a step off white, the "well" behind cards (a board, a settings page) two steps off.
LIGHT = {
    # roles
    "primary": "#FF4F46E5", "onPrimary": "#FFFFFFFF", "surface": "#FFFFFFFF", "onSurface": "#FF18181B",
    "error": "#FFDC2626", "success": "#FF16A34A", "warning": "#FFD97706",
    "colors": {
        # grounds
        "primaryBackground": "#FFFFFFFF",   # fields, cards, the work surface
        "secondaryBackground": "#FFFAFAFB",  # chrome: sidebar, toolbars, table head, dialog foot
        "tertiaryBackground": "#FFF4F4F6",   # pressed, the well behind cards
        "raisedBackground": "#FFFFFFFF",     # dialogs, menus, popovers
        "window": "#FFFFFFFF",
        "chrome": "#FFFAFAFB",
        "sidebar": "#FFFAFAFB",
        "band": "#FFFAFAFB",
        "well": "#FFF4F4F6",
        "card": "#FFFFFFFF",
        "pageFill": "#FFFFFFFF",
        "subtleFill": "#FFF4F4F6",
        "neutralFill": "#FFE4E4E7",
        "track": "#FFE4E4E7",
        # ink
        "primaryText": "#FF18181B",
        "secondaryText": "#FF52525B",
        "tertiaryText": "#FF71717A",
        "ink": "#FF18181B", "ink2": "#FF52525B", "ink3": "#FF71717A", "ink4": "#FFA1A1AA",
        "onAccent": "#FFFFFFFF",
        # lines
        "primaryBorder": "#FFE4E4E7",
        "secondaryBorder": "#FFD4D4D8",
        "line": "#FFE4E4E7",
        "lineStrong": "#FFD4D4D8",
        # accent
        "accent": "#FF4F46E5",
        "accentHover": "#FF4338CA",
        "accentText": "#FF4338CA",
        "accentTint": "#FFEEF0FE",
        "accentTintBorder": "#FFC7CBF9",
        "focusBorder": "#FF6366F1",
        "focusRing": "#664F46E5",
        "activeTint": "#FFEEF0FE",
        "primaryTint": "#FFEEF0FE",
        "primaryTintBorder": "#FFC7CBF9",
        "selection": "#FFEEF0FE",
        # states (overlays over whatever is under)
        "hoverOverlay": "#0A18181B",
        "pressedOverlay": "#1418181B",
        "hover": "#FFF4F4F5",
        "selectedRow": "#FFF5F5FF",
        # tooltip, scrim
        "tooltipBackground": "#FF18181B", "tooltipText": "#FFFAFAFA", "tooltipMuted": "#FFA1A1AA",
        "scrim": "#6618181B",
        # status: ink, tint, border, dot
        "info": "#FF2563EB",
        "neutralTint": "#FFF4F4F5", "neutralTintBorder": "#FFE4E4E7", "neutralInk": "#FF52525B", "neutralDot": "#FFA1A1AA",
        "infoTint": "#FFEFF5FF", "infoTintBorder": "#FFC9DCFD", "infoInk": "#FF1D4ED8", "infoDot": "#FF3B82F6",
        "successTint": "#FFEDFAF2", "successTintBorder": "#FFBDEACD", "successInk": "#FF15803D", "successDot": "#FF22C55E",
        "warningTint": "#FFFFF8EB", "warningTintBorder": "#FFF8DDA4", "warningInk": "#FFB45309", "warningDot": "#FFF59E0B",
        "errorTint": "#FFFEF2F2", "errorTintBorder": "#FFFBCACA", "errorInk": "#FFB91C1C", "errorDot": "#FFEF4444",
        "dangerFill": "#FFDC2626",
        # label hues (tags, avatars, kanban labels): tint + ink pairs
        "violetTint": "#FFF3EFFE", "violetInk": "#FF6D28D9", "violetDot": "#FF8B5CF6",
        "pinkTint": "#FFFDF0F7", "pinkInk": "#FFBE185D", "pinkDot": "#FFEC4899",
        "tealTint": "#FFEBFAF8", "tealInk": "#FF0F766E", "tealDot": "#FF14B8A6",
        "amberTint": "#FFFFF7E6", "amberInk": "#FFB45309", "amberDot": "#FFF59E0B",
        "skyTint": "#FFEEF7FE", "skyInk": "#FF0369A1", "skyDot": "#FF0EA5E9",
        "greenTint": "#FFEEFAF1", "greenInk": "#FF15803D", "greenDot": "#FF22C55E",
        "redTint": "#FFFEF1F1", "redInk": "#FFB91C1C", "redDot": "#FFEF4444",
        "slateTint": "#FFF1F2F4", "slateInk": "#FF475569", "slateDot": "#FF94A3B8",
        "keycap": "#FFFFFFFF", "keycapBorder": "#FFD9D9DE", "keycapInk": "#FF71717A",
        "chart1": "#FF4F46E5", "chart2": "#FF14B8A6", "chart3": "#FFF59E0B", "chart4": "#FFEC4899", "chart5": "#FF0EA5E9",
        "iconTile": "#FFEEF0FE",
    },
}

DARK = {
    "primary": "#FF6D70F0", "onPrimary": "#FFFFFFFF", "surface": "#FF141417", "onSurface": "#FFF4F4F5",
    "error": "#FFF87171", "success": "#FF4ADE80", "warning": "#FFFBBF24",
    "colors": {
        "primaryBackground": "#FF18181C",
        "secondaryBackground": "#FF141417",
        "tertiaryBackground": "#FF232329",
        "raisedBackground": "#FF1E1E23",
        "window": "#FF18181C",
        "chrome": "#FF141417",
        "sidebar": "#FF141417",
        "band": "#FF1C1C21",
        "well": "#FF111114",
        "card": "#FF1E1E23",
        "pageFill": "#FF18181C",
        "subtleFill": "#FF232329",
        "neutralFill": "#FF34343C",
        "track": "#FF2E2E35",
        "primaryText": "#FFF4F4F5",
        "secondaryText": "#FFB4B4BC",
        "tertiaryText": "#FF8A8A94",
        "ink": "#FFF4F4F5", "ink2": "#FFB4B4BC", "ink3": "#FF8A8A94", "ink4": "#FF5F5F69",
        "onAccent": "#FFFFFFFF",
        "primaryBorder": "#FF2C2C33",
        "secondaryBorder": "#FF3A3A43",
        "line": "#FF2C2C33",
        "lineStrong": "#FF3A3A43",
        "accent": "#FF7C7FF7",
        "accentHover": "#FF9A9CF9",
        "accentText": "#FFA5A8FA",
        "accentTint": "#FF24244A",
        "accentTintBorder": "#FF3A3B78",
        "focusBorder": "#FF8B8EF8",
        "focusRing": "#807C7FF7",
        "activeTint": "#FF24244A",
        "primaryTint": "#FF24244A",
        "primaryTintBorder": "#FF3A3B78",
        "selection": "#FF24244A",
        "hoverOverlay": "#0FFFFFFF",
        "pressedOverlay": "#1AFFFFFF",
        "hover": "#FF222228",
        "selectedRow": "#FF1F1F38",
        "tooltipBackground": "#FFF4F4F5", "tooltipText": "#FF18181B", "tooltipMuted": "#FF71717A",
        "scrim": "#99000000",
        "info": "#FF60A5FA",
        "neutralTint": "#FF26262C", "neutralTintBorder": "#FF34343C", "neutralInk": "#FFB4B4BC", "neutralDot": "#FF71717A",
        "infoTint": "#FF172238", "infoTintBorder": "#FF22365E", "infoInk": "#FF93C5FD", "infoDot": "#FF60A5FA",
        "successTint": "#FF132A1E", "successTintBorder": "#FF1D4630", "successInk": "#FF86EFAC", "successDot": "#FF4ADE80",
        "warningTint": "#FF2E2310", "warningTintBorder": "#FF4E3A14", "warningInk": "#FFFCD34D", "warningDot": "#FFFBBF24",
        "errorTint": "#FF331819", "errorTintBorder": "#FF5A2426", "errorInk": "#FFFCA5A5", "errorDot": "#FFF87171",
        "dangerFill": "#FFDC2626",
        "violetTint": "#FF2A2142", "violetInk": "#FFC4B5FD", "violetDot": "#FFA78BFA",
        "pinkTint": "#FF3A1A2C", "pinkInk": "#FFF9A8D4", "pinkDot": "#FFF472B6",
        "tealTint": "#FF102D2B", "tealInk": "#FF5EEAD4", "tealDot": "#FF2DD4BF",
        "amberTint": "#FF33260E", "amberInk": "#FFFCD34D", "amberDot": "#FFFBBF24",
        "skyTint": "#FF0F2938", "skyInk": "#FF7DD3FC", "skyDot": "#FF38BDF8",
        "greenTint": "#FF132A1E", "greenInk": "#FF86EFAC", "greenDot": "#FF4ADE80",
        "redTint": "#FF331819", "redInk": "#FFFCA5A5", "redDot": "#FFF87171",
        "slateTint": "#FF24262B", "slateInk": "#FFCBD5E1", "slateDot": "#FF94A3B8",
        "keycap": "#FF232329", "keycapBorder": "#FF3A3A43", "keycapInk": "#FFB4B4BC",
        "chart1": "#FF7C7FF7", "chart2": "#FF2DD4BF", "chart3": "#FFFBBF24", "chart4": "#FFF472B6", "chart5": "#FF38BDF8",
        "iconTile": "#FF24244A",
    },
}


def style(size, weight=400, height=None, color="primaryText", family=FONT, **extra):
    s = {"fontFamily": family, "fontSize": size, "fontWeight": weight}
    if height is not None:
        s["height"] = height
    s["color"] = color
    s["leadingDistribution"] = "even"
    s.update(extra)
    return s


# --- type ---------------------------------------------------------------------------------------------------------
# Inter at desktop sizes: 13 is the body of an app (lists, tables, forms), 14 the reading size (a message, a
# description), 12 the metadata. Titles are tight and heavy; group labels small spaced capitals.
TEXT = {
    # the notation's looks
    "body": style(13, 400, 1.54),
    "bodySecondary": style(13, 400, 1.54, "secondaryText"),
    "muted": style(13, 400, 1.54, "secondaryText"),
    "small": style(12, 400, 1.42, "secondaryText"),
    "caption": style(12, 400, 1.42, "tertiaryText"),
    "strong": style(13, 600, 1.54),
    "reading": style(14, 400, 1.6),
    "lead": style(15, 400, 1.55, "secondaryText"),
    "display": style(30, 700, 1.2, letterSpacing=-0.6),
    "pageTitle": style(24, 700, 1.25, letterSpacing=-0.4),
    "title": style(24, 700, 1.25, letterSpacing=-0.4),
    "heading1": style(30, 700, 1.2, letterSpacing=-0.6),
    "heading2": style(24, 700, 1.25, letterSpacing=-0.4),
    "heading3": style(18, 600, 1.35, letterSpacing=-0.2),
    "heading": style(15, 600, 1.4, letterSpacing=-0.1),
    "sectionTitle": style(15, 600, 1.4, letterSpacing=-0.1),
    "panelTitle": style(14, 600, 1.4),
    "dialogTitle": style(16, 600, 1.35, letterSpacing=-0.1),
    "barTitle": style(15, 600, 1.35, letterSpacing=-0.1),
    "rowTitle": style(13, 500, 1.4),
    "rowTitleStrong": style(13, 600, 1.4),
    "meta": style(12, 400, 1.35, "tertiaryText"),
    "metaStrong": style(12, 500, 1.35, "secondaryText"),
    "overline": style(11, 600, 1.3, "tertiaryText", letterSpacing=0.6),
    "columnHead": style(12, 500, 1.3, "tertiaryText"),
    "fieldLabel": style(12.5, 500, 1.3, "secondaryText"),
    "fieldLabelWide": style(12.5, 500, 1.3, "secondaryText"),
    "inputText": style(13, 400, 1.3),
    "inputTextWide": style(13, 400, 1.3),
    "placeholder": style(13, 400, 1.3, "ink4"),
    "helper": style(12, 400, 1.4, "tertiaryText"),
    "badge": style(11.5, 500, 1.2, "secondaryText"),
    "tag": style(12, 500, 1.2, "secondaryText"),
    "keycap": style(11, 500, 1.0, "keycapInk"),
    "number": style(24, 600, 1.2, letterSpacing=-0.4, tabularFigures=True),
    "numberLarge": style(30, 700, 1.15, letterSpacing=-0.6, tabularFigures=True),
    "mono": style(12, 400, 1.5, "secondaryText", MONO),
    "code": style(12.5, 400, 1.55, "primaryText", MONO),
    "danger": style(13, 500, 1.54, "errorInk"),
    "success": style(13, 500, 1.54, "successInk"),
    "link": style(13, 500, 1.54, "accentText"),
    "tooltip": style(12, 500, 1.35, "tooltipText"),
    # the controls' label per step
    "controlXs": style(11.5, 500, 1.2),
    "controlCompact": style(12, 500, 1.2),
    "controlSmall": style(12.5, 500, 1.2),
    "controlMedium": style(13, 500, 1.2),
    "controlLarge": style(14, 500, 1.2),
}

SPACING = {"0.5": 2, "1": 4, "1.5": 6, "2": 8, "3": 12, "4": 16, "5": 20, "6": 24, "8": 32, "10": 40, "12": 48, "16": 64,
           "card": 16, "tile": 12, "cardGap": 8, "badge": 8, "gutter": 32, "section": 64, "page": 32, "pane": 20, "bar": 12}

RADII = {"inner": 4, "control": 6, "controlXs": 4, "controlCompact": 6, "controlSmall": 6, "controlMedium": 6, "controlLarge": 7,
         "tag": 4, "badge": 999, "chip": 999, "card": 8, "tile": 8, "panel": 10, "menu": 8, "popup": 10, "dialog": 12,
         "sheet": 14, "progress": 999, "bar": 3, "avatar": 999, "full": 9999}

SIZES = {"xs": 24, "compact": 30, "small": 32, "medium": 34, "large": 40, "iconOnlyCompact": 16, "iconOnlySmall": 16, "iconOnlyMedium": 18,
         "control": 34, "controlDense": 30, "iconButton": 30,
         "icon": 16, "iconNav": 16, "iconEmpty": 24,
         "navItem": 32, "rowDense": 36, "row": 44, "rowRelaxed": 56, "tableHead": 36,
         "topBar": 52, "toolbar": 48, "badge": 20, "tag": 20, "avatar": 28, "avatarSmall": 20, "avatarLarge": 36,
         "dialogSmall": 420, "dialogMedium": 560, "dialogLarge": 760, "drawer": 420, "menu": 220,
         "sidebar": 240, "rail": 60, "pane": 360, "inspector": 340,
         "content": 1200, "narrow": 720, "reading": 680, "progress": 6, "ring": 4, "focusRing": 2}

SHADOWS_LIGHT = {
    "level1": [{"type": "dropShadow", "color": "#0A18181B", "offset": [0, 1], "blurRadius": 2}],
    "level2": [{"type": "dropShadow", "color": "#0F18181B", "offset": [0, 2], "blurRadius": 6, "spreadRadius": -1},
               {"type": "dropShadow", "color": "#0A18181B", "offset": [0, 1], "blurRadius": 2}],
    "level3": [{"type": "dropShadow", "color": "#1A18181B", "offset": [0, 12], "blurRadius": 32, "spreadRadius": -8},
               {"type": "dropShadow", "color": "#0F18181B", "offset": [0, 2], "blurRadius": 6}],
    "level4": [{"type": "dropShadow", "color": "#2618181B", "offset": [0, 24], "blurRadius": 56, "spreadRadius": -12},
               {"type": "dropShadow", "color": "#1418181B", "offset": [0, 4], "blurRadius": 12, "spreadRadius": -2}],
}
SHADOWS_DARK = {
    "level1": [{"type": "dropShadow", "color": "#33000000", "offset": [0, 1], "blurRadius": 2}],
    "level2": [{"type": "dropShadow", "color": "#4D000000", "offset": [0, 2], "blurRadius": 6, "spreadRadius": -1}],
    "level3": [{"type": "dropShadow", "color": "#66000000", "offset": [0, 12], "blurRadius": 32, "spreadRadius": -8}],
    "level4": [{"type": "dropShadow", "color": "#80000000", "offset": [0, 24], "blurRadius": 56, "spreadRadius": -12}],
}


def theme():
    t = {k: v for k, v in LIGHT.items() if k != "colors"}
    t.update({
        "radius": RADII["dialog"],
        "fontFamily": FONT,
        "iconStyle": "outlined",
        "colors": LIGHT["colors"],
        "textStyles": TEXT,
        "dark": {**{k: v for k, v in DARK.items() if k != "colors"}, "colors": DARK["colors"], "shadows": SHADOWS_DARK},
        "spacing": SPACING,
        "radii": RADII,
        "sizes": SIZES,
        "shadows": SHADOWS_LIGHT,
        "durations": {"control": 120, "transition": 180, "tooltipDelay": 400, "enter": 200},
        "curves": {"standard": "easeOut", "enter": "easeOut"},
    })
    return t


def write_source_site():
    """components/src/site.json: the site the components are written in (Desk's theme, each .txt expanded to
    components/<Name>.json)."""
    src = os.path.join(ROOT, "components", "src")
    names = sorted(f[:-4] for f in os.listdir(os.path.join(src, "components")) if f.endswith(".txt"))
    site = {"schema": 3, "pages": [], "designSystem": "../../", "components": [f"../{n}.json" for n in names]}
    with open(os.path.join(src, "site.json"), "w", newline="\n") as f:
        json.dump(site, f, indent=1)
        f.write("\n")


def main():
    write_source_site()
    comps = sorted(f for f in os.listdir(os.path.join(ROOT, "components")) if f.endswith(".json"))
    manifest = {
        "schema": 3,
        "id": "desk",
        "name": "Desk",
        "version": "1.0.0",
        "description": "Desktop apps at full polish: a pointer, a large window, long sessions. Zinc neutrals, one indigo accent, "
                       "Inter at 13, 34 px controls, hairlines over fills, a chrome a step off the work surface, and the "
                       "app shell, toolbar, table, list, board and dialog parts a desktop app is made of.",
        "design": "DESIGN.md",
        "patterns": "README.md",
        "theme": theme(),
        "components": [f"components/{c}" for c in comps],
        "replaces": [],
        "examples": [],
        "fonts": [
            {"family": FONT, "fonts": [{"asset": "fonts/Inter-Regular.otf"}, {"asset": "fonts/Inter-Medium.otf", "weight": 500},
                                        {"asset": "fonts/Inter-SemiBold.otf", "weight": 600}, {"asset": "fonts/Inter-Bold.otf", "weight": 700}]},
            {"family": MONO, "fonts": [{"asset": "fonts/JetBrainsMono-Regular.ttf"}, {"asset": "fonts/JetBrainsMono-Medium.ttf", "weight": 500}]},
        ],
    }
    with open(os.path.join(ROOT, "design_system.json"), "w", newline="\n") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    print(f"design_system.json: {len(comps)} components")


if __name__ == "__main__":
    main()

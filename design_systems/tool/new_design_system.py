#!/usr/bin/env python3
"""Writes a design system from a short brand description.

A design system here is data: a theme (color roles and names, text styles, radii, sizes, shadows, light and
dark) and component documents that read it by name. SSUI's components name no color of their own, so another
design system is the same components over another theme. This writes that theme from a few choices and copies
the components, giving a folder that drops in wherever `ssui` does (`"designSystem": "<id>"`, `--design-system`).

    python3 design_systems/tool/new_design_system.py design_systems/tool/brands/paper.json

The brand file:

    {"id": "paper", "name": "Paper", "description": "...",
     "primary": "#0F766E", "primaryDark": "#2DD4BF",      # the brand color, and its lighter form for dark mode
     "ink": "#1C1917", "surface": "#FFFCF7",              # text and page, light mode
     "inkDark": "#FAFAF9", "surfaceDark": "#1C1917",      # and dark mode
     "radius": 2,                                         # the control radius; panels and dialogs scale from it
     "fontFamily": null,                                  # null: the platform's
     "density": "regular",                                # compact (0.875), regular (1), comfortable (1.15), or a number
     "typeScale": 1,                                      # every font size times this (1.1: a tenth larger)
     "success": "#15803D", "warning": "#B45309", "error": "#B91C1C", "info": "#0E7490"}

Everything else is worked out: the neutral scale is the surface mixed toward the ink, tints are the role at 10 %
with a 28 % border (16 % and 36 % in dark), text styles keep SSUI's weights at its sizes times the type scale, and
control heights, paddings and gaps are SSUI's times the density (in the theme and in every component). Edit the written
design_system.json afterwards for anything a brand wants different; the components are plain documents too.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rgb(h):
    h = h.lstrip('#')[-6:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def argb(c, a=1.0):
    return '#%02X%02X%02X%02X' % (round(a * 255), *c)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])


def on(c):
    """Ink that reads on color c."""
    return (255, 255, 255) if lum(c) < 0.4 else (17, 24, 39)


def names(surface, ink, primary, roles, dark):
    m = lambda t: argb(mix(surface, ink, t))
    tint, border = (0.16, 0.36) if dark else (0.10, 0.28)
    out = {
        'primaryBackground': argb(surface), 'secondaryBackground': m(0.03 if not dark else 0.04),
        'tertiaryBackground': m(0.06 if not dark else 0.14),
        'primaryText': argb(ink), 'secondaryText': argb(ink, 0.72 if not dark else 0.6), 'tertiaryText': argb(ink, 0.45 if not dark else 0.4),
        'primaryBorder': m(0.12 if not dark else 0.16), 'secondaryBorder': m(0.2 if not dark else 0.24),
        'info': argb(roles['info']), 'purple': '#FF9333EA' if not dark else '#FFA855F7',
        'subtleFill': m(0.06 if not dark else 0.08), 'neutralFill': m(0.78 if not dark else 0.24),
        'raisedBackground': argb(surface) if not dark else m(0.14),
        'track': m(0.12 if not dark else 0.16), 'scrim': '#66000000' if not dark else '#99000000', 'onAccent': argb(on(primary)),
        'focusBorder': argb(primary, 0.5), 'hoverOverlay': argb(ink, 0.04 if not dark else 0.08),
        'pressedOverlay': argb(ink, 0.08 if not dark else 0.14), 'activeTint': argb(primary, 0.14 if not dark else 0.22),
        'primaryTint': argb(primary, tint), 'primaryTintBorder': argb(primary, border),
        'neutralTint': m(0.06 if not dark else 0.08), 'neutralTintBorder': m(0.12 if not dark else 0.16),
        'tooltipBackground': argb(ink), 'tooltipText': argb(surface), 'tooltipMuted': argb(surface, 0.6),
    }
    for role in ('success', 'warning', 'error', 'info'):
        out[f'{role}Tint'] = argb(roles[role], tint)
        out[f'{role}TintBorder'] = argb(roles[role], border)
    return out


DENSITIES = {'compact': 0.875, 'regular': 1, 'comfortable': 1.15}

# A size chosen by a prop is written as a formula (props.size == 'xs' ? 24 : (...)): its numbers scale too.
_TABLE = re.compile(r"^\$\{= props\.\w+ == '")
_NUMBER = re.compile(r"(?<![\w.'#])(\d+(?:\.\d+)?)(?![\w.'])")


def half(v):
    """Rounded to half a pixel, an integer when whole."""
    r = round(v * 2) / 2
    return int(r) if r == int(r) else r


def rescale(doc, density, type_scale):
    """SSUI's component with its type at type_scale and its control heights, paddings and gaps at density."""
    if density == 1 and type_scale == 1:
        return doc
    space = lambda v: v if isinstance(v, bool) or not isinstance(v, (int, float)) else (0 if v == 0 else max(1, round(v * density)))

    tall = lambda v: max(1, round(v * max(density, type_scale)))

    def formula(text, f):
        return _NUMBER.sub(lambda m: '%g' % f(float(m.group(1))), text)

    def walk(v, key=None):
        if isinstance(v, dict):
            out = {}
            for k, x in v.items():
                if k == 'fontSize' and isinstance(x, (int, float)) and not isinstance(x, bool):
                    out[k] = half(x * type_scale)
                elif k == 'padding' and key == 'layout':
                    out[k] = [space(i) for i in x] if isinstance(x, list) else space(x)
                elif k in ('spacing', 'runSpacing') and key == 'props':
                    out[k] = space(x)
                elif k == 'height' and key == 'layout' and isinstance(x, (int, float)) and not isinstance(x, bool) and x >= 20:
                    # A control's or a bar's fixed height; dots, rules and icons (under 20) stay. It holds text, so
                    # it grows with the type when that grows more than the density.
                    out[k] = tall(x)
                elif k == 'bind' and isinstance(x, dict):
                    out[k] = {}
                    for path, f in x.items():
                        if isinstance(f, str) and path == 'layout.height':
                            f = formula(f, lambda n: n if n < 20 else tall(n))
                        elif isinstance(f, str) and _TABLE.match(f):
                            if path.endswith('fontSize'):
                                f = formula(f, lambda n: half(n * type_scale))
                            elif path in ('layout.padding', 'props.spacing'):
                                f = formula(f, space)
                        out[k][path] = f
                else:
                    out[k] = walk(x, k)
            return out
        if isinstance(v, list):
            return [walk(x, key) for x in v]
        return v

    return walk(doc)


def main(path):
    brand = json.load(open(path))
    base = json.load(open(f'{HERE}/ssui/design_system.json'))
    theme = json.loads(json.dumps(base['theme']))
    g = lambda k, d: rgb(brand.get(k) or d)
    primary, primary_dark = g('primary', '#2563EB'), g('primaryDark', brand.get('primary') or '#3B82F6')
    ink, surface = g('ink', '#111827'), g('surface', '#FFFFFF')
    ink_d, surface_d = g('inkDark', '#FFFFFF'), g('surfaceDark', '#141414')
    roles = {k: g(k, d) for k, d in (('success', '#16A34A'), ('warning', '#EA580C'), ('error', '#DC2626'), ('info', '#0891B2'))}
    lighter = {k: mix(v, (255, 255, 255), 0.25) for k, v in roles.items()}
    radius = brand.get('radius', 7)
    theme.update({
        'primary': argb(primary), 'onPrimary': argb(on(primary)), 'surface': argb(surface), 'onSurface': argb(ink),
        'error': argb(roles['error']), 'success': argb(roles['success']), 'warning': argb(roles['warning']),
        'radius': radius, 'buttonRadius': radius,
        'colors': names(surface, ink, primary, roles, dark=False),
        'radii': {'inner': max(0, round(radius * 5 / 7)), 'control': radius, 'panel': round(radius * 8 / 7 + (1 if radius else 0)),
                  'dialog': round(radius * 12 / 7), 'full': 9999},
    })
    theme['dark'] = {
        **{k: v for k, v in theme['dark'].items() if k not in ('colors',)},
        'primary': argb(primary_dark), 'onPrimary': argb(on(primary_dark)), 'surface': argb(surface_d), 'onSurface': argb(ink_d),
        'error': argb(lighter['error']), 'success': argb(lighter['success']), 'warning': argb(lighter['warning']),
        'colors': names(surface_d, ink_d, primary_dark, lighter, dark=True),
    }
    if brand.get('fontFamily'):
        theme['fontFamily'] = brand['fontFamily']
    density = brand.get('density', 1)
    density = DENSITIES[density] if isinstance(density, str) else density
    type_scale = brand.get('typeScale', 1)
    theme['textStyles'] = {k: {**v, **({'fontSize': half(v['fontSize'] * type_scale)} if 'fontSize' in v else {})}
                           for k, v in theme['textStyles'].items()}
    theme['sizes'] = {k: round(v * density) for k, v in theme['sizes'].items()}
    theme['spacing'] = {k: max(1, round(v * density)) for k, v in theme['spacing'].items()}
    out = f"{HERE}/{brand['id']}"
    os.makedirs(f'{out}/components', exist_ok=True)
    # SSUI's components write its radii as numbers (5 inner, 6 and 7 control, 8 panel, 12 dialog): each becomes
    # this brand's radius of the same role. A full round (a pill, a dot) stays one.
    role = {5: theme['radii']['inner'], 6: theme['radii']['control'], 7: theme['radii']['control'],
            8: theme['radii']['panel'], 12: theme['radii']['dialog']}

    def round_all(node):
        """Whether the node is a circle or a pill: its radius is half its fixed size or more."""
        layout, decoration = node.get('layout'), node.get('decoration')
        r = decoration.get('radius') if isinstance(decoration, dict) else None
        if not isinstance(layout, dict) or not isinstance(r, (int, float)) or isinstance(r, bool):
            return False
        sides = [x for x in (layout.get('width'), layout.get('height')) if isinstance(x, (int, float)) and not isinstance(x, bool)]
        return bool(sides) and min(sides) <= 2 * r

    def reradius(v, key=None):
        if isinstance(v, dict):
            if round_all(v):
                # A dot or a marker stays round whatever the brand's corners.
                return {**{k: reradius(x, k) for k, x in v.items() if k != 'decoration'},
                        'decoration': {**{k: reradius(x, k) for k, x in v['decoration'].items() if k != 'radius'}, 'radius': 9999}}
            return {k: reradius(x, k) for k, x in v.items()}
        if isinstance(v, list):
            return [reradius(x, key) for x in v]
        if key in ('radius', 'borderRadius') and isinstance(v, (int, float)) and not isinstance(v, bool) and v in role:
            return role[v]
        return v

    for c in base['components']:
        with open(f'{HERE}/ssui/{c}') as f:
            doc = rescale(reradius(json.load(f)), density, type_scale)
        with open(f'{out}/{c}', 'w') as f:
            json.dump(doc, f, indent=1, ensure_ascii=False)
            f.write('\n')
    manifest = {**base, 'id': brand['id'], 'name': brand.get('name', brand['id']), 'version': brand.get('version', '1.0.0'),
                'description': brand.get('description', ''), 'theme': theme, 'examples': []}
    manifest.pop('design', None)
    manifest.pop('patterns', None)
    with open(f'{out}/design_system.json', 'w') as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write('\n')
    with open(f'{out}/README.md', 'w') as f:
        f.write(f"# {manifest['name']}\n\n{manifest['description']}\n\nWritten by `design_systems/tool/new_design_system.py` from "
                f"`design_systems/tool/brands/{brand['id']}.json`: SSUI's {len(base['components'])} components over this brand's theme. "
                "Run it again after changing the brand file; edit `design_system.json` by hand for anything else.\n")
    print(f"{out}: {len(base['components'])} components")


if __name__ == '__main__':
    main(sys.argv[1])

#!/usr/bin/env python3
"""Builds the Skip design system.

    python3 design_systems/skip/tool/build.py

1. Runs design_systems/tool/new_design_system.py on tool/brands/skip.json: SSUI's components and theme, rebranded
   (so the standard controls come along).
2. Merges Skip's own tokens (tokens.py: colors, radii, shadows, the display type scale) into the theme.
3. Writes Skip's blocks (blocks.py) and illustrations (art.py) as component documents, listed first.
4. Writes the two token variants as theme overrides (themes/pink.json, themes/athlete.json): a site puts one
   in its `theme` and every block, illustration and control follows, with no change to a page.
"""
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # design_systems/skip
SYSTEMS = os.path.dirname(ROOT)                   # design_systems
sys.path.insert(0, HERE)

import blocks  # noqa: E402
import tokens  # noqa: E402

spec = importlib.util.spec_from_file_location('nds', f'{SYSTEMS}/tool/new_design_system.py')
nds = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nds)


README = '''# Skip

A consumer fitness design system for the Skip jump rope app: a brand layer over SSUI's controls, plus screen
blocks and drawn illustrations. See DESIGN.md (the look and the tokens) and PATTERNS.md (how blocks compose).

Built by `python3 design_systems/skip/tool/build.py` (do not edit the generated files by hand):

| File | What it is |
|---|---|
| `tool/tokens.py` | The token sets: default, pink, athlete (colors, radii, shadows, the display type scale) |
| `tool/blocks.py` | The %d blocks: %s |
| `tool/art.py` | The illustrations (hero, streak, empty, record, cheer; adult and kid) as customPaint draw lists colored by tokens |
| `tool/build.py` | Runs `design_systems/tool/new_design_system.py` on `tool/brands/skip.json` (SSUI's %d components, rebranded), merges the tokens, writes the blocks first in the component list, and writes `themes/*.json` |
| `themes/pink.json`, `themes/athlete.json` | Whole token sets as theme overrides for a site's `theme` |

`EmptyState` here replaces SSUI's component of the same name.
'''


def ssui_names(token_set, dark=False):
    """The names SSUI's components read, worked out from a token set's brand as new_design_system.py does."""
    b = token_set['brand']
    roles = {k: nds.rgb(v) for k, v in (('success', '#12A150'), ('warning', '#E8590C'), ('error', '#E11D48'), ('info', '#0284C7'))}
    surface, ink, primary = nds.rgb(b['surface']), nds.rgb(b['ink']), nds.rgb(b['primary'])
    is_dark = nds.lum(surface) < 0.2
    return {
        'roles': {'primary': nds.argb(primary), 'onPrimary': nds.argb(nds.on(primary)), 'surface': nds.argb(surface),
                  'onSurface': nds.argb(ink)},
        'colors': nds.names(surface, ink, primary, roles, dark=is_dark),
    }


def theme_patch(token_set, with_ssui):
    """A token set as a theme (or a theme override)."""
    patch = {'colors': dict(token_set['colors']), 'radii': dict(token_set['radii']), 'shadows': dict(token_set['shadows']),
             'textStyles': tokens.text_styles(token_set)}
    if with_ssui:
        s = ssui_names(token_set)
        patch.update(s['roles'])
        patch['colors'] = {**s['colors'], **patch['colors']}
    return patch


def main():
    subprocess.run([sys.executable, f'{SYSTEMS}/tool/new_design_system.py', f'{SYSTEMS}/tool/brands/skip.json'], check=True,
                   stdout=subprocess.DEVNULL)
    manifest = json.load(open(f'{ROOT}/design_system.json'))
    theme = manifest['theme']
    patch = theme_patch(tokens.DEFAULT, with_ssui=False)
    theme['colors'].update(patch['colors'])
    theme['radii'].update(patch['radii'])
    theme['shadows'].update(patch['shadows'])
    theme['textStyles'].update(patch['textStyles'])
    theme['durations'].update({'enter': 520, 'stagger': 70})
    # The default set is a light one: dark mode keeps SSUI's derived names and takes the athlete set's colors.
    theme['dark']['colors'].update(tokens.ATHLETE['colors'])

    docs = blocks.all_components()
    own = []
    for doc in docs:
        name = doc['widget']['type']
        with open(f'{ROOT}/components/{name}.json', 'w') as f:
            json.dump(doc, f, indent=1, ensure_ascii=False)
            f.write('\n')
        own.append(f'components/{name}.json')
    manifest['components'] = own + [c for c in manifest['components'] if c not in own]
    manifest['design'] = 'DESIGN.md'
    manifest['patterns'] = 'PATTERNS.md'
    with open(f'{ROOT}/design_system.json', 'w') as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write('\n')

    os.makedirs(f'{ROOT}/themes', exist_ok=True)
    for name in ('pink', 'athlete'):
        with open(f'{ROOT}/themes/{name}.json', 'w') as f:
            json.dump(theme_patch(tokens.SETS[name], with_ssui=True), f, indent=1, ensure_ascii=False)
            f.write('\n')
    # The default set as an override too, so a site without the design system (a from-scratch page) can take it whole.
    with open(f'{ROOT}/themes/default.json', 'w') as f:
        json.dump(theme_patch(tokens.DEFAULT, with_ssui=True), f, indent=1, ensure_ascii=False)
        f.write('\n')
    with open(f'{ROOT}/README.md', 'w') as f:
        f.write(README % (len(own), ', '.join(c.split('/')[1][:-5] for c in own), len(manifest['components']) - len(own)))
    print(f'{ROOT}: {len(own)} blocks, {len(manifest["components"])} components in all')


if __name__ == '__main__':
    main()

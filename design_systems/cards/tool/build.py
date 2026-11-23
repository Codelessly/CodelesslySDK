#!/usr/bin/env python3
"""Builds the Cards design system, then the showcase that uses it.

    python3 design_systems/cards/tool/build.py [--no-showcase]
    py -X utf8 design_systems/cards/tool/build.py --no-showcase      (Windows: the files are read as UTF-8)

1. Runs design_systems/tool/new_design_system.py on tool/brand.json: SSUI's components and theme, rebranded
   (so the standard controls come along).
2. Merges the Cards tokens (tokens.py: colors, radii, shadows, the type scale, the fonts) into the theme, light
   and dark.
3. Writes the card blocks (blocks.py) and the drawn media (art.py) as component documents, listed first.
4. Writes themes/light.json and themes/dark.json: each token set as a theme override for a site's `theme`.
5. Unless --no-showcase: runs examples/showcase/tool/build.py (expands the 17 cards, renders them, makes the sheet).
"""
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # design_systems/cards
SYSTEMS = os.path.dirname(ROOT)                   # design_systems
SDK = os.path.dirname(SYSTEMS)
sys.path.insert(0, HERE)

import blocks  # noqa: E402
import core_words  # noqa: E402
import page_words  # noqa: E402
import repairs  # noqa: E402
import tokens  # noqa: E402

spec = importlib.util.spec_from_file_location('nds', f'{SYSTEMS}/tool/new_design_system.py')
nds = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nds)

README = '''# Cards

A design system for inline chat cards: a brand layer over SSUI's controls, plus card blocks at full polish and
drawn media (no image files). See DESIGN.md (the look and the tokens) and PATTERNS.md (one worked card per kind).
TO-DESKTOP.md says how the same words are laid out on a tablet and a desktop by themselves (a card keeps a card's
measure; an app window is written with the page words and folds to a rail and a drawer), with three whole windows
in `examples/desktop`; `../NAMES.md` lists the parts Desk and Cards name differently.

Built by `python3 design_systems/cards/tool/build.py` (on Windows `py -X utf8 design_systems/cards/tool/build.py
--no-showcase`: the `-X utf8` is needed, the sources are UTF-8). A change made to a generated component by hand is lost at
the next build unless it is recorded: `python3 design_systems/cards/tool/repairs.py --record` writes each such
change to `tool/repairs/<Name>.json`, which the build applies last:

| File | What it is |
|---|---|
| `tool/brand.json` | The brand given to `design_systems/tool/new_design_system.py` (SSUI's %d components, rebranded) |
| `tool/tokens.py` | The token sets, light and dark: colors, radii, shadows, the type scale, the fonts |
| `tool/kit.py` | The helpers blocks are written with |
| `tool/blocks.py` | The %d blocks: %s |
| `tool/page_words/components/*.txt` | The %d page words, written in the notation (`tool/page_words.py` expands them when one changed): %s |
| `tool/core_words.py` | The notation's own words on every component, run last: a tone is `info`, `success`, `warning`, `danger` or `neutral`, a size `small`, `medium` or `large`, a field's empty text its `hint`, its keyboard its `type`, a masked field `password` |
| `tool/art.py` | The drawn media as customPaint draw lists colored by tokens: scenes, product and food glyphs, weather glyphs, the map |
| `tool/build.py` | The build |
| `themes/light.json`, `themes/dark.json` | Each token set as a theme override for a site's `theme` |
| `fonts/` | Inter, Inter Display and JetBrains Mono (SIL Open Font License), Latin subsets |

These blocks and page words replace SSUI's components of the same name: %s.
'''


def theme_patch(name):
    """A token set as a whole theme override: SSUI's own names and roles for that mode, then the Cards tokens."""
    token_set = tokens.SETS[name]
    ssui = json.load(open(f'{SYSTEMS}/ssui/design_system.json'))['theme']
    src = ssui if name == 'light' else ssui['dark']
    patch = {k: src[k] for k in ('primary', 'onPrimary', 'surface', 'onSurface', 'error', 'success', 'warning') if k in src}
    patch.update({'colors': {**src['colors'], **token_set['colors']}, 'radii': dict(token_set['radii']),
                  'shadows': dict(token_set['shadows']), 'textStyles': tokens.text_styles()})
    return patch


def main():
    subprocess.run([sys.executable, f'{SYSTEMS}/tool/new_design_system.py', f'{HERE}/brand.json'], check=True,
                   stdout=subprocess.DEVNULL)
    manifest = json.load(open(f'{ROOT}/design_system.json'))
    theme = manifest['theme']
    # The neutrals and roles are SSUI's own, not derived: every name SSUI's theme has is taken from it as written
    # (design_systems/ssui/design_system.json, converted from soft_saas_ui's lib/soft_saas/design_tokens.dart).
    ssui = json.load(open(f'{SYSTEMS}/ssui/design_system.json'))['theme']
    for k in ('primary', 'onPrimary', 'surface', 'onSurface', 'error', 'success', 'warning'):
        if k in ssui:
            theme[k] = ssui[k]
    theme['colors'].update(ssui['colors'])
    theme.setdefault('dark', {})
    for k, v in ssui.get('dark', {}).items():
        if k == 'colors':
            theme['dark'].setdefault('colors', {}).update(v)
        elif k in ('primary', 'onPrimary', 'surface', 'onSurface', 'error', 'success', 'warning'):
            theme['dark'][k] = v
    theme['colors'].update(tokens.LIGHT['colors'])
    theme['radii'].update(tokens.LIGHT['radii'])
    theme['shadows'].update(tokens.LIGHT['shadows'])
    theme['textStyles'].update(tokens.text_styles())
    theme['textStyles']['mono']['fontFamily'] = tokens.MONO
    # Plain parts: the short words' styles, every style in the brand's text family, the card, badge and button
    # tokens, and per-step control radii in place of one buttonRadius for every height.
    theme['textStyles'].update({n: {**st, 'leadingDistribution': 'even'} for n, st in tokens.PLAIN_TEXT_STYLES.items()})
    theme['textStyles'].update({n: {**st, 'leadingDistribution': 'even'} for n, st in tokens.PAGE_TEXT_STYLES.items()})
    for st in theme['textStyles'].values():
        st.setdefault('fontFamily', tokens.TEXT)
    for k in ('radii', 'sizes', 'spacing', 'shadows'):
        theme[k].update(tokens.PLAIN[k])
        theme[k].update(tokens.PAGE[k])
    theme.pop('buttonRadius', None)
    theme['colors'].update(tokens.PLAIN_COLORS)
    theme['colors'].update(tokens.PAGE_COLORS)
    theme['fontFamily'] = tokens.TEXT
    theme['durations'].update({'enter': 360})
    dark = theme.setdefault('dark', {})
    dark.setdefault('colors', {}).update(tokens.DARK['colors'])
    dark['colors'].update(tokens.PLAIN_DARK_COLORS)
    dark['colors'].update(tokens.PAGE_DARK_COLORS)
    dark['shadows'] = {**theme['shadows'], **tokens.DARK['shadows'], **tokens.PLAIN_DARK_SHADOWS, **tokens.PAGE_DARK_SHADOWS}
    manifest['fonts'] = tokens.FONTS

    # Two repairs to the copied SSUI controls under this brand: code styles name the shipped mono family, and one
    # preview frame is widened (Inter sets wider than the font SSUI was drawn with).
    for c in manifest['components']:
        path = f'{ROOT}/{c}'
        text = open(path).read()
        fixed = text.replace('"monospace"', '"%s"' % tokens.MONO)
        if c.endswith('/ResourceChip.json'):
            fixed = fixed.replace('110,\n    26', '150,\n    26')
        if fixed != text:
            open(path, 'w').write(fixed)

    base = [c for c in manifest['components']]
    base_names = {c.split('/')[1][:-5] for c in base}
    docs = blocks.all_components()
    own = []
    for doc in docs:
        name = doc['widget']['type']
        with open(f'{ROOT}/components/{name}.json', 'w') as f:
            json.dump(doc, f, indent=1, ensure_ascii=False)
            f.write('\n')
        own.append(f'components/{name}.json')
    # Last, what Cards changes in what was just written (repairs.py): the menu, and the fixes made to a
    # generated block as edited JSON, each recorded as a patch so that this build gives it back.
    repairs.apply(ROOT, quiet=True)
    # The page words (page_words.py): an app window's parts, written in the notation; one named as a component
    # above takes its place.
    page = page_words.install(ROOT)
    # Every component in the notation's own words (core_words.py): a tone, a size, a field's hint and type.
    core_words.apply(ROOT)
    replaced = sorted(base_names & {o.split('/')[1][:-5] for o in own + page})
    # Blocks stored after the build (designed on demand in a session and written into components/): kept, after
    # the blocks made here.
    made = set(own) | set(base) | set(page)
    kept = sorted(f'components/{f}' for f in os.listdir(f'{ROOT}/components') if f.endswith('.json') and f'components/{f}' not in made)
    manifest['components'] = own + page + [c for c in base if c not in own and c not in page] + kept
    manifest['design'] = 'DESIGN.md'
    manifest['patterns'] = 'PATTERNS.md'
    with open(f'{ROOT}/design_system.json', 'w') as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write('\n')

    os.makedirs(f'{ROOT}/themes', exist_ok=True)
    for name in ('light', 'dark'):
        with open(f'{ROOT}/themes/{name}.json', 'w') as f:
            json.dump(theme_patch(name), f, indent=1, ensure_ascii=False)
            f.write('\n')
    names = [o.split('/')[1][:-5] for o in own]
    with open(f'{ROOT}/README.md', 'w') as f:
        f.write(README % (len(manifest['components']) - len(own) - len(page), len(own), ', '.join(names), len(page),
                          ', '.join(o.split('/')[1][:-5] for o in page), ', '.join(replaced) or 'none'))
    with open(f'{ROOT}/BLOCKS.txt', 'w') as f:
        f.write(','.join(names) + '\n')
    print(f'{ROOT}: {len(own)} blocks, {len(page)} page words, {len(manifest["components"])} components in all')

    # A page word's source changed: expand the sources (the manifest above is what they are expanded with), then
    # build once more with what that wrote.
    if '--page-words-expanded' not in sys.argv and page_words.stale() and page_words.expand(SDK):
        sys.argv.append('--page-words-expanded')
        return main()

    if '--no-showcase' not in sys.argv:
        sys.exit(subprocess.run([sys.executable, f'{SDK}/examples/showcase/tool/build.py'] + [a for a in sys.argv[1:] if a != '--page-words-expanded']).returncode)


if __name__ == '__main__':
    main()

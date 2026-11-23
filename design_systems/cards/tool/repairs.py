#!/usr/bin/env python3
"""What Cards changes in the components its build generates, so that a rebuild keeps it.

build.py writes every component it copies from SSUI (rebranded) and every block of blocks.py afresh. A change
made to one of those files by hand, or by an agent fixing a block on a real page, would be lost at the next
build. This module holds such changes and build.py applies them last:

1. Repairs written here as code (REPAIRS): the menu, which SSUI drew for a dense editor; the sort menu, which
   SSUI drew as an open panel.
2. Recorded patches, one file per component in tool/repairs/<Name>.json: a JSON merge patch (maps merge, null
   removes a key, anything else replaces) over what the build generates.

    python3 design_systems/cards/tool/repairs.py              # applies both to components/ in place
    python3 design_systems/cards/tool/repairs.py --record     # after editing generated components by hand:
                                                              # builds a pristine copy, and records each
                                                              # difference as a patch (and checks a rebuild
                                                              # gives the files back)

A change that belongs in blocks.py (a block's own design) is better made there; record is for the fixes that
arrive as edited JSON.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PATCHES = f'{HERE}/repairs'

# From this window width on a menu's text is the page's size.
PAGE = 700


def _menu_popover(doc):
    """SSUI's menu was drawn for a dense editor: 11 px items, a 1 px inset, and a panel corner that the brand's
    radius scales to 15. Under Cards a menu is a small surface of the control family: a corner of 10, as a
    Select's menu has, items inset from its edge with a corner of their own under the pointer, and text at the
    card's body size (the page's on a wide window)."""
    n = doc['nodes']
    menu = n['menu']
    menu['layout']['padding'] = 5
    # The corner of a Select's own menu, so the two kinds of menu match (the theme's radii.menu).
    menu['decoration']['radius'] = 10
    menu['bind']['decoration.radius'] = "${= props.size == 'small' ? 8 : 10}"
    # One Tab stop: Up and Down move through its items, Home and End jump, a typed letter finds an item.
    menu['focusGroup'] = {'typeAhead': True}
    heading = n['heading']
    heading['layout']['padding'] = [9, 7, 9, 5]
    heading['decoration'] = {}
    style = n['headingText']['props']['style']
    style.update({'fontSize': 11, 'fontWeight': 600, 'letterSpacing': 0.2, 'color': 'tertiaryText'})
    for p in doc['widget'].get('props', []):
        if p['key'] == 'size':
            p['doc'] = 'small: radius 8. medium: radius 10.'
    return doc


def _menu_item(doc):
    n = doc['nodes']
    item = n['item']
    item['props']['spacing'] = 10
    item['layout']['padding'] = [9, 7, 9, 7]
    item['layout']['constraints'] = {'minHeight': 34}
    item['decoration']['radius'] = 6
    item['states'] = {
        'hovered': {'item': {'decoration': {'fills': [{'color': 'secondaryBackground'}]}}},
        'pressed': {'item': {'decoration': {'fills': [{'color': 'secondaryBackground'}]}, 'opacity': 0.85}},
        # The row the keyboard is on, as the one under the pointer (the focus ring shows too).
        'focused': {'item': {'decoration': {'fills': [{'color': 'secondaryBackground'}]}}},
    }
    item['media'] = [{'minWidth': PAGE, 'patch': {'layout': {'padding': [10, 8, 10, 8], 'constraints': {'minHeight': 38}}}}]
    n['glyph']['props']['size'] = 16
    n['glyph']['layout'].update({'width': 16, 'height': 16})
    n['texts']['props']['spacing'] = 2
    for name, size, page in (('title', 13, 14), ('subtitle', 11.5, 12.5), ('trailing', 11.5, 12.5)):
        n[name]['props']['style']['fontSize'] = size
        n[name]['media'] = [{'minWidth': PAGE, 'patch': {'props': {'style': {'fontSize': page}}}}]
    for p in doc.get('previews', []):
        if p.get('size') == [226, 28]:
            p['size'] = [226, 34]
    return doc


def _sort_menu(doc):
    """SSUI's SortMenu is the body of a menu: an open panel of options, meant to be put in a popover. Written on
    a page (`SortMenu @sort options=[...]`) it drew that panel open, over what is beside it. Under Cards it
    is a closed control: a dropdown showing the choice (its menu opens on a tap, as a Select's does) and, beside
    it, the arrow that flips the direction."""
    n = doc['nodes']
    if doc['roots'] == ['sort']:
        return doc
    flip, arrow = n['flip'], n['arrow']
    flip.pop('bind', None)
    flip['layout'] = {'width': 28, 'height': 28}
    flip['decoration'] = {'radius': 9}
    arrow['props']['size'] = 15
    arrow['layout'] = {'width': 15, 'height': 15}
    doc['roots'] = ['sort']
    doc['nodes'] = {
        'sort': {
            'type': 'row',
            'children': ['choice', 'flip'],
            'props': {'crossAxisAlignment': 'center', 'spacing': 4},
            'layout': {'width': {'hug': 216}, 'height': {'hug': 36}},
        },
        # The page's own dropdown (what `Select` is on a page): the theme's field, its menu on a tap.
        'choice': {
            'type': 'dropdown',
            'layout': {'width': 184, 'height': 36},
            'props': {'style': 'inputText', 'hint': 'Sort by'},
            'bind': {'props.items': '${props.options}', 'props.value': '${props.value}'},
            'actions': [{
                'trigger': {'type': 'changed'},
                'actions': [
                    {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'},
                    {'type': 'componentEvent', 'event': 'onChanged', 'value': '${result}'},
                ],
            }],
        },
        'flip': flip,
        'arrow': arrow,
    }
    doc['widget']['doc'] = ('A closed control that picks what a list is sorted by (a dropdown: its menu opens on a tap) and which way '
                            '(the arrow beside it). The choice and the direction (asc or desc) are kept in your variables. '
                            'Fires onChanged and onDirectionChanged.')
    for preview in doc.get('previews', []):
        preview['size'] = [216, 36]
    return doc


def _reorderable_list(doc):
    """`addable=false` is a fixed set of items whose order alone changes: SSUI hid the + of the header and still
    drew the x that removes a row. The x goes with the +."""
    doc['nodes']['remove'].setdefault('bind', {})['visible'] = '${props.addable}'
    for p in doc['widget'].get('props', []):
        if p['key'] == 'addable':
            p['doc'] = 'The + in the header and the x on each row. False: a fixed set of items, only their order changes.'
    return doc


def _banner(doc):
    """SSUI's banner calls its red tone error; under Cards it is danger, the word every other tone here has."""
    text = json.dumps(doc, ensure_ascii=False)
    text = text.replace("props.tone == 'error'", "props.tone == 'danger'")
    doc = json.loads(text)
    for p in doc['widget']['props']:
        if p['key'] == 'tone':
            p['type']['values'] = ['danger' if v == 'error' else v for v in p['type']['values']]
    doc['widget']['doc'] = doc['widget']['doc'].replace('(info, success, warning, error)', '(info, success, warning, danger)')
    return doc


REPAIRS = {'MenuPopover': _menu_popover, 'MenuItem': _menu_item, 'SortMenu': _sort_menu, 'ReorderableList': _reorderable_list, 'Banner': _banner}

# A removed key in a recorded patch. JSON null cannot say it: a document may hold a null of its own.
REMOVED = {'$removed': True}


def _diff(a, b):
    """The merge patch that turns [a] into [b], or None when they are equal."""
    if isinstance(a, dict) and isinstance(b, dict):
        out = {}
        for k in b:
            if k not in a:
                out[k] = b[k]
            elif a[k] != b[k]:
                out[k] = _diff(a[k], b[k])
        for k in a:
            if k not in b:
                out[k] = REMOVED
        return out
    return b


def _merge(a, patch):
    if isinstance(a, dict) and isinstance(patch, dict) and patch != REMOVED:
        out = dict(a)
        for k, v in patch.items():
            if v == REMOVED:
                out.pop(k, None)
            elif k in out:
                out[k] = _merge(out[k], v)
            else:
                out[k] = v
        return out
    return patch


def _read(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def _write(path, doc):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
        f.write('\n')


def patches():
    """The recorded patches, by component type."""
    if not os.path.isdir(PATCHES):
        return {}
    return {f[:-5]: _read(f'{PATCHES}/{f}') for f in sorted(os.listdir(PATCHES)) if f.endswith('.json')}


def repair(name, doc, recorded=None):
    """The component document [doc] of type [name] with Cards' changes (the same document when it has none)."""
    if name in REPAIRS:
        doc = REPAIRS[name](doc)
    recorded = patches() if recorded is None else recorded
    if name in recorded:
        doc = _merge(doc, recorded[name])
    return doc


def apply(root=ROOT, quiet=False):
    recorded = patches()
    for name in sorted(set(REPAIRS) | set(recorded)):
        path = f'{root}/components/{name}.json'
        if not os.path.exists(path):
            print(f'repairs: no component {name} (its patch is stale: remove tool/repairs/{name}.json)', file=sys.stderr)
            continue
        _write(path, repair(name, _read(path), recorded))
        if not quiet:
            print(f'repaired {name}')


def _pristine():
    """A fresh build of the design systems in a temporary folder, with no recorded patch applied."""
    tmp = tempfile.mkdtemp(prefix='cards-build-')
    systems = os.path.dirname(ROOT)
    shutil.copytree(systems, f'{tmp}/design_systems')
    shutil.rmtree(f'{tmp}/design_systems/cards/tool/repairs', ignore_errors=True)
    subprocess.run([sys.executable, f'{tmp}/design_systems/cards/tool/build.py', '--no-showcase'], check=True,
                   stdout=subprocess.DEVNULL, env={**os.environ, 'PYTHONUTF8': '1'})
    return tmp


def record():
    """Records, for every generated component that differs from a pristine build, the patch that gives it back."""
    tmp = _pristine()
    built = f'{tmp}/design_systems/cards/components'
    os.makedirs(PATCHES, exist_ok=True)
    kept = set()
    for f in sorted(os.listdir(f'{ROOT}/components')):
        if not f.endswith('.json') or not os.path.exists(f'{built}/{f}'):
            continue
        ours, fresh = _read(f'{ROOT}/components/{f}'), _read(f'{built}/{f}')
        if ours == fresh:
            continue
        # A number that differs in its last place (a drawing's coordinates on another machine) is not a change.
        if json.loads(json.dumps(ours), parse_float=lambda s: round(float(s), 9)) == json.loads(json.dumps(fresh), parse_float=lambda s: round(float(s), 9)):
            continue
        patch = _diff(fresh, ours)
        if _merge(fresh, patch) != ours:
            raise SystemExit(f'{f}: the patch does not give the file back')
        _write(f'{PATCHES}/{f}', patch)
        kept.add(f)
        print(f'recorded {f[:-5]}')
    for f in os.listdir(PATCHES):
        if f.endswith('.json') and f not in kept:
            os.remove(f'{PATCHES}/{f}')
            print(f'dropped {f[:-5]} (the build gives it by itself now)')
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    if '--record' in sys.argv:
        record()
    else:
        apply()

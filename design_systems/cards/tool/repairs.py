#!/usr/bin/env python3
"""Repairs to the controls Cards copies from SSUI, under this brand.

SSUI's menu was drawn for a dense editor: 11 px items, a 1 px inset, and a panel corner that the brand's radius
scales to 15 (a menu's corner then reads rounder than the button that opened it). Under Cards a menu is a small
surface of the control family: a corner of 10, as a Select's menu has, items inset from its edge with a corner of their own under
the pointer, and text at the card's body size (the page's on a wide window).

    python3 design_systems/cards/tool/repairs.py        # applies them to components/ in place

build.py applies the same after it copies SSUI's components, so a rebuild keeps them.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# From this window width on a menu's text is the page's size.
PAGE = 700


def _menu_popover(doc):
    n = doc['nodes']
    menu = n['menu']
    menu['layout']['padding'] = 5
    # The corner of a Select's own menu, so the two kinds of menu match.
    menu['decoration']['radius'] = 10
    menu['bind']['decoration.radius'] = "${= props.size == 'small' ? 8 : 10}"
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


REPAIRS = {'MenuPopover': _menu_popover, 'MenuItem': _menu_item}


def repair(name, doc):
    """The component document [doc] of type [name], repaired (the same document when it needs none)."""
    return REPAIRS[name](doc) if name in REPAIRS else doc


def apply(root=ROOT):
    for name in REPAIRS:
        path = f'{root}/components/{name}.json'
        with open(path, encoding='utf-8') as f:
            doc = json.load(f)
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(repair(name, doc), f, indent=1, ensure_ascii=False)
            f.write('\n')
        print(f'repaired {name}')


if __name__ == '__main__':
    apply()

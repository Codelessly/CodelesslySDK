#!/usr/bin/env python3
"""Writes the reference site's two pages (home.json, contact.json) as Codelessly layout documents."""
import json, sys

OUT = sys.argv[1]
INK, MUTED, BRAND, BRAND_DARK, SOFT, LINE, WHITE, DARK = '#FF0F172A', '#FF475569', '#FF4F46E5', '#FF4338CA', '#FFF1F5F9', '#FFE2E8F0', '#FFFFFFFF', '#FF0F172A'
FONT = 'Inter'


def style(size, weight=400, color=INK, height=None, **kw):
    s = {'fontFamily': FONT, 'fontSize': size, 'fontWeight': weight, 'color': color}
    if height: s['height'] = height
    s.update(kw)
    return s


class Doc:
    def __init__(self):
        self.nodes = {}

    def add(self, id, node):
        assert id not in self.nodes, id
        self.nodes[id] = node
        return id

    def text(self, id, text, st, width=None, height=None, **props):
        return self.add(id, {'type': 'text', 'layout': {'width': width or {'hug': 100}, 'height': height or {'hug': 20}},
                             'props': {'text': text, 'style': st, **props}})

    def col(self, id, children, width, height, padding=0, spacing=0, cross='start', main='start', fills=None, radius=None, **extra):
        n = {'type': 'column', 'children': children, 'layout': {'width': width, 'height': height}}
        if padding: n['layout']['padding'] = padding
        props = {}
        if spacing: props['spacing'] = spacing
        if cross != 'center': props['crossAxisAlignment'] = cross
        if main != 'start': props['mainAxisAlignment'] = main
        if props: n['props'] = props
        deco = {}
        if fills: deco['fills'] = [{'color': fills}]
        if radius: deco['radius'] = radius
        if deco: n['decoration'] = deco
        for k, v in extra.items():
            if k in ('props', 'decoration', 'layout'):
                n.setdefault(k, {}).update(v)
            else:
                n[k] = v
        return self.add(id, n)

    def row(self, id, children, width, height, padding=0, spacing=0, cross='center', main='start', fills=None, radius=None, **extra):
        n = self.nodes[self.col(id, children, width, height, padding, spacing, cross, main, fills, radius, **extra)]
        n['type'] = 'row'
        if cross == 'center' and 'props' in n: n['props'].pop('crossAxisAlignment', None)
        return id


def button(d, id, label, primary=True, width=None, on=None):
    """A custom button: a row with a fill, padding, a label and hover/press states."""
    bg, fg, hover = (BRAND, WHITE, BRAND_DARK) if primary else (WHITE, INK, SOFT)
    lbl = d.text(f'{id}-label', label, style(15, 600, fg))
    n = {'type': 'row', 'children': [lbl],
         'layout': {'width': width or {'hug': 140}, 'height': {'hug': 44}, 'padding': [20, 12, 20, 12]},
         'props': {'mainAxisAlignment': 'center'},
         'decoration': {'fills': [{'color': bg}], 'radius': 10},
         'states': {'hovered': {id: {'decoration': {'fills': [{'color': hover}]}}},
                    'pressed': {id: {'opacity': 0.85}}}}
    if not primary:
        n['decoration']['strokes'] = [{'color': LINE}]
    if on: n['actions'] = [{'trigger': {'type': 'click'}, 'actions': on}]
    return d.add(id, n)


def link(d, id, label, on, color=MUTED, hover=INK, size=15):
    t = d.text(f'{id}-t', label, style(size, 500, color))
    return d.add(id, {'type': 'row', 'children': [t], 'layout': {'width': {'hug': 60}, 'height': {'hug': 36}, 'padding': [8, 8, 8, 8]},
                      'states': {'hovered': {t: {'props': {'style': {'color': hover}}}}},
                      'actions': [{'trigger': {'type': 'click'}, 'actions': on}]})


# --- home ---------------------------------------------------------------------------------------------------------
FEATURES = [
    ('bolt', 'Fast by default', 'Pages render as native Flutter widgets, so scrolling and transitions stay smooth.'),
    ('devices', 'Every screen size', 'Design a canvas per breakpoint and the right one shows on every device.'),
    ('lock', 'Private by design', 'Your data stays in your project. Nothing is shared without your say-so.'),
]
PLANS = [
    ('starter', 'Starter', 0, 0, 'For trying things out', ['1 project', 'Community support', 'Basic analytics'], False),
    ('pro', 'Pro', 19, 15, 'For growing teams', ['10 projects', 'Priority support', 'Advanced analytics', 'Custom domains'], True),
    ('team', 'Team', 49, 39, 'For whole organizations', ['Unlimited projects', 'Dedicated manager', 'SSO and audit logs'], False),
]
FAQ = [
    {'q': 'Can I cancel at any time?', 'a': 'Yes. Your plan stays active until the end of the billing period, and you can export everything.'},
    {'q': 'Is there a free trial?', 'a': 'Every paid plan starts with 14 days free. No card needed to start.'},
    {'q': 'Do you offer discounts for non-profits?', 'a': 'We do: write to us from the contact page and we will set it up.'},
    {'q': 'How does annual billing work?', 'a': 'You pay for twelve months up front and save about 20% compared with monthly billing.'},
]


def home():
    d = Doc()
    roots = []
    for bp, w, h, pad in [('mobile', 390, 844, 20), ('tablet', 834, 1112, 32), ('desktop', 1440, 900, 64)]:
        p = bp[0]  # id prefix
        inner = w - 2 * pad
        content_max = 1100
        cw = min(inner, content_max)
        sections = []
        canvas = f'{p}-home'
        roots.append(canvas)
        scroll = lambda target: [{'type': 'scrollTo', 'node': target, 'durationMs': 400}]
        go_contact = [{'type': 'navigate', 'to': 'contact'}]

        # Header.
        logo = d.row(f'{p}-logo', [d.add(f'{p}-logo-mark', {'type': 'box', 'layout': {'width': 28, 'height': 28},
                                                              'decoration': {'fills': [{'type': 'linear', 'stops': [{'position': 0, 'color': BRAND}, {'position': 1, 'color': '#FFEC4899'}]}], 'radius': 8}}),
                                   d.text(f'{p}-logo-text', 'Lumen', style(20, 800))],
                     {'hug': 100}, {'hug': 28}, spacing=10)
        if bp == 'mobile':
            menu_btn = d.add(f'{p}-menu', {'type': 'box', 'children': None, 'layout': {'width': 40, 'height': 40}})
            d.nodes[menu_btn] = {'type': 'row', 'children': [
                                     d.add(f'{p}-menu-icon', {'type': 'icon', 'layout': {'width': 24, 'height': 24},
                                                              'props': {'icon': 'menu', 'color': INK}, 'bind': {'visible': '${= !menuOpen}'}}),
                                     d.add(f'{p}-close-icon', {'type': 'icon', 'layout': {'width': 24, 'height': 24},
                                                               'props': {'icon': 'close', 'color': INK}, 'bind': {'visible': '${menuOpen}'}})],
                                 'layout': {'width': 40, 'height': 40}, 'props': {'mainAxisAlignment': 'center'},
                                 'decoration': {'radius': 8},
                                 'states': {'hovered': {menu_btn: {'decoration': {'fills': [{'color': SOFT}]}}}},
                                 'actions': [{'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'menuOpen', 'op': 'toggle'}]}]}
            header = d.row(f'{p}-header', [logo, menu_btn], {'fill': inner}, {'hug': 64}, padding=[pad, 12, pad, 12], main='spaceBetween')
            menu_items = []
            for key, label, act in [('features', 'Features', scroll(f'{p}-features')), ('pricing', 'Pricing', scroll(f'{p}-pricing')),
                                    ('faq', 'FAQ', scroll(f'{p}-faq')), ('contact', 'Contact', go_contact)]:
                menu_items.append(link(d, f'{p}-mnav-{key}', label, [{'type': 'setVariable', 'variable': 'menuOpen', 'value': 'false'}] + act, size=17))
            menu = d.col(f'{p}-menu-panel', menu_items, {'fill': inner}, {'hug': 180}, padding=[pad - 8, 4, pad, 12], spacing=2,
                         fills=WHITE, bind={'visible': '${menuOpen}'},
                         decoration={'strokes': [{'color': LINE}], 'strokeSides': 'bottom'})
            sections += [header, menu]
        else:
            nav = d.row(f'{p}-nav', [link(d, f'{p}-nav-{k}', l, a) for k, l, a in [
                ('features', 'Features', scroll(f'{p}-features')), ('pricing', 'Pricing', scroll(f'{p}-pricing')),
                ('faq', 'FAQ', scroll(f'{p}-faq'))]] + [button(d, f'{p}-nav-contact', 'Contact us', on=go_contact)],
                {'hug': 400}, {'hug': 44}, spacing=8 if bp == 'desktop' else 4)
            header = d.row(f'{p}-header', [logo, nav], {'fill': cw}, {'hug': 72}, padding=[0, 16, 0, 16], main='spaceBetween',
                           layout={'constraints': {'maxWidth': content_max}})
            sections.append(d.col(f'{p}-header-band', [header], {'fill': inner}, {'hug': 72}, padding=[pad, 0, pad, 0], cross='center',
                                  decoration={'strokes': [{'color': LINE}], 'strokeSides': 'bottom'}))

        # Hero.
        big = {'mobile': 36, 'tablet': 48, 'desktop': 60}[bp]
        hero_text = [
            d.row(f'{p}-badge', [d.text(f'{p}-badge-t', 'New: responsive canvases', style(13, 600, BRAND))],
                  {'hug': 180}, {'hug': 28}, padding=[12, 6, 12, 6], fills='#FFEEF2FF', radius=14),
            d.text(f'{p}-hero-title', 'Ship native apps from a design, not a backlog', style(big, 800, height=1.1, letterSpacing=-1),
                   width={'fill': cw}, textAlign='center' if bp != 'mobile' else 'start'),
            d.text(f'{p}-hero-sub', 'Lumen turns your screens into real Flutter UI that updates the moment you publish. No app store wait, no rewrite.',
                   style(17 if bp == 'mobile' else 19, 400, MUTED, height=1.5), width={'fill': min(cw, 680)}, textAlign='center' if bp != 'mobile' else 'start'),
            d.row(f'{p}-hero-ctas', [button(d, f'{p}-cta-start', 'Get started', on=go_contact),
                                     button(d, f'{p}-cta-pricing', 'See pricing', primary=False, on=scroll(f'{p}-pricing'))],
                  {'hug': 300}, {'hug': 44}, spacing=12),
        ]
        hero_cross = 'start' if bp == 'mobile' else 'center'
        hero = d.col(f'{p}-hero', hero_text, {'fill': cw}, {'hug': 300}, padding=[0, 48 if bp == 'mobile' else 80, 0, 32],
                     spacing=20, cross=hero_cross, layout={'constraints': {'maxWidth': content_max}})
        visual = d.add(f'{p}-hero-visual', {'type': 'box', 'layout': {'width': {'fill': cw}, 'height': 200 if bp == 'mobile' else 360,
                                                                       'constraints': {'maxWidth': content_max}},
                                            'decoration': {'fills': [{'type': 'image', 'image': {'url': 'assets/hero.png', 'fit': 'cover'}}],
                                                           'radius': 20, 'clip': 'antiAlias',
                                                           'effects': [{'type': 'dropShadow', 'color': '#1F0F172A', 'offset': [0, 20], 'blurRadius': 40}]}})
        sections.append(d.col(f'{p}-hero-band', [hero, visual], {'fill': inner}, {'hug': 600}, padding=[pad, 0, pad, 64], cross='center'))

        # Features.
        cards = []
        for i, (icon, title, body) in enumerate(FEATURES):
            cards.append(d.col(f'{p}-feature-{i}', [
                d.row(f'{p}-feature-{i}-icon-bg', [d.add(f'{p}-feature-{i}-icon', {'type': 'icon', 'layout': {'width': 24, 'height': 24},
                                                                                   'props': {'icon': icon, 'color': BRAND}})],
                      44, 44, main='center', fills='#FFEEF2FF', radius=12),
                d.text(f'{p}-feature-{i}-title', title, style(18, 700), width={'fill': 100}),
                d.text(f'{p}-feature-{i}-body', body, style(15, 400, MUTED, height=1.5), width={'fill': 100}),
            ], {'fill': 300}, {'hug': 200}, padding=24, spacing=12, fills=WHITE, radius=16,
                decoration={'strokes': [{'color': LINE}]}))
        grid = (d.col if bp == 'mobile' else d.row)(f'{p}-feature-grid', cards, {'fill': cw}, {'hug': 220}, spacing=16 if bp == 'mobile' else 24,
                                                    cross='start' if bp != 'mobile' else 'start')
        if bp != 'mobile':
            d.nodes[grid]['props']['crossAxisAlignment'] = 'stretch'
        feat_head = d.col(f'{p}-features-head', [
            d.text(f'{p}-features-kicker', 'FEATURES', style(13, 700, BRAND, letterSpacing=1.5)),
            d.text(f'{p}-features-title', 'Everything you need to ship', style(28 if bp == 'mobile' else 36, 800), width={'fill': 100},
                   textAlign='start' if bp == 'mobile' else 'center'),
        ], {'fill': cw}, {'hug': 80}, spacing=8, cross='start' if bp == 'mobile' else 'center')
        sections.append(d.col(f'{p}-features', [d.col(f'{p}-features-inner', [feat_head, grid], {'fill': cw}, {'hug': 400}, spacing=32,
                                                      layout={'constraints': {'maxWidth': content_max}})],
                              {'fill': inner}, {'hug': 500}, padding=[pad, 64, pad, 64], cross='center', fills=SOFT))

        # Pricing.
        def seg(id, label, value):
            t = d.text(f'{id}-t', label, style(14, 600, MUTED))
            d.nodes[t]['bind'] = {'props.style.color': "${= annual == %s ? '%s' : '%s'}" % (value, INK, MUTED)}
            return d.add(id, {'type': 'row', 'children': [t], 'layout': {'width': {'hug': 90}, 'height': {'hug': 36}, 'padding': [16, 8, 16, 8]},
                              'props': {'mainAxisAlignment': 'center'},
                              'decoration': {'fills': [{'color': WHITE}], 'radius': 18},
                              'bind': {'decoration.fills[0].color': "${= annual == %s ? '%s' : '#00FFFFFF'}" % (value, WHITE)},
                              'actions': [{'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'annual', 'value': value}]}]})
        toggle = d.row(f'{p}-billing', [seg(f'{p}-billing-monthly', 'Monthly', 'false'), seg(f'{p}-billing-annual', 'Annual  -20%', 'true')],
                       {'hug': 220}, {'hug': 44}, padding=4, spacing=4, fills='#FFE2E8F0', radius=22)
        plan_cards = []
        for key, name, monthly, yearly, blurb, items, hot in PLANS:
            c = f'{p}-plan-{key}'
            fg = WHITE if hot else INK
            sub = '#FFC7D2FE' if hot else MUTED
            kids = [d.row(f'{c}-top', [d.text(f'{c}-name', name, style(18, 700, fg))] +
                          ([d.row(f'{c}-pop', [d.text(f'{c}-pop-t', 'Popular', style(12, 700, BRAND))], {'hug': 70}, {'hug': 24}, padding=[10, 4, 10, 4], fills=WHITE, radius=12)] if hot else []),
                          {'fill': 100}, {'hug': 24}, main='spaceBetween'),
                    d.text(f'{c}-blurb', blurb, style(14, 400, sub), width={'fill': 100}),
                    d.row(f'{c}-price-row', [
                        d.text(f'{c}-price', f'${monthly}', style(44, 800, fg)),
                        d.text(f'{c}-period', '/ month', style(14, 500, sub)),
                    ], {'hug': 150}, {'hug': 56}, spacing=6, cross='end')]
            d.nodes[f'{c}-price']['bind'] = {'props.text': "${= annual ? '$%d' : '$%d'}" % (yearly, monthly)}
            if monthly:
                d.nodes[f'{c}-period']['bind'] = {'props.text': "${= annual ? '/ month, billed yearly' : '/ month'}"}
            for j, it in enumerate(items):
                kids.append(d.row(f'{c}-item-{j}', [d.add(f'{c}-item-{j}-i', {'type': 'icon', 'layout': {'width': 18, 'height': 18},
                                                                              'props': {'icon': 'check', 'color': WHITE if hot else BRAND}}),
                                                     d.text(f'{c}-item-{j}-t', it, style(14, 400, fg))], {'hug': 150}, {'hug': 20}, spacing=8))
            kids.append(button(d, f'{c}-cta', 'Start free trial' if monthly else 'Start for free', primary=not hot, width={'fill': 100},
                               on=[{'type': 'navigate', 'to': 'contact', 'params': {'plan': key}}]))
            if hot:
                d.nodes[f'{c}-cta']['decoration']['fills'] = [{'color': WHITE}]
                d.nodes[f'{c}-cta-label']['props']['style']['color'] = BRAND
                d.nodes[f'{c}-cta']['states']['hovered'] = {f'{c}-cta': {'decoration': {'fills': [{'color': '#FFEEF2FF'}]}}}
            plan_cards.append(d.col(c, kids, {'fill': 300}, {'hug': 420}, padding=28, spacing=16, fills=BRAND if hot else WHITE, radius=20,
                                    decoration={'strokes': [{'color': BRAND if hot else LINE}],
                                                'effects': [{'type': 'dropShadow', 'color': '#330F172A' if hot else '#0D0F172A', 'offset': [0, 12], 'blurRadius': 32}]}))
        plans = (d.col if bp == 'mobile' else d.row)(f'{p}-plans', plan_cards, {'fill': cw}, {'hug': 460}, spacing=20 if bp == 'mobile' else 24,
                                                     cross='start')
        if bp != 'mobile':
            d.nodes[plans]['props']['crossAxisAlignment'] = 'stretch'
        price_head = d.col(f'{p}-pricing-head', [
            d.text(f'{p}-pricing-kicker', 'PRICING', style(13, 700, BRAND, letterSpacing=1.5)),
            d.text(f'{p}-pricing-title', 'Simple plans that grow with you', style(28 if bp == 'mobile' else 36, 800), width={'fill': 100},
                   textAlign='start' if bp == 'mobile' else 'center'),
            toggle,
        ], {'fill': cw}, {'hug': 120}, spacing=16, cross='start' if bp == 'mobile' else 'center')
        sections.append(d.col(f'{p}-pricing', [d.col(f'{p}-pricing-inner', [price_head, plans], {'fill': cw}, {'hug': 600}, spacing=36,
                                                     layout={'constraints': {'maxWidth': content_max}})],
                              {'fill': inner}, {'hug': 700}, padding=[pad, 72, pad, 72], cross='center'))

        # FAQ.
        item = f'{p}-faq-item'
        d.add(item, {'type': 'column', 'children': [f'{item}-head', f'{item}-a'],
                     'layout': {'width': {'fill': 100}, 'height': {'hug': 64}, 'padding': [20, 18, 20, 18]},
                     'props': {'spacing': 10, 'crossAxisAlignment': 'start'},
                     'decoration': {'fills': [{'color': WHITE}], 'radius': 14, 'strokes': [{'color': LINE}]},
                     'states': {'hovered': {item: {'decoration': {'strokes': [{'color': '#FFA5B4FC'}]}}}},
                     'actions': [{'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'openFaq', 'value': '${= openFaq == index ? -1 : index}'}]}]})
        d.row(f'{item}-head', [d.text(f'{item}-q', '${item.q}', style(16, 600), width={'fill': 100}),
                               d.add(f'{item}-chev', {'type': 'icon', 'layout': {'width': 22, 'height': 22}, 'props': {'icon': 'expand_more', 'color': MUTED},
                                                      'bind': {'layout.rotation': '${= openFaq == index ? 180 : 0}'}})],
              {'fill': 100}, {'hug': 24}, spacing=12)
        d.text(f'{item}-a', '${item.a}', style(15, 400, MUTED, height=1.5), width={'fill': 100}, height={'hug': 22})
        d.nodes[f'{item}-a']['bind'] = {'visible': '${= openFaq == index}'}
        faq_list = d.add(f'{p}-faq-list', {'type': 'listView', 'children': [item], 'layout': {'width': {'fill': min(cw, 760)}, 'height': {'hug': 320},
                                                                                         'constraints': {'maxWidth': 760}},
                                           'props': {'scrollable': False, 'spacing': 12}, 'bind': {'data': '${faq}'}})
        sections.append(d.col(f'{p}-faq', [
            d.text(f'{p}-faq-title', 'Questions, answered', style(28 if bp == 'mobile' else 36, 800), width={'fill': min(cw, 760)},
                   textAlign='start' if bp == 'mobile' else 'center', ),
            faq_list], {'fill': inner}, {'hug': 500}, padding=[pad, 64, pad, 72], spacing=28, cross='center', fills=SOFT))
        d.nodes[f'{p}-faq-title']['layout']['constraints'] = {'maxWidth': 760}

        # Footer.
        foot_links = d.row(f'{p}-foot-links', [link(d, f'{p}-foot-{k}', l, a, color='#FF94A3B8', hover=WHITE, size=14) for k, l, a in [
            ('features', 'Features', scroll(f'{p}-features')), ('pricing', 'Pricing', scroll(f'{p}-pricing')), ('contact', 'Contact', go_contact)]],
            {'hug': 200}, {'hug': 36}, spacing=4)
        copy = d.text(f'{p}-copyright', '© 2026 Lumen Labs. All rights reserved.', style(13, 400, '#FF94A3B8'))
        foot = (d.col if bp == 'mobile' else d.row)(f'{p}-footer-inner', [d.text(f'{p}-foot-logo', 'Lumen', style(18, 800, WHITE)), foot_links, copy],
                                                     {'fill': cw}, {'hug': 60}, spacing=12, cross='start' if bp == 'mobile' else 'center',
                                                     main='start' if bp == 'mobile' else 'spaceBetween',
                                                     layout={'constraints': {'maxWidth': content_max}})
        sections.append(d.col(f'{p}-footer', [foot], {'fill': inner}, {'hug': 120}, padding=[pad, 40, pad, 40], cross='center', fills=DARK))

        body = d.col(f'{p}-body', sections, {'fill': w}, {'fill': h}, props={'scrollable': True}, cross='center')
        d.add(canvas, {'type': 'canvas', 'name': 'Home', 'path': 'home' if False else None, 'props': {'screen': 'home', 'breakpoint': bp},
                       'slots': {'body': body}, 'layout': {'width': w, 'height': h}, 'decoration': {'fills': [{'color': WHITE}]}})
        d.nodes[canvas].pop('path')
    return {'schema': 2, 'roots': roots, 'nodes': d.nodes,
            'variables': {'page_variables': [
                {'name': 'annual', 'type': 'boolean', 'value': False},
                {'name': 'menuOpen', 'type': 'boolean', 'value': False},
                {'name': 'openFaq', 'type': 'integer', 'value': -1},
                {'name': 'faq', 'type': 'list', 'value': FAQ}]}}


# --- contact ------------------------------------------------------------------------------------------------------
def contact():
    d = Doc()
    pad = 24
    logo = d.row('c-logo', [d.add('c-logo-mark', {'type': 'box', 'layout': {'width': 28, 'height': 28},
                                                   'decoration': {'fills': [{'type': 'linear', 'stops': [{'position': 0, 'color': BRAND}, {'position': 1, 'color': '#FFEC4899'}]}], 'radius': 8}}),
                            d.text('c-logo-text', 'Lumen', style(20, 800))], {'hug': 100}, {'hug': 28}, spacing=10,
                 actions=[{'trigger': {'type': 'click'}, 'actions': [{'type': 'navigate', 'to': 'm-home'}]}])
    back = link(d, 'c-back', '← Back to home', [{'type': 'navigate', 'to': 'm-home'}])
    header = d.row('c-header', [logo, back], {'fill': 1100}, {'hug': 72}, padding=[0, 16, 0, 16], main='spaceBetween',
                   layout={'constraints': {'maxWidth': 1100}})

    def field(key, label, hint, error, valid, multiline=False, keyboard=None):
        props = {'decoration': {'labelText': label, 'hintText': hint, 'filled': True, 'fillColor': WHITE,
                                'border': {'type': 'outline', 'borderRadius': 10, 'borderSide': {'color': LINE}},
                                'enabledBorder': {'type': 'outline', 'borderRadius': 10, 'borderSide': {'color': LINE}},
                                'focusedBorder': {'type': 'outline', 'borderRadius': 10, 'borderSide': {'color': BRAND, 'width': 2}},
                                'labelStyle': style(15, 400, MUTED), 'contentPadding': [14, 16, 14, 16]},
                 'style': style(16, 400)}
        if multiline:
            props.update({'maxLines': 5, 'minLines': 5, 'keyboardType': 'multiline'})
        if keyboard: props['keyboardType'] = keyboard
        f = d.add(f'c-{key}', {'type': 'textField', 'layout': {'width': {'fill': 100}, 'height': 140 if multiline else 56}, 'props': props,
                               'actions': [{'trigger': {'type': 'changed'}, 'actions': [{'type': 'setVariable', 'variable': key, 'value': '${result}'}]}]})
        e = d.text(f'c-{key}-error', error, style(13, 500, '#FFDC2626'), width={'fill': 100})
        d.nodes[e]['bind'] = {'visible': '${= tried && !(%s)}' % valid}
        return d.col(f'c-{key}-group', [f, e], {'fill': 100}, {'hug': 80}, spacing=6)

    valid = {
        'name': 'length(trim(name)) > 0',
        'email': "matches(trim(email), '^[^@ ]+@[^@ ]+[.][^@ ]+$')",
        'message': 'length(trim(message)) >= 10',
    }
    all_valid = ' && '.join(f'({v})' for v in valid.values())
    submit = button(d, 'c-submit', 'Send message', width={'fill': 100}, on=[
        {'type': 'setVariable', 'variable': 'tried', 'value': 'true'},
        {'type': 'if', 'condition': {'left': '${= %s}' % all_valid, 'op': 'isTrue'},
         'then': [{'type': 'setVariable', 'variable': 'sent', 'value': 'true'},
                  {'type': 'showToast', 'message': 'Message sent', 'style': 'success'}]}])
    form = d.col('c-form', [
        d.text('c-title', 'Talk to us', style(32, 800), width={'fill': 100}),
        d.text('c-sub', '${= route.plan == null ? "Tell us what you are building and we will get back to you within a day." : "You picked the " + route.plan + " plan. Tell us about your team and we will set up your trial."}',
               style(16, 400, MUTED, height=1.5), width={'fill': 100}),
        field('name', 'Your name', 'Ada Lovelace', 'Please enter your name.', valid['name']),
        field('email', 'Work email', 'ada@company.com', 'Enter a valid email address, like name@company.com.', valid['email'], keyboard='emailAddress'),
        field('message', 'How can we help?', 'A few words about your project', 'Tell us a little more (at least 10 characters).', valid['message'], multiline=True),
        submit,
    ], {'fill': 560}, {'hug': 600}, padding=32, spacing=18, fills=WHITE, radius=20,
        layout={'constraints': {'maxWidth': 560}},
        decoration={'strokes': [{'color': LINE}], 'effects': [{'type': 'dropShadow', 'color': '#140F172A', 'offset': [0, 16], 'blurRadius': 40}]},
        bind={'visible': '${= !sent}'})
    thanks = d.col('c-thanks', [
        d.row('c-thanks-icon-bg', [d.add('c-thanks-icon', {'type': 'icon', 'layout': {'width': 32, 'height': 32}, 'props': {'icon': 'check_circle', 'color': '#FF16A34A'}})],
              56, 56, main='center', fills='#FFDCFCE7', radius=28),
        d.text('c-thanks-title', 'Thanks, ${name}!', style(26, 800), width={'fill': 100}, textAlign='center'),
        d.text('c-thanks-body', "We got your message and will reply to ${email} within one business day.", style(16, 400, MUTED, height=1.5),
               width={'fill': 100}, textAlign='center'),
        button(d, 'c-thanks-home', 'Back to home', primary=False, on=[{'type': 'navigate', 'to': 'm-home'}]),
    ], {'fill': 560}, {'hug': 300}, padding=40, spacing=16, cross='center', fills=WHITE, radius=20,
        layout={'constraints': {'maxWidth': 560}},
        decoration={'strokes': [{'color': LINE}]}, bind={'visible': '${sent}'})
    body = d.col('c-body', [d.col('c-header-band', [header], {'fill': 1000}, {'hug': 72}, padding=[pad, 0, pad, 0], cross='center',
                                  fills=WHITE, decoration={'strokes': [{'color': LINE}], 'strokeSides': 'bottom'}),
                            d.col('c-main', [form, thanks], {'fill': 1000}, {'hug': 700}, padding=[pad, 48, pad, 64], cross='center')],
                 {'fill': 390}, {'fill': 844}, props={'scrollable': True}, cross='center')
    d.add('contact', {'type': 'canvas', 'name': 'Contact', 'path': 'contact', 'slots': {'body': body},
                      'layout': {'width': 390, 'height': 844}, 'decoration': {'fills': [{'color': SOFT}]}})
    return {'schema': 2, 'roots': ['contact'], 'nodes': d.nodes,
            'variables': {'contact': [
                {'name': 'name', 'type': 'text', 'value': ''},
                {'name': 'email', 'type': 'text', 'value': ''},
                {'name': 'message', 'type': 'text', 'value': ''},
                {'name': 'tried', 'type': 'boolean', 'value': False},
                {'name': 'sent', 'type': 'boolean', 'value': False}]}}


for name, doc in [('home', home()), ('contact', contact())]:
    with open(f'{OUT}/{name}.json', 'w') as f:
        json.dump(doc, f, indent=1)
        f.write('\n')
print('ok')

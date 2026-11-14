#!/usr/bin/env python3
"""Writes three inline cards, as a model answering in chat would make them, twice: made of SSUI components
(examples/cards/, a site whose design system is SSUI) and of the core's raw controls with no design system
(examples/cards_raw/, for comparison). A flight picker with confirm, an order summary with editable quantities,
a contact form with validation."""
import json
import os

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FLIGHTS = [
    {'id': 'tp1351', 'depart': '07:10', 'arrive': '09:45', 'airline': 'TAP', 'duration': '2h 35m', 'stops': 'Direct', 'price': '£84'},
    {'id': 'ba500', 'depart': '11:55', 'arrive': '14:35', 'airline': 'British Airways', 'duration': '2h 40m', 'stops': 'Direct', 'price': '£112'},
    {'id': 'u2731', 'depart': '16:20', 'arrive': '20:50', 'airline': 'easyJet', 'duration': '3h 30m', 'stops': '1 stop', 'price': '£61'},
]
ITEMS = [
    {'id': 'bananas', 'name': 'Organic bananas', 'price': 1.99, 'qty': 2},
    {'id': 'milk', 'name': 'Whole milk 1L', 'price': 1.35, 'qty': 1},
    {'id': 'loaf', 'name': 'Sourdough loaf', 'price': 4.20, 'qty': 1},
    {'id': 'eggs', 'name': 'Free-range eggs x12', 'price': 3.80, 'qty': 1},
]
SUBTOTAL = "sum(items, i => i.price * i.qty)"
DELIVERY = f"({SUBTOTAL} >= 20 || {SUBTOTAL} == 0 ? 0 : 3.5)"
MONEY = "formatCurrency({}, 'GBP', 'en_GB')"


def doc(id_, nodes, variables, root_children, page='secondaryBackground'):
    nodes = dict(nodes)
    return {'schema': 3, 'id': id_, 'roots': [id_], 'variables': {id_: variables}, 'nodes': {
        id_: {'type': 'canvas', 'name': id_, 'slots': {'body': 'page'}, 'layout': {'width': 390, 'height': {'hug': 600}}},
        'page': {'type': 'column', 'children': ['card'], 'layout': {'width': {'fill': 390}, 'height': {'fill': 600}, 'padding': 16},
                 'decoration': {'fills': [{'color': page}]}},
        **nodes,
        'card': {**nodes['card'], 'children': root_children},
    }}


def txt(t, style, w=None, h=None, **kw):
    n = {'type': 'text', 'props': {'text': t, 'style': style}, 'layout': {'width': w or {'fill': 334}, 'height': h or {'hug': 18}}}
    n.update(kw)
    return n


# --- SSUI ------------------------------------------------------------------------------------------------

CARD = {'type': 'column', 'props': {'spacing': 12, 'crossAxisAlignment': 'stretch'},
        'layout': {'width': {'fill': 358}, 'height': {'hug': 400}, 'padding': 12},
        'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8}}


def footer(children):
    return {'type': 'row', 'children': children, 'props': {'mainAxisAlignment': 'end', 'spacing': 6},
            'layout': {'width': {'fill': 334}, 'height': {'hug': 28}}}


def ssui_flight():
    nodes = {
        'card': CARD,
        'head': {'type': 'column', 'children': ['title', 'sub'], 'props': {'spacing': 2}, 'layout': {'width': {'fill': 334}, 'height': {'hug': 40}}},
        'title': txt('Choose your flight', 'sectionTitle', h={'hug': 20}),
        'sub': txt('London LHR to Lisbon LIS · Fri 21 Nov · 1 adult', 'bodySecondary'),
        'box': {'type': 'column', 'children': ['list'], 'layout': {'width': {'fill': 334}, 'height': {'hug': 150}},
                'decoration': {'strokes': [{'color': 'primaryBorder'}], 'radius': 8, 'clip': 'antiAlias'}},
        'list': {'type': 'listView', 'children': ['flight'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 334}, 'height': {'hug': 150}}, 'bind': {'data': '${flights}'}},
        'flight': {'type': 'ListRow', 'props': {'title': 'Flight', 'icon': 'flight_takeoff'},
                   'layout': {'width': {'fill': 334}, 'height': {'hug': 52}},
                   'slots': {'trailing': 'price'},
                   'bind': {'props.title': '${item.depart} – ${item.arrive}', 'props.subtitle': '${item.airline} · ${item.duration} · ${item.stops}',
                            'props.selected': '${= item.id == chosen}', 'props.divider': '${= index < length(flights) - 1}'},
                   'actions': [{'trigger': {'type': 'event', 'event': 'onPressed', 'when': '!confirmed'},
                                'actions': [{'type': 'setVariable', 'variable': 'chosen', 'value': '${item.id}'}]}]},
        'price': txt('${item.price}', {'from': 'body', 'fontWeight': 600}, {'hug': 40}, {'hug': 20}),
        'done': {'type': 'Banner', 'props': {'tone': 'success', 'title': 'Flight booked', 'message': 'Confirmation sent to your email.'},
                 'layout': {'width': {'fill': 334}, 'height': {'hug': 56}}, 'bind': {'visible': '${confirmed}'}},
        'foot': footer(['cancel', 'confirm']),
        'cancel': {'type': 'Button', 'props': {'label': 'Cancel', 'variant': 'ghost'}, 'layout': {'width': {'hug': 60}, 'height': {'hug': 28}},
                   'bind': {'visible': '${= !confirmed}'},
                   'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'cancel'}]}]},
        'confirm': {'type': 'Button', 'props': {'label': 'Confirm', 'icon': 'check'}, 'layout': {'width': {'hug': 90}, 'height': {'hug': 28}},
                    'bind': {'props.enabled': "${= chosen != '' && !confirmed}",
                             'props.label': "${= chosen == '' ? 'Choose a flight' : 'Confirm ' + find(flights, f => f.id == chosen).price}"},
                    'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [
                        {'type': 'setVariable', 'variable': 'confirmed', 'value': 'true'},
                        {'type': 'componentEvent', 'event': 'confirm', 'value': {'flight': '${chosen}'}}]}]},
    }
    variables = [{'name': 'flights', 'type': 'list', 'value': FLIGHTS}, {'name': 'chosen', 'type': 'text', 'value': ''},
                 {'name': 'confirmed', 'type': 'boolean', 'value': False}]
    return doc('flight_picker', nodes, variables, ['head', 'box', 'done', 'foot'])


def ssui_order():
    nodes = {
        'card': CARD,
        'title': txt('Review your order', 'sectionTitle', h={'hug': 20}),
        'box': {'type': 'column', 'children': ['list'], 'layout': {'width': {'fill': 334}, 'height': {'hug': 200}},
                'decoration': {'strokes': [{'color': 'primaryBorder'}], 'radius': 8, 'clip': 'antiAlias'}},
        'list': {'type': 'listView', 'children': ['line'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 334}, 'height': {'hug': 200}}, 'bind': {'data': '${items}'}},
        'line': {'type': 'ListRow', 'props': {'title': 'Item', 'icon': 'shopping_basket'}, 'layout': {'width': {'fill': 334}, 'height': {'hug': 52}},
                 'slots': {'trailing': 'stepper'},
                 'bind': {'props.title': '${item.name}', 'props.subtitle': "${= formatCurrency(item.price, 'GBP', 'en_GB') + ' each'}",
                          'props.divider': '${= index < length(items) - 1}'}},
        'stepper': {'type': 'row', 'children': ['minus', 'qty', 'plus'], 'props': {'spacing': 6, 'crossAxisAlignment': 'center'},
                    'layout': {'width': {'hug': 80}, 'height': {'hug': 24}}},
        'minus': {'type': 'IconButton', 'props': {'icon': 'remove', 'variant': 'outline', 'size': 'xs'}, 'layout': {'width': {'hug': 24}, 'height': {'hug': 24}},
                  'bind': {'props.enabled': '${= item.qty > 0}'},
                  'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [
                      {'type': 'setVariable', 'variable': 'items', 'value': "${= set(items, index, set(item, 'qty', max(0, item.qty - 1)))}"}]}]},
        'qty': txt('${item.qty}', {'from': 'body', 'fontWeight': 600, 'tabularFigures': True}, {'hug': 16}, {'hug': 20}, **{'props': {'text': '${item.qty}', 'style': {'from': 'body', 'fontWeight': 600, 'tabularFigures': True}, 'textAlign': 'center'}}),
        'plus': {'type': 'IconButton', 'props': {'icon': 'add', 'variant': 'outline', 'size': 'xs'}, 'layout': {'width': {'hug': 24}, 'height': {'hug': 24}},
                 'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [
                     {'type': 'setVariable', 'variable': 'items', 'value': "${= set(items, index, set(item, 'qty', item.qty + 1))}"}]}]},
        'promo': {'type': 'Field', 'props': {'label': 'Promo code', 'help': 'SAVE10 takes 10 % off.'}, 'children': ['promoIn'],
                  'layout': {'width': {'fill': 334}, 'height': {'hug': 70}}},
        'promoIn': {'type': 'TextInput', 'props': {'value': 'promo', 'placeholder': 'Code'}, 'layout': {'width': {'fill': 334}, 'height': 28}},
        'totals': {'type': 'column', 'children': ['subRow', 'delRow', 'discRow', 'rule', 'totRow'], 'props': {'spacing': 6},
                   'layout': {'width': {'fill': 334}, 'height': {'hug': 100}}},
        'rule': {'type': 'box', 'layout': {'width': {'fill': 334}, 'height': 1}, 'decoration': {'fills': [{'color': 'primaryBorder'}]}},
        'foot': footer(['cancel', 'place']),
        'cancel': {'type': 'Button', 'props': {'label': 'Cancel', 'variant': 'ghost'}, 'layout': {'width': {'hug': 60}, 'height': {'hug': 28}},
                   'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'cancel'}]}]},
        'place': {'type': 'Button', 'props': {'label': 'Place order'}, 'layout': {'width': {'hug': 90}, 'height': {'hug': 28}},
                  'bind': {'props.enabled': f'${{= {SUBTOTAL} > 0}}', 'props.label': "${= 'Place order · ' + " + MONEY.format('total') + '}'},
                  'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [
                      {'type': 'componentEvent', 'event': 'placeOrder', 'value': {'items': '${items}', 'total': '${total}'}}]}]},
    }
    discount = f"(upper(promo) == 'SAVE10' ? {SUBTOTAL} * 0.1 : 0)"
    rows = [('sub', 'Subtotal', SUBTOTAL, 'bodySecondary'), ('del', 'Delivery', DELIVERY, 'bodySecondary'),
            ('disc', 'Discount', f'-{discount}', 'bodySecondary'), ('tot', 'Total', 'total', {'from': 'body', 'fontWeight': 600})]
    for key, label, expr, style in rows:
        nodes[f'{key}Row'] = {'type': 'row', 'children': [f'{key}L', f'{key}V'], 'props': {'mainAxisAlignment': 'spaceBetween'},
                              'layout': {'width': {'fill': 334}, 'height': {'hug': 18}}}
        nodes[f'{key}L'] = txt(label, style, {'hug': 80})
        nodes[f'{key}V'] = txt('', style, {'hug': 60}, bind={'props.text': '${= ' + MONEY.format(expr) + '}'})
    nodes['discRow']['bind'] = {'visible': "${= upper(promo) == 'SAVE10'}"}
    variables = [{'name': 'items', 'type': 'list', 'value': ITEMS}, {'name': 'promo', 'type': 'text', 'value': ''},
                 {'name': 'total', 'type': 'decimal', 'formula': f'{SUBTOTAL} + {DELIVERY} - {discount}'}]
    return doc('order_summary', nodes, variables, ['title', 'box', 'promo', 'totals', 'foot'])


def validate_actions(fields):
    acts = [{'type': 'setVariable', 'variable': f'{v}Error', 'value': '${= ' + rule + '}'} for v, rule in fields]
    ok = ' && '.join(f"{v}Error == ''" for v, _ in fields)
    acts.append({'type': 'if', 'condition': {'left': '${= ' + ok + '}', 'op': 'isTrue'},
                 'then': [{'type': 'setVariable', 'variable': 'sent', 'value': 'true'},
                          {'type': 'componentEvent', 'event': 'submit', 'value': {'name': '${name}', 'email': '${email}', 'topic': '${topic}', 'message': '${message}'}}]})
    return acts


RULES = [('name', "trim(name) == '' ? 'Enter your name.' : ''"),
         ('email', "!contains(email, '@') || !contains(email, '.') ? 'Enter an email like name@company.com.' : ''"),
         ('message', "length(trim(message)) < 10 ? 'Tell us a little more (10 characters or more).' : ''")]


def ssui_contact():
    nodes = {
        'card': CARD,
        'head': {'type': 'column', 'children': ['title', 'sub'], 'props': {'spacing': 2}, 'layout': {'width': {'fill': 334}, 'height': {'hug': 40}}},
        'title': txt('Contact us', 'sectionTitle', h={'hug': 20}),
        'sub': txt('We answer within one working day.', 'bodySecondary'),
        'form': {'type': 'column', 'children': ['fName', 'fEmail', 'fTopic', 'fMsg'], 'props': {'spacing': 12},
                 'layout': {'width': {'fill': 334}, 'height': {'hug': 300}}, 'bind': {'visible': '${= !sent}'}},
        'fName': {'type': 'Field', 'props': {'label': 'Name', 'required': True}, 'children': ['inName'],
                  'layout': {'width': {'fill': 334}, 'height': {'hug': 50}}, 'bind': {'props.error': '${nameError}'}},
        'inName': {'type': 'TextInput', 'props': {'value': 'name', 'placeholder': 'Ada Lovelace'}, 'layout': {'width': {'fill': 334}, 'height': 28},
                   'bind': {'props.error': "${= nameError != ''}"}},
        'fEmail': {'type': 'Field', 'props': {'label': 'Email', 'required': True}, 'children': ['inEmail'],
                   'layout': {'width': {'fill': 334}, 'height': {'hug': 50}}, 'bind': {'props.error': '${emailError}'}},
        'inEmail': {'type': 'TextInput', 'props': {'value': 'email', 'placeholder': 'name@company.com', 'keyboard': 'emailAddress'},
                    'layout': {'width': {'fill': 334}, 'height': 28}, 'bind': {'props.error': "${= emailError != ''}"}},
        'fTopic': {'type': 'Field', 'props': {'label': 'Topic'}, 'children': ['inTopic'], 'layout': {'width': {'fill': 334}, 'height': {'hug': 50}}},
        'inTopic': {'type': 'Select', 'props': {'value': 'topic', 'options': ['Billing', 'A bug', 'A feature idea', 'Something else']},
                    'layout': {'width': {'fill': 334}, 'height': 28}},
        'fMsg': {'type': 'Field', 'props': {'label': 'Message', 'required': True, 'help': 'Steps to reproduce help us most.'}, 'children': ['inMsg'],
                 'layout': {'width': {'fill': 334}, 'height': {'hug': 120}}, 'bind': {'props.error': '${messageError}'}},
        'inMsg': {'type': 'TextArea', 'props': {'value': 'message', 'placeholder': 'How can we help?'}, 'layout': {'width': {'fill': 334}, 'height': 88},
                  'bind': {'props.error': "${= messageError != ''}"}},
        'done': {'type': 'Banner', 'props': {'tone': 'success', 'title': 'Message sent', 'message': 'Thanks — we will reply to your email.'},
                 'layout': {'width': {'fill': 334}, 'height': {'hug': 56}}, 'bind': {'visible': '${sent}'}},
        'foot': footer(['send']),
        'send': {'type': 'Button', 'props': {'label': 'Send message', 'icon': 'send'}, 'layout': {'width': {'hug': 90}, 'height': {'hug': 28}},
                 'bind': {'visible': '${= !sent}'},
                 'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': validate_actions(RULES)}]},
    }
    variables = [{'name': n, 'type': 'text', 'value': ''} for n in ['name', 'email', 'message', 'nameError', 'emailError', 'messageError']]
    variables += [{'name': 'topic', 'type': 'text', 'value': 'Billing'}, {'name': 'sent', 'type': 'boolean', 'value': False}]
    return doc('contact_form', nodes, variables, ['head', 'form', 'done', 'foot'])


# --- raw controls, no design system ------------------------------------------------------------------------

INK, MUTED, LINE, PAPER = '#FF111111', '#FF5F6368', '#FFE0E0E0', '#FFFFFFFF'
RAW_CARD = {'type': 'column', 'props': {'spacing': 12, 'crossAxisAlignment': 'stretch'},
            'layout': {'width': {'fill': 358}, 'height': {'hug': 400}, 'padding': 16},
            'decoration': {'fills': [{'color': PAPER}], 'strokes': [{'color': LINE}], 'radius': 12}}
TITLE = {'fontSize': 18, 'fontWeight': 600, 'color': INK}
BODY = {'fontSize': 14, 'color': INK}
SMALL = {'fontSize': 13, 'color': MUTED}


def raw_btn(type_, label, **kw):
    n = {'type': type_, 'props': {'label': label}, 'layout': {'width': 140 if len(label) > 8 else 100, 'height': 40}}
    n.update(kw)
    return n


def raw_flight():
    nodes = {
        'card': RAW_CARD,
        'title': txt('Choose your flight', TITLE, h={'hug': 24}),
        'sub': txt('London LHR to Lisbon LIS · Fri 21 Nov · 1 adult', SMALL),
        'list': {'type': 'listView', 'children': ['flight'], 'props': {'scrollable': False, 'spacing': 8},
                 'layout': {'width': {'fill': 326}, 'height': {'hug': 200}}, 'bind': {'data': '${flights}'}},
        'flight': {'type': 'row', 'children': ['pick', 'ftexts', 'fprice'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 326}, 'height': 64, 'padding': [4, 0, 12, 0]},
                   'decoration': {'strokes': [{'color': LINE}], 'radius': 8},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'setVariable', 'variable': 'chosen', 'value': '${item.id}'}]}]},
        'pick': {'type': 'radio', 'props': {'value': 'x'}, 'layout': {'width': 40, 'height': 40},
                 'bind': {'props.value': '${item.id}', 'props.groupValue': '${chosen}'}},
        'ftexts': {'type': 'column', 'children': ['ftime', 'fdetail'], 'props': {'spacing': 2}, 'layout': {'width': {'fill': 200}, 'height': {'hug': 40}}},
        'ftime': txt('${item.depart} – ${item.arrive}', {**BODY, 'fontWeight': 600}, {'fill': 200}),
        'fdetail': txt('${item.airline} · ${item.duration} · ${item.stops}', SMALL, {'fill': 200}),
        'fprice': txt('${item.price}', {**BODY, 'fontWeight': 600}, {'hug': 40}),
        'foot': {'type': 'row', 'children': ['cancel', 'confirm'], 'props': {'mainAxisAlignment': 'end', 'spacing': 8},
                 'layout': {'width': {'fill': 326}, 'height': {'hug': 40}}},
        'cancel': raw_btn('textButton', 'Cancel'),
        'confirm': raw_btn('filledButton', 'Confirm', bind={'props.enabled': "${= chosen != ''}"},
                           actions=[{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'confirm', 'value': {'flight': '${chosen}'}}]}]),
    }
    variables = [{'name': 'flights', 'type': 'list', 'value': FLIGHTS}, {'name': 'chosen', 'type': 'text', 'value': ''}]
    return doc('flight_picker', nodes, variables, ['title', 'sub', 'list', 'foot'], page='#FFF1F5F9')


def raw_order():
    nodes = {
        'card': RAW_CARD,
        'title': txt('Review your order', TITLE, h={'hug': 24}),
        'list': {'type': 'listView', 'children': ['line'], 'props': {'scrollable': False, 'spacing': 4},
                 'layout': {'width': {'fill': 326}, 'height': {'hug': 200}}, 'bind': {'data': '${items}'}},
        'line': {'type': 'row', 'children': ['lname', 'minus', 'qty', 'plus'], 'props': {'crossAxisAlignment': 'center'},
                 'layout': {'width': {'fill': 326}, 'height': 48}},
        'lname': txt('${item.name}', BODY, {'fill': 200}),
        'minus': {'type': 'iconButton', 'props': {'icon': {'name': 'remove'}}, 'layout': {'width': 40, 'height': 40},
                  'actions': [{'trigger': 'click', 'actions': [{'type': 'setVariable', 'variable': 'items', 'value': "${= set(items, index, set(item, 'qty', max(0, item.qty - 1)))}"}]}]},
        'qty': txt('${item.qty}', BODY, {'hug': 16}),
        'plus': {'type': 'iconButton', 'props': {'icon': {'name': 'add'}}, 'layout': {'width': 40, 'height': 40},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'setVariable', 'variable': 'items', 'value': "${= set(items, index, set(item, 'qty', item.qty + 1))}"}]}]},
        'promoIn': {'type': 'textField', 'props': {'decoration': {'labelText': 'Promo code'}}, 'layout': {'width': {'fill': 326}, 'height': 56},
                    'bind': {'props.initialValue': '${promo}'},
                    'actions': [{'trigger': {'type': 'changed'}, 'actions': [{'type': 'setVariable', 'variable': 'promo', 'value': '${result}'}]}]},
        'totRow': {'type': 'row', 'children': ['totL', 'totV'], 'props': {'mainAxisAlignment': 'spaceBetween'}, 'layout': {'width': {'fill': 326}, 'height': {'hug': 20}}},
        'totL': txt('Total', {**BODY, 'fontWeight': 600}, {'hug': 60}),
        'totV': txt('', {**BODY, 'fontWeight': 600}, {'hug': 60}, bind={'props.text': '${= ' + MONEY.format(f'{SUBTOTAL} + {DELIVERY}') + '}'}),
        'foot': {'type': 'row', 'children': ['cancel', 'place'], 'props': {'mainAxisAlignment': 'end', 'spacing': 8},
                 'layout': {'width': {'fill': 326}, 'height': {'hug': 40}}},
        'cancel': raw_btn('outlinedButton', 'Cancel'),
        'place': raw_btn('filledButton', 'Place order'),
    }
    variables = [{'name': 'items', 'type': 'list', 'value': ITEMS}, {'name': 'promo', 'type': 'text', 'value': ''}]
    return doc('order_summary', nodes, variables, ['title', 'list', 'promoIn', 'totRow', 'foot'], page='#FFF1F5F9')


def raw_contact():
    def field(id_, label, var_, **props):
        return {'type': 'textField', 'props': {'decoration': {'labelText': label}, **props}, 'layout': {'width': {'fill': 326}, 'height': 56},
                'bind': {'props.initialValue': '${' + var_ + '}', 'props.decoration.errorText': '${' + var_ + 'Error}'},
                'actions': [{'trigger': {'type': 'changed'}, 'actions': [{'type': 'setVariable', 'variable': var_, 'value': '${result}'}]}]}
    nodes = {
        'card': RAW_CARD,
        'title': txt('Contact us', TITLE, h={'hug': 24}),
        'sub': txt('We answer within one working day.', SMALL),
        'inName': field('inName', 'Name', 'name'),
        'inEmail': field('inEmail', 'Email', 'email', keyboardType='emailAddress'),
        'inTopic': {'type': 'dropdown', 'props': {'items': ['Billing', 'A bug', 'A feature idea', 'Something else'], 'value': 'Billing', 'isExpanded': True},
                    'layout': {'width': {'fill': 326}, 'height': 48}},
        'inMsg': {**field('inMsg', 'Message', 'message', maxLines=4), 'layout': {'width': {'fill': 326}, 'height': 120}},
        'foot': {'type': 'row', 'children': ['send'], 'props': {'mainAxisAlignment': 'end'}, 'layout': {'width': {'fill': 326}, 'height': {'hug': 40}}},
        'send': raw_btn('filledButton', 'Send message', actions=[{'trigger': 'click', 'actions': validate_actions(RULES)}]),
    }
    variables = [{'name': n, 'type': 'text', 'value': ''} for n in ['name', 'email', 'message', 'nameError', 'emailError', 'messageError']]
    variables += [{'name': 'topic', 'type': 'text', 'value': 'Billing'}, {'name': 'sent', 'type': 'boolean', 'value': False}]
    return doc('contact_form', nodes, variables, ['title', 'sub', 'inName', 'inEmail', 'inTopic', 'inMsg', 'foot'], page='#FFF1F5F9')


def write(folder, docs, manifest):
    os.makedirs(f'{HERE}/examples/{folder}', exist_ok=True)
    for d in docs:
        with open(f"{HERE}/examples/{folder}/{d['id']}.json", 'w') as f:
            json.dump(d, f, indent=1, ensure_ascii=False)
            f.write('\n')
    with open(f'{HERE}/examples/{folder}/site.json', 'w') as f:
        json.dump(manifest, f, indent=1)
        f.write('\n')


if __name__ == '__main__':
    pages = ['flight_picker.json', 'order_summary.json', 'contact_form.json']
    write('cards', [ssui_flight(), ssui_order(), ssui_contact()], {'schema': 3, 'pages': pages, 'designSystem': '../..'})
    write('cards_raw', [raw_flight(), raw_order(), raw_contact()], {'schema': 3, 'pages': pages})
    print('written')

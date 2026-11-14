#!/usr/bin/env python3
"""Writes examples/gallery.json: every SSUI component in every variant, size and state."""
import json
import os

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
nodes = {}
sections = []
variables = []


def var(name, type_, value):
    variables.append({'name': name, 'type': type_, 'value': value})
    return name


def n(id_, node):
    nodes[id_] = node
    return id_


def section(title, rows):
    """A titled section; each row is a list of node ids (a wrapping row)."""
    sid = f's{len(sections)}'
    kids = [n(f'{sid}t', {'type': 'text', 'props': {'text': title, 'style': 'sectionTitle'},
                          'layout': {'width': {'fill': 1100}, 'height': {'hug': 20}}})]
    for i, row in enumerate(rows):
        kids.append(n(f'{sid}r{i}', {'type': 'row', 'children': row, 'props': {'wrap': True, 'spacing': 12, 'runSpacing': 12, 'crossAxisAlignment': 'start' if title.startswith('Card') else 'center'},
                                     'layout': {'width': {'fill': 1100}, 'height': {'hug': 40}}}))
    sections.append(n(sid, {'type': 'column', 'children': kids, 'props': {'spacing': 10, 'crossAxisAlignment': 'start'},
                            'layout': {'width': {'fill': 1100}, 'height': {'hug': 120}}}))


def call(id_, type_, w, h, **props):
    return n(id_, {'type': type_, 'props': props, 'layout': {'width': w, 'height': h}})


HUG = {'hug': 80}
sizes = ['xs', 'compact', 'small', 'medium', 'large']
H = {'xs': 24, 'compact': 28, 'small': 32, 'medium': 36, 'large': 44}

# Buttons: every variant at every size, then icon and disabled.
rows = []
for v in ['primary', 'secondary', 'outline', 'ghost', 'destructive']:
    rows.append([call(f'btn_{v}_{s}', 'Button', {'hug': 80}, {'hug': H[s]}, label=f'{v.capitalize()} {s}', variant=v, size=s) for s in sizes])
rows.append([call('btn_icon', 'Button', HUG, {'hug': 28}, label='New file', icon='add'),
             call('btn_icon_out', 'Button', HUG, {'hug': 28}, label='Export', icon='download', variant='outline'),
             call('btn_dis', 'Button', HUG, {'hug': 28}, label='Disabled', enabled=False),
             call('btn_dis_out', 'Button', HUG, {'hug': 28}, label='Disabled', variant='outline', enabled=False),
             call('btn_hover', 'Button', HUG, {'hug': 28}, label='Hover me', variant='outline'),
             call('btn_press', 'Button', HUG, {'hug': 28}, label='Press me', variant='secondary')])
rows.append([call(f'ib_{v}_{s}', 'IconButton', {'hug': H[s]}, {'hug': H[s]}, icon=i, variant=v, size=s)
             for v, i in [('ghost', 'more_horiz'), ('outline', 'add'), ('primary', 'send')] for s in ['xs', 'compact', 'medium']]
            + [call('ib_dis', 'IconButton', {'hug': 28}, {'hug': 28}, icon='delete', enabled=False)])
section('Buttons and icon buttons (sizes xs 24, compact 28, small 32, medium 36, large 44)', rows)

# Fields.
var('name', 'text', '')
var('email', 'text', 'ada@example.com')
var('note', 'text', '')
var('plan', 'text', 'Monthly')
var('planEmpty', 'text', '')
section('Text input, text area, select', [
    [call('ti_empty', 'TextInput', 220, 28, value='name', placeholder='Full name'),
     call('ti_filled', 'TextInput', 220, 28, value='email', placeholder='Email'),
     call('ti_error', 'TextInput', 220, 28, value='email', error=True),
     call('ti_dis', 'TextInput', 220, 28, value='email', enabled=False)],
    [call('ta', 'TextArea', 300, 88, value='note', placeholder='Add a note…'),
     call('sel', 'Select', 200, 28, value='plan', options=['Weekly', 'Monthly', 'Yearly']),
     call('sel_empty', 'Select', 200, 28, value='planEmpty', options=['Weekly', 'Monthly'], placeholder='Choose a plan'),
     call('sel_err', 'Select', 200, 28, value='planEmpty', options=['Weekly'], error=True),
     call('sel_dis', 'Select', 200, 28, value='plan', options=['Weekly', 'Monthly', 'Yearly'], enabled=False)],
    [n('fieldA', {'type': 'Field', 'props': {'label': 'Email', 'help': 'We never share it.', 'required': True},
                  'children': [call('fieldAin', 'TextInput', {'fill': 260}, 28, value='email')], 'layout': {'width': 260, 'height': {'hug': 70}}}),
     n('fieldB', {'type': 'Field', 'props': {'label': 'Name', 'error': 'Enter your name.', 'required': True},
                  'children': [call('fieldBin', 'TextInput', {'fill': 260}, 28, value='name', error=True)], 'layout': {'width': 260, 'height': {'hug': 70}}})],
])

# Selection controls.
var('agree', 'boolean', True)
var('news', 'boolean', False)
var('ship', 'text', 'standard')
var('notify', 'boolean', True)
var('dark', 'boolean', False)
var('volume', 'decimal', 40)
section('Checkbox, radio, switch, slider', [
    [call('cb_on', 'Checkbox', HUG, {'hug': 28}, value='agree', label='I agree'),
     call('cb_off', 'Checkbox', HUG, {'hug': 28}, value='news', label='Send me news'),
     call('cb_dis', 'Checkbox', HUG, {'hug': 28}, value='agree', label='Disabled', enabled=False),
     call('rd_a', 'Radio', HUG, {'hug': 28}, value='standard', group='ship', label='Standard'),
     call('rd_b', 'Radio', HUG, {'hug': 28}, value='express', group='ship', label='Express'),
     call('rd_dis', 'Radio', HUG, {'hug': 28}, value='x', group='ship', label='Disabled', enabled=False),
     call('sw_on', 'Switch', HUG, {'hug': 28}, value='notify', label='Notifications'),
     call('sw_off', 'Switch', HUG, {'hug': 28}, value='dark', label='Dark mode'),
     call('sw_dis', 'Switch', HUG, {'hug': 28}, value='notify', label='Disabled', enabled=False)],
    [call('sl', 'Slider', 240, 28, value='volume', min=0, max=100),
     call('sl_steps', 'Slider', 240, 28, value='volume', min=0, max=100, divisions=5),
     call('sl_dis', 'Slider', 240, 28, value='volume', min=0, max=100, enabled=False)],
])

var('period', 'text', 'Week')
var('tab', 'text', 'Overview')
section('Segmented control and tabs', [
    [call(f'seg_{s}', 'SegmentedControl', {'hug': 200}, {'hug': H[s]}, value='period', options=['Day', 'Week', 'Month'], size=s) for s in ['xs', 'compact', 'medium']],
    [call('tabs', 'Tabs', 420, 36, value='tab', tabs=['Overview', 'Activity', 'Settings'])],
])

section('Chips, badges, avatars, tooltip, progress', [
    [call('chip', 'Chip', {'hug': 60}, {'hug': 24}, label='Design'),
     call('chip_sel', 'Chip', {'hug': 60}, {'hug': 24}, label='Selected', selected=True),
     call('chip_icon', 'Chip', {'hug': 60}, {'hug': 24}, label='Tagged', icon='sell'),
     call('chip_rm', 'Chip', {'hug': 60}, {'hug': 24}, label='Removable', removable=True)]
    + [call(f'badge_{t}', 'Badge', {'hug': 50}, {'hug': 20}, label=t.capitalize(), tone=t, dot=t in ('success', 'error')) for t in ['neutral', 'primary', 'success', 'warning', 'error', 'info']],
    [call(f'av_{s}', 'Avatar', {'hug': 24}, {'hug': 24}, name='Ada Lovelace', size=s) for s in ['xs', 'small', 'medium', 'large']]
    + [call('tip', 'Tooltip', {'hug': 80}, {'hug': 24}, text='Search', shortcut='Ctrl K'),
       call('pb', 'ProgressBar', 200, 4, value=0.62), call('pb_ok', 'ProgressBar', 200, 4, value=1, tone='success')],
])

section('Card, list rows, section header, banners, empty state', [
    [n('card', {'type': 'Card', 'props': {'title': 'Billing', 'subtitle': 'Your plan and invoices'}, 'layout': {'width': 340, 'height': {'hug': 160}},
                'slots': {'actions': call('cardAct', 'Button', {'hug': 60}, {'hug': 24}, label='Manage', variant='outline', size='xs')},
                'children': [n('cardBody', {'type': 'text', 'props': {'text': 'Team plan, 12 seats, renews on 1 December.', 'style': 'body'},
                                            'layout': {'width': {'fill': 316}, 'height': {'hug': 20}}})]}),
     n('list', {'type': 'column', 'children': [
         call('lh', 'SectionHeader', {'fill': 340}, 36, title='Files', count='3'),
         call('lr1', 'ListRow', {'fill': 340}, {'hug': 36}, title='Q3 report.pdf', icon='description'),
         call('lr2', 'ListRow', {'fill': 340}, {'hug': 36}, title='Roadmap.key', icon='slideshow', selected=True),
         call('lr3', 'ListRow', {'fill': 340}, {'hug': 52}, title='Ada Lovelace', subtitle='ada@example.com', icon='person_outline', divider=False)],
                'layout': {'width': 340, 'height': {'hug': 160}},
                'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8, 'clip': 'antiAlias'}}),
     n('banners', {'type': 'column', 'props': {'spacing': 8}, 'layout': {'width': 360, 'height': {'hug': 200}}, 'children': [
         call(f'bn_{t}', 'Banner', {'fill': 360}, {'hug': 40}, message=m, tone=t, title=ti) for t, ti, m in [
             ('info', '', 'A new version is available.'), ('success', 'Saved', 'Your changes are live.'),
             ('warning', 'Payment failed', 'Update your card to keep your plan.'), ('error', '', 'Could not reach the server.')]]})],
    [n('emptyBox', {'type': 'column', 'children': [n('empty', {'type': 'EmptyState', 'props': {'title': 'No invoices yet', 'message': 'Invoices appear here once you bill a customer.', 'icon': 'receipt_long'},
                                                              'slots': {'actions': call('emptyAct', 'Button', {'hug': 80}, {'hug': 28}, label='Create invoice', icon='add')},
                                                              'layout': {'width': {'fill': 340}, 'height': {'hug': 200}}})],
                    'layout': {'width': 340, 'height': {'hug': 200}},
                    'decoration': {'strokes': [{'color': 'primaryBorder'}], 'radius': 8}}),
     n('dialog', {'type': 'Dialog', 'props': {'title': 'Delete project?', 'description': 'This removes 14 files. It cannot be undone.'},
                  'layout': {'width': 400, 'height': {'hug': 160}},
                  'children': [call('dlgField', 'TextInput', {'fill': 376}, 28, value='name', placeholder='Type the project name')],
                  'slots': {'actions': n('dlgActs', {'type': 'row', 'props': {'spacing': 6}, 'layout': {'width': {'hug': 160}, 'height': {'hug': 28}}, 'children': [
                      call('dlgCancel', 'Button', {'hug': 60}, {'hug': 28}, label='Cancel', variant='ghost'),
                      call('dlgDelete', 'Button', {'hug': 60}, {'hug': 28}, label='Delete', variant='destructive')]})}})],
])

nodes['gallery'] = {'type': 'canvas', 'name': 'Gallery', 'slots': {'body': 'page'}, 'layout': {'width': 1200, 'height': 1600},
                    'decoration': {'fills': [{'color': 'secondaryBackground'}]}}
nodes['page'] = {'type': 'column', 'children': ['heading', *sections], 'props': {'spacing': 24, 'crossAxisAlignment': 'start', 'scrollable': True},
                 'layout': {'width': {'fill': 1200}, 'height': {'fill': 1600}, 'padding': [48, 40, 48, 40]}}
nodes['heading'] = {'type': 'text', 'props': {'text': 'Soft SaaS UI: every component', 'style': 'pageTitle'},
                    'layout': {'width': {'fill': 1100}, 'height': {'hug': 26}}}
doc = {'schema': 3, 'id': 'gallery', 'roots': ['gallery'], 'variables': {'gallery': variables}, 'nodes': nodes}
with open(f'{HERE}/examples/gallery.json', 'w') as f:
    json.dump(doc, f, indent=1, ensure_ascii=False)
    f.write('\n')
print(len(nodes), 'nodes')

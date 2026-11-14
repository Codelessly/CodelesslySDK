#!/usr/bin/env python3
"""Writes the SSUI design system's data: design_system.json (the tokens) and
components/*.json, converted from the Flutter package soft_saas_ui
(lib/soft_saas/{design_tokens,theme,typography,control_size,
neumorphic_shadows}.dart and lib/soft_saas/components).

The JSON files are the design system; this script is how they were made
and how they are changed consistently (one place per token and per
component). Run from anywhere: python3 design_systems/ssui/tool/generate.py
"""
import json
import os

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# --- tokens (design_tokens.dart, typography.dart, control_size.dart, neumorphic_shadows.dart) --------------

LIGHT = {
    'primaryBackground': '#FFFFFFFF', 'secondaryBackground': '#FFF9FAFB', 'tertiaryBackground': '#FFF3F4F6',
    'primaryText': '#FF111827', 'secondaryText': '#FF4B5563', 'tertiaryText': '#FF9CA3AF',
    'primaryBorder': '#FFE5E7EB', 'secondaryBorder': '#FFD1D5DB',
    'info': '#FF0891B2', 'purple': '#FF9333EA',
    'subtleFill': '#FFF3F4F6', 'neutralFill': '#FF374151', 'raisedBackground': '#FFFFFFFF',
    'track': '#FFE5E7EB', 'scrim': '#66000000', 'onAccent': '#FFFFFFFF',
    'focusBorder': '#802563EB', 'hoverOverlay': '#0A000000', 'pressedOverlay': '#14000000',
    'activeTint': '#242563EB',
    'primaryTint': '#1A2563EB', 'primaryTintBorder': '#472563EB',
    'successTint': '#1A16A34A', 'successTintBorder': '#4716A34A',
    'warningTint': '#1AEA580C', 'warningTintBorder': '#47EA580C',
    'errorTint': '#1ADC2626', 'errorTintBorder': '#47DC2626',
    'infoTint': '#1A0891B2', 'infoTintBorder': '#470891B2',
    'neutralTint': '#FFF3F4F6', 'neutralTintBorder': '#FFE5E7EB',
    'tooltipBackground': '#FF111827', 'tooltipText': '#FFFFFFFF', 'tooltipMuted': '#99FFFFFF',
}
DARK = {
    'primaryBackground': '#FF141414', 'secondaryBackground': '#FF1C1C1C', 'tertiaryBackground': '#FF383838',
    'primaryText': '#FFFFFFFF', 'secondaryText': '#99FFFFFF', 'tertiaryText': '#66FFFFFF',
    'primaryBorder': '#FF383838', 'secondaryBorder': '#FF4A4A4A',
    'info': '#FF06B6D4', 'purple': '#FFA855F7',
    'subtleFill': '#FF262626', 'neutralFill': '#FF4A4A4A', 'raisedBackground': '#FF383838',
    'track': '#FF383838', 'scrim': '#99000000', 'onAccent': '#FFFFFFFF',
    'focusBorder': '#803B82F6', 'hoverOverlay': '#14FFFFFF', 'pressedOverlay': '#24FFFFFF',
    'activeTint': '#383B82F6',
    'primaryTint': '#293B82F6', 'primaryTintBorder': '#5C3B82F6',
    'successTint': '#2922C55E', 'successTintBorder': '#5C22C55E',
    'warningTint': '#29FB923C', 'warningTintBorder': '#5CFB923C',
    'errorTint': '#29EF4444', 'errorTintBorder': '#5CEF4444',
    'infoTint': '#2906B6D4', 'infoTintBorder': '#5C06B6D4',
    'neutralTint': '#FF262626', 'neutralTintBorder': '#FF383838',
    'tooltipBackground': '#FFF3F4F6', 'tooltipText': '#FF111827', 'tooltipMuted': '#99111827',
}


def style(size, weight, color, height=1.4, **extra):
    s = {'fontSize': size, 'fontWeight': weight, 'height': height, 'color': color, 'leadingDistribution': 'even'}
    s.update(extra)
    return s


# SoftSaaSTypography's roles; control labels follow the control size (11.5 / 12 / 12.5 / 13 / 15, 500, 1.2).
TEXT_STYLES = {
    'pageTitle': style(20, 600, 'primaryText', 1.3, letterSpacing=-0.2),
    'sectionTitle': style(14, 600, 'primaryText'),
    'dialogTitle': style(14, 600, 'primaryText'),
    'panelTitle': style(12, 600, 'primaryText'),
    'body': style(13, 400, 'primaryText', 1.5),
    'bodySecondary': style(12, 400, 'secondaryText', 1.5),
    'inputText': style(12.5, 400, 'primaryText', 1.25),
    'placeholder': style(12.5, 400, 'tertiaryText', 1.25),
    'fieldLabel': style(11.5, 600, 'secondaryText', 1.3),
    'caption': style(11, 400, 'tertiaryText'),
    'mono': style(12, 400, 'primaryText', 1.5, fontFamily='monospace'),
    'badge': style(11, 500, 'primaryText', 1.2),
    'controlXs': style(11.5, 500, 'primaryText', 1.2),
    'controlCompact': style(12, 500, 'primaryText', 1.2),
    'controlSmall': style(12.5, 500, 'primaryText', 1.2),
    'controlMedium': style(13, 500, 'primaryText', 1.2),
    'controlLarge': style(15, 500, 'primaryText', 1.2),
    'heading1': style(30, 700, 'primaryText', 1.2),
    'heading2': style(24, 700, 'primaryText', 1.2),
    'heading3': style(18, 600, 'primaryText', 1.2),
}


def shadow(color, dy, blur, spread=0):
    e = {'type': 'dropShadow', 'color': color, 'offset': [0, dy], 'blurRadius': blur}
    if spread:
        e['spreadRadius'] = spread
    return e


SHADOWS_LIGHT = {
    'level1': [shadow('#0D000000', 1, 2)],
    'level2': [shadow('#1A000000', 2, 4, -1), shadow('#0D000000', 1, 2)],
    'level3': [shadow('#1F000000', 4, 16, -2), shadow('#0F000000', 1, 3)],
    'level4': [shadow('#24000000', 12, 32, -6), shadow('#0F000000', 2, 6)],
}
SHADOWS_DARK = {
    'level1': [shadow('#4D000000', 1, 2)],
    'level2': [shadow('#4D000000', 2, 4, -1)],
    'level3': [shadow('#80000000', 8, 16, -4), shadow('#40000000', 1, 3)],
    'level4': [shadow('#80000000', 16, 40, -8), shadow('#40000000', 2, 6)],
}

THEME = {
    'primary': '#FF2563EB', 'onPrimary': '#FFFFFFFF', 'surface': '#FFFFFFFF', 'onSurface': '#FF111827',
    'error': '#FFDC2626', 'success': '#FF16A34A', 'warning': '#FFEA580C',
    'radius': 7, 'buttonRadius': 7,
    'colors': LIGHT,
    'textStyles': TEXT_STYLES,
    'dark': {
        'primary': '#FF3B82F6', 'onPrimary': '#FFFFFFFF', 'surface': '#FF141414', 'onSurface': '#FFFFFFFF',
        'error': '#FFEF4444', 'success': '#FF22C55E', 'warning': '#FFFB923C',
        'colors': DARK, 'shadows': SHADOWS_DARK,
    },
    'spacing': {'1': 4, '2': 8, '3': 12, '4': 16, '5': 20, '6': 24, '8': 32, '10': 40, '12': 48, '16': 64},
    'radii': {'inner': 5, 'control': 7, 'panel': 8, 'dialog': 12, 'full': 9999},
    'sizes': {
        'xs': 24, 'compact': 28, 'small': 32, 'medium': 36, 'large': 44,
        'topBar': 44, 'panelHeader': 36, 'tableRow': 36, 'tableRowDense': 28, 'tableHeader': 32,
        'dialogHeader': 48, 'dialogFooter': 49, 'statusBar': 24,
        'dialogSmall': 400, 'dialogMedium': 520, 'dialogLarge': 720,
    },
    'shadows': SHADOWS_LIGHT,
    'durations': {'control': 150, 'transition': 200, 'tooltipDelay': 400},
    'curves': {'standard': 'easeInOut', 'enter': 'easeOut'},
}

# The control scale (SoftSaaSControlSize): height, padding x, font, icon, gap, radius.
SIZES = ['xs', 'compact', 'small', 'medium', 'large']
H = {'xs': 24, 'compact': 28, 'small': 32, 'medium': 36, 'large': 44}
PX = {'xs': 6, 'compact': 8, 'small': 10, 'medium': 10, 'large': 12}
FONT = {'xs': 11.5, 'compact': 12, 'small': 12.5, 'medium': 13, 'large': 15}
ICON = {'xs': 12, 'compact': 14, 'small': 14, 'medium': 16, 'large': 18}
GAP = {'xs': 6, 'compact': 6, 'small': 6, 'medium': 6, 'large': 8}
RADIUS = {'xs': 5, 'compact': 7, 'small': 7, 'medium': 7, 'large': 7}


def by(prop, table, default=None):
    """A formula picking table[props.<prop>]: nested conditionals."""
    keys = list(table)
    expr = repr(table[keys[-1]]) if default is None else repr(default)
    for k in reversed(keys[:-1] if default is None else keys):
        v = table[k]
        expr = f"props.{prop} == '{k}' ? {v!r} : ({expr})"
    return '${= ' + expr.replace('"', "'") + '}'


def sized(table):
    return by('size', table)


# --- declarations -------------------------------------------------------------------------------------------

STRING = {'kind': 'string', 'flutter': 'String'}
BOOL = {'kind': 'boolean', 'flutter': 'bool'}
NUMBER = {'kind': 'number', 'flutter': 'double'}
STRINGS = {'kind': 'list', 'flutter': 'List<String>', 'item': STRING}


def enum(*values):
    return {'kind': 'enumeration', 'flutter': 'String', 'values': list(values)}


def var(of):
    return {'kind': 'variable', 'of': of}


def prop(key, type_, default, doc='', required=False):
    p = {'key': key, 'type': type_, 'default': default}
    if doc:
        p['doc'] = doc
    if required:
        p['required'] = True
    return p


SIZE_PROP = prop('size', enum(*SIZES), 'compact',
                 'The control scale: xs 24 (rows, dense panels), compact 28 (the default), small 32, medium 36, large 44.')


def component(type_, doc, root, nodes, props=(), events=(), slots=(), children=None, previews=(), variables=None):
    widget = {'type': type_, 'doc': doc}
    if props:
        widget['props'] = list(props)
    if events:
        widget['events'] = [e if isinstance(e, dict) else {'key': e} for e in events]
    if slots:
        widget['slots'] = list(slots)
    if children:
        widget['children'] = children
    doc_ = {'schema': 3, 'id': type_, 'roots': [root], 'widget': widget}
    if variables:
        doc_['variables'] = {root: variables}
    if previews:
        doc_['previews'] = list(previews)
    doc_['nodes'] = _struts_out_of_spacing(nodes)
    return doc_


def _struts_out_of_spacing(nodes):
    """A row that starts with its height strut keeps its spacing between its content only.

    The strut is zero wide, but as a sibling of the content the row's spacing put one gap
    after it: every button, badge and chip had that much extra room on its left. The
    content moves into an inner row that carries the spacing; the outer row holds the
    strut and that inner row with no spacing.
    """
    out = dict(nodes)
    for nid, n in nodes.items():
        kids = n.get('children') or []
        if n.get('type') != 'row' or len(kids) < 2 or kids[0] != 'strut':
            continue
        outer = {**n, 'props': dict(n.get('props') or {}), 'layout': dict(n.get('layout') or {})}
        inner_id = nid + 'Content'
        assert inner_id not in nodes, inner_id
        fills = isinstance(outer['layout'].get('width'), dict) and 'fill' in outer['layout']['width']
        inner = {'type': 'row', 'children': kids[1:],
                 'props': {k: v for k, v in outer['props'].items() if k in ('spacing', 'crossAxisAlignment', 'mainAxisAlignment')},
                 'layout': {'width': {'fill': 100} if fills else {'hug': 40}, 'height': {'hug': 16}}}
        outer['props']['spacing'] = 0
        outer['children'] = ['strut', inner_id]
        bind = dict(outer.get('bind') or {})
        if 'props.spacing' in bind:
            inner['bind'] = {'props.spacing': bind.pop('props.spacing')}
            outer['bind'] = bind
        out[nid] = outer
        out[inner_id] = inner
    return out


def preview(_name, _w, _h, **props):
    return {'name': _name, 'size': [_w, _h], 'props': props}


def text(t, style_, w=None, h=None, **kw):
    n = {'type': 'text', 'props': {'text': t, 'style': style_},
         'layout': {'width': w or {'hug': 40}, 'height': h or {'hug': 16}}}
    n.update(kw)
    return n


def icon(name, color, size, **kw):
    n = {'type': 'icon', 'props': {'icon': name, 'color': color, 'size': size}, 'layout': {'width': size, 'height': size}}
    n.update(kw)
    return n


def strut(height_formula, h):
    """A zero-wide box whose height is the control's: the row around it is exactly that tall."""
    return {'type': 'box', 'layout': {'width': 0, 'height': h}, 'bind': {'layout.height': height_formula}}


HOVER = {'decoration': {'foregroundFills': [{'color': 'hoverOverlay'}]}}
PRESS = {'decoration': {'foregroundFills': [{'color': 'pressedOverlay'}]}}

COMPONENTS = []


def add(c):
    COMPONENTS.append(c)
    return c


# --- components ---------------------------------------------------------------------------------------------

def pressable_states(root, extra_disabled=None):
    states = {'hovered': {root: HOVER}, 'pressed': {root: PRESS}, 'disabled': {root: {'opacity': 0.5}}}
    if extra_disabled:
        states['disabled'].update(extra_disabled)
    return states


def click(event, when='props.enabled', value=None, more=()):
    a = {'type': 'componentEvent', 'event': event}
    if value is not None:
        a['value'] = value
    return {'trigger': {'type': 'click', 'when': when}, 'actions': [*more, a]}


ON_ACCENT_VARIANTS = "props.variant == 'primary' || props.variant == 'secondary' || props.variant == 'destructive'"

# Button (button.dart: SoftSaaSButton): primary fills with Action Blue, secondary a neutral fill, outline a
# hairline, ghost nothing, destructive Alert Red; hover and press are overlays; 50 % when disabled.
add(component(
    'Button',
    'A button on the control scale: primary (one per view), secondary, outline, ghost or destructive. Fires onPressed.',
    'button',
    props=[
        prop('label', STRING, 'Button', 'The text.', required=True),
        prop('variant', enum('primary', 'secondary', 'outline', 'ghost', 'destructive'), 'primary',
             'primary fills with the brand colour; secondary a strong neutral; outline a hairline; ghost nothing; destructive red.'),
        SIZE_PROP,
        prop('icon', STRING, '', 'A Material icon name shown before the label (empty: none).'),
        prop('enabled', BOOL, True, 'False: 50 % opacity, not pressable.'),
    ],
    events=['onPressed'],
    previews=[preview('Primary', 96, 28, label='Save'), preview('Outline', 96, 28, label='Cancel', variant='outline')],
    nodes={
        'button': {
            'type': 'row', 'children': ['strut', 'icon', 'label'],
            'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center', 'spacing': 6},
            'layout': {'width': {'hug': 72}, 'height': {'hug': 28}, 'padding': [10, 0, 10, 0]},
            'decoration': {'fills': [{'color': 'primary'}], 'strokes': [{'color': '#00000000'}], 'radius': 7},
            'bind': {
                # button.dart: the control's paddingX + 2 (8 / 10 / 12 / 12 / 14).
                'layout.padding': sized({s: [PX[s] + 2, 0, PX[s] + 2, 0] for s in SIZES}),
                'props.spacing': sized(GAP),
                'decoration.radius': sized(RADIUS),
                'decoration.fills[0].color': "${= props.variant == 'primary' ? theme.primary : (props.variant == 'secondary' ? theme.colors.neutralFill : (props.variant == 'destructive' ? theme.error : '#00000000'))}",
                'decoration.strokes[0].color': "${= props.variant == 'outline' ? theme.colors.primaryBorder : '#00000000'}",
                'disabled': '${= !props.enabled}',
            },
            'states': pressable_states('button'),
            'actions': [click('onPressed')],
        },
        'strut': strut(sized(H), 28),
        'icon': {**icon('add', 'onAccent', 14), 'bind': {
            'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}', 'props.size': sized(ICON),
            'layout.width': sized(ICON), 'layout.height': sized(ICON),
            'props.color': "${= " + ON_ACCENT_VARIANTS + " ? theme.colors.onAccent : theme.colors.primaryText}"}},
        'label': {**text('${props.label}', 'controlCompact', {'hug': 40}, {'hug': 15}), 'bind': {
            'props.style.fontSize': sized(FONT),
            'props.style.color': "${= " + ON_ACCENT_VARIANTS + " ? theme.colors.onAccent : theme.colors.primaryText}"},
            'props': {'text': '${props.label}', 'style': 'controlCompact', 'maxLines': 1, 'overflow': 'ellipsis'}},
    },
))


# IconButton (icon_button / SoftSaaSIconButton): a square on the control scale, ghost by default.
add(component(
    'IconButton',
    'A square icon-only button on the control scale: ghost (the default), outline or primary. Fires onPressed.',
    'button',
    props=[
        prop('icon', STRING, 'more_horiz', 'A Material icon name.', required=True),
        prop('variant', enum('ghost', 'outline', 'primary'), 'ghost', 'ghost: nothing until hovered; outline: a hairline; primary: the brand fill.'),
        SIZE_PROP,
        prop('enabled', BOOL, True, 'False: 50 % opacity, not pressable.'),
    ],
    events=['onPressed'],
    previews=[preview('Ghost', 28, 28, icon='more_horiz'), preview('Outline', 28, 28, icon='add', variant='outline')],
    nodes={
        'button': {
            'type': 'row', 'children': ['strut', 'glyph'],
            'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
            'layout': {'width': {'hug': 28}, 'height': {'hug': 28}},
            'decoration': {'fills': [{'color': '#00000000'}], 'strokes': [{'color': '#00000000'}], 'radius': 7},
            'bind': {
                'layout.padding': sized({s: [(H[s] - ICON[s]) / 2, 0, (H[s] - ICON[s]) / 2, 0] for s in SIZES}),
                'decoration.radius': sized(RADIUS),
                'decoration.fills[0].color': "${= props.variant == 'primary' ? theme.primary : '#00000000'}",
                'decoration.strokes[0].color': "${= props.variant == 'outline' ? theme.colors.primaryBorder : '#00000000'}",
                'disabled': '${= !props.enabled}',
            },
            'states': pressable_states('button'),
            'actions': [click('onPressed')],
        },
        'strut': strut(sized(H), 28),
        'glyph': {**icon('more_horiz', 'primaryText', 14), 'bind': {
            'props.icon': '${props.icon}', 'props.size': sized(ICON), 'layout.width': sized(ICON), 'layout.height': sized(ICON),
            'props.color': "${= props.variant == 'primary' ? theme.colors.onAccent : theme.colors.secondaryText}"}},
    },
))


def outline(color, width=1):
    return {'type': 'outline', 'borderRadius': 7, 'borderSide': {'color': color, 'width': width}}


FIELD_DECORATION = {
    'isDense': True, 'filled': True, 'fillColor': 'primaryBackground',
    'contentPadding': [8, 6, 8, 6],
    'hintStyle': 'placeholder',
    'border': outline('primaryBorder'), 'enabledBorder': outline('primaryBorder'),
    'focusedBorder': outline('focusBorder', 1.5), 'errorBorder': outline('error'),
    'focusedErrorBorder': outline('error', 1.5), 'disabledBorder': outline('primaryBorder'),
    'hoverColor': '#00000000',
}

# TextInput (text_input.dart / SoftSaaSControlShell): the platform text field, every part styled: hairline at
# rest, the focus border (primary at 50 %, 1.5) when focused, the error colour on error, 50 % when disabled.
add(component(
    'TextInput',
    'A one-line text field on the control scale (28 by default), its value kept in your variable. Fires onChanged and onSubmitted.',
    'field',
    props=[
        prop('value', var(STRING), '', 'The name of your text variable: the field shows it and writes it as the user types.'),
        prop('placeholder', STRING, '', 'Shown while empty.'),
        prop('error', BOOL, False, 'Draws the error border (the message goes under it: a Field\'s error).'),
        prop('obscure', BOOL, False, 'Hides the text (passwords).'),
        prop('keyboard', enum('text', 'emailAddress', 'number', 'phone', 'url', 'visiblePassword'), 'text', 'The keyboard a phone shows.'),
        prop('enabled', BOOL, True, 'False: 50 % opacity, not editable.'),
    ],
    events=[{'key': 'onChanged', 'payload': STRING}, {'key': 'onSubmitted', 'payload': STRING}],
    previews=[preview('Empty', 240, 28, placeholder='name@company.com'), preview('Filled', 240, 28, value='Ada Lovelace')],
    nodes={
        'field': {
            'type': 'textField',
            'layout': {'width': {'fill': 240}, 'height': 28},
            'props': {'style': 'inputText', 'decoration': FIELD_DECORATION, 'cursorColor': 'primary', 'cursorHeight': 14},
            'bind': {
                'props.initialValue': '${props.value}',
                'props.decoration.hintText': '${props.placeholder}',
                'props.decoration.errorText': "${= props.error ? '​' : ''}",
                'props.obscureText': '${props.obscure}',
                'props.keyboardType': '${props.keyboard}',
                'props.enabled': '${props.enabled}',
                'disabled': '${= !props.enabled}',
            },
            'states': {'disabled': {'field': {'opacity': 0.5}}},
            'actions': [
                {'trigger': {'type': 'changed'}, 'actions': [
                    {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'},
                    {'type': 'componentEvent', 'event': 'onChanged', 'value': '${result}'}]},
                {'trigger': {'type': 'submitted'}, 'actions': [{'type': 'componentEvent', 'event': 'onSubmitted', 'value': '${result}'}]},
            ],
        },
    },
))

# TextArea (text_area.dart): the same shell, several lines.
add(component(
    'TextArea',
    'A multi-line text field (a note, a message), styled as TextInput, its value kept in your variable. Fires onChanged.',
    'field',
    props=[
        prop('value', var(STRING), '', 'The name of your text variable.'),
        prop('placeholder', STRING, '', 'Shown while empty.'),
        prop('error', BOOL, False, 'Draws the error border.'),
        prop('enabled', BOOL, True, 'False: 50 % opacity, not editable.'),
    ],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Empty', 320, 88, placeholder='Add a note…')],
    nodes={
        'field': {
            'type': 'textField',
            'layout': {'width': {'fill': 320}, 'height': 88},
            'props': {'style': {'from': 'inputText', 'height': 1.5}, 'maxLines': 0, 'decoration': {**FIELD_DECORATION, 'contentPadding': [8, 7, 8, 7]},
                      'keyboardType': 'multiline', 'textAlignVertical': 'top', 'cursorColor': 'primary'},
            'bind': {
                'props.initialValue': '${props.value}',
                'props.decoration.hintText': '${props.placeholder}',
                'props.decoration.errorText': "${= props.error ? '​' : ''}",
                'props.enabled': '${props.enabled}',
                'disabled': '${= !props.enabled}',
            },
            'states': {'disabled': {'field': {'opacity': 0.5}}},
            'actions': [{'trigger': {'type': 'changed'}, 'actions': [
                {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'},
                {'type': 'componentEvent', 'event': 'onChanged', 'value': '${result}'}]}],
        },
    },
))

# Select (select.dart / SoftSaaSDropdown): the platform dropdown (its menu), inside the control shell: hairline,
# radius 7, 28 high, a chevron in tertiary text.
add(component(
    'Select',
    'A dropdown of options on the control scale, the choice kept in your variable. Fires onChanged.',
    'shell',
    props=[
        prop('options', STRINGS, ['One', 'Two', 'Three'], 'The options, as shown.', required=True),
        prop('value', var(STRING), '', 'The name of your text variable holding the chosen option.'),
        prop('placeholder', STRING, 'Select…', 'Shown while nothing is chosen.'),
        prop('error', BOOL, False, 'Draws the error border.'),
        prop('enabled', BOOL, True, 'False: 50 % opacity, closed.'),
    ],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Chosen', 200, 28, options=['Weekly', 'Monthly', 'Yearly'], value='Monthly'),
              preview('Empty', 200, 28, options=['Weekly', 'Monthly'])],
    nodes={
        'shell': {
            'type': 'row', 'children': ['menu'],
            'props': {'crossAxisAlignment': 'center'},
            'layout': {'width': {'fill': 200}, 'height': 28, 'padding': [8, 0, 4, 0]},
            'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 7},
            'bind': {
                'decoration.strokes[0].color': '${= props.error ? theme.error : theme.colors.primaryBorder}',
                'disabled': '${= !props.enabled}',
            },
            'states': {'hovered': {'shell': {'decoration': {'strokes': [{'color': 'secondaryBorder'}]}}},
                       'disabled': {'shell': {'opacity': 0.5}}},
        },
        'menu': {
            'type': 'dropdown',
            'layout': {'width': {'fill': 188}, 'height': {'fill': 28}},
            'props': {'underline': False, 'isExpanded': True, 'isDense': True, 'style': 'inputText',
                      'selectedItemStyle': 'inputText', 'hintStyle': 'placeholder', 'iconSize': 18,
                      'iconEnabledColor': 'tertiaryText', 'iconDisabledColor': 'tertiaryText',
                      'dropdownColor': 'primaryBackground', 'borderRadius': 7, 'elevation': 3},
            'bind': {'props.items': '${props.options}', 'props.value': '${props.value}', 'props.hint': '${props.placeholder}',
                     'props.enabled': '${props.enabled}'},
            'actions': [{'trigger': {'type': 'changed'}, 'actions': [
                {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'},
                {'type': 'componentEvent', 'event': 'onChanged', 'value': '${result}'}]}],
        },
    },
))

# Checkbox (checkbox.dart): a 16 px box, radius 4, a hairline (secondary border) at rest; checked: the brand
# fill and a white check. Drawn from core nodes.
add(component(
    'Checkbox',
    'A check box with an optional label, its value kept in your variable. Fires onChanged.',
    'row',
    props=[
        prop('value', var(BOOL), '', 'The name of your boolean variable.'),
        prop('label', STRING, '', 'Text beside the box (empty: none).'),
        prop('enabled', BOOL, True, 'False: 50 % opacity, not toggled.'),
    ],
    events=[{'key': 'onChanged', 'payload': BOOL}],
    previews=[preview('Checked', 160, 28, label='Remember me', value=True), preview('Unchecked', 160, 28, label='Remember me')],
    nodes={
        'row': {
            'type': 'row', 'children': ['box', 'label'],
            'props': {'crossAxisAlignment': 'center', 'spacing': 8},
            'layout': {'width': {'hug': 120}, 'height': {'hug': 28}, 'constraints': {'minHeight': 24}},
            'bind': {'selected': '${= props.value == true}', 'disabled': '${= !props.enabled}'},
            'states': {
                'selected': {'box': {'decoration': {'fills': [{'color': 'primary'}], 'strokes': [{'color': 'primary'}]}},
                             'check': {'visible': True}},
                'hovered': {'box': {'decoration': {'strokes': [{'color': 'tertiaryText'}]}}},
                'disabled': {'row': {'opacity': 0.5}},
            },
            'actions': [{'trigger': {'type': 'click', 'when': 'props.enabled'}, 'actions': [
                {'type': 'setVariable', 'variable': 'props.value', 'value': '${= !(props.value == true)}'},
                {'type': 'componentEvent', 'event': 'onChanged', 'value': '${= props.value == true}'}]}],
        },
        'box': {
            'type': 'row', 'children': ['check'],
            'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
            'layout': {'width': 16, 'height': 16},
            'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'secondaryBorder'}], 'radius': 4},
        },
        'check': {**icon('check', 'onAccent', 12), 'visible': False},
        'label': {**text('${props.label}', 'body', {'hug': 80}, {'hug': 19}), 'bind': {'visible': "${= props.label != ''}"}},
    },
))

# Radio (radio.dart): a 16 px circle, a hairline at rest; selected: a brand ring and a 6 px dot.
add(component(
    'Radio',
    'One option of a group: selected while your variable holds its value; tapping sets it. Fires onChanged.',
    'row',
    props=[
        prop('value', STRING, '', 'This option\'s value.', required=True),
        prop('group', var(STRING), '', 'The name of your text variable holding the group\'s chosen value.'),
        prop('label', STRING, '', 'Text beside the circle.'),
        prop('enabled', BOOL, True, 'False: 50 % opacity.'),
    ],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Selected', 160, 28, value='a', group='a', label='Standard'), preview('Not selected', 160, 28, value='b', group='a', label='Express')],
    nodes={
        'row': {
            'type': 'row', 'children': ['ring', 'label'],
            'props': {'crossAxisAlignment': 'center', 'spacing': 8},
            'layout': {'width': {'hug': 120}, 'height': {'hug': 28}, 'constraints': {'minHeight': 24}},
            'bind': {'selected': '${= props.group == props.value}', 'disabled': '${= !props.enabled}'},
            'states': {
                'selected': {'ring': {'decoration': {'strokes': [{'color': 'primary'}], 'strokeWidth': 5}}},
                'hovered': {'ring': {'decoration': {'strokes': [{'color': 'tertiaryText'}]}}},
                'disabled': {'row': {'opacity': 0.5}},
            },
            'actions': [{'trigger': {'type': 'click', 'when': 'props.enabled'}, 'actions': [
                {'type': 'setVariable', 'variable': 'props.group', 'value': '${props.value}'},
                {'type': 'componentEvent', 'event': 'onChanged', 'value': '${props.value}'}]}],
        },
        'ring': {
            'type': 'box', 'layout': {'width': 16, 'height': 16},
            'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'secondaryBorder'}], 'strokeWidth': 1, 'radius': 8},
        },
        'label': {**text('${props.label}', 'body', {'hug': 80}, {'hug': 19}), 'bind': {'visible': "${= props.label != ''}"}},
    },
))

# Switch (switch.dart): a 32 x 18 pill track, a 14 px white thumb with a level-1 shadow; on: the brand track.
add(component(
    'Switch',
    'An on/off toggle with an optional label, its value kept in your variable. Fires onChanged.',
    'row',
    props=[
        prop('value', var(BOOL), '', 'The name of your boolean variable.'),
        prop('label', STRING, '', 'Text beside the switch.'),
        prop('enabled', BOOL, True, 'False: 50 % opacity.'),
    ],
    events=[{'key': 'onChanged', 'payload': BOOL}],
    previews=[preview('On', 160, 28, value=True, label='Notifications'), preview('Off', 160, 28, label='Notifications')],
    nodes={
        'row': {
            'type': 'row', 'children': ['track', 'label'],
            'props': {'crossAxisAlignment': 'center', 'spacing': 8},
            'layout': {'width': {'hug': 120}, 'height': {'hug': 28}, 'constraints': {'minHeight': 24}},
            'bind': {'selected': '${= props.value == true}', 'disabled': '${= !props.enabled}'},
            'states': {
                'hovered': {'track': {'decoration': {'fills': [{'color': 'tertiaryText'}]}}},
                'selected': {'track': {'decoration': {'fills': [{'color': 'primary'}]}, 'props': {'mainAxisAlignment': 'end'}}},
                'disabled': {'row': {'opacity': 0.5}},
            },
            'actions': [{'trigger': {'type': 'click', 'when': 'props.enabled'}, 'actions': [
                {'type': 'setVariable', 'variable': 'props.value', 'value': '${= !(props.value == true)}'},
                {'type': 'componentEvent', 'event': 'onChanged', 'value': '${= props.value == true}'}]}],
        },
        'track': {
            'type': 'row', 'children': ['thumb'],
            'props': {'mainAxisAlignment': 'start', 'crossAxisAlignment': 'center'},
            'layout': {'width': 36, 'height': 20, 'padding': 2},
            'decoration': {'fills': [{'color': 'secondaryBorder'}], 'radius': 10},
        },
        'thumb': {
            'type': 'box', 'layout': {'width': 16, 'height': 16},
            'decoration': {'fills': [{'color': '#FFFFFFFF'}], 'radius': 8, 'effects': SHADOWS_LIGHT['level1']},
        },
        'label': {**text('${props.label}', 'body', {'hug': 80}, {'hug': 19}), 'bind': {'visible': "${= props.label != ''}"}},
    },
))

# Slider (slider.dart): the platform slider (dragging, keys), every part styled: a 4 px track in the track
# colour, the brand fill, a 14 px white thumb with a hairline.
add(component(
    'Slider',
    'A value between min and max, dragged, kept in your variable. Fires onChanged.',
    'slider',
    props=[
        prop('value', var(NUMBER), '', 'The name of your number variable.'),
        prop('min', NUMBER, 0, 'The smallest value.'),
        prop('max', NUMBER, 100, 'The largest value.'),
        prop('divisions', {'kind': 'integer', 'flutter': 'int'}, 0, 'Steps between min and max (0: continuous).'),
        prop('enabled', BOOL, True, 'False: 50 % opacity.'),
    ],
    events=[{'key': 'onChanged', 'payload': NUMBER}],
    previews=[preview('Half', 240, 28, value=50)],
    nodes={
        'slider': {
            'type': 'slider',
            'layout': {'width': {'fill': 240}, 'height': 28},
            'props': {'trackHeight': 4, 'activeTrackColor': 'primary', 'inactiveTrackColor': 'track', 'thumbColor': '#FFFFFFFF',
                      'thumbRadius': 7, 'thumbBorderColor': 'secondaryBorder', 'thumbBorderWidth': 1, 'overlayColor': 'activeTint',
                      'showValueIndicator': 'never', 'padding': [7, 0, 7, 0]},
            'bind': {'props.value': '${= props.value == null ? props.min : props.value}', 'props.min': '${props.min}', 'props.max': '${props.max}',
                     'props.divisions': '${= props.divisions > 0 ? props.divisions : null}',
                     'disabled': '${= !props.enabled}'},
            'states': {'disabled': {'slider': {'opacity': 0.5}}},
            'actions': [{'trigger': {'type': 'changed'}, 'actions': [
                {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'},
                {'type': 'componentEvent', 'event': 'onChanged', 'value': '${result}'}]}],
        },
    },
))

# SegmentedControl (segmented_control.dart): a subtle-fill track, radius 7, 2 px inset; the chosen segment is
# raised (raised background, level-1 shadow, radius 5) with primary text, the others secondary text.
add(component(
    'SegmentedControl',
    'Two to five mutually exclusive options in one control (a view switch, a period), the choice in your variable. Fires onChanged.',
    'track',
    props=[
        prop('options', STRINGS, ['Day', 'Week', 'Month'], 'The options, as shown.', required=True),
        prop('value', var(STRING), '', 'The name of your text variable holding the chosen option.'),
        SIZE_PROP,
    ],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Week', 240, 28, options=['Day', 'Week', 'Month'], value='Week')],
    nodes={
        'track': {
            'type': 'row', 'children': ['segments'],
            'props': {'crossAxisAlignment': 'center'},
            'layout': {'width': {'hug': 200}, 'height': {'hug': 28}, 'padding': 2},
            'decoration': {'fills': [{'color': 'subtleFill'}], 'radius': 7},
        },
        'segments': {
            'type': 'listView', 'children': ['segment'],
            'props': {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': 2},
            'layout': {'width': {'hug': 196}, 'height': 24},
            'bind': {'data': '${props.options}', 'layout.height': sized({k: v - 4 for k, v in H.items()})},
        },
        'segment': {
            'type': 'row', 'children': ['segmentLabel'],
            'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
            'layout': {'width': {'hug': 60}, 'height': {'fill': 24}, 'padding': [10, 0, 10, 0]},
            'decoration': {'fills': [{'color': '#00000000'}], 'radius': 5},
            'bind': {'selected': '${= item == props.value}', 'layout.padding': sized({s: [PX[s] + 2, 0, PX[s] + 2, 0] for s in SIZES})},
            'states': {
                'selected': {'segment': {'decoration': {'fills': [{'color': 'raisedBackground'}], 'effects': SHADOWS_LIGHT['level1']}},
                             'segmentLabel': {'props': {'style': {'color': 'primaryText'}}}},
                'hovered': {'segmentLabel': {'props': {'style': {'color': 'primaryText'}}}},
            },
            'actions': [{'trigger': 'click', 'actions': [
                {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}],
        },
        'segmentLabel': {**text('${item}', {'from': 'controlCompact', 'color': 'secondaryText'}, {'hug': 40}, {'hug': 15}),
                         'bind': {'props.style.fontSize': sized(FONT)}},
    },
))

# Tabs (tabs.dart / SoftSaaSTabs): a 36 px bar with a hairline below; the current tab in primary text with a
# 2 px brand underline, the others secondary text.
add(component(
    'Tabs',
    'A row of tabs over a panel, the current one in your variable; show the panel for it yourself. Fires onChanged.',
    'bar',
    props=[
        prop('tabs', STRINGS, ['Overview', 'Activity', 'Settings'], 'The tab labels.', required=True),
        prop('value', var(STRING), '', 'The name of your text variable holding the current tab.'),
    ],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Overview', 360, 36, tabs=['Overview', 'Activity', 'Settings'], value='Overview')],
    nodes={
        'bar': {
            'type': 'row', 'children': ['tabList'],
            'layout': {'width': {'fill': 360}, 'height': 36, 'padding': [12, 0, 12, 0]},
            'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'},
        },
        'tabList': {
            'type': 'listView', 'children': ['tab'],
            'props': {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': 16},
            'layout': {'width': {'fill': 336}, 'height': {'fill': 36}},
            'bind': {'data': '${props.tabs}'},
        },
        'tab': {
            'type': 'stack', 'children': ['tabLabel', 'tabLine'],
            'layout': {'width': {'hug': 60}, 'height': {'fill': 36}},
            'bind': {'selected': '${= item == props.value}'},
            'states': {
                'selected': {'tabLabel': {'props': {'style': {'color': 'primaryText', 'fontWeight': 600}}}, 'tabLine': {'visible': True}},
                'hovered': {'tabLabel': {'props': {'style': {'color': 'primaryText'}}}},
            },
            'actions': [{'trigger': 'click', 'actions': [
                {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}],
        },
        'tabLabel': {**text('${item}', {'from': 'controlCompact', 'color': 'secondaryText'}, {'hug': 50}, {'hug': 15}),
                     'layout': {'width': {'hug': 50}, 'height': {'hug': 15}, 'y': {'align': 0}}},
        'tabLine': {'type': 'box', 'visible': False, 'layout': {'width': {'fill': 50}, 'height': 2, 'y': {'end': 0}},
                    'decoration': {'fills': [{'color': 'primary'}], 'radius': [1, 1, 0, 0]}},
    },
))

TONES = ['neutral', 'primary', 'success', 'warning', 'error', 'info']
TINT = "${= props.tone == 'neutral' ? theme.colors.neutralTint : (props.tone == 'primary' ? theme.colors.primaryTint : (props.tone == 'success' ? theme.colors.successTint : (props.tone == 'warning' ? theme.colors.warningTint : (props.tone == 'error' ? theme.colors.errorTint : theme.colors.infoTint))))}"
TINT_BORDER = TINT.replace('Tint :', 'TintBorder :').replace('Tint)', 'TintBorder)').replace('infoTint)', 'infoTintBorder)')
INK = "${= props.tone == 'neutral' ? theme.colors.secondaryText : (props.tone == 'primary' ? theme.primary : (props.tone == 'success' ? theme.success : (props.tone == 'warning' ? theme.warning : (props.tone == 'error' ? theme.error : theme.colors.info))))}"
TONE_PROP = prop('tone', enum(*TONES), 'neutral', 'neutral, primary, success, warning, error or info: a 10 % tint, a matching hairline, the tone\'s ink.')

# Badge (badge.dart / status_badge.dart): a fixed-height pill, tinted fill and tint border, never wider than its text.
add(component(
    'Badge',
    'A small status or count label: tinted, 20 px high, radius 5 (a pill for counts), as wide as its text.',
    'badge',
    props=[prop('label', STRING, 'Badge', 'The text.', required=True), TONE_PROP,
           prop('dot', BOOL, False, 'A 6 px dot of the tone before the text (a status).'),
           prop('pill', BOOL, False, 'Fully rounded (a count); rounded corners (radius 5) otherwise.')],
    previews=[preview('Success', 80, 20, label='Paid', tone='success'), preview('Neutral', 80, 20, label='Draft')],
    nodes={
        'badge': {
            'type': 'row', 'children': ['strut', 'dot', 'label'],
            'props': {'crossAxisAlignment': 'center', 'spacing': 5},
            'layout': {'width': {'hug': 48}, 'height': {'hug': 20}, 'padding': [8, 0, 8, 0]},
            'decoration': {'fills': [{'color': 'neutralTint'}], 'strokes': [{'color': 'neutralTintBorder'}], 'radius': 5},
            'bind': {'decoration.fills[0].color': TINT, 'decoration.strokes[0].color': TINT_BORDER,
                     'decoration.radius': "${= props.pill ? 10 : 5}"},
        },
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 20}},
        'dot': {'type': 'box', 'layout': {'width': 6, 'height': 6}, 'decoration': {'fills': [{'color': 'secondaryText'}], 'radius': 3},
                'bind': {'visible': '${props.dot}', 'decoration.fills[0].color': INK}},
        'label': {**text('${props.label}', 'badge', {'hug': 30}, {'hug': 14}), 'bind': {'props.style.color': INK}},
    },
))

# Chip (chip.dart / resource_chip.dart): a 24 px label on the subtle fill, radius 5; selectable (the active tint
# and primary text when selected) and removable (an x).
add(component(
    'Chip',
    'A compact label: a tag, a filter (selected or not) or a removable value. Fires onPressed and onRemove.',
    'chip',
    props=[
        prop('label', STRING, 'Chip', 'The text.', required=True),
        prop('selected', BOOL, False, 'The active tint and primary text (a filter that is on).'),
        prop('removable', BOOL, False, 'An x after the label that fires onRemove.'),
        prop('icon', STRING, '', 'A Material icon name before the label (empty: none).'),
    ],
    events=['onPressed', 'onRemove'],
    previews=[preview('Tag', 96, 24, label='Design'), preview('Selected', 96, 24, label='Design', selected=True),
              preview('Removable', 110, 24, label='Design', removable=True)],
    nodes={
        'chip': {
            'type': 'row', 'children': ['strut', 'icon', 'label', 'remove'],
            'props': {'crossAxisAlignment': 'center', 'spacing': 4},
            'layout': {'width': {'hug': 60}, 'height': {'hug': 24}, 'padding': [8, 0, 8, 0]},
            'decoration': {'fills': [{'color': 'subtleFill'}], 'strokes': [{'color': '#00000000'}], 'radius': 5},
            'bind': {'selected': '${props.selected}', 'layout.padding': "${= props.removable ? [8, 0, 4, 0] : [8, 0, 8, 0]}"},
            'states': {
                'selected': {'chip': {'decoration': {'fills': [{'color': 'activeTint'}], 'strokes': [{'color': 'primaryTintBorder'}]}},
                             'label': {'props': {'style': {'color': 'primary'}}}, 'icon': {'props': {'color': 'primary'}}},
                'hovered': {'chip': HOVER},
            },
            'actions': [click('onPressed', when='')],
        },
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 24}},
        'icon': {**icon('sell', 'secondaryText', 12), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'label': text('${props.label}', {'from': 'controlCompact', 'color': 'primaryText'}, {'hug': 40}, {'hug': 15}),
        'remove': {
            'type': 'row', 'children': ['x'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
            'layout': {'width': 16, 'height': 16}, 'decoration': {'radius': 4},
            'bind': {'visible': '${props.removable}'},
            'states': {'hovered': {'remove': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
            'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onRemove', 'value': '${props.label}'}]}],
        },
        'x': icon('close', 'secondaryText', 12),
    },
))

# Card (card.dart / SoftSaaSPanel): radius 8, primary background, a hairline, no shadow; a header (title 12/600,
# subtitle, trailing actions) over a 12 px padded body.
add(component(
    'Card',
    'A bordered panel: an optional header (title, subtitle, trailing actions) over its body (the call\'s children).',
    'card',
    props=[prop('title', STRING, '', 'The header\'s title (empty: no header).'),
           prop('subtitle', STRING, '', 'A line under the title.'),
           prop('elevated', BOOL, False, 'Floats over content: shadow level 1 (cards are flat by default).')],
    slots=['actions'], children='list',
    previews=[preview('With header', 320, 140, title='Billing', subtitle='Your plan and invoices')],
    nodes={
        'card': {
            'type': 'column', 'children': ['header', 'body'],
            'props': {'crossAxisAlignment': 'stretch'},
            'layout': {'width': {'fill': 320}, 'height': {'hug': 140}},
            'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8, 'clip': 'antiAlias'},
            'bind': {'decoration.effects': '${= props.elevated ? theme.shadows.level1 : []}'},
        },
        'header': {
            'type': 'row', 'children': ['titles', 'actions'],
            'props': {'crossAxisAlignment': 'center', 'spacing': 8},
            'layout': {'width': {'fill': 320}, 'height': {'hug': 36}, 'padding': [12, 9, 10, 9], 'constraints': {'minHeight': 36}},
            'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'},
            'bind': {'visible': "${= props.title != ''}"},
        },
        'titles': {'type': 'column', 'children': ['title', 'subtitle'], 'props': {'crossAxisAlignment': 'start', 'spacing': 1},
                   'layout': {'width': {'fill': 240}, 'height': {'hug': 32}}},
        'title': text('${props.title}', 'panelTitle', {'fill': 240}, {'hug': 17}),
        'subtitle': {**text('${props.subtitle}', 'caption', {'fill': 240}, {'hug': 15}), 'bind': {'visible': "${= props.subtitle != ''}"}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
        'body': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 8},
                 'layout': {'width': {'fill': 320}, 'height': {'hug': 80}, 'padding': 12}},
        'content': {'type': 'slot'},
    },
))

# Dialog (dialog.dart / SoftSaaSDialog): radius 12, a hairline, shadow level 4; a 48 px header (title 14/600, a
# 28 px ghost close), a body padded 12 / 0 / 12 / 12, a 49 px footer with a hairline and its actions 6 apart.
add(component(
    'Dialog',
    'A dialog\'s frame for a modal canvas: title, optional description, body (the call\'s children) and footer actions. Fires onClose.',
    'dialog',
    props=[prop('title', STRING, 'Dialog', 'The title.', required=True),
           prop('description', STRING, '', 'A line under the title.'),
           prop('closable', BOOL, True, 'A close button in the header (fires onClose).')],
    slots=['actions'], children='list', events=['onClose'],
    previews=[preview('Confirm', 400, 200, title='Delete project?', description='This cannot be undone.')],
    nodes={
        'dialog': {
            'type': 'column', 'children': ['head', 'body', 'foot'],
            'props': {'crossAxisAlignment': 'stretch'},
            'layout': {'width': {'fill': 400}, 'height': {'hug': 200}, 'constraints': {'maxWidth': 520}},
            'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12,
                           'effects': SHADOWS_LIGHT['level4'], 'clip': 'antiAlias'},
            'bind': {'decoration.effects': '${theme.shadows.level4}'},
        },
        'head': {'type': 'row', 'children': ['heading', 'close'], 'props': {'crossAxisAlignment': 'start', 'spacing': 8},
                 'layout': {'width': {'fill': 400}, 'height': {'hug': 48}, 'padding': [12, 10, 10, 10], 'constraints': {'minHeight': 48}}},
        'heading': {'type': 'column', 'children': ['title', 'description'], 'props': {'crossAxisAlignment': 'start', 'spacing': 2},
                    'layout': {'width': {'fill': 330}, 'height': {'hug': 28}, 'padding': [0, 5, 0, 0]}},
        'title': text('${props.title}', 'dialogTitle', {'fill': 330}, {'hug': 20}),
        'description': {**text('${props.description}', 'bodySecondary', {'fill': 330}, {'hug': 18}),
                        'bind': {'visible': "${= props.description != ''}"}},
        'close': {'type': 'IconButton', 'props': {'icon': 'close'}, 'layout': {'width': 28, 'height': 28},
                  'bind': {'visible': '${props.closable}'},
                  'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'onClose'}]}]},
        'body': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 12},
                 'layout': {'width': {'fill': 400}, 'height': {'hug': 60}, 'padding': [12, 0, 12, 12]}},
        'content': {'type': 'slot'},
        'foot': {'type': 'row', 'children': ['actions'], 'props': {'mainAxisAlignment': 'end', 'crossAxisAlignment': 'center', 'spacing': 6},
                 'layout': {'width': {'fill': 400}, 'height': {'hug': 49}, 'padding': [12, 10, 12, 10]},
                 'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'top'}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
    },
))

# Banner (banner.dart / toast.dart): a tinted, hairline-bordered message with the tone's icon; also a toast's look.
TONE_ICON = "${= props.tone == 'success' ? 'check_circle' : (props.tone == 'warning' ? 'warning_amber' : (props.tone == 'error' ? 'error_outline' : 'info_outline'))}"
add(component(
    'Banner',
    'An inline message (info, success, warning, error): the tone\'s tint, icon and an optional action (the actions slot). Fires onDismiss.',
    'banner',
    props=[prop('title', STRING, '', 'A bold first line (empty: none).'),
           prop('message', STRING, 'Message', 'The text.', required=True),
           prop('tone', enum('info', 'success', 'warning', 'error', 'neutral'), 'info', 'The colour and icon.'),
           prop('dismissible', BOOL, False, 'An x that fires onDismiss.')],
    slots=['actions'], events=['onDismiss'],
    previews=[preview('Warning', 360, 56, title='Payment failed', message='Update your card to keep your plan.', tone='warning')],
    nodes={
        'banner': {
            'type': 'row', 'children': ['glyph', 'texts', 'actions', 'dismiss'],
            'props': {'crossAxisAlignment': 'start', 'spacing': 8},
            'layout': {'width': {'fill': 360}, 'height': {'hug': 56}, 'padding': [12, 10, 10, 10]},
            'decoration': {'fills': [{'color': 'infoTint'}], 'strokes': [{'color': 'infoTintBorder'}], 'radius': 8},
            'bind': {'decoration.fills[0].color': TINT, 'decoration.strokes[0].color': TINT_BORDER},
        },
        'glyph': {**icon('info_outline', 'info', 16, layout={'width': 16, 'height': 16, 'margin': [0, 1, 0, 0]}),
                  'bind': {'props.icon': TONE_ICON, 'props.color': INK}},
        'texts': {'type': 'column', 'children': ['title', 'message'], 'props': {'crossAxisAlignment': 'start', 'spacing': 2},
                  'layout': {'width': {'fill': 250}, 'height': {'hug': 36}}},
        'title': {**text('${props.title}', {'from': 'body', 'fontWeight': 600}, {'fill': 250}, {'hug': 19}),
                  'bind': {'visible': "${= props.title != ''}"}},
        'message': text('${props.message}', {'from': 'body', 'color': 'secondaryText'}, {'fill': 250}, {'hug': 19}),
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
        'dismiss': {'type': 'IconButton', 'props': {'icon': 'close', 'size': 'xs'}, 'layout': {'width': 24, 'height': 24},
                    'bind': {'visible': '${props.dismissible}'},
                    'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'onDismiss'}]}]},
    },
))


# Avatar (avatar.dart): a circle with initials on the subtle fill (or an image), sizes 20 / 24 / 32 / 40.
add(component(
    'Avatar',
    'A person or workspace: initials in a circle, or a photo.',
    'avatar',
    props=[prop('name', STRING, 'Ada Lovelace', 'Whose: its initials are shown.', required=True),
           prop('image', STRING, '', 'A photo URL (empty: initials).'),
           prop('size', enum('xs', 'small', 'medium', 'large'), 'small', 'xs 20, small 24, medium 32, large 40.')],
    previews=[preview('Initials', 32, 32, name='Ada Lovelace', size='medium')],
    nodes={
        'avatar': {'type': 'row', 'children': ['circle'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                   'layout': {'width': {'hug': 24}, 'height': {'hug': 24}}},
        'circle': {
            'type': 'row', 'children': ['initials'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
            'layout': {'width': 24, 'height': 24},
            'decoration': {'fills': [{'color': 'tertiaryBackground'}, {'type': 'image', 'image': {'url': '', 'fit': 'cover'}, 'visible': False}],
                           'strokes': [{'color': 'primaryBorder'}], 'radius': 9999, 'clip': 'antiAlias'},
            'bind': {'layout.width': by('size', {'xs': 20, 'small': 24, 'medium': 32, 'large': 40}),
                     'layout.height': by('size', {'xs': 20, 'small': 24, 'medium': 32, 'large': 40}),
                     'decoration.fills[1].image.url': '${props.image}', 'decoration.fills[1].visible': "${= props.image != ''}"},
        },
        'initials': {**text("${= upper(substring(props.name, 0, 1)) + (contains(props.name, ' ') ? upper(substring(split(props.name, ' ')[1], 0, 1)) : '')}",
                            {'from': 'controlXs', 'color': 'secondaryText', 'fontWeight': 600}, {'hug': 16}, {'hug': 14}),
                     'bind': {'props.style.fontSize': by('size', {'xs': 9, 'small': 10, 'medium': 12, 'large': 14}),
                              'visible': "${= props.image == ''}"}},
    },
))

# ProgressBar (progress_bar.dart): a 4 px track in the track colour, the brand fill (or a tone's).
add(component(
    'ProgressBar',
    'How far something has got: a 4 px bar, value from 0 to 1, in the brand colour or a tone.',
    'track',
    props=[prop('value', NUMBER, 0.5, 'From 0 to 1.'),
           prop('tone', enum('primary', 'success', 'warning', 'error'), 'primary', 'The fill\'s colour.')],
    previews=[preview('Half', 240, 4, value=0.5)],
    nodes={
        'track': {'type': 'row', 'children': ['fill', 'rest'], 'layout': {'width': {'fill': 240}, 'height': 4},
                  'decoration': {'fills': [{'color': 'track'}], 'radius': 2, 'clip': 'antiAlias'}},
        'fill': {'type': 'box', 'layout': {'width': {'fill': 120}, 'height': {'fill': 4}, 'flex': 500},
                 'decoration': {'fills': [{'color': 'primary'}], 'radius': 2},
                 'bind': {'layout.flex': '${= round(max(0, min(1, props.value)) * 1000)}',
                          'decoration.fills[0].color': "${= props.tone == 'success' ? theme.success : (props.tone == 'warning' ? theme.warning : (props.tone == 'error' ? theme.error : theme.primary))}"}},
        'rest': {'type': 'box', 'layout': {'width': {'fill': 120}, 'height': {'fill': 4}, 'flex': 500},
                 'bind': {'layout.flex': '${= 1000 - round(max(0, min(1, props.value)) * 1000)}'}},
    },
))

# ListRow (selectable_list_row.dart / action_list_item.dart): a 36 px row (28 dense), 12 px padding, an icon, a
# title and an optional subtitle, a trailing slot; hover overlay; selected: the active tint.
add(component(
    'ListRow',
    'One row of a list or table-like list: icon, title, optional subtitle and trailing content (the trailing slot). Fires onPressed.',
    'row',
    props=[prop('title', STRING, 'Title', 'The main text.', required=True),
           prop('subtitle', STRING, '', 'A second line (empty: none).'),
           prop('icon', STRING, '', 'A Material icon name before the text (empty: none).'),
           prop('selected', BOOL, False, 'The active tint (the current item).'),
           prop('dense', BOOL, False, '28 px instead of 36 (inspectors, menus).'),
           prop('divider', BOOL, True, 'A hairline under the row.')],
    slots=['trailing'], events=['onPressed'],
    previews=[preview('Row', 320, 36, title='Invoice #1042', icon='description'),
              preview('Two lines', 320, 52, title='Ada Lovelace', subtitle='ada@example.com', icon='person_outline')],
    nodes={
        'row': {
            'type': 'row', 'children': ['strut', 'glyph', 'texts', 'trailing'],
            'props': {'crossAxisAlignment': 'center', 'spacing': 10},
            'layout': {'width': {'fill': 320}, 'height': {'hug': 36}, 'padding': [12, 6, 12, 6]},
            'decoration': {'fills': [{'color': '#00000000'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'},
            'bind': {'selected': '${props.selected}', 'decoration.strokes[0].color': "${= props.divider ? theme.colors.primaryBorder : '#00000000'}"},
            'states': {'hovered': {'row': HOVER}, 'pressed': {'row': PRESS},
                       'selected': {'row': {'decoration': {'fills': [{'color': 'activeTint'}]}}}},
            'actions': [click('onPressed', when='')],
        },
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 24}, 'bind': {'layout.height': '${= props.dense ? 16 : 24}'}},
        'glyph': {**icon('description', 'secondaryText', 16), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'texts': {'type': 'column', 'children': ['title', 'subtitle'], 'props': {'crossAxisAlignment': 'start', 'spacing': 1},
                  'layout': {'width': {'fill': 220}, 'height': {'hug': 19}}},
        'title': {**text('${props.title}', 'body', {'fill': 220}, {'hug': 19}), 'props': {'text': '${props.title}', 'style': 'body', 'maxLines': 1, 'overflow': 'ellipsis'}},
        'subtitle': {**text('${props.subtitle}', 'bodySecondary', {'fill': 220}, {'hug': 18}), 'bind': {'visible': "${= props.subtitle != ''}"},
                     'props': {'text': '${props.subtitle}', 'style': 'bodySecondary', 'maxLines': 1, 'overflow': 'ellipsis'}},
        'trailing': {'type': 'slot', 'props': {'name': 'trailing'}},
    },
))

# Field (form_field.dart / SoftSaaSFormField): the label above (11.5 / 600, secondary text, a required mark),
# 6 px, the control (the call's children), then a help or error line.
add(component(
    'Field',
    'A form field\'s frame: a label above the control (the call\'s child), and a help or error line under it.',
    'field',
    props=[prop('label', STRING, 'Label', 'The label.', required=True),
           prop('help', STRING, '', 'A hint under the control (empty: none).'),
           prop('error', STRING, '', 'An error under the control, instead of the help (empty: none); pass error: true to the control too.'),
           prop('required', BOOL, False, 'A required mark after the label.')],
    children='list',
    previews=[preview('With help', 280, 72, label='Email', help='We never share it.')],
    nodes={
        'field': {'type': 'column', 'children': ['labelRow', 'control', 'help', 'error'],
                  'props': {'crossAxisAlignment': 'stretch', 'spacing': 6},
                  'layout': {'width': {'fill': 280}, 'height': {'hug': 72}}},
        'labelRow': {'type': 'row', 'children': ['label', 'mark'], 'props': {'spacing': 2}, 'layout': {'width': {'fill': 280}, 'height': {'hug': 15}}},
        'label': text('${props.label}', 'fieldLabel', {'hug': 60}, {'hug': 15}),
        'mark': {**text('*', {'from': 'fieldLabel', 'color': 'error'}, {'hug': 6}, {'hug': 15}), 'bind': {'visible': '${props.required}'}},
        'control': {'type': 'slot'},
        'help': {**text('${props.help}', 'caption', {'fill': 280}, {'hug': 15}), 'bind': {'visible': "${= props.help != '' && props.error == ''}"}},
        'error': {**text('${props.error}', {'from': 'caption', 'color': 'error'}, {'fill': 280}, {'hug': 15}), 'bind': {'visible': "${= props.error != ''}"}},
    },
))

# SectionHeader (section_header.dart / panel header): 36 px, title 12/600, an optional count, a hairline below,
# trailing actions.
add(component(
    'SectionHeader',
    'A 36 px header over a list or panel: title, optional count badge and trailing actions (the actions slot).',
    'header',
    props=[prop('title', STRING, 'Section', 'The title.', required=True),
           prop('count', STRING, '', 'A count shown in a badge after the title (empty: none).')],
    slots=['actions'],
    previews=[preview('Files', 320, 36, title='Files', count='12')],
    nodes={
        'header': {'type': 'row', 'children': ['title', 'count', 'gap', 'actions'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'fill': 320}, 'height': 36, 'padding': [12, 0, 8, 0]},
                   'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'title': text('${props.title}', 'panelTitle', {'hug': 60}, {'hug': 17}),
        'count': {'type': 'Badge', 'props': {'label': '0', 'pill': True}, 'layout': {'width': {'hug': 24}, 'height': {'hug': 20}},
                  'bind': {'props.label': '${props.count}', 'visible': "${= props.count != ''}"}},
        'gap': {'type': 'spacer'},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
    },
))

# EmptyState (empty_state.dart): an icon in a tinted circle, a title 14/600, a line of secondary text, an action.
add(component(
    'EmptyState',
    'What a list or page shows when there is nothing yet (or nothing found): icon, title, message and an action (the actions slot).',
    'empty',
    props=[prop('icon', STRING, 'inbox', 'A Material icon name.'),
           prop('title', STRING, 'Nothing here yet', 'The title.', required=True),
           prop('message', STRING, '', 'One or two sentences: what to do next.')],
    slots=['actions'],
    previews=[preview('Empty', 320, 200, title='No invoices yet', message='Invoices appear here once you bill a customer.')],
    nodes={
        'empty': {'type': 'column', 'children': ['badge', 'title', 'message', 'actions'],
                  'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center', 'spacing': 6},
                  'layout': {'width': {'fill': 320}, 'height': {'hug': 200}, 'padding': [24, 32, 24, 32]}},
        'badge': {'type': 'row', 'children': ['glyph'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                  'layout': {'width': 40, 'height': 40, 'margin': [0, 0, 0, 6]},
                  'decoration': {'fills': [{'color': 'subtleFill'}], 'radius': 20}},
        'glyph': {**icon('inbox', 'secondaryText', 20), 'bind': {'props.icon': '${props.icon}'}},
        'title': {**text('${props.title}', 'sectionTitle', {'hug': 200}, {'hug': 20}), 'props': {'text': '${props.title}', 'style': 'sectionTitle', 'textAlign': 'center'}},
        'message': {**text('${props.message}', 'bodySecondary', {'fill': 272}, {'hug': 18}),
                    'props': {'text': '${props.message}', 'style': 'bodySecondary', 'textAlign': 'center'},
                    'bind': {'visible': "${= props.message != ''}"}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
    },
))

# Tooltip (tooltip.dart / SoftSaaSTooltip): the inverted bubble, radius 5, 11.5 px text, an optional shortcut.
add(component(
    'Tooltip',
    'The tooltip bubble: inverted surface, radius 5, 11.5 px text and an optional shortcut; for a hover hint on a node use its tooltip behavior.',
    'bubble',
    props=[prop('text', STRING, 'Tooltip', 'The text.', required=True), prop('shortcut', STRING, '', 'A key hint after the text (empty: none).')],
    previews=[preview('With shortcut', 120, 24, text='Search', shortcut='Ctrl K')],
    nodes={
        'bubble': {'type': 'row', 'children': ['label', 'shortcut'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'hug': 80}, 'height': {'hug': 24}, 'padding': [8, 4, 8, 4]},
                   'decoration': {'fills': [{'color': 'tooltipBackground'}], 'radius': 5}},
        'label': text('${props.text}', {'from': 'controlXs', 'color': 'tooltipText'}, {'hug': 40}, {'hug': 14}),
        'shortcut': {**text('${props.shortcut}', {'from': 'controlXs', 'color': 'tooltipMuted'}, {'hug': 20}, {'hug': 14}),
                     'bind': {'visible': "${= props.shortcut != ''}"}},
    },
))


# --- batch 2 (Researchy/soft_saas_ui/src/components): small status and stat pieces ---------------------------

STATUS = ['neutral', 'success', 'warning', 'error', 'info']
# StatusDot.tsx: green 500, red 500, blue 500 (warning and info share it), neutral 400; a 4 px glow at 30 %.
DOT = "${= props.status == 'success' ? '#FF22C55E' : (props.status == 'error' ? '#FFEF4444' : (props.status == 'neutral' ? '#FFA3A3A3' : '#FF3B82F6'))}"
DOT_GLOW = "${= props.status == 'success' ? '#4D22C55E' : (props.status == 'error' ? '#4DEF4444' : (props.status == 'neutral' ? '#4D6B7280' : '#4D3B82F6'))}"

# StatusDot (StatusDot.tsx): a round dot 8 / 12 / 16 with a soft glow of its colour, an optional 14/500 label 8 px after.
add(component(
    'StatusDot',
    'A live state at a glance: a glowing dot (success, warning, error, info, neutral) with an optional label.',
    'row',
    props=[prop('status', enum(*STATUS), 'success', 'success (green), error (red), warning and info (blue), neutral (grey).'),
           prop('label', STRING, '', 'Text after the dot (empty: none).'),
           prop('size', enum('sm', 'md', 'lg'), 'md', 'The dot: sm 8, md 12, lg 16.')],
    previews=[preview('Online', 90, 20, status='success', label='Online'), preview('Error', 90, 20, status='error', label='Offline')],
    nodes={
        'row': {'type': 'row', 'children': ['dot', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                'layout': {'width': {'hug': 80}, 'height': {'hug': 20}}},
        'dot': {'type': 'box', 'layout': {'width': 12, 'height': 12},
                'decoration': {'fills': [{'color': '#FF22C55E'}], 'radius': 9999,
                               'effects': [{'type': 'dropShadow', 'color': '#4D22C55E', 'offset': [0, 0], 'blurRadius': 4, 'spreadRadius': 2}]},
                'bind': {'layout.width': by('size', {'sm': 8, 'md': 12, 'lg': 16}), 'layout.height': by('size', {'sm': 8, 'md': 12, 'lg': 16}),
                         'decoration.fills[0].color': DOT, 'decoration.effects[0].color': DOT_GLOW}},
        'label': {**text('${props.label}', style(14, 500, 'primaryText', 1.4), {'hug': 60}, {'hug': 20}),
                  'bind': {'visible': "${= props.label != ''}"}},
    },
))

# CountBadge (CountBadge.tsx): 16 high, at least 18 wide, a full pill on the tertiary fill, 10/600 secondary text.
add(component(
    'CountBadge',
    'A count beside a title or tab: a 16 px grey pill, 10/600. Above max it reads "max+".',
    'badge',
    props=[prop('count', NUMBER, 3, 'The number.', required=True),
           prop('max', NUMBER, 999, 'Above this it shows "max+".'),
           prop('showZero', BOOL, False, 'False hides it at 0.')],
    previews=[preview('Three', 24, 16, count=3), preview('Over', 40, 16, count=1200)],
    nodes={
        'badge': {'type': 'row', 'children': ['label'],
                  'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 18}, 'height': 16, 'padding': [6, 0, 6, 0], 'constraints': {'minWidth': 18}},
                  'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 9999},
                  'bind': {'visible': '${= props.showZero || props.count != 0}'}},
        'label': text("${= min(props.count, props.max)}${= props.count > props.max ? '+' : ''}",
                      style(10, 600, 'secondaryText', 1, fontFeatures=['tnum']), {'hug': 8}, {'hug': 10}),
    },
))

# StatusBadge (StatusBadge.tsx): a full pill, 1 px tone border on its 10 % tint, 10.5/700 in the tone, 1 x 7 padding,
# 16 line height (18 high).
add(component(
    'StatusBadge',
    'A run or sync state as a small pill in its tone: neutral, success, warning, error or info.',
    'badge',
    props=[prop('label', STRING, 'synced', 'The state\'s text.', required=True),
           prop('tone', enum('neutral', 'success', 'warning', 'error', 'info'), 'neutral',
                'neutral (unknown, skipped), success (done, synced), warning (pending, stale), error (failed, blocked), info (active, generated).')],
    previews=[preview('Synced', 60, 18, label='synced', tone='success'), preview('Failed', 60, 18, label='failed', tone='error')],
    nodes={
        'badge': {'type': 'row', 'children': ['label'], 'props': {'crossAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 50}, 'height': {'hug': 18}, 'padding': [7, 1, 7, 1]},
                  'decoration': {'fills': [{'color': 'neutralTint'}], 'strokes': [{'color': 'neutralTintBorder'}], 'radius': 999},
                  'bind': {'decoration.fills[0].color': TINT, 'decoration.strokes[0].color': TINT_BORDER}},
        'label': {**text('${props.label}', style(10.5, 700, 'secondaryText', 16 / 10.5), {'hug': 36}, {'hug': 16}),
                  'bind': {'props.style.color': INK}},
    },
))

# InlineStat (InlineStat.tsx): an 11 px tertiary icon, 4 px, the value 10.5/600 with -0.1 tracking.
add(component(
    'InlineStat',
    'One small figure with its icon (files, lines, stars): a muted 11 px icon and a bold 10.5 px value.',
    'stat',
    props=[prop('icon', STRING, 'description', 'The icon\'s name.'),
           prop('value', STRING, '128', 'The figure, already formatted.', required=True)],
    previews=[preview('Files', 50, 14, icon='description', value='128')],
    nodes={
        'stat': {'type': 'row', 'children': ['glyph', 'value'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                 'layout': {'width': {'hug': 40}, 'height': {'hug': 14}}},
        'glyph': {**icon('description', 'tertiaryText', 11), 'bind': {'props.icon': '${props.icon}'}},
        'value': text('${props.value}', style(10.5, 600, 'primaryText', 1.3, letterSpacing=-0.1), {'hug': 24}, {'hug': 14}),
    },
))

# StatTile (StatsRow.tsx, density dashboard): a bordered tile on the secondary fill, radius 7, 12 x 14 padding; an
# 11 px secondary label with a 14 px icon 7 px before it, then the value 21/650 at 1.1.
add(component(
    'StatTile',
    'A dashboard figure: a small labelled icon line over a large value, in a bordered tile.',
    'tile',
    props=[prop('label', STRING, 'Revenue', 'What is counted.', required=True),
           prop('value', STRING, '$48,200', 'The figure, already formatted.', required=True),
           prop('icon', STRING, 'trending_up', 'The icon before the label.')],
    previews=[preview('Revenue', 170, 72, label='Revenue', value='$48,200')],
    nodes={
        'tile': {'type': 'column', 'children': ['head', 'value'], 'props': {'crossAxisAlignment': 'start', 'spacing': 6},
                 'layout': {'width': {'fill': 170}, 'height': {'hug': 72}, 'padding': [14, 12, 14, 12], 'constraints': {'minWidth': 0}},
                 'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 7}},
        'head': {'type': 'row', 'children': ['glyph', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 7},
                 'layout': {'width': {'fill': 140}, 'height': {'hug': 16}}},
        'glyph': {**icon('trending_up', 'secondaryText', 14), 'bind': {'props.icon': '${props.icon}'}},
        'label': text('${props.label}', style(11, 400, 'secondaryText', 1.4), {'hug': 60}, {'hug': 16}),
        'value': text('${props.value}', style(21, 600, 'primaryText', 1.1), {'fill': 140}, {'hug': 24}),
    },
))

# IconBox (IconBox.tsx): 30 x 30, radius 7, a 10 % tint of the primary under a 15 px primary icon.
add(component(
    'IconBox',
    'A tinted square holding an icon, for a dialog or card header: 30 px, radius 7, the brand colour at 10 %.',
    'box',
    props=[prop('icon', STRING, 'settings', 'The icon\'s name.', required=True)],
    previews=[preview('Settings', 30, 30, icon='settings')],
    nodes={
        'box': {'type': 'row', 'children': ['glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                'layout': {'width': 30, 'height': 30}, 'decoration': {'fills': [{'color': 'primaryTint'}], 'radius': 7}},
        'glyph': {**icon('settings', 'primary', 15), 'bind': {'props.icon': '${props.icon}'}},
    },
))

# ToggleRow (ToggleRow.tsx): a settings row with no box: the title 12.5/600 (-0.2), an optional description 11 at 1.4
# two pixels under it, and a switch 12 px after; 60 % when disabled.
add(component(
    'ToggleRow',
    'A setting with its switch: a bold title, an optional muted description, the switch at the end. Fires onChanged.',
    'row',
    props=[prop('label', STRING, 'Watch for changes', 'The setting\'s name.', required=True),
           prop('description', STRING, '', 'A line under it (empty: none).'),
           prop('value', var(BOOL), '', 'The name of your boolean variable.'),
           prop('enabled', BOOL, True, 'False: 60 % opacity, no toggling.')],
    events=[{'key': 'onChanged', 'payload': BOOL}],
    previews=[preview('With description', 320, 40, label='Watch for changes', description='Re-index when a file is saved.', value=True)],
    nodes={
        'row': {'type': 'row', 'children': ['texts', 'toggle'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                'layout': {'width': {'fill': 320}, 'height': {'hug': 40}},
                'bind': {'opacity': '${= props.enabled ? 1 : 0.6}'}},
        'texts': {'type': 'column', 'children': ['label', 'description'], 'props': {'crossAxisAlignment': 'start', 'spacing': 2},
                  'layout': {'width': {'fill': 240}, 'height': {'hug': 34}}},
        'label': text('${props.label}', style(12.5, 600, 'primaryText', 1.3, letterSpacing=-0.2), {'fill': 240}, {'hug': 16}),
        'description': {**text('${props.description}', style(11, 400, 'secondaryText', 1.4), {'fill': 240}, {'hug': 15}),
                        'bind': {'visible': "${= props.description != ''}"}},
        # The control the tree draws (SSUI's own switch, 28 x 16 at this size).
        'toggle': {'type': 'switch', 'layout': {'width': {'hug': 28}, 'height': {'hug': 16}},
                   'bind': {'props.value': '${= props.value == true}', 'props.enabled': '${props.enabled}'},
                   'actions': [{'trigger': {'type': 'changed'}, 'actions': [
                       {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'},
                       {'type': 'componentEvent', 'event': 'onChanged', 'value': '${result}'}]}]},
    },
))


# --- batch 3: loading, error, list and section pieces ---------------------------------------------------------

# Skeleton (Skeleton.tsx): a neutral block (#E5E5E5, #383838 in dark) standing in for content: text radius 4,
# rectangular 8, circular a full round; it pulses to half opacity over 2 s.
add(component(
    'Skeleton',
    'A grey placeholder for content still loading: a line of text, a block or a circle, gently pulsing.',
    'block',
    props=[prop('variant', enum('text', 'rectangular', 'circular'), 'text', 'text (radius 4), rectangular (radius 8) or circular.'),
           ],
    previews=[preview('Line', 200, 20), preview('Circle', 48, 48, variant='circular')],
    nodes={
        'block': {'type': 'box', 'layout': {'width': {'fill': 200}, 'height': 20},
                  'decoration': {'fills': [{'color': 'track'}], 'radius': 4},
                  'bind': {'decoration.radius': by('variant', {'text': 4, 'rectangular': 8, 'circular': 9999})},
                  'animations': [{'id': 'pulse', 'duration': 1000, 'curve': 'easeInOut', 'repeat': {'reverse': True},
                                  'tracks': [{'path': 'opacity', 'from': 1, 'to': 0.5}]}]},
    },
))

# ErrorBar (ErrorBar.tsx): a 4 px error rule, 6 px, then a 12 px alert icon and the message 11/500 (-0.1) in
# secondary text with a dotted underline; pressing it opens the details.
add(component(
    'ErrorBar',
    'A failure under a card or row: a red rule over a one-line message with an alert icon. Fires onPressed.',
    'bar',
    props=[prop('message', STRING, 'Sync failed: connection lost', 'What went wrong, one line.', required=True)],
    events=['onPressed'],
    previews=[preview('Failed', 260, 26, message='Sync failed: connection lost')],
    nodes={
        'bar': {'type': 'column', 'children': ['rule', 'line'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 6},
                'layout': {'width': {'fill': 260}, 'height': {'hug': 26}},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed'}]}]},
        'rule': {'type': 'box', 'layout': {'width': {'fill': 260}, 'height': 4}, 'decoration': {'fills': [{'color': 'error'}], 'radius': 2}},
        'line': {'type': 'row', 'children': ['glyph', 'message'], 'props': {'crossAxisAlignment': 'center', 'spacing': 7},
                 'layout': {'width': {'fill': 260}, 'height': {'hug': 16}}},
        'glyph': icon('error_outline', 'error', 12),
        'message': {**text('${props.message}', style(11, 500, 'secondaryText', 1.4, letterSpacing=-0.1, decoration='underline',
                                                      decorationStyle='dotted'), {'fill': 240}, {'hug': 16}),
                    'props': {'text': '${props.message}', 'maxLines': 1, 'overflow': 'ellipsis',
                              'style': style(11, 500, 'secondaryText', 1.4, letterSpacing=-0.1, decoration='underline', decorationStyle='dotted')}},
    },
))

# FeatureBulletItem (FeatureBulletItem.tsx): a 13 px secondary icon 2 px down, 10 px, then a sentence 12.5 at 1.4 (-0.1).
add(component(
    'FeatureBulletItem',
    'One line of a feature list: a muted icon and a sentence.',
    'row',
    props=[prop('icon', STRING, 'check', 'The icon\'s name.'),
           prop('text', STRING, 'Indexes your files as they change.', 'The sentence.', required=True)],
    previews=[preview('Feature', 280, 18, text='Indexes your files as they change.')],
    nodes={
        'row': {'type': 'row', 'children': ['glyphBox', 'text'], 'props': {'crossAxisAlignment': 'start', 'spacing': 10},
                'layout': {'width': {'fill': 280}, 'height': {'hug': 18}}},
        'glyphBox': {'type': 'column', 'children': ['glyph'], 'layout': {'width': 13, 'height': {'hug': 15}, 'padding': [0, 2, 0, 0]}},
        'glyph': {**icon('check', 'secondaryText', 13), 'bind': {'props.icon': '${props.icon}'}},
        'text': text('${props.text}', style(12.5, 400, 'secondaryText', 1.4, letterSpacing=-0.1), {'fill': 250}, {'hug': 18}),
    },
))

# SectionCard (SectionCard.tsx): a bordered card, radius 6, 10 px padding, the small shadow; an optional header
# row 10 px above the body: the title 11/700 uppercase with 0.06 em tracking in secondary text, actions at the end.
add(component(
    'SectionCard',
    'A small titled section: an uppercase 11 px label over its content (the call\'s children), actions at the end of the header.',
    'card',
    props=[prop('title', STRING, 'Details', 'The label (empty: no header).')],
    slots=['actions'],
    children='list',
    previews=[preview('Titled', 280, 80, title='Details')],
    nodes={
        'card': {'type': 'column', 'children': ['header', 'body'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 10},
                 'layout': {'width': {'fill': 280}, 'height': {'hug': 80}, 'padding': 10},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 6,
                                'effects': SHADOWS_LIGHT['level1']},
                 'bind': {'decoration.effects': '${theme.shadows.level1}'}},
        'header': {'type': 'row', 'children': ['title', 'actions'],
                   'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'spaceBetween', 'spacing': 8},
                   'layout': {'width': {'fill': 260}, 'height': {'hug': 15}},
                   'bind': {'visible': "${= props.title != ''}"}},
        'title': {'type': 'text', 'props': {'text': '${= upper(props.title)}', 'maxLines': 1, 'overflow': 'ellipsis',
                                             'style': style(11, 700, 'secondaryText', 1.3, letterSpacing=0.66)},
                  'layout': {'width': {'fill': 200}, 'height': {'hug': 15}}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
        'body': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 8},
                 'layout': {'width': {'fill': 260}, 'height': {'hug': 40}}},
        'content': {'type': 'slot'},
    },
))

# MetaInfo (MetaInfo.tsx): a tertiary 11 px line: a clock and an age, a middle dot 8 px either side, a branch icon
# (green when accented) and a monospace commit.
add(component(
    'MetaInfo',
    'When and which revision, in one muted line: a clock with an age, then a branch icon with a commit.',
    'row',
    props=[prop('age', STRING, '2h ago', 'How long ago (empty: none).'),
           prop('commit', STRING, 'a1b2c3d', 'The short commit (empty: none).'),
           prop('accent', BOOL, False, 'The branch icon in the success colour.')],
    previews=[preview('Both', 200, 14, age='2h ago', commit='a1b2c3d')],
    nodes={
        'row': {'type': 'row', 'children': ['clock', 'age', 'dot', 'branch', 'commit'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                'layout': {'width': {'hug': 160}, 'height': {'hug': 14}, 'constraints': {'minHeight': 13}}},
        'clock': {**icon('schedule', 'tertiaryText', 11), 'bind': {'visible': "${= props.age != ''}"}},
        'age': {**text('${props.age}', style(11, 400, 'tertiaryText', 1.2, letterSpacing=-0.1), {'hug': 40}, {'hug': 14}),
                'bind': {'visible': "${= props.age != ''}"}},
        'dot': {**text('·', style(11, 400, 'tertiaryText', 1.2), {'hug': 4}, {'hug': 14}),
                'layout': {'width': {'hug': 4}, 'height': {'hug': 14}, 'margin': [4, 0, 4, 0]},
                'bind': {'visible': "${= props.age != '' && props.commit != ''}"}},
        'branch': {**icon('account_tree', 'tertiaryText', 11),
                   'bind': {'visible': "${= props.commit != ''}", 'props.color': "${= props.accent ? theme.success : theme.colors.tertiaryText}"}},
        'commit': {**text('${props.commit}', style(11, 400, 'tertiaryText', 1.2, letterSpacing=-0.1, fontFamily='monospace'), {'hug': 50}, {'hug': 14}),
                   'bind': {'visible': "${= props.commit != ''}"}},
    },
))


# --- batch 4: links, counts on icons, work in progress --------------------------------------------------------

# Hyperlink (Hyperlink.tsx): 14/500 in the primary colour, underlined, 2 px above and below, an optional 14 px
# "open in new" icon 4 px after; hovered it is 600, pressed 20 % darker. Opens its url.
add(component(
    'Hyperlink',
    'A text link in the brand colour, underlined; it opens its URL. Fires onPressed.',
    'link',
    props=[prop('text', STRING, 'Open the docs', 'The words.', required=True),
           prop('url', STRING, '', 'Where it goes (empty: only onPressed fires).'),
           prop('showIcon', BOOL, False, 'An "open in new" icon after the text.'),
           prop('underline', BOOL, True, 'False underlines only while hovered.')],
    events=['onPressed'],
    previews=[preview('Link', 110, 24, text='Open the docs'), preview('With icon', 130, 24, text='Open the docs', showIcon=True)],
    nodes={
        'link': {'type': 'row', 'children': ['label', 'glyph'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                 'layout': {'width': {'hug': 100}, 'height': {'hug': 24}, 'padding': [0, 2, 0, 2]},
                 'states': {'hovered': {'label': {'props': {'style': {'fontWeight': 600, 'decoration': 'underline'}}}},
                            'pressed': {'label': {'props': {'style': {'color': '#FF1E4FBC'}}}}},
                 'actions': [{'trigger': 'click', 'actions': [
                     {'type': 'componentEvent', 'event': 'onPressed', 'value': '${props.url}'},
                     {'type': 'openLink', 'url': '${props.url}', 'when': {'left': "${= props.url != ''}", 'op': 'isTrue'}}]}]},
        'label': {**text('${props.text}', style(14, 500, 'primary', 1.4, letterSpacing=-0.14, decoration='underline', decorationColor='primary'),
                         {'hug': 90}, {'hug': 20}),
                  'bind': {'props.style.decoration': "${= props.underline ? 'underline' : 'none'}"}},
        'glyph': {**icon('open_in_new', 'primary', 14), 'bind': {'visible': '${props.showIcon}'}},
    },
))

# NotificationBadge (NotificationBadge.tsx): a count pill 18 high (at least 18 wide, 4 px sides, 12/700 white) or an
# 8 px dot, in the danger colour by default, on the top right corner of what it wraps (4 px out), with a small shadow.
add(component(
    'NotificationBadge',
    'A count or a dot on the corner of what it wraps (an icon button, an avatar): red by default, hidden at zero.',
    'wrap',
    props=[prop('count', NUMBER, 3, 'The number (0 hides it unless showZero).'),
           prop('max', NUMBER, 99, 'Above this it shows "max+".'),
           prop('dot', BOOL, False, 'A plain 8 px dot instead of the number.'),
           prop('showZero', BOOL, False, 'Shows at 0 too.'),
           prop('variant', enum('danger', 'primary', 'success'), 'danger', 'The colour.')],
    children='list',
    previews=[preview('Count', 40, 40, count=3)],
    nodes={
        # The wrapped thing sits 4 px in from the top and right, so the badge overhangs its corner by that much.
        'wrap': {'type': 'stack', 'children': ['content', 'badge'], 'layout': {'width': {'hug': 36}, 'height': {'hug': 36}, 'padding': [0, 4, 4, 0]}},
        'content': {'type': 'slot'},
        'badge': {'type': 'row', 'children': ['label'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 18}, 'height': 18, 'padding': [4, 0, 4, 0], 'constraints': {'minWidth': 18},
                             'x': {'end': -4}, 'y': {'start': -4}} if False else {'width': {'hug': 18}, 'height': 18, 'padding': [4, 0, 4, 0], 'constraints': {'minWidth': 18}, 'x': {'end': 0}, 'y': {'start': 0}},
                  'decoration': {'fills': [{'color': 'error'}], 'radius': 9999, 'effects': SHADOWS_LIGHT['level2']},
                  'bind': {'visible': '${= props.showZero || props.count > 0}',
                           'layout.height': '${= props.dot ? 8 : 18}', 'layout.constraints': '${= props.dot ? {minWidth: 8} : {minWidth: 18}}',
                           'layout.padding': '${= props.dot ? [0, 0, 0, 0] : [4, 0, 4, 0]}',
                           'decoration.fills[0].color': "${= props.variant == 'primary' ? theme.primary : (props.variant == 'success' ? theme.success : theme.error)}"}},
        'label': {**text("${= min(props.count, props.max)}${= props.count > props.max ? '+' : ''}", style(12, 700, 'onPrimary', 16 / 12), {'hug': 8}, {'hug': 16}),
                  'bind': {'visible': '${= !props.dot}'}},
    },
))

# PulsingDots (PulsingDots.tsx): three 4 px dots 2 px apart in the primary colour, each fading 0.2 to 1 and back over
# 0.9 s, a third of the cycle apart.
def _pulse(delay):
    return [{'id': 'pulse', 'duration': 450, 'delay': delay, 'curve': 'linear', 'repeat': {'reverse': True},
             'tracks': [{'path': 'opacity', 'from': 0.2, 'to': 1}]}]


add(component(
    'PulsingDots',
    'Work in progress with no percentage: three small dots pulsing one after another.',
    'dots',
    previews=[preview('Working', 20, 8)],
    nodes={
        'dots': {'type': 'row', 'children': ['d1', 'd2', 'd3'], 'props': {'crossAxisAlignment': 'center', 'spacing': 2},
                 'layout': {'width': {'hug': 16}, 'height': {'hug': 4}}},
        'd1': {'type': 'box', 'layout': {'width': 4, 'height': 4}, 'decoration': {'fills': [{'color': 'primary'}], 'radius': 2}, 'animations': _pulse(0)},
        'd2': {'type': 'box', 'layout': {'width': 4, 'height': 4}, 'decoration': {'fills': [{'color': 'primary'}], 'radius': 2}, 'animations': _pulse(300)},
        'd3': {'type': 'box', 'layout': {'width': 4, 'height': 4}, 'decoration': {'fills': [{'color': 'primary'}], 'radius': 2}, 'animations': _pulse(600)},
    },
))


def write():
    os.makedirs(f'{HERE}/components', exist_ok=True)
    for c in COMPONENTS:
        with open(f"{HERE}/components/{c['id']}.json", 'w') as f:
            json.dump(c, f, indent=1, ensure_ascii=False)
            f.write('\n')
    manifest = {
        'schema': 3, 'id': 'ssui', 'name': 'Soft SaaS UI', 'version': '1.0.0',
        'description': 'A flat desktop SaaS and editor language: quiet surfaces, hairline borders, shadows only on '
                       'floating surfaces, one control scale (24/28/32/36/44, 28 by default), light and dark.',
        'design': 'DESIGN.md', 'patterns': 'PATTERNS.md',
        'theme': THEME,
        'components': [f"components/{c['id']}.json" for c in COMPONENTS],
        'replaces': REPLACES,
        'examples': ['examples/gallery.json'],
    }
    with open(f'{HERE}/design_system.json', 'w') as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write('\n')
    print(f'{len(COMPONENTS)} components')


REPLACES = ['filledButton', 'elevatedButton', 'outlinedButton', 'textButton', 'iconButton', 'textField', 'checkbox',
            'switch', 'radio', 'slider', 'dropdown', 'segmentedButton']

if __name__ == '__main__':
    write()

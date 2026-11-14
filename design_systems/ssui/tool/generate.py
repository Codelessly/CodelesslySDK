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
# Read from the theme, so the same components take another design system's corners.
RADIUS_BY_SIZE = "${= props.size == 'xs' ? theme.radii.inner : theme.radii.control}"


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
             'primary fills with the brand color; secondary a strong neutral; outline a hairline; ghost nothing; destructive red.'),
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
                'decoration.radius': RADIUS_BY_SIZE,
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
                'decoration.radius': RADIUS_BY_SIZE,
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
# rest, the focus border (primary at 50 %, 1.5) when focused, the error color on error, 50 % when disabled.
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
# color, the brand fill, a 14 px white thumb with a hairline.
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
        # Fills what a card with a height has left (so a list in it can fill and scroll); in a card that hugs
        # there is nothing to fill and it is as tall as its content.
        'body': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 8},
                 'layout': {'width': {'fill': 320}, 'height': {'fill': 0}, 'padding': 12}},
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
           prop('tone', enum('info', 'success', 'warning', 'error', 'neutral'), 'info', 'The color and icon.'),
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

# ProgressBar (progress_bar.dart): a 4 px track in the track color, the brand fill (or a tone's).
add(component(
    'ProgressBar',
    'How far something has got: a 4 px bar, value from 0 to 1, in the brand color or a tone.',
    'track',
    props=[prop('value', NUMBER, 0.5, 'From 0 to 1.'),
           prop('tone', enum('primary', 'success', 'warning', 'error'), 'primary', 'The fill\'s color.')],
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

# StatusDot (StatusDot.tsx): a round dot 8 / 12 / 16 with a soft glow of its color, an optional 14/500 label 8 px after.
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
    'A dashboard figure: a small labeled icon line over a large value, in a bordered tile.',
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
    'A tinted square holding an icon, for a dialog or card header: 30 px, radius 7, the brand color at 10 %.',
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
           prop('accent', BOOL, False, 'The branch icon in the success color.')],
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

# Hyperlink (Hyperlink.tsx): 14/500 in the primary color, underlined, 2 px above and below, an optional 14 px
# "open in new" icon 4 px after; hovered it is 600, pressed 20 % darker. Opens its url.
add(component(
    'Hyperlink',
    'A text link in the brand color, underlined; it opens its URL. Fires onPressed.',
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
# 8 px dot, in the danger color by default, on the top right corner of what it wraps (4 px out), with a small shadow.
add(component(
    'NotificationBadge',
    'A count or a dot on the corner of what it wraps (an icon button, an avatar): red by default, hidden at zero.',
    'wrap',
    props=[prop('count', NUMBER, 3, 'The number (0 hides it unless showZero).'),
           prop('max', NUMBER, 99, 'Above this it shows "max+".'),
           prop('dot', BOOL, False, 'A plain 8 px dot instead of the number.'),
           prop('showZero', BOOL, False, 'Shows at 0 too.'),
           prop('variant', enum('danger', 'primary', 'success'), 'danger', 'The color.')],
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

# PulsingDots (PulsingDots.tsx): three 4 px dots 2 px apart in the primary color, each fading 0.2 to 1 and back over
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


# --- batch 5: small buttons ----------------------------------------------------------------------------------

# AddButton (AddButton.tsx): a quiet list-footer action: a 13 px icon and a 12/500 label (-0.1), 5 px apart, all in
# tertiary text, centered in its row.
add(component(
    'AddButton',
    'A quiet "add another" under a list: a small muted icon and label, centered. Fires onPressed.',
    'row',
    props=[prop('label', STRING, 'Add folder', 'The words.', required=True),
           prop('icon', STRING, 'add', 'The icon before them.')],
    events=['onPressed'],
    previews=[preview('Add', 280, 20, label='Add folder')],
    nodes={
        'row': {'type': 'row', 'children': ['glyph', 'label'],
                'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center', 'spacing': 5},
                'layout': {'width': {'fill': 280}, 'height': {'hug': 20}},
                'states': {'hovered': {'label': {'props': {'style': {'color': 'secondaryText'}}}, 'glyph': {'props': {'color': 'secondaryText'}}}},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed'}]}]},
        'glyph': {**icon('add', 'tertiaryText', 13), 'bind': {'props.icon': '${props.icon}'}},
        'label': text('${props.label}', style(12, 500, 'tertiaryText', 1.3, letterSpacing=-0.1), {'hug': 60}, {'hug': 16}),
    },
))

# ProviderPill (ProviderPill.tsx): a small bordered action pill: 2 x 7 padding, radius 6, the primary background with
# a 1 px border, 11/500 secondary text on a 16 px line, an optional icon 4 px before.
add(component(
    'ProviderPill',
    'A small bordered pill for a row\'s action or state ("Add key", "Connected"). Fires onPressed.',
    'pill',
    props=[prop('label', STRING, 'Add key', 'The words.', required=True),
           prop('icon', STRING, '', 'An icon before them (empty: none).')],
    events=['onPressed'],
    previews=[preview('Add key', 60, 22, label='Add key'), preview('Connected', 90, 22, label='Connected', icon='check')],
    nodes={
        'pill': {'type': 'row', 'children': ['glyph', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                 'layout': {'width': {'hug': 56}, 'height': {'hug': 22}, 'padding': [7, 2, 7, 2]},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 6},
                 'states': {'hovered': {'pill': HOVER}, 'pressed': {'pill': PRESS}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed'}]}]},
        'glyph': {**icon('check', 'secondaryText', 11), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'label': text('${props.label}', style(11, 500, 'secondaryText', 16 / 11), {'hug': 40}, {'hug': 16}),
    },
))

# CopyButton (CopyButton.tsx): a ghost icon button showing "copy" that copies its text, then shows a check for 2 s;
# with showLabel it is a labeled button reading "Copy", then "Copied!".
add(component(
    'CopyButton',
    'Copies its text to the clipboard and shows a check for two seconds. Fires onCopy.',
    'button',
    props=[prop('text', STRING, '', 'What is copied.', required=True),
           prop('showLabel', BOOL, False, 'A label ("Copy", then "Copied!") after the icon.')],
    events=['onCopy'],
    variables=[{'name': 'copied', 'type': 'boolean', 'value': False}],
    previews=[preview('Icon', 28, 28, text='npm install'), preview('Labeled', 80, 28, text='npm install', showLabel=True)],
    nodes={
        'button': {'type': 'row', 'children': ['glyph', 'label'],
                   'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'hug': 28}, 'height': 28, 'padding': [7, 0, 7, 0], 'constraints': {'minWidth': 28}},
                   'decoration': {'fills': [{'color': '#00000000'}], 'radius': 7},
                   'bind': {'decoration.fills[0].color': "${= copied && props.showLabel ? theme.primary : '#00000000'}"},
                   'states': {'hovered': {'button': HOVER}, 'pressed': {'button': PRESS}},
                   'tooltip': 'Copy to clipboard',
                   'actions': [{'trigger': 'click', 'actions': [
                       {'type': 'copyToClipboard', 'text': '${props.text}'},
                       {'type': 'setVariable', 'variable': 'copied', 'value': '${= true}'},
                       {'type': 'componentEvent', 'event': 'onCopy', 'value': '${props.text}'},
                       {'type': 'delay', 'ms': 2000},
                       {'type': 'setVariable', 'variable': 'copied', 'value': '${= false}'}]}]},
        'glyph': {**icon('content_copy', 'secondaryText', 14),
                  'bind': {'props.icon': "${= copied ? 'check' : 'content_copy'}",
                           'props.color': "${= copied && props.showLabel ? theme.onPrimary : theme.colors.secondaryText}"}},
        'label': {**text('Copy', {'from': 'controlCompact'}, {'hug': 30}, {'hug': 15}),
                  'bind': {'visible': '${props.showLabel}', 'props.text': "${= copied ? 'Copied!' : 'Copy'}",
                           'props.style.color': "${= copied ? theme.onPrimary : theme.colors.primaryText}"}},
    },
))

# BackButton (BackButton.tsx): an arrow and "Back" 8 px apart, 14/500, 4 x 8 padding, radius 2; the subtle fill when
# hovered and the border color when pressed; muted and inert when disabled.
add(component(
    'BackButton',
    'Goes back: a left arrow and a label. Fires onPressed.',
    'button',
    props=[prop('label', STRING, 'Back', 'The words.'),
           prop('enabled', BOOL, True, 'False: muted, takes no press.')],
    events=['onPressed'],
    previews=[preview('Back', 70, 30)],
    nodes={
        'button': {'type': 'row', 'children': ['glyph', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'hug': 70}, 'height': {'hug': 30}, 'padding': [8, 4, 8, 4]},
                   'decoration': {'fills': [{'color': '#00000000'}], 'radius': 2},
                   'bind': {'disabled': '${= !props.enabled}'},
                   'states': {'hovered': {'button': {'decoration': {'fills': [{'color': 'subtleFill'}]}}, 'glyph': {'props': {'color': 'primaryText'}}},
                              'pressed': {'button': {'decoration': {'fills': [{'color': 'primaryBorder'}]}}},
                              'disabled': {'label': {'props': {'style': {'color': 'tertiaryText'}}}, 'glyph': {'props': {'color': 'tertiaryText'}}}},
                   'actions': [click('onPressed')]},
        'glyph': icon('arrow_back', 'secondaryText', 16),
        'label': text('${props.label}', style(14, 500, 'primaryText', 1.4, letterSpacing=-0.14), {'hug': 34}, {'hug': 20}),
    },
))

# --- batch 6: chips, rows and small status ---------------------------------------------------------------------

# TextInputLabel (TextInputLabel.tsx): a field's label 11.5/600 (-0.1) in secondary text, a description 10.5 in
# tertiary 4 px under it, then the field (the call's children) 6 px below.
add(component(
    'TextInputLabel',
    'A label over a field: the label, an optional description under it, then the call\'s children.',
    'group',
    props=[prop('label', STRING, 'Name', 'The label.', required=True),
           prop('description', STRING, '', 'A muted line under the label (empty: none).')],
    children='list',
    previews=[preview('Label', 240, 40, label='Workspace name', description='Shown in the sidebar.')],
    nodes={
        'group': {'type': 'column', 'children': ['label', 'description', 'gap', 'content'], 'props': {'crossAxisAlignment': 'stretch'},
                  'layout': {'width': {'fill': 240}, 'height': {'hug': 40}}},
        'label': text('${props.label}', style(11.5, 600, 'secondaryText', 1.35, letterSpacing=-0.1), {'fill': 240}, {'hug': 16}),
        'description': {**text('${props.description}', style(10.5, 400, 'tertiaryText', 1.4, letterSpacing=-0.1), {'fill': 240}, {'hug': 15}),
                        'layout': {'width': {'fill': 240}, 'height': {'hug': 15}, 'margin': [0, 4, 0, 0]},
                        'bind': {'visible': "${= props.description != ''}"}},
        'gap': {'type': 'box', 'layout': {'width': 0, 'height': 6}},
        'content': {'type': 'slot'},
    },
))

# PersonChip (PersonChip.tsx): a person, bot or team as a 24 px pill: an 18 px avatar that fills its circle (photo,
# else initials 8/650; a bot glyph; a team's accent tile with radius 5), 5 px, the name 11.5 on an 18 px line;
# padding 2 with 8 after the name (3 with a remove button), a 1 px border, fully round.
add(component(
    'PersonChip',
    'A person, a bot or a team as a small pill: avatar and name. Fires onPressed and onRemove.',
    'chip',
    props=[prop('name', STRING, 'Ada Lovelace', 'Whose.', required=True),
           prop('image', STRING, '', 'A photo URL (empty: initials, or the kind\'s glyph).'),
           prop('kind', enum('human', 'bot', 'team'), 'human', 'human: photo or initials. bot: a bot glyph. team: an accent tile.'),
           prop('trailing', STRING, '', 'Muted words after the name ("· git").'),
           prop('removable', BOOL, False, 'An x at the end that fires onRemove.')],
    events=['onPressed', 'onRemove'],
    previews=[preview('Person', 110, 24, name='Ada Lovelace'), preview('Team', 110, 24, name='Platform', kind='team'),
              preview('Removable', 120, 24, name='Grace Hopper', removable=True)],
    nodes={
        'chip': {'type': 'row', 'children': ['avatar', 'name', 'trailing', 'remove'], 'props': {'crossAxisAlignment': 'center', 'spacing': 5},
                 'layout': {'width': {'hug': 100}, 'height': {'hug': 24}, 'padding': [2, 2, 8, 2]},
                 'decoration': {'strokes': [{'color': 'primaryBorder'}], 'radius': 9999},
                 'bind': {'layout.padding': "${= props.removable ? [2, 2, 3, 2] : [2, 2, 8, 2]}"},
                 'states': {'hovered': {'chip': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed', 'value': '${props.name}'}]}]},
        'avatar': {'type': 'row', 'children': ['initials', 'glyph'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                   'layout': {'width': 18, 'height': 18},
                   'decoration': {'fills': [{'color': 'subtleFill'}, {'type': 'image', 'image': {'url': '', 'fit': 'cover'}, 'visible': False}],
                                  'radius': 9999, 'clip': 'antiAlias'},
                   'bind': {'decoration.radius': "${= props.kind == 'team' ? 5 : 9999}",
                            'decoration.fills[0].color': "${= props.kind == 'team' ? theme.colors.primaryTint : theme.colors.subtleFill}",
                            'decoration.fills[1].image.url': '${props.image}',
                            'decoration.fills[1].visible': "${= props.image != '' && props.kind != 'team'}"}},
        'initials': {**text("${= upper(substring(props.name, 0, 1)) + (contains(props.name, ' ') ? upper(substring(split(props.name, ' ')[1], 0, 1)) : '')}",
                            style(8, 600, 'secondaryText', 1), {'hug': 12}, {'hug': 8}),
                     'bind': {'visible': "${= props.kind == 'human' && props.image == ''}"}},
        'glyph': {**icon('smart_toy', 'secondaryText', 13),
                  'bind': {'visible': "${= props.kind == 'team' || (props.kind == 'bot' && props.image == '')}",
                           'props.icon': "${= props.kind == 'team' ? 'groups' : 'smart_toy'}",
                           'props.size': "${= props.kind == 'team' ? 11 : 13}",
                           'props.color': "${= props.kind == 'team' ? theme.primary : theme.colors.secondaryText}"}},
        'name': {'type': 'text', 'props': {'text': '${props.name}', 'maxLines': 1, 'overflow': 'ellipsis',
                                            'style': style(11.5, 400, 'primaryText', 18 / 11.5)},
                 'layout': {'width': {'hug': 60}, 'height': {'hug': 18}}},
        'trailing': {**text('${props.trailing}', style(11.5, 400, 'tertiaryText', 18 / 11.5), {'hug': 30}, {'hug': 18}),
                     'bind': {'visible': "${= props.trailing != ''}"}},
        'remove': {'type': 'row', 'children': ['x'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                   'layout': {'width': 16, 'height': 16}, 'decoration': {'radius': 9999},
                   'bind': {'visible': '${props.removable}'},
                   'states': {'hovered': {'remove': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onRemove', 'value': '${props.name}'}]}]},
        'x': icon('close', 'tertiaryText', 11),
    },
))

# ResourceChip (ResourceChip.tsx): a document, file or link as a bordered chip: a 13 px icon by kind, 6 px, the
# label 11/500 (+0.11) on a 1.25 line; padding 5 x 8 (3 x 8 and at most 190 wide inline), radius 5, the low shadow.
KIND_ICON = "${= props.kind == 'file' ? 'insert_drive_file' : (props.kind == 'image' ? 'image' : (props.kind == 'video' ? 'videocam' : (props.kind == 'audio' ? 'music_note' : (props.kind == 'link' ? 'link' : 'description'))))}"
add(component(
    'ResourceChip',
    'A document, file, image, video, audio or link as a small bordered chip. Fires onPressed.',
    'chip',
    props=[prop('label', STRING, 'Launch plan', 'Its name.', required=True),
           prop('kind', enum('document', 'file', 'image', 'video', 'audio', 'link'), 'document', 'Which icon.'),
           prop('inline', BOOL, False, 'Shorter (3 px above and below) and at most 190 wide, to sit in a line of text.'),
           prop('enabled', BOOL, True, 'Off: dimmed, no press.')],
    events=['onPressed'],
    previews=[preview('Document', 110, 26, label='Launch plan'), preview('Link', 110, 26, label='docs.example.com', kind='link')],
    nodes={
        'chip': {'type': 'row', 'children': ['glyph', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                 'layout': {'width': {'hug': 100}, 'height': {'hug': 26}, 'padding': [8, 5, 8, 5]},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 5,
                                'effects': SHADOWS_LIGHT['level1']},
                 'bind': {'decoration.effects': '${theme.shadows.level1}',
                          'layout.padding': '${= props.inline ? [8, 3, 8, 3] : [8, 5, 8, 5]}',
                          'opacity': '${= props.enabled ? 1 : 0.58}'},
                 'states': {'hovered': {'chip': HOVER}, 'pressed': {'chip': PRESS}},
                 'actions': [click('onPressed', value='${props.label}')]},
        'glyph': {**icon('description', 'primaryText', 13), 'bind': {'props.icon': KIND_ICON}},
        'label': {'type': 'text', 'props': {'text': '${props.label}', 'maxLines': 1, 'overflow': 'ellipsis',
                                             'style': style(11, 500, 'primaryText', 1.25, letterSpacing=0.11)},
                  'layout': {'width': {'hug': 60}, 'height': {'hug': 14}, 'constraints': {'maxWidth': 400}},
                  'bind': {'layout.constraints': "${= props.inline ? {'maxWidth': 155} : {'maxWidth': 400}}"}},
    },
))

# FileListItem (FileListItem.tsx): a file as a full-width row: a 14 px tertiary icon, 7 px, the name 12 on a 1.25
# line (the path's last part unless named), then meta and actions; padding 5 x 6, radius 4, the subtle fill on hover.
add(component(
    'FileListItem',
    'A file in a list: icon, name, then meta and actions at the end. Fires onPressed with the path.',
    'row',
    props=[prop('path', STRING, 'docs/launch-plan.md', 'The file\'s path.', required=True),
           prop('name', STRING, '', 'What to show (empty: the path\'s last part).'),
           prop('icon', STRING, 'description', 'The icon.')],
    events=['onPressed'],
    slots=['meta', 'actions'],
    previews=[preview('File', 260, 26, path='docs/launch-plan.md')],
    nodes={
        'row': {'type': 'row', 'children': ['glyph', 'name', 'meta', 'actions'], 'props': {'crossAxisAlignment': 'center', 'spacing': 7},
                'layout': {'width': {'fill': 260}, 'height': {'hug': 25}, 'padding': [6, 5, 6, 5]},
                'decoration': {'radius': 4},
                'states': {'hovered': {'row': {'decoration': {'fills': [{'color': 'secondaryBackground'}]}}}},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed', 'value': '${props.path}'}]}]},
        'glyph': {**icon('description', 'tertiaryText', 14), 'bind': {'props.icon': '${props.icon}'}},
        'name': {'type': 'text', 'props': {'text': "${= props.name != '' ? props.name : last(split(props.path, '/'))}", 'maxLines': 1,
                                            'overflow': 'ellipsis', 'style': style(12, 400, 'primaryText', 1.25)},
                 'layout': {'width': {'fill': 180}, 'height': {'hug': 15}}},
        'meta': {'type': 'slot', 'props': {'name': 'meta'}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
    },
))

# StatusIndicator (StatusIndicator.tsx): a 15 px glyph for where a job is: a spinner while running or setting up
# (primary), a check circle when synced or complete (success), an alert when errored (error), a badge when setup
# is needed (primary), a play triangle when paused (tertiary).
RUN_STATES = ['setupNeeded', 'settingUp', 'synced', 'completion', 'running', 'paused', 'errored']
IN_FLIGHT = "(props.status == 'running' || props.status == 'settingUp')"
add(component(
    'StatusIndicator',
    'Where a job is, as one 15 px glyph: spinning while it runs, a check when done, an alert on error. Fires onPressed.',
    'box',
    props=[prop('status', enum(*RUN_STATES), 'synced', 'setupNeeded, settingUp, synced, completion, running, paused or errored.')],
    events=['onPressed'],
    previews=[preview('Synced', 15, 15, status='synced'), preview('Running', 15, 15, status='running'),
              preview('Errored', 15, 15, status='errored')],
    nodes={
        'box': {'type': 'row', 'children': ['spinner', 'glyph'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                'layout': {'width': 15, 'height': 15},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed', 'value': '${props.status}'}]}]},
        'spinner': {'type': 'circularProgressIndicator', 'props': {'color': 'primary', 'strokeWidth': 1.5, 'strokeCap': 'round'},
                    'layout': {'width': 12, 'height': 12},
                    'bind': {'visible': '${= %s}' % IN_FLIGHT}},
        'glyph': {**icon('check_circle_outline', 'success', 15),
                  'bind': {'visible': '${= !%s}' % IN_FLIGHT,
                           'props.icon': "${= props.status == 'errored' ? 'error_outline' : (props.status == 'setupNeeded' ? 'new_releases' : (props.status == 'paused' ? 'play_arrow' : 'check_circle_outline'))}",
                           'props.color': "${= props.status == 'errored' ? theme.error : (props.status == 'setupNeeded' ? theme.primary : (props.status == 'paused' ? theme.colors.tertiaryText : theme.success))}"}},
    },
))

# DiffStatsBadge (DiffStatsBadge.tsx): an 11 px file icon, 5 px, then a chip per kind of change that happened:
# +created (success), ~modified (warning), -deleted (error), or one muted 0; each monospace 10/600 on a 1.4 line,
# padding 1 x 5, radius 4, 4 px apart.
def _diff_chip(id_, sign, key, ink, tint):
    return {
        id_: {'type': 'row', 'children': [id_ + 'Text'], 'layout': {'width': {'hug': 20}, 'height': {'hug': 16}, 'padding': [5, 1, 5, 1]},
              'decoration': {'fills': [{'color': tint}], 'radius': 4},
              'bind': {'visible': '${= props.%s > 0}' % key}},
        id_ + 'Text': text(sign + '${props.%s}' % key, style(10, 600, ink, 1.4, fontFamily='monospace'), {'hug': 14}, {'hug': 14}),
    }


add(component(
    'DiffStatsBadge',
    'What a change did to files: +created, ~modified and -deleted counts as small colored chips after a file icon.',
    'badge',
    props=[prop('created', NUMBER, 0, 'Files created.'), prop('modified', NUMBER, 0, 'Files modified.'),
           prop('deleted', NUMBER, 0, 'Files deleted.')],
    previews=[preview('Mixed', 110, 16, created=3, modified=12, deleted=1), preview('None', 40, 16)],
    nodes={
        'badge': {'type': 'row', 'children': ['glyph', 'chips'], 'props': {'crossAxisAlignment': 'center', 'spacing': 5},
                  'layout': {'width': {'hug': 100}, 'height': {'hug': 16}}},
        'glyph': icon('insert_drive_file', 'tertiaryText', 11),
        'chips': {'type': 'row', 'children': ['created', 'modified', 'deleted', 'zero'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                  'layout': {'width': {'hug': 80}, 'height': {'hug': 16}}},
        **_diff_chip('created', '+', 'created', 'success', 'successTint'),
        **_diff_chip('modified', '~', 'modified', 'warning', 'warningTint'),
        **_diff_chip('deleted', '-', 'deleted', 'error', 'errorTint'),
        'zero': {'type': 'row', 'children': ['zeroText'], 'layout': {'width': {'hug': 16}, 'height': {'hug': 16}, 'padding': [5, 1, 5, 1]},
                 'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 4},
                 'bind': {'visible': '${= props.created <= 0 && props.modified <= 0 && props.deleted <= 0}'}},
        'zeroText': text('0', style(10, 600, 'tertiaryText', 1.4, fontFamily='monospace'), {'hug': 8}, {'hug': 14}),
    },
))

# --- batch 7: panel, progress and connection -------------------------------------------------------------------

# Panel (Panel.tsx): a bordered container, radius 10: a header (padding 10 x 14, a 16 px icon, 8 px, the title
# 12/600 with a subtitle 10.5 in tertiary 2 px under it, then what trails) over a hairline, then the content.
# Expandable: the header toggles the content and ends in a 15 px chevron that turns; elevated: the level 2 shadow.
add(component(
    'Panel',
    'A bordered section with a header: a title, an optional icon and subtitle, the call\'s children below. '
    'Expandable opens and closes on its header. Fires onToggle.',
    'panel',
    props=[prop('title', STRING, 'Section', 'The header\'s title (empty and not expandable: no header).'),
           prop('subtitle', STRING, '', 'A muted line under the title.'),
           prop('icon', STRING, '', 'An icon before the title (empty: none).'),
           prop('variant', enum('default', 'expandable', 'elevated'), 'default',
                'default: a header over the content. expandable: the header opens and closes it. elevated: with a shadow.'),
           prop('open', BOOL, False, 'Expandable: whether the content shows at first.')],
    events=[{'key': 'onToggle', 'payload': BOOL}],
    slots=['trailing'],
    children='list',
    variables=[{'name': 'toggled', 'type': 'boolean', 'value': False}],
    previews=[preview('Default', 280, 90, title='Billing', subtitle='Plan and invoices'),
              preview('Expandable', 280, 40, title='Advanced', variant='expandable')],
    nodes={
        'panel': {'type': 'column', 'children': ['header', 'body'], 'props': {'crossAxisAlignment': 'stretch'},
                  # 1 px of padding: the border takes room, as in the source, so a filled child never covers it.
                  'layout': {'width': {'fill': 280}, 'height': {'hug': 90}, 'padding': 1},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 10,
                                 'clip': 'antiAlias', 'effects': []},
                  'bind': {'decoration.effects': "${= props.variant == 'elevated' ? theme.shadows.level2 : []}"}},
        'header': {'type': 'row', 'children': ['glyph', 'titles', 'trailing', 'chevron'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 280}, 'height': {'hug': 34}, 'padding': [14, 10, 14, 10]},
                   'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'},
                   'bind': {'visible': "${= props.title != '' || props.variant == 'expandable'}",
                            'decoration.strokes[0].visible': "${= props.variant != 'expandable' || (props.open != toggled)}"},
                   'actions': [{'trigger': {'type': 'click', 'when': "props.variant == 'expandable'"}, 'actions': [
                       {'type': 'setVariable', 'variable': 'toggled', 'value': '${= !toggled}'},
                       {'type': 'componentEvent', 'event': 'onToggle', 'value': '${= (props.open != toggled)}'}]}]},
        'glyph': {**icon('settings', 'secondaryText', 16), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'titles': {'type': 'column', 'children': ['title', 'subtitle'], 'props': {'crossAxisAlignment': 'start', 'spacing': 2},
                   'layout': {'width': {'fill': 200}, 'height': {'hug': 14}}},
        'title': text('${props.title}', style(12, 600, 'primaryText', 1.15), {'hug': 60}, {'hug': 14}),
        'subtitle': {**text('${props.subtitle}', style(10.5, 400, 'tertiaryText', 1.3), {'hug': 80}, {'hug': 14}),
                     'bind': {'visible': "${= props.subtitle != ''}"}},
        'trailing': {'type': 'slot', 'props': {'name': 'trailing'}},
        'chevron': {**icon('chevron_right', 'tertiaryText', 15),
                    'bind': {'visible': "${= props.variant == 'expandable'}", 'props.icon': "${= (props.open != toggled) ? 'expand_more' : 'chevron_right'}"}},
        'body': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 280}, 'height': {'fill': 0}},
                 'bind': {'visible': "${= props.variant != 'expandable' || (props.open != toggled)}"}},
        'content': {'type': 'slot'},
    },
))

# LoadMoreFooter (LoadMore.tsx): a 32 px centered footer under a list, 11 px muted: a small spinner and "Loading
# more…" while loading; "Couldn't load more" and Retry on an error; a "Load more" link when there is more; else the
# end's label.
add(component(
    'LoadMore',
    'The foot of a long list: a "Load more" link, a spinner while it loads, Retry after an error, or the end\'s label. Fires onLoadMore.',
    'footer',
    props=[prop('hasMore', BOOL, True, 'Whether more can be loaded.'),
           prop('loading', BOOL, False, 'A load is under way.'),
           prop('error', STRING, '', 'Why the last load failed (empty: it did not).'),
           prop('loadLabel', STRING, 'Load more', 'The link\'s words.'),
           prop('endLabel', STRING, '', 'What to say when there is no more (empty: nothing).')],
    events=['onLoadMore'],
    previews=[preview('More', 240, 32), preview('Loading', 240, 32, loading=True), preview('Error', 240, 32, error='timeout')],
    nodes={
        'footer': {'type': 'row', 'children': ['spinner', 'words', 'link'],
                   'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'fill': 240}, 'height': 32}},
        'spinner': {'type': 'circularProgressIndicator', 'props': {'color': 'primary', 'strokeWidth': 1.5, 'strokeCap': 'round'},
                    'layout': {'width': 11, 'height': 11}, 'bind': {'visible': '${props.loading}'}},
        'words': {**text("${= props.loading ? 'Loading more…' : (props.error != '' ? 'Couldn’t load more' : props.endLabel)}",
                         style(11, 400, 'tertiaryText', 1.3), {'hug': 80}, {'hug': 14}),
                  'bind': {'visible': "${= props.loading || props.error != '' || (!props.hasMore && props.endLabel != '')}"}},
        'link': {'type': 'row', 'children': ['linkText'], 'layout': {'width': {'hug': 60}, 'height': {'hug': 18}, 'padding': [6, 2, 6, 2]},
                 'decoration': {'radius': 4},
                 'bind': {'visible': "${= !props.loading && (props.error != '' || props.hasMore)}"},
                 'states': {'hovered': {'link': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onLoadMore'}]}]},
        'linkText': text("${= props.error != '' ? 'Retry' : props.loadLabel}", style(11, 400, 'primary', 1.3), {'hug': 50}, {'hug': 14}),
    },
))

# ConnectionStatus (ConnectionStatus.tsx): a live connection in one line: an 11 px plug in the state's color
# (success connected, warning reconnecting, error disconnected, tertiary connecting), 4 px, the label 10/600 in
# secondary text.
LINK_STATES = ['connecting', 'connected', 'reconnecting', 'disconnected']
add(component(
    'ConnectionStatus',
    'Whether a live connection is up: a small plug in the state\'s color and its name.',
    'row',
    props=[prop('status', enum(*LINK_STATES), 'connected', 'connecting, connected, reconnecting or disconnected.'),
           prop('label', STRING, '', 'Other words than the state\'s own (empty: "Connected", "Reconnecting…"...).')],
    previews=[preview('Connected', 80, 14, status='connected'), preview('Reconnecting', 90, 14, status='reconnecting')],
    nodes={
        'row': {'type': 'row', 'children': ['glyph', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                'layout': {'width': {'hug': 80}, 'height': {'hug': 14}}},
        'glyph': {**icon('power', 'success', 11),
                  'bind': {'props.icon': "${= props.status == 'connected' ? 'power' : 'power_off'}",
                           'props.color': "${= props.status == 'connected' ? theme.success : (props.status == 'reconnecting' ? theme.warning : (props.status == 'disconnected' ? theme.error : theme.colors.tertiaryText))}"}},
        'label': text("${= props.label != '' ? props.label : (props.status == 'connected' ? 'Connected' : (props.status == 'reconnecting' ? 'Reconnecting…' : (props.status == 'disconnected' ? 'Disconnected' : 'Connecting…')))}",
                      style(10, 600, 'secondaryText', 1.3), {'hug': 60}, {'hug': 13}),
    },
))

# RadialProgress (RadialProgress.tsx): an 18 px ring 3 thick with the percent inside, 6.5/800: error under 20,
# warning under 60, success from there; muted is tertiary at 55 %.
add(component(
    'RadialProgress',
    'A percent as a tiny ring with the number inside: red under 20, amber under 60, green above.',
    'ring',
    props=[prop('value', NUMBER, 60, 'From 0 to 100.', required=True),
           prop('muted', BOOL, False, 'Not counted yet: gray and dimmed.')],
    previews=[preview('Sixty', 18, 18, value=60), preview('Low', 18, 18, value=12), preview('Muted', 18, 18, value=40, muted=True)],
    nodes={
        'ring': {'type': 'stack', 'children': ['arc', 'center'], 'layout': {'width': 18, 'height': 18},
                 'bind': {'opacity': '${= props.muted ? 0.55 : 1}'}},
        'arc': {'type': 'circularProgressIndicator',
                'props': {'value': 0.6, 'color': 'success', 'backgroundColor': 'track', 'strokeWidth': 3, 'strokeAlign': -1},
                'layout': {'width': 18, 'height': 18},
                'bind': {'props.value': '${= max(0, min(100, props.value)) / 100}',
                         'props.color': "${= props.muted ? theme.colors.tertiaryText : (props.value < 20 ? theme.error : (props.value < 60 ? theme.warning : theme.success))}"}},
        'center': {'type': 'row', 'children': ['number'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                   'layout': {'width': 18, 'height': 18}},
        'number': {**text('${= round(max(0, min(100, props.value)))}', style(6.5, 800, 'secondaryText', 1, letterSpacing=-0.39), {'hug': 8}, {'hug': 7}),
                   'bind': {'props.style.color': "${= props.muted ? theme.colors.tertiaryText : theme.colors.secondaryText}"}},
    },
))

# --- batch 8: provider rows, option icons and card actions -----------------------------------------------------

def _plate(root, size, pad, radius, letter_size, url, letter, color):
    """A bordered square holding a logo, or a letter when there is none."""
    return {
        root: {'type': 'row', 'children': [root + 'Letter'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
               'layout': {'width': size, 'height': size},
               'decoration': {'fills': [{'color': 'primaryBackground'},
                                        {'type': 'image', 'image': {'url': '', 'fit': 'contain'}, 'visible': False}],
                              'strokes': [{'color': 'primaryBorder'}], 'radius': radius, 'clip': 'antiAlias'},
               'bind': {'decoration.fills[1].image.url': '${%s}' % url, 'decoration.fills[1].visible': "${= %s != ''}" % url}},
        root + 'Letter': {**text(letter, style(letter_size, 700, 'primary', 1), {'hug': 10}, {'hug': letter_size}),
                          'bind': {'visible': "${= %s == ''}" % url, 'props.style.color': color}},
    }


LETTER_COLOR = "${= props.color != '' ? props.color : theme.primary}"

# ProviderIcon (ProviderIcon.tsx): a 34 px plate, radius 8, bordered on the primary background, holding the
# provider's logo contained with 5 px around it, or a letter 14/700 in its color.
add(component(
    'ProviderIcon',
    'A provider\'s logo on a small bordered plate, or its letter when there is no logo.',
    'plate',
    props=[prop('image', STRING, '', 'The logo\'s URL (empty: the letter).'),
           prop('letter', STRING, '?', 'The letter shown without a logo.'),
           prop('color', STRING, '', 'The letter\'s color (empty: the brand color).')],
    previews=[preview('Letter', 34, 34, letter='S')],
    nodes=_plate('plate', 34, 5, 8, 14, 'props.image', '${props.letter}', LETTER_COLOR),
))

# OptionIcon (OptionIcon.tsx): an 18 px square, radius 5: a bordered logo that covers it, a letter 9/700 when
# there is none, or an 11 px icon on the subtle fill.
add(component(
    'OptionIcon',
    'The small square before an option in a menu or list: a logo, a letter or an icon.',
    'box',
    props=[prop('image', STRING, '', 'A logo\'s URL (empty: the icon, else the letter).'),
           prop('icon', STRING, '', 'An icon on a subtle square (empty: the letter).'),
           prop('letter', STRING, '', 'A letter, when there is neither.'),
           prop('color', STRING, '', 'The letter\'s color (empty: the brand color).')],
    previews=[preview('Icon', 18, 18, icon='bolt'), preview('Letter', 18, 18, letter='G')],
    nodes={
        'box': {'type': 'row', 'children': ['glyph', 'letter'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                'layout': {'width': 18, 'height': 18},
                'decoration': {'fills': [{'color': 'tertiaryBackground'}, {'type': 'image', 'image': {'url': '', 'fit': 'cover'}, 'visible': False}],
                               'strokes': [{'color': 'primaryBorder', 'visible': False}], 'radius': 5, 'clip': 'antiAlias'},
                'bind': {'decoration.fills[0].color': "${= props.icon != '' && props.image == '' ? theme.colors.tertiaryBackground : theme.colors.primaryBackground}",
                         'decoration.fills[1].image.url': '${props.image}', 'decoration.fills[1].visible': "${= props.image != ''}",
                         'decoration.strokes[0].visible': "${= props.image != '' || props.icon == ''}"}},
        'glyph': {**icon('bolt', 'secondaryText', 11), 'bind': {'visible': "${= props.image == '' && props.icon != ''}", 'props.icon': '${props.icon}'}},
        'letter': {**text('${props.letter}', style(9, 700, 'primary', 1), {'hug': 8}, {'hug': 9}),
                   'bind': {'visible': "${= props.image == '' && props.icon == ''}", 'props.style.color': LETTER_COLOR}},
    },
))

# ProviderCard (ProviderCard.tsx): a provider in a settings list, 8 px above and below: the 34 px plate, 12 px,
# the name 13/600 (-0.2) with a 6 px dot (success with a glow when connected, else secondary text) and a subtitle
# 11.5 on a 1.4 line 2 px under it, 8 px, then the action pill (a 10 px link icon and 11/500 words).
add(component(
    'ProviderCard',
    'A service you connect to, as a row: its logo or letter, name and a dot for connected, a subtitle, and an action pill. Fires onAction.',
    'row',
    props=[prop('label', STRING, 'GitHub', 'The provider\'s name.', required=True),
           prop('subtitle', STRING, '', 'A line under the name.'),
           prop('connected', BOOL, True, 'A green dot (else a gray one).'),
           prop('image', STRING, '', 'The logo\'s URL (empty: the name\'s first letter).'),
           prop('color', STRING, '', 'The letter\'s color (empty: primary text).'),
           prop('actionLabel', STRING, 'Connected', 'The pill\'s words.')],
    events=['onAction'],
    previews=[preview('Connected', 300, 50, label='GitHub', subtitle='acme-inc · 14 repositories'),
              preview('Not connected', 300, 50, label='Linear', connected=False, actionLabel='Connect')],
    nodes={
        'row': {'type': 'row', 'children': ['plate', 'words', 'pill'], 'props': {'crossAxisAlignment': 'center'},
                'layout': {'width': {'fill': 300}, 'height': {'hug': 50}, 'padding': [0, 8, 0, 8]}},
        **_plate('plate', 34, 5, 8, 14, 'props.image', '${= upper(substring(props.label, 0, 1))}',
                 "${= props.color != '' ? props.color : theme.colors.primaryText}"),
        'words': {'type': 'column', 'children': ['line', 'subtitle'], 'props': {'crossAxisAlignment': 'start', 'spacing': 2},
                  'layout': {'width': {'fill': 200}, 'height': {'hug': 30}, 'margin': [12, 0, 8, 0]}},
        'line': {'type': 'row', 'children': ['label', 'dot'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                 'layout': {'width': {'hug': 80}, 'height': {'hug': 14}}},
        'label': text('${props.label}', style(13, 600, 'primaryText', 1.1, letterSpacing=-0.2), {'hug': 60}, {'hug': 14}),
        'dot': {'type': 'box', 'layout': {'width': 6, 'height': 6},
                'decoration': {'fills': [{'color': 'success'}], 'radius': 3, 'effects': [shadow('#6616A34A', 0, 4, 1)]},
                'bind': {'decoration.fills[0].color': '${= props.connected ? theme.success : theme.colors.secondaryText}',
                         'decoration.effects[0].visible': '${props.connected}'}},
        'subtitle': {'type': 'text', 'props': {'text': '${props.subtitle}', 'maxLines': 1, 'overflow': 'ellipsis',
                                                'style': style(11.5, 400, 'secondaryText', 1.4)},
                     'layout': {'width': {'fill': 200}, 'height': {'hug': 16}},
                     'bind': {'visible': "${= props.subtitle != ''}"}},
        'pill': {'type': 'row', 'children': ['pillIcon', 'pillLabel'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                 'layout': {'width': {'hug': 80}, 'height': {'hug': 22}, 'padding': [7, 2, 7, 2]},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 6},
                 'states': {'hovered': {'pill': HOVER}, 'pressed': {'pill': PRESS}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onAction', 'value': '${props.label}'}]}]},
        'pillIcon': {**icon('link', 'success', 10),
                     'bind': {'props.color': '${= props.connected ? theme.success : theme.colors.secondaryText}'}},
        'pillLabel': text('${props.actionLabel}', style(11, 500, 'secondaryText', 16 / 11), {'hug': 56}, {'hug': 16}),
    },
))

# CardActions (CardActions.tsx): the action strip closing a card: 34 px, a hairline above, the secondary
# background, the bottom corners rounded 10; equal actions split by 1 px rules, each an 11 px icon, 5 px, and its
# label 11/600 (-0.1) in secondary text.
add(component(
    'CardActions',
    'The strip of actions at the foot of a card: equal buttons split by hairlines. Fires onAction with the label.',
    'strip',
    props=[prop('actions', STRINGS, ['Open', 'Share'], 'The labels, in order.', required=True),
           prop('icons', STRINGS, [], 'An icon for each (same order; none: no icons).')],
    events=[{'key': 'onAction', 'payload': STRING}],
    previews=[preview('Two', 280, 34, actions=['Open', 'Share'], icons=['open_in_new', 'ios_share'])],
    nodes={
        'strip': {'type': 'row', 'children': ['list'], 'layout': {'width': {'fill': 280}, 'height': 34},
                  'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'top',
                                 'radius': [0, 0, 10, 10], 'clip': 'antiAlias'}},
        'list': {'type': 'gridView', 'children': ['action'],
                 'props': {'crossAxisCount': 2, 'mainAxisExtent': 34, 'physics': 'never', 'alwaysScroll': False},
                 'layout': {'width': {'fill': 280}, 'height': 34},
                 'bind': {'data': '${props.actions}', 'props.crossAxisCount': '${= max(1, length(props.actions))}'}},
        'action': {'type': 'row', 'children': ['actionIcon', 'actionLabel'],
                   'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center', 'spacing': 5},
                   'layout': {'width': {'fill': 140}, 'height': {'fill': 34}},
                   'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'left'},
                   'bind': {'decoration.strokes[0].visible': '${= index > 0}'},
                   'states': {'hovered': {'action': HOVER}, 'pressed': {'action': PRESS}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onAction', 'value': '${item}'}]}]},
        'actionIcon': {**icon('open_in_new', 'secondaryText', 11),
                       'bind': {'visible': '${= length(props.icons) > index}', 'props.icon': "${= length(props.icons) > index ? props.icons[index] : 'circle'}"}},
        'actionLabel': text('${item}', style(11, 600, 'secondaryText', 1.3, letterSpacing=-0.1), {'hug': 40}, {'hug': 14}),
    },
))

# --- batch 9: where you are: breadcrumb, page dots, steps ------------------------------------------------------

# Breadcrumb (Breadcrumb.tsx): the path to this page, 14/500, 8 px apart: earlier levels in secondary text (primary
# on hover), a 16 px tertiary chevron between, the last level in primary text; an optional home icon button first.
add(component(
    'Breadcrumb',
    'The path to this page: each level a link, the last one where you are. Fires onNavigate with the level\'s label ("Home" for the icon).',
    'nav',
    props=[prop('items', STRINGS, ['Projects', 'Design system', 'Components'], 'The levels, outermost first.', required=True),
           prop('showHomeIcon', BOOL, False, 'A home icon before the first level.')],
    events=[{'key': 'onNavigate', 'payload': STRING}],
    previews=[preview('Three', 300, 24, items=['Projects', 'Design system', 'Components']),
              preview('Home', 320, 24, items=['Settings', 'Profile'], showHomeIcon=True)],
    nodes={
        'nav': {'type': 'row', 'children': ['home', 'homeSeparator', 'levels'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                'layout': {'width': {'hug': 300}, 'height': {'hug': 24}}},
        'home': {'type': 'row', 'children': ['homeIcon'], 'layout': {'width': {'hug': 24}, 'height': {'hug': 24}, 'padding': 4},
                 'decoration': {'radius': 6}, 'bind': {'visible': '${props.showHomeIcon}'},
                 'states': {'hovered': {'home': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}},
                                        'homeIcon': {'props': {'color': 'primaryText'}}}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onNavigate', 'value': 'Home'}]}]},
        'homeIcon': icon('home', 'secondaryText', 16),
        'homeSeparator': {**icon('chevron_right', 'tertiaryText', 16), 'bind': {'visible': '${props.showHomeIcon}'}},
        'levels': {'type': 'listView', 'children': ['level'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': 8},
                   'layout': {'width': {'hug': 260}, 'height': 20}, 'bind': {'data': '${props.items}'}},
        'level': {'type': 'row', 'children': ['label', 'separator'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                  'layout': {'width': {'hug': 80}, 'height': {'fill': 20}},
                  'bind': {'selected': '${= index == length(props.items) - 1}'},
                  'states': {'hovered': {'label': {'props': {'style': {'color': 'primaryText'}}}},
                             'selected': {'label': {'props': {'style': {'color': 'primaryText'}}}}},
                  'actions': [{'trigger': {'type': 'click', 'when': 'index < length(props.items) - 1'},
                               'actions': [{'type': 'componentEvent', 'event': 'onNavigate', 'value': '${item}'}]}]},
        'label': text('${item}', style(14, 500, 'secondaryText', 1.4), {'hug': 60}, {'hug': 20}),
        'separator': {**icon('chevron_right', 'tertiaryText', 16), 'bind': {'visible': '${= index < length(props.items) - 1}'}},
    },
))

# PageControl (PageControl.tsx): which page of a carousel: a row of 4 px dots 4 px apart on the tertiary
# background, the current one a 12 px brand bar; all with radius 2.
add(component(
    'PageControl',
    'Which page of several: small dots, the current one a wider brand bar. Fires onPageTapped with the index.',
    'dots',
    props=[prop('currentPage', NUMBER, 0, 'The current page, from 0.', required=True),
           prop('totalPages', NUMBER, 3, 'How many pages.', required=True)],
    events=[{'key': 'onPageTapped', 'payload': NUMBER}],
    previews=[preview('Second of five', 48, 4, currentPage=1, totalPages=5)],
    nodes={
        'dots': {'type': 'row', 'children': ['list'], 'layout': {'width': {'hug': 40}, 'height': {'hug': 4}}},
        'list': {'type': 'listView', 'children': ['dot'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': 4},
                 'layout': {'width': {'hug': 40}, 'height': 4, 'padding': [2, 0, 2, 0]},
                 'bind': {'data': '${= range(max(0, props.totalPages))}'}},
        'dot': {'type': 'box', 'layout': {'width': 4, 'height': {'fill': 4}},
                'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 2},
                'bind': {'layout.width': '${= item == props.currentPage ? 12 : 4}',
                         'decoration.fills[0].color': '${= item == props.currentPage ? theme.primary : theme.colors.tertiaryBackground}'},
                'transitions': [{'property': 'layout.width', 'duration': 200, 'curve': 'easeInOut'}],
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPageTapped', 'value': '${item}'}]}]},
    },
))

# StepIndicator (StepIndicator.tsx, the track): steps across, each at least 120 wide: a 16 px marker (a brand disc
# with a check when done; a 1.5 px brand ring with a 6 px dot and a 3 px soft halo when current; a bordered ring
# when upcoming) joined to the next by a 1.5 px line (brand once done), and under it the label 11.5 on a 16 px line
# (650 in primary text once reached, 500 tertiary before) and a detail 10.5 tertiary.
add(component(
    'StepIndicator',
    'Progress through named steps: done steps checked, the current one ringed, the rest to come. Fires onStepPressed with the index.',
    'steps',
    props=[prop('steps', STRINGS, ['Details', 'Review', 'Confirm'], 'The steps\' names, in order.', required=True),
           prop('current', NUMBER, 1, 'The current step, from 0 (the count: all done).', required=True),
           prop('details', STRINGS, [], 'A muted line under each name (same order; none: no lines).')],
    events=[{'key': 'onStepPressed', 'payload': NUMBER}],
    previews=[preview('Second of three', 380, 44, steps=['Details', 'Review', 'Confirm'], current=1)],
    nodes={
        'steps': {'type': 'row', 'children': ['list'], 'layout': {'width': {'hug': 380}, 'height': {'hug': 44}}},
        'list': {'type': 'listView', 'children': ['step'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False},
                 'layout': {'width': {'hug': 380}, 'height': 44, 'padding': [0, 3, 0, 3]},
                 'bind': {'data': '${props.steps}', 'layout.height': '${= length(props.details) > 0 ? 58 : 44}'}},
        'step': {'type': 'column', 'children': ['rail', 'name', 'detail'], 'props': {'crossAxisAlignment': 'start'},
                 'layout': {'width': 120, 'height': {'fill': 38}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onStepPressed', 'value': '${index}'}]}]},
        'rail': {'type': 'row', 'children': ['marker', 'line'], 'props': {'crossAxisAlignment': 'center'},
                 'layout': {'width': {'fill': 120}, 'height': 16, 'padding': [3, 0, 0, 0]}},
        'marker': {'type': 'row', 'children': ['check', 'pip'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                   'layout': {'width': 16, 'height': 16},
                   'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeWidth': 1.5, 'radius': 8,
                                  'effects': [{'type': 'dropShadow', 'color': 'primaryTint', 'offset': [0, 0], 'blurRadius': 0, 'spreadRadius': 3, 'visible': False}]},
                   'bind': {'decoration.fills[0].color': '${= index < props.current ? theme.primary : theme.colors.primaryBackground}',
                            'decoration.strokes[0].color': '${= index <= props.current ? theme.primary : theme.colors.primaryBorder}',
                            'decoration.effects[0].visible': '${= index == props.current}'}},
        'check': {**icon('check', 'onAccent', 10), 'bind': {'visible': '${= index < props.current}'}},
        'pip': {'type': 'box', 'layout': {'width': 6, 'height': 6}, 'decoration': {'fills': [{'color': 'primary'}], 'radius': 3},
                'bind': {'visible': '${= index == props.current}'}},
        'line': {'type': 'box', 'layout': {'width': {'fill': 80}, 'height': 1.5, 'margin': [6, 0, 6, 0]},
                 'decoration': {'fills': [{'color': 'primaryBorder'}], 'radius': 1},
                 'bind': {'visible': '${= index < length(props.steps) - 1}',
                          'decoration.fills[0].color': '${= index < props.current ? theme.primary : theme.colors.primaryBorder}'}},
        'name': {'type': 'text', 'props': {'text': '${item}', 'maxLines': 1, 'overflow': 'ellipsis',
                                            'style': style(11.5, 500, 'tertiaryText', 16 / 11.5)},
                 'layout': {'width': {'fill': 108}, 'height': {'hug': 16}, 'margin': [0, 6, 12, 0]},
                 'bind': {'props.style.color': '${= index <= props.current ? theme.colors.primaryText : theme.colors.tertiaryText}',
                          'props.style.fontWeight': '${= index <= props.current ? 600 : 500}'}},
        'detail': {'type': 'text', 'props': {'text': "${= length(props.details) > index ? props.details[index] : ''}", 'maxLines': 1,
                                              'overflow': 'ellipsis', 'style': style(10.5, 400, 'tertiaryText', 14 / 10.5)},
                   'layout': {'width': {'fill': 108}, 'height': {'hug': 14}, 'margin': [0, 0, 12, 0]},
                   'bind': {'visible': '${= length(props.details) > index}'}},
    },
))

# --- batch 10: stepper, search bar, theme toggle, download ------------------------------------------------------

def _step_button(id_, glyph, side, formula, enabled):
    radius = [8, 0, 0, 8] if side == 'start' else [0, 8, 8, 0]
    return {
        id_: {'type': 'row', 'children': [id_ + 'Icon'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
              'layout': {'width': 32, 'height': {'fill': 36}}, 'decoration': {'radius': radius},
              'bind': {'disabled': '${= !(%s)}' % enabled},
              'states': {'hovered': {id_: {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}},
                         'disabled': {id_ + 'Icon': {'props': {'color': 'tertiaryText'}}}},
              'actions': [{'trigger': {'type': 'click', 'when': enabled}, 'actions': [
                  {'type': 'setVariable', 'variable': 'props.value', 'value': '${= %s}' % formula},
                  {'type': 'componentEvent', 'event': 'onChanged', 'value': '${props.value}'}]}]},
        id_ + 'Icon': icon(glyph, 'primaryText', 16),
    }


# Stepper (Stepper.tsx): a number with a minus and a plus: an optional label 14/500, 12 px, then a bordered group
# with radius 8: 32 px buttons with 16 px icons either side of the value 14/500 (16 px either side of it, at least
# 60 wide, hairlines between); a button at its limit is tertiary.
add(component(
    'Stepper',
    'A number changed one step at a time: minus, the value, plus. The value is kept in your variable. Fires onChanged.',
    'stepper',
    props=[prop('value', var(NUMBER), '', 'The name of your number variable.'),
           prop('min', NUMBER, 0, 'The least it goes.'),
           prop('max', NUMBER, 100, 'The most it goes.'),
           prop('step', NUMBER, 1, 'How much a press changes it.'),
           prop('label', STRING, '', 'Words before it (empty: none).'),
           prop('enabled', BOOL, True, 'False: dimmed, no presses.')],
    events=[{'key': 'onChanged', 'payload': NUMBER}],
    previews=[preview('Three', 140, 36, value=3), preview('Labeled', 220, 36, value=1, label='Seats')],
    nodes={
        'stepper': {'type': 'row', 'children': ['label', 'group'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                    'layout': {'width': {'hug': 140}, 'height': {'hug': 36}},
                    'bind': {'opacity': '${= props.enabled ? 1 : 0.5}'}},
        'label': {**text('${props.label}', style(14, 500, 'primaryText', 1.4), {'hug': 40}, {'hug': 20}),
                  'bind': {'visible': "${= props.label != ''}"}},
        'group': {'type': 'row', 'children': ['minus', 'value', 'plus'], 'props': {'crossAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 124}, 'height': 36, 'padding': 1},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8,
                                 'clip': 'antiAlias'}},
        **_step_button('minus', 'remove', 'start', 'max(props.min, props.value - props.step)', 'props.enabled && props.value > props.min'),
        'value': {'type': 'row', 'children': ['number'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 60}, 'height': {'fill': 34}, 'padding': [16, 0, 16, 0], 'constraints': {'minWidth': 60}},
                  'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'leftRight'}},
        'number': text('${props.value}', style(14, 500, 'primaryText', 1.4), {'hug': 20}, {'hug': 20}),
        **_step_button('plus', 'add', 'end', 'min(props.max, props.value + props.step)', 'props.enabled && props.value < props.max'),
    },
))

# SearchBar (SearchBar.tsx): a search field with radius 12 and a hairline on the primary background: a 16 px
# secondary search icon, 8 px, the text (14; 16 large) and, once there is text, a clear button (a 16 px x, 4 px
# around it, radius 6). 32, 40 or 48 high with 12, 16 or 20 px either side.
SEARCH_H = {'sm': 32, 'md': 40, 'lg': 48}
add(component(
    'SearchBar',
    'A rounded search field with a search icon and a clear button, its text kept in your variable. Fires onChanged, onSubmitted and onClear.',
    'bar',
    props=[prop('value', var(STRING), '', 'The name of your text variable.'),
           prop('placeholder', STRING, 'Search...', 'Shown while empty.'),
           prop('size', enum('sm', 'md', 'lg'), 'md', 'sm 32, md 40, lg 48 high.')],
    events=[{'key': 'onChanged', 'payload': STRING}, {'key': 'onSubmitted', 'payload': STRING}, 'onClear'],
    previews=[preview('Empty', 300, 40), preview('Typed', 300, 40, value='invoices')],
    nodes={
        'bar': {'type': 'row', 'children': ['strut', 'glyph', 'field', 'clear'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                'layout': {'width': {'fill': 300}, 'height': {'hug': 40}, 'padding': [16, 0, 16, 0]},
                'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12},
                'bind': {'layout.padding': by('size', {'sm': [12, 0, 12, 0], 'md': [16, 0, 16, 0], 'lg': [20, 0, 20, 0]})}},
        'strut': strut(by('size', SEARCH_H), 40),
        'glyph': icon('search', 'secondaryText', 16),
        'field': {
            'type': 'textField', 'layout': {'width': {'fill': 200}, 'height': {'hug': 24}},
            'props': {'style': {'from': 'inputText', 'fontSize': 14},
                      'decoration': {'isDense': True, 'isCollapsed': True, 'border': {'type': 'none'}, 'hintStyle': 'placeholder'},
                      'cursorColor': 'primary', 'textInputAction': 'search'},
            'bind': {'props.initialValue': '${props.value}', 'props.decoration.hintText': '${props.placeholder}',
                     'props.style.fontSize': by('size', {'sm': 14, 'md': 14, 'lg': 16})},
            'actions': [
                {'trigger': {'type': 'changed'}, 'actions': [
                    {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'},
                    {'type': 'componentEvent', 'event': 'onChanged', 'value': '${result}'}]},
                {'trigger': {'type': 'submitted'}, 'actions': [{'type': 'componentEvent', 'event': 'onSubmitted', 'value': '${result}'}]},
            ],
        },
        'clear': {'type': 'row', 'children': ['x'], 'layout': {'width': {'hug': 24}, 'height': {'hug': 24}, 'padding': 4},
                  'decoration': {'radius': 6}, 'bind': {'visible': "${= props.value != ''}"},
                  'states': {'hovered': {'clear': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}, 'x': {'props': {'color': 'primaryText'}}}},
                  'actions': [{'trigger': 'click', 'actions': [
                      {'type': 'setVariable', 'variable': 'props.value', 'value': ''},
                      {'type': 'componentEvent', 'event': 'onChanged', 'value': ''},
                      {'type': 'componentEvent', 'event': 'onClear'}]}]},
        'x': icon('close', 'secondaryText', 16),
    },
))

# ThemeToggle (ThemeToggle.tsx): a 36 px button, radius 8, 8 px round a 20 px icon: a moon on the light theme
# (a hairline round it), a sun on the dark one; pressing it switches the site's mode.
add(component(
    'ThemeToggle',
    'Switches the site between light and dark: a moon in light mode, a sun in dark. Fires onChanged with the new mode.',
    'button',
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Light', 36, 36)],
    nodes={
        'button': {'type': 'row', 'children': ['glyph'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                   'layout': {'width': {'hug': 36}, 'height': {'hug': 36}, 'padding': 8},
                   'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8},
                   'bind': {'decoration.strokes[0].visible': '${= !theme.isDark}',
                            'decoration.fills[0].color': '${= theme.isDark ? theme.colors.tertiaryBackground : theme.colors.primaryBackground}'},
                   'states': {'hovered': {'button': HOVER}, 'pressed': {'button': PRESS}},
                   'actions': [{'trigger': 'click', 'actions': [
                       {'type': 'componentEvent', 'event': 'onChanged', 'value': "${= theme.isDark ? 'light' : 'dark'}"},
                       {'type': 'setThemeMode', 'mode': "${= theme.isDark ? 'light' : 'dark'}"}]}]},
        'glyph': {**icon('dark_mode', 'primaryText', 20), 'bind': {'props.icon': "${= theme.isDark ? 'light_mode' : 'dark_mode'}"}},
    },
))

# DownloadButton (DownloadButton.tsx): a button that starts a download: a download icon and a label on the control
# scale (the primary look), or the ghost icon alone; a spinner in the icon's place while it runs.
add(component(
    'DownloadButton',
    'Starts a download: a download icon with a label, or the icon alone. Fires onPressed.',
    'button',
    props=[prop('label', STRING, 'Download', 'The words (empty: the icon alone, on a ghost button).'),
           prop('loading', BOOL, False, 'A spinner in the icon\'s place; no presses.'),
           prop('enabled', BOOL, True, 'False: dimmed, no presses.')],
    events=['onPressed'],
    previews=[preview('Labeled', 110, 36), preview('Icon', 36, 36, label='')],
    nodes={
        'button': {'type': 'row', 'children': ['strut', 'spinner', 'glyph', 'label'],
                   'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'hug': 110}, 'height': {'hug': 36}, 'padding': [10, 0, 10, 0], 'constraints': {'minWidth': 36}},
                   'decoration': {'fills': [{'color': 'primary'}], 'radius': 7},
                   'bind': {'decoration.fills[0].color': "${= props.label == '' ? '#00000000' : theme.primary}",
                            'decoration.radius': '${theme.radii.control}',
                            'opacity': '${= props.enabled ? 1 : 0.5}'},
                   'states': {'hovered': {'button': HOVER}, 'pressed': {'button': PRESS}},
                   'actions': [click('onPressed', when='props.enabled && !props.loading')]},
        'strut': strut('${theme.sizes.medium}', 36),
        'spinner': {'type': 'circularProgressIndicator', 'props': {'color': 'onAccent', 'strokeWidth': 1.5, 'strokeCap': 'round'},
                    'layout': {'width': 13, 'height': 13},
                    'bind': {'visible': '${props.loading}',
                             'props.color': "${= props.label == '' ? theme.colors.secondaryText : theme.colors.onAccent}"}},
        'glyph': {**icon('download', 'onAccent', 16),
                  'bind': {'visible': '${= !props.loading}',
                           'props.color': "${= props.label == '' ? theme.colors.secondaryText : theme.colors.onAccent}"}},
        'label': {**text('${props.label}', {'from': 'controlMedium', 'color': 'onAccent'}, {'hug': 60}, {'hug': 18}),
                  'bind': {'visible': "${= props.label != ''}"}},
    },
))

# --- batch 11: upgrade button, filter legend, banners ------------------------------------------------------------

# UpgradeButton (UpgradeButton.tsx): the call to upgrade: an orange to pink gradient (or solid orange), radius 8,
# white 600 text with an icon 8 px before it; 6 x 12 at 14 (16 px icon), 8 x 16 at 16 (20), 12 x 24 at 18 (24);
# an orange glow under it.
add(component(
    'UpgradeButton',
    'The call to upgrade a plan: a warm gradient button with a crown or sparkles. Fires onPressed.',
    'button',
    props=[prop('label', STRING, 'Upgrade to Pro', 'The words.'),
           prop('variant', enum('gradient', 'primary'), 'gradient', 'gradient: orange to pink. primary: solid orange.'),
           prop('size', enum('sm', 'md', 'lg'), 'md', 'sm, md or lg.'),
           prop('icon', enum('crown', 'sparkles'), 'crown', 'Which icon.')],
    events=['onPressed'],
    previews=[preview('Gradient', 180, 40), preview('Small solid', 150, 32, variant='primary', size='sm', icon='sparkles')],
    nodes={
        'button': {'type': 'row', 'children': ['glyph', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'hug': 170}, 'height': {'hug': 40}, 'padding': [16, 8, 16, 8]},
                   'decoration': {'fills': [{'color': '#FFF97316'},
                                            {'type': 'linear', 'begin': [-1, 0], 'end': [1, 0],
                                             'stops': [{'color': '#FFF97316', 'position': 0}, {'color': '#FFDB2777', 'position': 1}]}],
                                  'radius': 8, 'effects': [shadow('#66FB923C', 4, 12, -2)]},
                   'bind': {'layout.padding': by('size', {'sm': [12, 6, 12, 6], 'md': [16, 8, 16, 8], 'lg': [24, 12, 24, 12]}),
                            'decoration.fills[1].visible': "${= props.variant == 'gradient'}"},
                   'states': {'hovered': {'button': HOVER}, 'pressed': {'button': PRESS}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed'}]}]},
        'glyph': {**icon('workspace_premium', '#FFFFFFFF', 20),
                  'bind': {'props.icon': "${= props.icon == 'crown' ? 'workspace_premium' : 'auto_awesome'}",
                           'props.size': by('size', {'sm': 16, 'md': 20, 'lg': 24}),
                           'layout.width': by('size', {'sm': 16, 'md': 20, 'lg': 24}),
                           'layout.height': by('size', {'sm': 16, 'md': 20, 'lg': 24})}},
        'label': {**text('${props.label}', style(16, 600, '#FFFFFFFF', 1.5), {'hug': 110}, {'hug': 24}),
                  'bind': {'props.style.fontSize': by('size', {'sm': 14, 'md': 16, 'lg': 18})}},
    },
))

# FilterLegend (FilterLegend.tsx): the strip of counts over a list that filters it: at least 28 high on the
# secondary background with a hairline under it, padding 7 x 12 (8 at the end); items 16 px apart, each a label
# 10 px in secondary text, a colon and its value 600 in the item's color; the active one underlined.
add(component(
    'FilterLegend',
    'A strip of labeled counts that filter the list under it; the active one is underlined. Fires onSelected with the label.',
    'strip',
    props=[prop('labels', STRINGS, ['All', 'Open', 'Closed'], 'The filters\' names.', required=True),
           prop('values', STRINGS, [], 'A value after each name (same order).'),
           prop('colors', STRINGS, [], 'A color for each value (same order; none: tertiary text).'),
           prop('active', STRING, '', 'The label of the filter in use.')],
    events=[{'key': 'onSelected', 'payload': STRING}],
    previews=[preview('Three', 320, 28, labels=['All', 'Open', 'Closed'], values=['42', '12', '30'], active='Open')],
    nodes={
        'strip': {'type': 'row', 'children': ['items'], 'props': {'crossAxisAlignment': 'center'},
                  'layout': {'width': {'fill': 320}, 'height': {'hug': 28}, 'padding': [12, 7, 8, 7], 'constraints': {'minHeight': 28}},
                  'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'items': {'type': 'listView', 'children': ['item'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': 16},
                  'layout': {'width': {'hug': 280}, 'height': 14}, 'bind': {'data': '${props.labels}'}},
        'item': {'type': 'row', 'children': ['label', 'value'], 'props': {'crossAxisAlignment': 'center'},
                 'layout': {'width': {'hug': 50}, 'height': {'fill': 14}},
                 'states': {'hovered': {'item': {'opacity': 0.75}}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onSelected', 'value': '${item}'}]}]},
        'label': {**text("${= length(props.values) > index ? item + ': ' : item}", style(10, 400, 'secondaryText', 1.4), {'hug': 30}, {'hug': 14}),
                  'bind': {'props.style.decoration': "${= item == props.active ? 'underline' : 'none'}"}},
        'value': {**text("${= length(props.values) > index ? props.values[index] : ''}", style(10, 600, 'tertiaryText', 1.4), {'hug': 16}, {'hug': 14}),
                  'bind': {'visible': '${= length(props.values) > index}',
                           'props.style.color': "${= length(props.colors) > index ? props.colors[index] : theme.colors.tertiaryText}"}},
    },
))

# OnboardingBanner (OnboardingBanner.tsx): the first-run panel, padding 20 x 16: a 64 px hero tile (radius 16,
# the brand at 10 % with a 20 % border, a 28 px brand icon), 16 px, the title 16/700 (-0.3) centered, 8 px, the
# subtitle 13 at 1.55 in secondary text centered, 20 px, the features in a tertiary box (radius 10, padding
# 12 x 14, 10 px apart: a 13 px icon and 12.5 text), the call's children, 20 px, a 40 px brand button (radius 10,
# 13/600) and a footer hint 11 in tertiary text 12 px under it.
add(component(
    'OnboardingBanner',
    'The first-run panel: a hero icon, a title and subtitle, what you get as bullets, and one button. Fires onCta.',
    'banner',
    props=[prop('icon', STRING, 'rocket_launch', 'The hero icon.'),
           prop('title', STRING, 'Welcome', 'The title.', required=True),
           prop('subtitle', STRING, '', 'A sentence under it.'),
           prop('features', STRINGS, [], 'What you get, one line each.'),
           prop('featureIcons', STRINGS, [], 'An icon for each line (same order; none: a check).'),
           prop('ctaLabel', STRING, 'Get started', 'The button\'s words.', required=True),
           prop('ctaIcon', STRING, '', 'An icon in the button (empty: none).'),
           prop('footerHint', STRING, '', 'A muted line under the button (empty: none).')],
    events=['onCta'],
    children='list',
    previews=[preview('Welcome', 320, 380, title='Set up your workspace', subtitle='Connect a provider to start running agents.',
                      features=['Runs on your machine', 'Bring your own keys', 'Nothing leaves your network'], ctaLabel='Connect a provider')],
    nodes={
        'banner': {'type': 'column', 'children': ['hero', 'title', 'subtitle', 'features', 'extra', 'cta', 'hint'],
                   'props': {'crossAxisAlignment': 'center'},
                   'layout': {'width': {'fill': 320}, 'height': {'hug': 380}, 'padding': [16, 20, 16, 20]}},
        'hero': {'type': 'row', 'children': ['heroIcon'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                 'layout': {'width': 64, 'height': 64},
                 'decoration': {'fills': [{'color': 'primaryTint'}], 'strokes': [{'color': 'primaryTintBorder'}], 'radius': 16}},
        'heroIcon': {**icon('rocket_launch', 'primary', 28), 'bind': {'props.icon': '${props.icon}'}},
        'title': {'type': 'text', 'props': {'text': '${props.title}', 'textAlign': 'center', 'style': style(16, 700, 'primaryText', 1.3, letterSpacing=-0.3)},
                  'layout': {'width': {'fill': 288}, 'height': {'hug': 21}, 'margin': [0, 16, 0, 0]}},
        'subtitle': {'type': 'text', 'props': {'text': '${props.subtitle}', 'textAlign': 'center', 'style': style(13, 400, 'secondaryText', 1.55, letterSpacing=-0.1)},
                     'layout': {'width': {'fill': 288}, 'height': {'hug': 40}, 'margin': [0, 8, 0, 0]},
                     'bind': {'visible': "${= props.subtitle != ''}"}},
        'features': {'type': 'column', 'children': ['featureList'], 'props': {'crossAxisAlignment': 'stretch'},
                     'layout': {'width': {'fill': 288}, 'height': {'hug': 80}, 'padding': [14, 12, 14, 12], 'margin': [0, 20, 0, 0]},
                     'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 10},
                     'bind': {'visible': '${= length(props.features) > 0}'}},
        'featureList': {'type': 'listView', 'children': ['feature'], 'props': {'scrollable': False, 'spacing': 10},
                        'layout': {'width': {'fill': 260}, 'height': {'hug': 60}}, 'bind': {'data': '${props.features}'}},
        'feature': {'type': 'row', 'children': ['featureIcon', 'featureText'], 'props': {'crossAxisAlignment': 'start', 'spacing': 10},
                    'layout': {'width': {'fill': 260}, 'height': {'hug': 18}}},
        'featureIcon': {**icon('check', 'secondaryText', 13),
                        'layout': {'width': 13, 'height': 13, 'margin': [0, 2, 0, 0]},
                        'bind': {'props.icon': "${= length(props.featureIcons) > index ? props.featureIcons[index] : 'check'}"}},
        'featureText': text('${item}', style(12.5, 400, 'secondaryText', 1.4, letterSpacing=-0.1), {'fill': 230}, {'hug': 18}),
        'extra': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch'},
                  'layout': {'width': {'fill': 288}, 'height': {'hug': 0}, 'margin': [0, 16, 0, 0]}},
        'content': {'type': 'slot'},
        'cta': {'type': 'row', 'children': ['ctaIcon', 'ctaLabel'],
                'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center', 'spacing': 8},
                'layout': {'width': {'fill': 288}, 'height': 40, 'margin': [0, 4, 0, 0]},
                'decoration': {'fills': [{'color': 'primary'}], 'radius': 10},
                'states': {'hovered': {'cta': HOVER}, 'pressed': {'cta': PRESS}},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onCta'}]}]},
        'ctaIcon': {**icon('arrow_forward', 'onAccent', 15), 'bind': {'visible': "${= props.ctaIcon != ''}", 'props.icon': '${props.ctaIcon}'}},
        'ctaLabel': text('${props.ctaLabel}', style(13, 600, 'onAccent', 1.3, letterSpacing=-0.1), {'hug': 120}, {'hug': 17}),
        'hint': {'type': 'text', 'props': {'text': '${props.footerHint}', 'textAlign': 'center', 'style': style(11, 400, 'tertiaryText', 1.3, letterSpacing=-0.1)},
                 'layout': {'width': {'fill': 288}, 'height': {'hug': 14}, 'margin': [0, 12, 0, 0]},
                 'bind': {'visible': "${= props.footerHint != ''}"}},
    },
))

# PromptBanner (PromptBanner.tsx): the 32 px notice that sits on top of a prompt box: rounded 12 at the top only,
# bordered (its lower edge meets the box under it), 16 px either side: a 14 px icon and a message 12/500 in the tone's color, and at the
# end a link in the same color. Neutral and info on the secondary background; warning and critical tinted.
BANNER_TONES = ['info', 'neutral', 'warning', 'critical']
BANNER_INK = "${= props.tone == 'critical' ? theme.error : (props.tone == 'warning' ? theme.warning : (props.tone == 'neutral' ? theme.colors.primaryText : theme.colors.secondaryText))}"
add(component(
    'PromptBanner',
    'A one-line notice attached to the top of a prompt box: credits left, a limit reached, read-only. Fires onPressed and onAction.',
    'banner',
    props=[prop('message', STRING, 'You have 3 runs left today', 'The notice.', required=True),
           prop('tone', enum(*BANNER_TONES), 'info', 'info and neutral: plain. warning and critical: tinted.'),
           prop('icon', STRING, '', 'An icon before the message (empty: none).'),
           prop('actionLabel', STRING, '', 'A link at the end ("Upgrade"); empty: none.')],
    events=['onPressed', 'onAction'],
    previews=[preview('Info', 320, 32, message='You have 3 runs left today', icon='bolt', actionLabel='Upgrade'),
              preview('Critical', 320, 32, message='Out of credits', tone='critical', icon='error_outline', actionLabel='Add credits')],
    nodes={
        'banner': {'type': 'row', 'children': ['left', 'action'],
                   'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'spaceBetween', 'spacing': 8},
                   'layout': {'width': {'fill': 320}, 'height': 32, 'padding': [16, 0, 16, 0]},
                   'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}],
                                  'radius': [12, 12, 0, 0]},
                   'bind': {'decoration.fills[0].color': "${= props.tone == 'critical' ? theme.colors.errorTint : (props.tone == 'warning' ? theme.colors.warningTint : theme.colors.secondaryBackground)}",
                            'decoration.strokes[0].color': "${= props.tone == 'critical' ? theme.colors.errorTintBorder : (props.tone == 'warning' ? theme.colors.warningTintBorder : theme.colors.primaryBorder)}"},
                   'states': {'hovered': {'banner': HOVER}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed'}]}]},
        'left': {'type': 'row', 'children': ['glyph', 'message'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 16}}},
        'glyph': {**icon('bolt', 'secondaryText', 14), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}', 'props.color': BANNER_INK}},
        'message': {'type': 'text', 'props': {'text': '${props.message}', 'maxLines': 1, 'overflow': 'ellipsis', 'style': style(12, 500, 'secondaryText', 1.3)},
                    'layout': {'width': {'fill': 180}, 'height': {'hug': 16}}, 'bind': {'props.style.color': BANNER_INK}},
        'action': {'type': 'row', 'children': ['actionLabel', 'chevron'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                   'layout': {'width': {'hug': 70}, 'height': {'hug': 16}}, 'bind': {'visible': "${= props.actionLabel != ''}"},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onAction'}]}]},
        'actionLabel': {**text('${props.actionLabel}', style(12, 600, 'secondaryText', 1.3), {'hug': 50}, {'hug': 16}), 'bind': {'props.style.color': BANNER_INK}},
        'chevron': {**icon('chevron_right', 'secondaryText', 14), 'bind': {'props.color': BANNER_INK}},
    },
))

# --- batch 12: running, cloud sync, expandable text, stacked progress ---------------------------------------------

# RunningIndicator (RunningIndicator.tsx): a job under way: a 4 px bar (radius 2, the brand on the tertiary
# background), 6 px, then three pulsing 4 px brand dots, 7 px, the label 11/500 (-0.1) in secondary text with a
# dotted underline, and the percent in tertiary text at the end.
add(component(
    'RunningIndicator',
    'A job under way: a thin progress bar over pulsing dots, what it is doing and the percent.',
    'box',
    props=[prop('label', STRING, 'Indexing files', 'What it is doing.', required=True),
           prop('progress', NUMBER, 0.4, 'From 0 to 1.', required=True)],
    previews=[preview('Forty', 260, 26, label='Indexing files', progress=0.4)],
    nodes={
        'box': {'type': 'column', 'children': ['track', 'line'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 6},
                'layout': {'width': {'fill': 260}, 'height': {'hug': 26}}},
        'track': {'type': 'row', 'children': ['fill', 'rest'], 'layout': {'width': {'fill': 260}, 'height': 4},
                  'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 2, 'clip': 'antiAlias'}},
        'fill': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': {'fill': 4}, 'flex': 400},
                 'decoration': {'fills': [{'color': 'primary'}], 'radius': 2},
                 'bind': {'layout.flex': '${= round(max(0, min(1, props.progress)) * 1000)}', 'visible': '${= props.progress > 0}'}},
        'rest': {'type': 'box', 'layout': {'width': {'fill': 160}, 'height': {'fill': 4}, 'flex': 600},
                 'bind': {'layout.flex': '${= 1000 - round(max(0, min(1, props.progress)) * 1000)}', 'visible': '${= props.progress < 1}'}},
        'line': {'type': 'row', 'children': ['dots', 'label', 'percent'], 'props': {'crossAxisAlignment': 'center', 'spacing': 7},
                 'layout': {'width': {'fill': 260}, 'height': {'hug': 15}}},
        'dots': {'type': 'row', 'children': ['d1', 'd2', 'd3'], 'props': {'crossAxisAlignment': 'center', 'spacing': 2},
                 'layout': {'width': {'hug': 16}, 'height': {'hug': 4}}},
        'd1': {'type': 'box', 'layout': {'width': 4, 'height': 4}, 'decoration': {'fills': [{'color': 'primary'}], 'radius': 2}, 'animations': _pulse(0)},
        'd2': {'type': 'box', 'layout': {'width': 4, 'height': 4}, 'decoration': {'fills': [{'color': 'primary'}], 'radius': 2}, 'animations': _pulse(300)},
        'd3': {'type': 'box', 'layout': {'width': 4, 'height': 4}, 'decoration': {'fills': [{'color': 'primary'}], 'radius': 2}, 'animations': _pulse(600)},
        'label': {'type': 'text', 'props': {'text': '${props.label}', 'maxLines': 1, 'overflow': 'ellipsis',
                                             'style': style(11, 500, 'secondaryText', 1.3, letterSpacing=-0.1, decoration='underline', decorationStyle='dotted')},
                  'layout': {'width': {'fill': 180}, 'height': {'hug': 15}}},
        'percent': text('${= round(max(0, min(1, props.progress)) * 100)}%', style(11, 500, 'tertiaryText', 1.3, letterSpacing=-0.1), {'hug': 26}, {'hug': 15}),
    },
))

# CloudSyncIndicator (CloudSyncIndicator.tsx): whether something is in the cloud: a 14 px cloud with a small badge
# at its lower right saying how: a check (synced, success), a spinner (checking, syncing), a clock (pending,
# warning), an alert (failed, error), a struck cloud (unavailable, tertiary). Pressing it asks for a sync.
SYNC_STATES = ['checking', 'synced', 'syncing', 'pending', 'failed', 'unavailable']
SYNC_BUSY = "(props.state == 'checking' || props.state == 'syncing')"
SYNC_INK = "${= props.state == 'synced' ? theme.success : (props.state == 'failed' ? theme.error : (props.state == 'pending' ? theme.warning : (props.state == 'unavailable' ? theme.colors.tertiaryText : theme.primary)))}"
add(component(
    'CloudSyncIndicator',
    'Whether something is saved to the cloud: a small cloud with a mark for synced, syncing, pending, failed or unavailable. Fires onPressed.',
    'box',
    props=[prop('state', enum(*SYNC_STATES), 'synced', 'checking, synced, syncing, pending, failed or unavailable.')],
    events=['onPressed'],
    previews=[preview('Synced', 20, 18), preview('Failed', 20, 18, state='failed')],
    nodes={
        'box': {'type': 'stack', 'children': ['cloud', 'badge'], 'layout': {'width': 20, 'height': 18},
                'actions': [{'trigger': {'type': 'click', 'when': "props.state != 'unavailable'"},
                             'actions': [{'type': 'componentEvent', 'event': 'onPressed', 'value': '${props.state}'}]}]},
        'cloud': {**icon('cloud', 'secondaryText', 14), 'layout': {'width': 14, 'height': 14, 'x': {'start': 0}, 'y': {'start': 1}},
                  'bind': {'props.icon': "${= props.state == 'unavailable' ? 'cloud_off' : 'cloud'}",
                           'props.color': "${= props.state == 'unavailable' ? theme.colors.tertiaryText : theme.colors.secondaryText}"}},
        'badge': {'type': 'row', 'children': ['spinner', 'mark'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                  'layout': {'width': 10, 'height': 10, 'x': {'end': 0}, 'y': {'end': 0}},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'radius': 5},
                  'bind': {'visible': "${= props.state != 'unavailable'}"}},
        'spinner': {'type': 'circularProgressIndicator', 'props': {'color': 'primary', 'strokeWidth': 1.2, 'strokeCap': 'round'},
                    'layout': {'width': 6, 'height': 6}, 'bind': {'visible': '${= %s}' % SYNC_BUSY}},
        'mark': {**icon('check', 'success', 8),
                 'bind': {'visible': '${= !%s}' % SYNC_BUSY,
                          'props.icon': "${= props.state == 'failed' ? 'priority_high' : (props.state == 'pending' ? 'schedule' : 'check')}",
                          'props.color': SYNC_INK}},
    },
))

# TextExpandable (TextExpandable.tsx): a line that opens what is under it: a 13 px chevron (turned when open),
# 5 px, the title 11.5/650 (+0.1) in secondary text; the call's children 12 px below when open.
add(component(
    'TextExpandable',
    'A small heading that opens and closes what is under it (the call\'s children). Fires onToggle.',
    'box',
    props=[prop('title', STRING, 'Details', 'The heading.', required=True),
           prop('open', BOOL, False, 'Whether it starts open.')],
    events=[{'key': 'onToggle', 'payload': BOOL}],
    children='list',
    variables=[{'name': 'toggled', 'type': 'boolean', 'value': False}],
    previews=[preview('Closed', 200, 16, title='Advanced options')],
    nodes={
        'box': {'type': 'column', 'children': ['head', 'body'], 'props': {'crossAxisAlignment': 'stretch'},
                'layout': {'width': {'fill': 200}, 'height': {'hug': 16}}},
        'head': {'type': 'row', 'children': ['chevron', 'title'], 'props': {'crossAxisAlignment': 'center', 'spacing': 5},
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 16}},
                 'actions': [{'trigger': 'click', 'actions': [
                     {'type': 'setVariable', 'variable': 'toggled', 'value': '${= !toggled}'},
                     {'type': 'componentEvent', 'event': 'onToggle', 'value': '${= props.open != toggled}'}]}]},
        'chevron': {**icon('chevron_right', 'secondaryText', 13), 'bind': {'props.icon': "${= (props.open != toggled) ? 'expand_more' : 'chevron_right'}"}},
        'title': text('${props.title}', style(11.5, 600, 'secondaryText', 1.35, letterSpacing=0.1), {'hug': 100}, {'hug': 16}),
        'body': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 0}, 'padding': [0, 12, 0, 0]},
                 'bind': {'visible': '${= props.open != toggled}'}},
        'content': {'type': 'slot'},
    },
))

# StackedProgressBar (StackedProgressBar.tsx): what a whole is made of: an 8 px track (radius 4, a faint fill and
# hairline) holding a segment per part in its color, as wide as its count out of the total, then the percent
# 13/600, 12 px after the track, in the color of how far it is (error under 25, warning under 50, brand under 90,
# success from there).
add(component(
    'StackedProgressBar',
    'Progress made of parts: a bar with a colored segment per part, as wide as its count of the total, and the percent done.',
    'bar',
    props=[prop('counts', {'kind': 'list', 'flutter': 'List<double>', 'item': NUMBER}, [6, 3, 1], 'How many in each part (up to six parts).', required=True),
           prop('colors', STRINGS, ['#FF16A34A', '#FF2563EB', '#FFDC2626'], 'A color for each part (same order).', required=True),
           prop('total', NUMBER, 20, 'The whole (what is not in a part is the empty track).', required=True),
           prop('showPercent', BOOL, True, 'The percent done after the bar.')],
    previews=[preview('Half', 260, 18, counts=[6, 3, 1], colors=['#FF16A34A', '#FF2563EB', '#FFDC2626'], total=20)],
    nodes={
        'bar': {'type': 'row', 'children': ['track', 'percent'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                'layout': {'width': {'fill': 260}, 'height': {'hug': 18}}},
        'track': {'type': 'row', 'children': [*['seg%d' % i for i in range(6)], 'rest'], 'layout': {'width': {'fill': 200}, 'height': 8},
                  'decoration': {'fills': [{'color': 'hoverOverlay'}], 'strokes': [{'color': 'secondaryBorder'}], 'strokeWidth': 0.5,
                                 'radius': 4, 'clip': 'antiAlias'}},
        # Up to six parts, each as wide as its count (a row shares its width by flex; a list cannot).
        **{'seg%d' % i: {'type': 'box', 'layout': {'width': {'fill': 30}, 'height': {'fill': 8}, 'flex': 1},
                         'decoration': {'fills': [{'color': 'primary'}], 'radius': 4},
                         'bind': {'visible': '${= length(props.counts) > %d && props.counts[%d] > 0}' % (i, i),
                                  'layout.flex': '${= length(props.counts) > %d ? max(1, round(props.counts[%d] * 1000 / max(1, props.total))) : 1}' % (i, i),
                                  'decoration.fills[0].color': '${= length(props.colors) > %d ? props.colors[%d] : theme.primary}' % (i, i)}}
           for i in range(6)},
        'rest': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': {'fill': 8}, 'flex': 500},
                 'bind': {'layout.flex': '${= max(1, round((props.total - sum(props.counts)) * 1000 / max(1, props.total)))}',
                          'visible': '${= sum(props.counts) < props.total}'}},
        'percent': {**text('${= round(sum(props.counts) / max(1, props.total) * 100)}%', style(13, 600, 'primary', 1.3), {'hug': 34}, {'hug': 17}),
                    'bind': {'visible': '${props.showPercent}',
                             'props.style.color': "${= sum(props.counts) / max(1, props.total) >= 0.9 ? theme.success : (sum(props.counts) / max(1, props.total) >= 0.5 ? theme.primary : (sum(props.counts) / max(1, props.total) >= 0.25 ? theme.warning : theme.error))}"}},
    },
))

# --- batch 13: tab toggle and chip tabs --------------------------------------------------------------------------

# TabToggle (TabToggle.tsx): a pill track with one raised pill for the choice: the track in the subtle fill with
# a hairline, radius 6 / 8 / 10 and 2 / 2 / 3 px inside; each option padded 5 x 10, 7 x 14 or 9 x 18 at 12.5,
# 13.5 or 14.5; the chosen one on the raised background with radius 4 / 6 / 7 and the low shadow, 500 in primary
# text, the others 400 in tertiary text (secondary on hover).
TT = ['sm', 'md', 'lg']
add(component(
    'TabToggle',
    'A choice between a few views as a pill track: the chosen one raised. The choice is kept in your variable. Fires onChanged.',
    'track',
    props=[prop('options', STRINGS, ['List', 'Grid'], 'The choices.', required=True),
           prop('value', var(STRING), '', 'The name of your text variable holding the choice.'),
           prop('size', enum(*TT), 'md', 'sm, md or lg.')],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Two', 160, 32, options=['List', 'Grid'], value='List')],
    nodes={
        'track': {'type': 'row', 'children': ['list'], 'props': {'crossAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 160}, 'height': {'hug': 32}, 'padding': 3},
                  'decoration': {'fills': [{'color': 'subtleFill'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8},
                  'bind': {'layout.padding': by('size', {'sm': 3, 'md': 3, 'lg': 4}),
                           'decoration.radius': by('size', {'sm': 6, 'md': 8, 'lg': 10})}},
        'list': {'type': 'listView', 'children': ['option'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False},
                 'layout': {'width': {'hug': 150}, 'height': 30},
                 'bind': {'data': '${props.options}', 'layout.height': by('size', {'sm': 25, 'md': 30, 'lg': 36})}},
        'option': {'type': 'row', 'children': ['label'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                   'layout': {'width': {'hug': 60}, 'height': {'fill': 30}, 'padding': [14, 0, 14, 0]},
                   'decoration': {'fills': [{'color': '#00000000'}], 'radius': 6},
                   'bind': {'selected': '${= item == props.value}',
                            'layout.padding': by('size', {'sm': [10, 0, 10, 0], 'md': [14, 0, 14, 0], 'lg': [18, 0, 18, 0]}),
                            'decoration.radius': by('size', {'sm': 4, 'md': 6, 'lg': 7})},
                   'states': {
                       'selected': {'option': {'decoration': {'fills': [{'color': 'raisedBackground'}], 'effects': SHADOWS_LIGHT['level1']}},
                                    'label': {'props': {'style': {'color': 'primaryText', 'fontWeight': 500}}}},
                       'hovered': {'label': {'props': {'style': {'color': 'secondaryText'}}}},
                   },
                   'actions': [{'trigger': 'click', 'actions': [
                       {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                       {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'label': {**text('${item}', style(13.5, 400, 'tertiaryText', 1.2), {'hug': 40}, {'hug': 16}),
                  'bind': {'props.style.fontSize': by('size', {'sm': 12.5, 'md': 13.5, 'lg': 14.5})}},
    },
))

# ChipTabs (ChipTabs.tsx): open documents as a row of 24 px pills, 5 px apart: each bordered, on the secondary
# background (the raised one when chosen, with the brand border and a 2 px soft ring), 8 px either side, the
# label 10.5/500 (secondary text; primary when chosen); an optional 18 px round add button at the end.
add(component(
    'ChipTabs',
    'Open items as a row of small pills, the chosen one outlined; an optional add button. Fires onSelected with the label and onAdd.',
    'row',
    props=[prop('tabs', STRINGS, ['Draft', 'Review', 'Final'], 'The pills\' labels.', required=True),
           prop('value', var(STRING), '', 'The name of your text variable holding the chosen label.'),
           prop('showAdd', BOOL, False, 'A round + after the pills.')],
    events=[{'key': 'onSelected', 'payload': STRING}, 'onAdd'],
    previews=[preview('Three', 220, 24, tabs=['Draft', 'Review', 'Final'], value='Review', showAdd=True)],
    nodes={
        'row': {'type': 'row', 'children': ['list', 'add'], 'props': {'crossAxisAlignment': 'center', 'spacing': 5},
                'layout': {'width': {'hug': 220}, 'height': {'hug': 28}}},
        'list': {'type': 'listView', 'children': ['chip'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': 5},
                 'layout': {'width': {'hug': 180}, 'height': 28, 'padding': 2}, 'bind': {'data': '${props.tabs}'}},
        'chip': {'type': 'row', 'children': ['label'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                 'layout': {'width': {'hug': 50}, 'height': {'fill': 24}, 'padding': [8, 0, 8, 0]},
                 'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 9999,
                                'effects': [{'type': 'dropShadow', 'color': 'primaryTint', 'offset': [0, 0], 'blurRadius': 0, 'spreadRadius': 2,
                                             'visible': False}]},
                 'bind': {'selected': '${= item == props.value}'},
                 'states': {
                     'selected': {'chip': {'decoration': {'fills': [{'color': 'raisedBackground'}], 'strokes': [{'color': 'primary'}],
                                                         'effects': [{'type': 'dropShadow', 'color': 'primaryTint', 'offset': [0, 0],
                                                                      'blurRadius': 0, 'spreadRadius': 2}]}},
                                  'label': {'props': {'style': {'color': 'primaryText'}}}},
                     'hovered': {'chip': HOVER},
                 },
                 'actions': [{'trigger': 'click', 'actions': [
                     {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                     {'type': 'componentEvent', 'event': 'onSelected', 'value': '${item}'}]}]},
        'label': text('${item}', style(10.5, 500, 'secondaryText', 1.2), {'hug': 34}, {'hug': 13}),
        'add': {'type': 'row', 'children': ['plus'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                'layout': {'width': 18, 'height': 18}, 'decoration': {'radius': 9999},
                'bind': {'visible': '${props.showAdd}'},
                'states': {'hovered': {'add': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}, 'plus': {'props': {'color': 'primaryText'}}}},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onAdd'}]}]},
        'plus': icon('add', 'tertiaryText', 12),
    },
))


# MenuButton (MenuButton.tsx): the ghost IconButton with the menu glyph.
add(component(
    'MenuButton',
    'A menu (hamburger) button. Fires onPressed.',
    'button',
    props=[prop('size', enum(*SIZES), 'medium', 'xs, compact, small, medium or large.'),
           prop('enabled', BOOL, True, 'False dims it and stops presses.')],
    events=['onPressed'],
    previews=[preview('Default', 36, 36)],
    nodes={
        'button': {'type': 'IconButton', 'props': {'icon': 'menu', 'variant': 'ghost'}, 'layout': {'width': {'hug': 36}, 'height': {'hug': 36}},
                   'bind': {'props.size': '${props.size}', 'props.enabled': '${props.enabled}'},
                   'tooltip': 'Open menu',
                   'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'onPressed'}]}]},
    },
))

# SplitButton (SplitButton.tsx): two halves in one bordered shell (small 22 px radius 5, medium 28 radius 7,
# large 32 radius 8): the action (an icon and a label 11/500, 8 px either side; small is the icon alone, 5 px
# around) and, past a 1 px seam, the trigger (a chevron). Neutral: the raised background and the strong border;
# primary: the brand color with a light seam and white ink. Busy turns the icon into a spinner and dims both.
SPLIT = ['small', 'medium', 'large']
SPLIT_INK = "${= props.tone == 'primary' ? theme.colors.onAccent : theme.colors.primaryText}"
add(component(
    'SplitButton',
    'An action with a second half that opens its choices. Fires onPressed (the action) and onMenu (the chevron).',
    'shell',
    props=[prop('label', STRING, 'Run', 'The action\'s label (small shows the icon alone).'),
           prop('icon', STRING, 'play_arrow', 'The action\'s icon (empty: none).'),
           prop('size', enum(*SPLIT), 'medium', 'small (22), medium (28) or large (32).'),
           prop('tone', enum('neutral', 'primary'), 'neutral', 'neutral: bordered. primary: filled with the brand color.'),
           prop('busy', BOOL, False, 'A spinner for the icon; both halves stop.'),
           prop('enabled', BOOL, True, 'False dims it and stops presses.')],
    events=['onPressed', 'onMenu'],
    previews=[preview('Neutral', 96, 28, label='Run'), preview('Primary', 120, 28, label='Generate', tone='primary')],
    nodes={
        'shell': {'type': 'row', 'children': ['main', 'seam', 'trigger'], 'props': {'crossAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 96}, 'height': {'hug': 28}, 'padding': 1},
                  'decoration': {'fills': [{'color': 'raisedBackground'}], 'strokes': [{'color': 'secondaryBorder'}], 'radius': 7, 'clip': 'antiAlias'},
                  'bind': {'decoration.radius': by('size', {'small': 5, 'medium': 7, 'large': 8}),
                           'decoration.fills[0].color': "${= props.tone == 'primary' ? theme.primary : theme.colors.raisedBackground}",
                           'decoration.strokes[0].color': "${= props.tone == 'primary' ? theme.primary : theme.colors.secondaryBorder}",
                           'opacity': '${= props.enabled && !props.busy ? 1 : 0.55}'}},
        'main': {'type': 'row', 'children': ['spin', 'glyph', 'label'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center', 'spacing': 6},
                 'layout': {'width': {'hug': 60}, 'height': 26, 'padding': [8, 0, 8, 0]},
                 'bind': {'layout.height': by('size', {'small': 20, 'medium': 26, 'large': 30}),
                          'layout.padding': by('size', {'small': [5, 0, 5, 0], 'medium': [8, 0, 8, 0], 'large': [8, 0, 8, 0]})},
                 'states': {'hovered': {'main': HOVER}, 'pressed': {'main': PRESS}},
                 'actions': [click('onPressed', 'props.enabled && !props.busy')]},
        'spin': {'type': 'activityIndicator', 'layout': {'width': 12, 'height': 12}, 'props': {'color': 'primaryText'},
                 'bind': {'visible': '${props.busy}', 'props.color': SPLIT_INK}},
        'glyph': {**icon('play_arrow', 'primaryText', 12),
                  'bind': {'visible': "${= props.icon != '' && !props.busy}", 'props.icon': '${props.icon}', 'props.color': SPLIT_INK}},
        'label': {**text('${props.label}', style(11, 500, 'primaryText', 1.1), {'hug': 30}, {'hug': 13}),
                  'bind': {'visible': "${= props.label != '' && props.size != 'small'}", 'props.style.color': SPLIT_INK,
                           'props.style.fontSize': by('size', {'small': 11, 'medium': 11, 'large': 12})}},
        'seam': {'type': 'box', 'layout': {'width': 1, 'height': 26}, 'decoration': {'fills': [{'color': 'secondaryBorder'}]},
                 'bind': {'layout.height': by('size', {'small': 20, 'medium': 26, 'large': 30}),
                          'decoration.fills[0].color': "${= props.tone == 'primary' ? '#4DFFFFFF' : theme.colors.secondaryBorder}"}},
        'trigger': {'type': 'row', 'children': ['chevron'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                    'layout': {'width': 26, 'height': 26},
                    'bind': {'layout.width': by('size', {'small': 20, 'medium': 26, 'large': 30}), 'layout.height': by('size', {'small': 20, 'medium': 26, 'large': 30})},
                    'states': {'hovered': {'trigger': HOVER}, 'pressed': {'trigger': PRESS}},
                    'actions': [click('onMenu', 'props.enabled && !props.busy')]},
        'chevron': {**icon('expand_more', 'primaryText', 12), 'bind': {'props.color': SPLIT_INK}},
    },
))

# WindowToolbar (WindowToolbar.tsx): a 28 px bar on the secondary background over a hairline, 7 px either
# side, 6 px apart: a 13 px icon in tertiary, the title 11.5/500 on one line, then what trails at the end.
add(component(
    'WindowToolbar',
    'The title bar of a document or a pane: an icon, a title and what the call puts at its end. Fires onTitle when the title is pressed.',
    'bar',
    props=[prop('title', STRING, 'Untitled', 'The title.', required=True),
           prop('icon', STRING, 'description', 'The icon before the title (empty: none).')],
    events=['onTitle'],
    slots=['actions'],
    previews=[preview('Default', 280, 28, title='Release notes')],
    nodes={
        'bar': {'type': 'row', 'children': ['strut', 'glyph', 'title', 'actions'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                'layout': {'width': {'fill': 280}, 'height': {'hug': 28}, 'padding': [7, 0, 7, 0]},
                'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'glyph': {**icon('description', 'tertiaryText', 13), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 27}},
        'title': {**text('${props.title}', style(11.5, 500, 'primaryText', 1.2), {'fill': 180}, {'hug': 14}),
                  'props': {'text': '${props.title}', 'style': style(11.5, 500, 'primaryText', 1.2), 'maxLines': 1, 'overflow': 'ellipsis'},
                  'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onTitle'}]}]},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
    },
))

# DocumentItem (DocumentItem.tsx): the compact document object: bordered, radius 5, a WindowToolbar over a
# content surface (the secondary background at 62 %, or white), padding 8 10 9, its entries 7 px apart; an
# optional description first, 10.5 on a 1.35 line in tertiary.
add(component(
    'DocumentItem',
    'A compact document object: a title bar over a content surface holding the call\'s children. Fires onOpen when the title is pressed.',
    'item',
    props=[prop('title', STRING, 'Document', 'The title in the bar.', required=True),
           prop('icon', STRING, 'description', 'The bar\'s icon (empty: none).'),
           prop('description', STRING, '', 'A muted line above the content.'),
           prop('surface', enum('gray', 'white'), 'gray', 'gray: the soft secondary surface. white: a white page.')],
    events=['onOpen'],
    slots=['actions'],
    children='list',
    previews=[preview('Default', 300, 90, title='Brief', description='Shared with the team')],
    nodes={
        'item': {'type': 'column', 'children': ['bar', 'body'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 300}, 'height': {'hug': 90}, 'padding': 1},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 5, 'clip': 'antiAlias'}},
        'bar': {'type': 'row', 'children': ['strut', 'glyph', 'title', 'actions'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                'layout': {'width': {'fill': 298}, 'height': {'hug': 28}, 'padding': [7, 0, 7, 0]},
                'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 27}},
        'glyph': {**icon('description', 'tertiaryText', 13), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'title': {**text('${props.title}', style(11.5, 500, 'primaryText', 1.2), {'fill': 180}, {'hug': 14}),
                  'props': {'text': '${props.title}', 'style': style(11.5, 500, 'primaryText', 1.2), 'maxLines': 1, 'overflow': 'ellipsis'},
                  'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onOpen'}]}]},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
        'body': {'type': 'column', 'children': ['description', 'content'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 7},
                 'layout': {'width': {'fill': 298}, 'height': {'hug': 40}, 'padding': [10, 8, 10, 9]},
                 'decoration': {'fills': [{'color': 'subtleFill'}]},
                 'bind': {'decoration.fills[0].color': "${= props.surface == 'white' ? theme.colors.primaryBackground : theme.colors.subtleFill}"}},
        'description': {**text('${props.description}', style(10.5, 400, 'tertiaryText', 1.35), {'fill': 280}, {'hug': 14}),
                        'bind': {'visible': "${= props.description != ''}"}},
        'content': {'type': 'slot'},
    },
))

# TextItem (TextItem.tsx with TextItem.css): a DocumentItem whose content is text: paragraphs 11.5 on a 1.45
# line in secondary, five lines at most; none: the empty line in tertiary italic. Its bar ends in the item's
# meta, 9.5 in tertiary: a status pill (radius 999, 2 x 6, weight 650; amber for pending or proposed, green
# for approved, confirmed or promoted, red for rejected) or a date, then a kind in monospace.
TI_AMBER = "(props.status == 'pending' || props.status == 'proposed')"
TI_GREEN = "(props.status == 'approved' || props.status == 'confirmed' || props.status == 'promoted')"
add(component(
    'TextItem',
    'A text object: a titled bar with a status or date over a preview of the text. Instructions, notes, learnings. Fires onOpen.',
    'item',
    props=[prop('title', STRING, 'Note', 'The title in the bar.', required=True),
           prop('value', STRING, '', 'The text shown (five lines at most).'),
           prop('description', STRING, '', 'A muted context line above the text.'),
           prop('status', STRING, '', 'A status pill in the bar: pending, proposed, approved, confirmed, promoted, rejected or your own.'),
           prop('date', STRING, '', 'A date in the bar, shown in place of the status.'),
           prop('kind', STRING, '', 'A kind after it, in monospace.'),
           prop('emptyLabel', STRING, 'No text captured yet.', 'Shown when there is no text.')],
    events=['onOpen'],
    previews=[preview('Pending', 320, 96, title='Tone of voice', value='Write plainly. Lead with the answer, then the reasons.', status='pending', kind='rule'),
              preview('Empty', 320, 70, title='Blockers', date='Nov 14')],
    nodes={
        'item': {'type': 'DocumentItem', 'props': {'title': 'Note'}, 'layout': {'width': {'fill': 320}, 'height': {'hug': 96}},
                 'children': ['value', 'empty'], 'slots': {'actions': 'meta'},
                 'bind': {'props.title': '${props.title}', 'props.description': '${props.description}'},
                 'actions': [{'trigger': {'type': 'event', 'event': 'onOpen'}, 'actions': [{'type': 'componentEvent', 'event': 'onOpen'}]}]},
        'meta': {'type': 'row', 'children': ['date', 'pill', 'dot', 'kind'], 'props': {'crossAxisAlignment': 'center', 'spacing': 5},
                 'layout': {'width': {'hug': 80}, 'height': {'hug': 16}}},
        'date': {**text('${props.date}', style(9.5, 400, 'tertiaryText', 1.2), {'hug': 40}, {'hug': 12}),
                 'bind': {'visible': "${= props.date != ''}"}},
        'pill': {'type': 'row', 'children': ['status'], 'props': {'crossAxisAlignment': 'center'},
                 'layout': {'width': {'hug': 40}, 'height': {'hug': 16}, 'padding': [6, 2, 6, 2]},
                 'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 9999},
                 'bind': {'visible': "${= props.status != '' && props.date == ''}",
                          'decoration.fills[0].color': "${= %s ? theme.colors.warningTint : (%s ? theme.colors.successTint : (props.status == 'rejected' ? theme.colors.errorTint : theme.colors.tertiaryBackground))}" % (TI_AMBER, TI_GREEN)}},
        'status': {**text('${= titleCase(props.status)}', style(9.5, 600, 'secondaryText', 1.2), {'hug': 30}, {'hug': 12}),
                   'bind': {'props.style.color': "${= %s ? theme.warning : (%s ? theme.success : (props.status == 'rejected' ? theme.error : theme.colors.secondaryText))}" % (TI_AMBER, TI_GREEN)}},
        'dot': {**text('·', style(9.5, 400, 'secondaryBorder', 1.2), {'hug': 4}, {'hug': 12}),
                'bind': {'visible': "${= props.kind != '' && (props.date != '' || props.status != '')}"}},
        'kind': {**text('${props.kind}', style(9.5, 400, 'tertiaryText', 1.2, fontFamily='monospace'), {'hug': 24}, {'hug': 12}),
                 'bind': {'visible': "${= props.kind != ''}"}},
        'value': {**text('${props.value}', style(11.5, 400, 'secondaryText', 1.45), {'fill': 300}, {'hug': 17}),
                  'props': {'text': '${props.value}', 'style': style(11.5, 400, 'secondaryText', 1.45), 'maxLines': 5, 'overflow': 'ellipsis'},
                  'bind': {'visible': "${= props.value != ''}"}},
        'empty': {**text('${props.emptyLabel}', {**style(11.5, 400, 'tertiaryText', 1.45), 'fontStyle': 'italic'}, {'fill': 300}, {'hug': 17}),
                  'bind': {'visible': "${= props.value == ''}"}},
    },
))

# CodeBlock (CodeBlock.tsx): code in a bordered box, radius 12: a header on the secondary background over a
# hairline (padding 12 x 16: a 16 px code icon, 12 px, the title 14/600, a language tag 12/500 on a 4 px
# radius chip padded 4 x 8; at the end a copy button), then the code in monospace 14 on a 24 px line,
# padding 16. Embedded (the body of a card around it): no border or header, 11.5 on a 19 px line, padding 10 x 12.
add(component(
    'CodeBlock',
    'Code in monospace with a header: a title, a language tag and a copy button. Embedded drops the frame. Fires onCopy.',
    'block',
    props=[prop('code', STRING, '', 'The code.', required=True),
           prop('title', STRING, '', 'A title in the header.'),
           prop('language', STRING, '', 'A language tag in the header (empty: none).'),
           prop('copyable', BOOL, True, 'A copy button in the header.'),
           prop('embedded', BOOL, False, 'The body of a card around it: no border, no header, smaller type.')],
    events=['onCopy'],
    previews=[preview('Titled', 360, 130, code='const total = items\n  .map((i) => i.price)\n  .reduce((a, b) => a + b, 0);', title='total.ts', language='ts'),
              preview('Embedded', 300, 60, code='npm install\nnpm run build', embedded=True)],
    nodes={
        'block': {'type': 'column', 'children': ['header', 'body'], 'props': {'crossAxisAlignment': 'stretch'},
                  'layout': {'width': {'fill': 360}, 'height': {'hug': 130}, 'padding': 1},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12, 'clip': 'antiAlias'},
                  'bind': {'decoration.strokes[0].visible': '${= !props.embedded}', 'decoration.radius': '${= props.embedded ? 0 : 12}',
                           'layout.padding': '${= props.embedded ? 0 : 1}'}},
        'header': {'type': 'row', 'children': ['glyph', 'title', 'tag', 'gap', 'copy'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                   'layout': {'width': {'fill': 358}, 'height': {'hug': 52}, 'padding': [16, 12, 16, 12]},
                   'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'},
                   'bind': {'visible': '${= !props.embedded}'}},
        'glyph': icon('code', 'secondaryText', 16),
        'title': {**text('${props.title}', style(14, 600, 'primaryText', 1.3), {'hug': 60}, {'hug': 18}),
                  'bind': {'visible': "${= props.title != ''}"}},
        'tag': {'type': 'row', 'children': ['language'], 'props': {'crossAxisAlignment': 'center'},
                'layout': {'width': {'hug': 30}, 'height': {'hug': 24}, 'padding': [8, 4, 8, 4]},
                'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 4},
                'bind': {'visible': "${= props.language != ''}"}},
        'language': text('${props.language}', style(12, 500, 'secondaryText', 1.3), {'hug': 20}, {'hug': 16}),
        'gap': {'type': 'box', 'layout': {'width': {'fill': 20}, 'height': 1}},
        'copy': {'type': 'CopyButton', 'props': {'text': ''}, 'layout': {'width': {'hug': 28}, 'height': 28},
                 'bind': {'props.text': '${props.code}', 'visible': '${props.copyable}'},
                 'actions': [{'trigger': {'type': 'event', 'event': 'onCopy'}, 'actions': [{'type': 'componentEvent', 'event': 'onCopy', 'value': '${props.code}'}]}]},
        'body': {'type': 'row', 'children': ['code'], 'props': {'crossAxisAlignment': 'start', 'scrollable': True},
                 'layout': {'width': {'fill': 358}, 'height': {'hug': 60}, 'padding': 16},
                 'decoration': {'fills': [{'color': 'secondaryBackground'}]},
                 'bind': {'layout.padding': '${= props.embedded ? [12, 10, 12, 10] : [16, 16, 16, 16]}',
                          'decoration.fills[0].color': '${= props.embedded ? theme.colors.primaryBackground : theme.colors.secondaryBackground}'}},
        'code': {**text('${props.code}', style(14, 400, 'primaryText', 24 / 14, fontFamily='monospace'), {'hug': 200}, {'hug': 24}),
                 'bind': {'props.style.fontSize': '${= props.embedded ? 11.5 : 14}', 'props.style.height': '${= props.embedded ? 1.652 : 1.714}'}},
    },
))

# BatchProgressBar (BatchProgressBar.tsx): one running operation as a row over a hairline on the secondary
# background, padding 8 x 10: a 13 px status icon, 6 px, the label 11/500 (the operation while it uploads,
# else Queued, Complete, Failed or Cancelled), then done/total 10 in tertiary with "(n failed)" in red; 6 px
# under it a 4 px pill track filled to the share done (blue, green when complete, red on an error, muted when
# cancelled) and, while it uploads, a 16 px round cancel button.
BATCH = ['pending', 'uploading', 'complete', 'error', 'cancelled']
BATCH_INK = "${= props.status == 'complete' ? '#FF22C55E' : (props.status == 'error' ? '#FFEF4444' : (props.status == 'uploading' ? '#FF3B82F6' : theme.colors.tertiaryText))}"
add(component(
    'BatchProgressBar',
    'One operation over many items: its state, how many are done, a thin bar and a cancel button while it runs. Stack one per operation. Fires onCancel.',
    'item',
    props=[prop('operation', STRING, 'Uploading', 'What is running, shown while it does.', required=True),
           prop('status', enum(*BATCH), 'uploading', 'pending, uploading, complete, error or cancelled.'),
           prop('completed', NUMBER, 0, 'How many are done.'),
           prop('total', NUMBER, 0, 'How many there are.'),
           prop('failed', NUMBER, 0, 'How many failed (0: not shown).'),
           prop('cancellable', BOOL, True, 'A cancel button while it uploads.')],
    events=['onCancel'],
    previews=[preview('Uploading', 280, 44, operation='Uploading images', completed=7, total=12),
              preview('Failed', 280, 44, operation='Processing', status='error', completed=2, total=8, failed=3)],
    nodes={
        'item': {'type': 'column', 'children': ['top', 'bottom'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 6},
                 'layout': {'width': {'fill': 280}, 'height': {'hug': 44}, 'padding': [10, 8, 10, 8]},
                 'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'top'}},
        'top': {'type': 'row', 'children': ['glyph', 'label', 'count', 'failed'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                'layout': {'width': {'fill': 260}, 'height': {'hug': 14}}},
        'glyph': {**icon('upload', 'primary', 13),
                  'bind': {'props.color': BATCH_INK,
                           'props.icon': "${= props.status == 'uploading' ? 'upload' : (props.status == 'pending' ? 'schedule' : (props.status == 'complete' ? 'check_circle' : 'cancel'))}"}},
        'label': text("${= props.status == 'uploading' ? props.operation : (props.status == 'pending' ? 'Queued' : (props.status == 'complete' ? 'Complete' : (props.status == 'error' ? 'Failed' : 'Cancelled')))}",
                      style(11, 500, 'primaryText', 1.25), {'fill': 160}, {'hug': 14}),
        'count': text('${props.completed}/${props.total}', style(10, 400, 'tertiaryText', 1.3), {'hug': 24}, {'hug': 13}),
        'failed': {**text('(${props.failed} failed)', style(10, 400, 'error', 1.3), {'hug': 40}, {'hug': 13}),
                   'bind': {'visible': '${= props.failed > 0}'}},
        'bottom': {'type': 'row', 'children': ['track', 'cancel'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'fill': 260}, 'height': {'hug': 16}}},
        'track': {'type': 'row', 'children': ['fill', 'rest'], 'layout': {'width': {'fill': 240}, 'height': 4},
                  'decoration': {'fills': [{'color': 'hoverOverlay'}], 'radius': 9999, 'clip': 'antiAlias'}},
        'fill': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': {'fill': 4}, 'flex': 1},
                 'decoration': {'fills': [{'color': 'primary'}], 'radius': 9999},
                 'bind': {'visible': '${= props.completed > 0 && props.total > 0}',
                          'layout.flex': '${= max(1, round(min(props.completed, props.total) * 1000 / max(1, props.total)))}',
                          'decoration.fills[0].color': BATCH_INK}},
        'rest': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': {'fill': 4}, 'flex': 1},
                 'bind': {'visible': '${= props.completed < props.total || props.total <= 0}',
                          'layout.flex': '${= max(1, round((props.total - min(props.completed, props.total)) * 1000 / max(1, props.total)))}'}},
        'cancel': {'type': 'row', 'children': ['x'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                   'layout': {'width': 16, 'height': 16}, 'decoration': {'fills': [{'color': 'hoverOverlay'}], 'radius': 9999},
                   'bind': {'visible': "${= props.status == 'uploading' && props.cancellable}"},
                   'tooltip': 'Cancel',
                   'states': {'hovered': {'cancel': {'decoration': {'fills': [{'color': 'pressedOverlay'}]}}, 'x': {'props': {'color': 'primaryText'}}}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onCancel'}]}]},
        'x': icon('close', 'tertiaryText', 9),
    },
))

# AgentChip (AgentChip.tsx): a running helper as a small bordered pill, radius 6, 2 x 8, its parts 4 px apart,
# 11 in secondary: an 11 px status icon (a turning arc in the brand color while running, a green check when
# done, an x on an error; idle: a bot), the label on one line (220 px at most), and an x to dismiss it
# (tertiary at 60 %, full on hover).
add(component(
    'AgentChip',
    'A helper at work as a small pill: its state, its name and an x to dismiss it. Fires onPressed and onDismiss.',
    'chip',
    props=[prop('label', STRING, 'Agent', 'Its name.', required=True),
           prop('status', enum('idle', 'running', 'done', 'error'), 'idle', 'idle, running, done or error.'),
           prop('dismissible', BOOL, False, 'An x after the label.'),
           prop('emphasized', BOOL, False, 'The label in the primary text color.')],
    events=['onPressed', 'onDismiss'],
    previews=[preview('Running', 120, 22, label='Researcher', status='running', dismissible=True),
              preview('Done', 100, 22, label='Reviewer', status='done')],
    nodes={
        'chip': {'type': 'row', 'children': ['spin', 'glyph', 'label', 'dismiss'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                 'layout': {'width': {'hug': 100}, 'height': {'hug': 22}, 'padding': [8, 2, 8, 2]},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 6},
                 'states': {'hovered': {'chip': HOVER}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed'}]}]},
        'spin': {'type': 'circularProgressIndicator', 'layout': {'width': 11, 'height': 11}, 'props': {'color': 'primary', 'strokeWidth': 1.5},
                 'bind': {'visible': "${= props.status == 'running'}"}},
        'glyph': {**icon('smart_toy', 'tertiaryText', 11),
                  'bind': {'visible': "${= props.status != 'running'}",
                           'props.icon': "${= props.status == 'done' ? 'check_circle' : (props.status == 'error' ? 'close' : 'smart_toy')}",
                           'props.color': "${= props.status == 'done' ? theme.success : (props.status == 'error' ? theme.error : theme.colors.tertiaryText)}"}},
        'label': {**text('${props.label}', style(11, 400, 'secondaryText', 1.5), {'hug': 60}, {'hug': 17}),
                  'props': {'text': '${props.label}', 'style': style(11, 400, 'secondaryText', 1.5), 'maxLines': 1, 'overflow': 'ellipsis'},
                  'layout': {'width': {'hug': 60}, 'height': {'hug': 17}, 'constraints': {'maxWidth': 220}},
                  'bind': {'props.style.color': '${= props.emphasized ? theme.colors.primaryText : theme.colors.secondaryText}',
                           'props.style.fontWeight': '${= props.emphasized ? 500 : 400}'}},
        'dismiss': {'type': 'row', 'children': ['x'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                    'layout': {'width': 15, 'height': 15, 'margin': [2, 0, 0, 0]}, 'decoration': {'radius': 4}, 'opacity': 0.6,
                    'bind': {'visible': '${props.dismissible}'},
                    'tooltip': 'Dismiss',
                    'states': {'hovered': {'dismiss': {'opacity': 1, 'decoration': {'fills': [{'color': 'pressedOverlay'}]}}}},
                    'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onDismiss'}]}]},
        'x': icon('close', 'tertiaryText', 11),
    },
))

# SelectableListRow (SelectableListRow.tsx): a row of a master list over a hairline, padding 9 12 10, 9 px
# between what leads and the text: the title 12.5/600 on an 18 px line with what trails 10.5 in tertiary at
# its end, 2 px under it a subtitle 11 on a 16 px line in secondary (monospace 10.5), then the call's meta
# 4 px under. Hovered: the hover wash; selected: the brand tint.
add(component(
    'SelectableListRow',
    'A row of a list you pick from: a title, a subtitle, a note at the end, selected or not. The call\'s children go under the text. Fires onSelected.',
    'row',
    props=[prop('title', STRING, 'Item', 'The title.', required=True),
           prop('subtitle', STRING, '', 'A line under it.'),
           prop('subtitleMono', BOOL, False, 'The subtitle in monospace (a path, an id).'),
           prop('trailing', STRING, '', 'A short note at the end of the title\'s line (a time, a count).'),
           prop('selected', BOOL, False, 'Tinted as the chosen row.')],
    events=['onSelected'],
    slots=['leading'],
    children='list',
    previews=[preview('Selected', 300, 54, title='Weekly digest', subtitle='Runs every Monday at 9', trailing='2h ago', selected=True),
              preview('Plain', 300, 54, title='Nightly export', subtitle='jobs/export.yaml', subtitleMono=True)],
    nodes={
        'row': {'type': 'row', 'children': ['leading', 'texts'], 'props': {'crossAxisAlignment': 'start', 'spacing': 9},
                'layout': {'width': {'fill': 300}, 'height': {'hug': 54}, 'padding': [12, 9, 12, 10]},
                'decoration': {'fills': [{'color': '#00000000'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'},
                'bind': {'selected': '${props.selected}'},
                'states': {'hovered': {'row': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}},
                           'selected': {'row': {'decoration': {'fills': [{'color': 'primaryTint'}]}}}},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onSelected'}]}]},
        'leading': {'type': 'slot', 'props': {'name': 'leading'}},
        'texts': {'type': 'column', 'children': ['line', 'subtitle', 'meta'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 2},
                  'layout': {'width': {'fill': 240}, 'height': {'hug': 36}}},
        'line': {'type': 'row', 'children': ['title', 'trailing'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                 'layout': {'width': {'fill': 240}, 'height': {'hug': 18}}},
        'title': {**text('${props.title}', style(12.5, 600, 'primaryText', 18 / 12.5), {'fill': 180}, {'hug': 18}),
                  'props': {'text': '${props.title}', 'style': style(12.5, 600, 'primaryText', 18 / 12.5), 'maxLines': 1, 'overflow': 'ellipsis'}},
        'trailing': {**text('${props.trailing}', style(10.5, 400, 'tertiaryText', 1.3), {'hug': 40}, {'hug': 14}),
                     'bind': {'visible': "${= props.trailing != ''}"}},
        'subtitle': {**text('${props.subtitle}', style(11, 400, 'secondaryText', 16 / 11), {'fill': 240}, {'hug': 16}),
                     'props': {'text': '${props.subtitle}', 'style': style(11, 400, 'secondaryText', 16 / 11), 'maxLines': 1, 'overflow': 'ellipsis'},
                     'bind': {'visible': "${= props.subtitle != ''}",
                              'props.style.fontFamily': "${= props.subtitleMono ? 'monospace' : theme.fontFamily}",
                              'props.style.fontSize': '${= props.subtitleMono ? 10.5 : 11}'}},
        'meta': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'start', 'spacing': 4},
                 'layout': {'width': {'fill': 240}, 'height': {'hug': 0}, 'padding': [0, 2, 0, 0]}},
        'content': {'type': 'slot'},
    },
))

# ActionListItem (ActionListItem.tsx): something you can act on, as a bordered card, radius 5, a faint shadow:
# a 52 px preview column on the secondary background with a 17 px icon, past a hairline the title 13/650,
# 4 px under it a path in monospace 10.5 in tertiary, 6 px under that a meta line 10.5 in tertiary; what the
# call puts at its end (buttons) sits centered, 6 8 6 0. Disabled: 58 %.
add(component(
    'ActionListItem',
    'Something you can act on, as a card: an icon panel, a title, a path and a note, with the call\'s actions at its end. Fires onPressed.',
    'card',
    props=[prop('title', STRING, 'Action', 'The title.', required=True),
           prop('path', STRING, '', 'A path or id under it, in monospace.'),
           prop('meta', STRING, '', 'A muted note under that.'),
           prop('icon', STRING, 'bolt', 'The icon in the panel.'),
           prop('enabled', BOOL, True, 'False dims it.')],
    events=['onPressed'],
    slots=['actions'],
    previews=[preview('Default', 340, 66, title='Summarize new tickets', path='automations/summarize.yaml', meta='Last run 2h ago')],
    nodes={
        'card': {'type': 'row', 'children': ['panel', 'texts', 'tail'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 8},
                 'layout': {'width': {'fill': 340}, 'height': {'hug': 66}, 'padding': 1},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 5, 'clip': 'antiAlias',
                                'effects': [shadow('#0A0F172A', 1, 2)]},
                 'bind': {'opacity': '${= props.enabled ? 1 : 0.58}'},
                 'actions': [click('onPressed')]},
        'panel': {'type': 'row', 'children': ['glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 52, 'height': {'hug': 40}, 'constraints': {'minHeight': 40}},
                  'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'right'}},
        'glyph': {**icon('bolt', 'primaryText', 17), 'bind': {'props.icon': '${props.icon}'}},
        'texts': {'type': 'column', 'children': ['title', 'path', 'meta'], 'props': {'crossAxisAlignment': 'stretch', 'mainAxisAlignment': 'center'},
                  'layout': {'width': {'fill': 200}, 'height': {'hug': 50}, 'padding': [0, 7, 0, 7]}},
        'title': {**text('${props.title}', style(13, 600, 'primaryText', 1.3), {'fill': 200}, {'hug': 17}),
                  'props': {'text': '${props.title}', 'style': style(13, 600, 'primaryText', 1.3), 'maxLines': 1, 'overflow': 'ellipsis'}},
        'path': {**text('${props.path}', style(10.5, 400, 'tertiaryText', 1.25, fontFamily='monospace'), {'fill': 200}, {'hug': 13}),
                 'props': {'text': '${props.path}', 'style': style(10.5, 400, 'tertiaryText', 1.25, fontFamily='monospace'), 'maxLines': 1, 'overflow': 'ellipsis'},
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 13}, 'margin': [0, 4, 0, 0]},
                 'bind': {'visible': "${= props.path != ''}"}},
        'meta': {**text('${props.meta}', style(10.5, 400, 'tertiaryText', 1.3), {'fill': 200}, {'hug': 14}),
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 14}, 'margin': [0, 6, 0, 0]},
                 'bind': {'visible': "${= props.meta != ''}"}},
        'tail': {'type': 'row', 'children': ['actions'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                 'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'padding': [0, 6, 8, 6]}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
    },
))

# FileMetadataCard (FileMetadataCard.tsx): what is known about a file as a two column grid, 8 px between rows
# and 10 between columns: a 92 px label 11/600 in tertiary, then its value 12 in primary (monospace 11.5); an
# optional amber callout under it (border #FDE68A, radius 6, on #FFFBEB, 7 x 8, 11.5 in #92400E).
add(component(
    'FileMetadataCard',
    'Facts about a file or a record as label and value rows, with an optional amber callout under them.',
    'card',
    props=[prop('labels', STRINGS, ['Path', 'Status', 'Updated'], 'The labels, one per row.', required=True),
           prop('values', STRINGS, ['docs/brief.md', 'Draft', 'Today'], 'The values, one per label.', required=True),
           prop('mono', BOOL, False, 'The values in monospace.'),
           prop('callout', STRING, '', 'A note in an amber box under the rows (empty: none).')],
    previews=[preview('Default', 300, 100, labels=['Path', 'Status', 'Updated'], values=['docs/brief.md', 'Draft', 'Today'],
                      callout='The template changed since this file was written.')],
    nodes={
        'card': {'type': 'column', 'children': ['rows', 'callout'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 10},
                 'layout': {'width': {'fill': 300}, 'height': {'hug': 100}}},
        'rows': {'type': 'listView', 'children': ['row'], 'props': {'scrollable': False, 'spacing': 8},
                 'layout': {'width': {'fill': 300}, 'height': {'hug': 60}}, 'bind': {'data': '${props.labels}'}},
        'row': {'type': 'row', 'children': ['label', 'value'], 'props': {'crossAxisAlignment': 'start', 'spacing': 10},
                'layout': {'width': {'fill': 300}, 'height': {'hug': 16}}},
        'label': text('${item}', style(11, 600, 'tertiaryText', 16 / 11), 92, {'hug': 16}),
        'value': {**text("${= length(props.values) > index ? props.values[index] : '—'}", style(12, 400, 'primaryText', 16 / 12), {'fill': 190}, {'hug': 16}),
                  'bind': {'props.style.fontFamily': "${= props.mono ? 'monospace' : theme.fontFamily}",
                           'props.style.fontSize': '${= props.mono ? 11.5 : 12}'}},
        'callout': {'type': 'row', 'children': ['note'], 'layout': {'width': {'fill': 300}, 'height': {'hug': 30}, 'padding': [8, 7, 8, 7]},
                    'decoration': {'fills': [{'color': 'warningTint'}], 'strokes': [{'color': 'warningTintBorder'}], 'radius': 6},
                    'bind': {'visible': "${= props.callout != ''}"}},
        'note': text('${props.callout}', style(11.5, 400, 'warning', 1.4), {'fill': 280}, {'hug': 16}),
    },
))

# RunRecordRow (RunRecordRow.tsx): one past run, padding 8 14 8 16: the title 12.5/600 (-0.2) with the time 10
# in secondary 8 px after it, under it the message 11.5 on a 1.4 line in secondary and the diff chips; at the
# end, 2 px down, a 16 px state: a turning arc in the brand color, a green check or a red x.
add(component(
    'RunRecordRow',
    'One past run in a history: what ran, when, a message, what it changed and how it ended.',
    'row',
    props=[prop('title', STRING, 'Run', 'What ran.', required=True),
           prop('timestamp', STRING, '', 'When, after the title.'),
           prop('message', STRING, '', 'A line under the title.'),
           prop('status', enum('running', 'success', 'error', 'none'), 'success', 'running, success, error or none.'),
           prop('created', NUMBER, 0, 'Files created.'), prop('modified', NUMBER, 0, 'Files modified.'),
           prop('deleted', NUMBER, 0, 'Files deleted.'),
           prop('divider', BOOL, False, 'A hairline over it (every row of a list but the first).')],
    previews=[preview('Success', 320, 56, title='Sync docs', timestamp='2h ago', message='Updated 3 pages from the handbook.', created=1, modified=3),
              preview('Running', 320, 34, title='Rebuild index', timestamp='now', status='running')],
    nodes={
        'row': {'type': 'row', 'children': ['texts', 'spin', 'state'], 'props': {'crossAxisAlignment': 'start', 'spacing': 4},
                'layout': {'width': {'fill': 320}, 'height': {'hug': 56}, 'padding': [16, 8, 14, 8]},
                'decoration': {'strokes': [{'color': 'primaryBorder', 'visible': False}], 'strokeSides': 'top'},
                'bind': {'decoration.strokes[0].visible': '${props.divider}'}},
        'texts': {'type': 'column', 'children': ['line', 'message', 'diff'], 'props': {'crossAxisAlignment': 'start', 'spacing': 3},
                  'layout': {'width': {'fill': 260}, 'height': {'hug': 40}}},
        'line': {'type': 'row', 'children': ['title', 'time'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                 'layout': {'width': {'fill': 260}, 'height': {'hug': 18}}},
        'title': {**text('${props.title}', style(12.5, 600, 'primaryText', 1.4, letterSpacing=-0.2), {'hug': 80}, {'hug': 18}),
                  'props': {'text': '${props.title}', 'style': style(12.5, 600, 'primaryText', 1.4, letterSpacing=-0.2), 'maxLines': 1, 'overflow': 'ellipsis'}},
        'time': {**text('${props.timestamp}', style(10, 400, 'secondaryText', 1.4), {'hug': 30}, {'hug': 14}),
                 'bind': {'visible': "${= props.timestamp != ''}"}},
        'message': {**text('${props.message}', style(11.5, 400, 'secondaryText', 1.4), {'fill': 260}, {'hug': 16}),
                    'bind': {'visible': "${= props.message != ''}"}},
        'diff': {'type': 'DiffStatsBadge', 'layout': {'width': {'hug': 80}, 'height': {'hug': 16}, 'margin': [0, 2, 0, 0]},
                 'bind': {'props.created': '${props.created}', 'props.modified': '${props.modified}', 'props.deleted': '${props.deleted}',
                          'visible': '${= props.created + props.modified + props.deleted > 0}'}},
        'spin': {'type': 'circularProgressIndicator', 'layout': {'width': 14, 'height': 14, 'margin': [0, 3, 1, 0]}, 'props': {'color': 'primary', 'strokeWidth': 2},
                 'bind': {'visible': "${= props.status == 'running'}"}},
        'state': {**icon('check_circle', 'success', 16), 'layout': {'width': 16, 'height': 16, 'margin': [0, 2, 0, 0]},
                  'bind': {'visible': "${= props.status == 'success' || props.status == 'error'}",
                           'props.icon': "${= props.status == 'error' ? 'cancel' : 'check_circle'}",
                           'props.color': "${= props.status == 'error' ? theme.error : theme.success}"}},
    },
))

# TrialBanner (TrialBanner.tsx, its compact bar): a trial running out, radius 8, padding 12, a 1 px tinted
# border: a 16 px icon, 8 px, the message 14/500, and at its end an upgrade button and an x. Blue while there
# is time; red when urgent.
add(component(
    'TrialBanner',
    'A bar telling how much of a trial is left, with an upgrade button and an x. Urgent turns it red. Fires onUpgrade and onDismiss.',
    'banner',
    props=[prop('message', STRING, '7 days left in your trial', 'What it says.'),
           prop('urgent', BOOL, False, 'Red: the trial is about to end or has.'),
           prop('actionLabel', STRING, 'Upgrade', 'The button\'s label (empty: no button).'),
           prop('dismissible', BOOL, True, 'An x at the end.')],
    events=['onUpgrade', 'onDismiss'],
    previews=[preview('Info', 380, 54), preview('Urgent', 380, 54, message='Your trial ends today', urgent=True)],
    nodes={
        'banner': {'type': 'row', 'children': ['glyph', 'message', 'action', 'dismiss'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 380}, 'height': {'hug': 54}, 'padding': 12},
                   'decoration': {'fills': [{'color': 'primaryTint'}], 'strokes': [{'color': 'primaryTintBorder'}], 'radius': 8},
                   'bind': {'decoration.fills[0].color': '${= props.urgent ? theme.colors.errorTint : theme.colors.primaryTint}',
                            'decoration.strokes[0].color': '${= props.urgent ? theme.colors.errorTintBorder : theme.colors.primaryTintBorder}'}},
        'glyph': {**icon('schedule', 'primary', 16),
                  'bind': {'props.icon': "${= props.urgent ? 'warning_amber' : 'schedule'}", 'props.color': '${= props.urgent ? theme.error : theme.primary}'}},
        'message': {**text('${props.message}', style(14, 500, 'primaryText', 1.4), {'fill': 200}, {'hug': 20}),
                    'bind': {'props.style.color': '${= props.urgent ? theme.error : theme.colors.primaryText}'}},
        'action': {'type': 'Button', 'props': {'label': 'Upgrade', 'size': 'small'}, 'layout': {'width': {'hug': 80}, 'height': {'hug': 32}},
                   'bind': {'props.label': '${props.actionLabel}', 'visible': "${= props.actionLabel != ''}",
                            'props.variant': "${= props.urgent ? 'destructive' : 'primary'}"},
                   'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'onUpgrade'}]}]},
        'dismiss': {'type': 'IconButton', 'props': {'icon': 'close', 'size': 'xs'}, 'layout': {'width': 24, 'height': 24},
                    'bind': {'visible': '${props.dismissible}'},
                    'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'onDismiss'}]}]},
    },
))

# AuthPromptBanner (AuthPromptBanner.tsx): an invitation to sign in, radius 12, padding 12, an 8 % tint of
# its accent with a 30 % border: a 36 px gradient plate, radius 10, with an 18 px white icon; 12 px on, the
# title 12/700, 3 px under it the description 11 on a 1.45 line in tertiary, 10 px under that a gradient
# button (6 x 12, radius 7, white 11/600 after a 12 px icon); a 20 px x in the top corner.
AUTH = {'blue': ('#FF3B82F6', '#FF2563EB'), 'purple': ('#FF8B5CF6', '#FF7C3AED'), 'green': ('#FF10B981', '#FF059669'), 'orange': ('#FFF59E0B', '#FFD97706')}
def _auth(pos, alpha=None):
    def c(k):
        v = AUTH[k][pos]
        return v if alpha is None else '#' + alpha + v[3:]
    return "${= props.accent == 'purple' ? '%s' : (props.accent == 'green' ? '%s' : (props.accent == 'orange' ? '%s' : '%s'))}" % (
        c('purple'), c('green'), c('orange'), c('blue'))
def _auth_gradient():
    return {'fills': [{'type': 'linear', 'begin': [-1, -1], 'end': [1, 1],
                       'stops': [{'color': AUTH['blue'][0], 'position': 0}, {'color': AUTH['blue'][1], 'position': 1}]}]}
AUTH_BIND = {'decoration.fills[0].stops[0].color': _auth(0), 'decoration.fills[0].stops[1].color': _auth(1)}
add(component(
    'AuthPromptBanner',
    'An invitation to sign in: an icon plate, a title, a line and a button, tinted in an accent. Fires onSignIn and onDismiss.',
    'banner',
    props=[prop('title', STRING, 'Sign in to sync', 'The title.'),
           prop('description', STRING, 'Keep your work across devices.', 'The line under it.'),
           prop('buttonLabel', STRING, 'Sign in', 'The button\'s label.'),
           prop('icon', STRING, 'cloud', 'The icon on the plate.'),
           prop('accent', enum('blue', 'purple', 'green', 'orange'), 'blue', 'blue, purple, green or orange.'),
           prop('busy', BOOL, False, 'Signing in: a spinner in the button.'),
           prop('dismissible', BOOL, True, 'An x in the corner.')],
    events=['onSignIn', 'onDismiss'],
    previews=[preview('Blue', 340, 92), preview('Purple', 340, 92, accent='purple', title='Connect your team', icon='group')],
    nodes={
        'banner': {'type': 'row', 'children': ['plate', 'texts', 'dismiss'], 'props': {'crossAxisAlignment': 'start', 'spacing': 12},
                   'layout': {'width': {'fill': 340}, 'height': {'hug': 92}, 'padding': 12},
                   'decoration': {'fills': [{'color': '#143B82F6'}], 'strokes': [{'color': '#4D3B82F6'}], 'radius': 12},
                   'bind': {'decoration.fills[0].color': _auth(0, '14'), 'decoration.strokes[0].color': _auth(0, '4D')}},
        'plate': {'type': 'row', 'children': ['glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 36, 'height': 36}, 'decoration': {**_auth_gradient(), 'radius': 10}, 'bind': dict(AUTH_BIND)},
        'glyph': {**icon('cloud', '#FFFFFFFF', 18), 'bind': {'props.icon': '${props.icon}'}},
        'texts': {'type': 'column', 'children': ['title', 'description', 'button'], 'props': {'crossAxisAlignment': 'start'},
                  'layout': {'width': {'fill': 240}, 'height': {'hug': 68}}},
        'title': text('${props.title}', style(12, 700, 'primaryText', 1.3), {'fill': 240}, {'hug': 16}),
        'description': {**text('${props.description}', style(11, 400, 'tertiaryText', 1.45), {'fill': 240}, {'hug': 16}),
                        'layout': {'width': {'fill': 240}, 'height': {'hug': 16}, 'margin': [0, 3, 0, 10]}},
        'button': {'type': 'row', 'children': ['spin', 'login', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'hug': 80}, 'height': {'hug': 26}, 'padding': [12, 6, 12, 6]},
                   'decoration': {**_auth_gradient(), 'radius': 7}, 'bind': {**AUTH_BIND, 'opacity': '${= props.busy ? 0.7 : 1}'},
                   'states': {'hovered': {'button': HOVER}, 'pressed': {'button': PRESS}},
                   'actions': [{'trigger': {'type': 'click', 'when': '!props.busy'}, 'actions': [{'type': 'componentEvent', 'event': 'onSignIn'}]}]},
        'spin': {'type': 'circularProgressIndicator', 'layout': {'width': 12, 'height': 12}, 'props': {'color': '#FFFFFFFF', 'strokeWidth': 2},
                 'bind': {'visible': '${props.busy}'}},
        'login': {**icon('login', '#FFFFFFFF', 12), 'bind': {'visible': '${= !props.busy}'}},
        'label': text('${props.buttonLabel}', style(11, 600, '#FFFFFFFF', 1.25), {'hug': 40}, {'hug': 14}),
        'dismiss': {'type': 'row', 'children': ['x'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                    'layout': {'width': 20, 'height': 20}, 'decoration': {'radius': 5},
                    'bind': {'visible': '${props.dismissible}'},
                    'states': {'hovered': {'dismiss': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}, 'x': {'props': {'color': 'primaryText'}}}},
                    'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onDismiss'}]}]},
        'x': icon('close', 'tertiaryText', 13),
    },
))

def _typed(event='onChanged', more=()):
    """A text field's reactions: its text into the call's variable, then the event."""
    return [{'trigger': {'type': 'changed'}, 'actions': [
                {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'},
                {'type': 'componentEvent', 'event': event, 'value': '${result}'}]},
            {'trigger': {'type': 'submitted'}, 'actions': [{'type': 'componentEvent', 'event': 'onSubmitted', 'value': '${result}'}]},
            *more]


def _bare_field(size, hint="${props.placeholder}", **props):
    """A text field with no frame of its own: the box around it draws the border."""
    return {'type': 'textField', 'layout': {'width': {'fill': 200}, 'height': {'hug': 20}},
            'props': {'style': {'from': 'inputText', 'fontSize': size},
                      'decoration': {'isDense': True, 'isCollapsed': True, 'border': {'type': 'none'},
                                     'hintStyle': {'from': 'placeholder', 'fontSize': size}},
                      'cursorColor': 'primary', **props},
            'bind': {'props.initialValue': '${props.value}', 'props.decoration.hintText': hint}}


# FullWidthSearchInput (FullWidthSearchInput.tsx): the search row at the top of a list or a pane: 36 px on the
# secondary background over a hairline, 10 px either side, a 13 px search icon in tertiary, 8 px, the text 12.
add(component(
    'FullWidthSearchInput',
    'The search row at the top of a list or a pane: edge to edge over a hairline. Its text is kept in your variable. Fires onChanged and onSubmitted.',
    'bar',
    props=[prop('value', var(STRING), '', 'The name of your text variable.'),
           prop('placeholder', STRING, 'Search', 'Shown while empty.')],
    events=[{'key': 'onChanged', 'payload': STRING}, {'key': 'onSubmitted', 'payload': STRING}],
    previews=[preview('Empty', 300, 36), preview('Typed', 300, 36, value='invoices')],
    nodes={
        'bar': {'type': 'row', 'children': ['strut', 'glyph', 'field'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                'layout': {'width': {'fill': 300}, 'height': {'hug': 36}, 'padding': [10, 0, 10, 0]},
                'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 35}},
        'glyph': icon('search', 'tertiaryText', 13),
        'field': {**_bare_field(12, textInputAction='search'), 'actions': _typed()},
    },
))

# HeaderSearchInput (HeaderSearchInput.tsx): a small search field for a header: 26 px, a 1 px border (the
# brand color when focused), radius 4, 8 px either side, the text 12.
add(component(
    'HeaderSearchInput',
    'A small search field for a header or a toolbar. Its text is kept in your variable. Fires onChanged and onSubmitted.',
    'field',
    props=[prop('value', var(STRING), '', 'The name of your text variable.'),
           prop('placeholder', STRING, 'Search', 'Shown while empty.')],
    events=[{'key': 'onChanged', 'payload': STRING}, {'key': 'onSubmitted', 'payload': STRING}],
    previews=[preview('Empty', 200, 26), preview('Typed', 200, 26, value='roadmap')],
    nodes={
        'field': {
            'type': 'textField', 'layout': {'width': {'fill': 200}, 'height': 26},
            'props': {'style': {'from': 'inputText', 'fontSize': 12},
                      'decoration': {'isDense': True, 'filled': True, 'fillColor': 'primaryBackground', 'contentPadding': [8, 5, 8, 5],
                                     'hintStyle': {'from': 'placeholder', 'fontSize': 12}, 'hoverColor': '#00000000',
                                     **{k: {'type': 'outline', 'borderRadius': 4, 'borderSide': {'color': c, 'width': 1}}
                                        for k, c in (('border', 'primaryBorder'), ('enabledBorder', 'primaryBorder'), ('focusedBorder', 'primary'))}},
                      'cursorColor': 'primary', 'textInputAction': 'search'},
            'bind': {'props.initialValue': '${props.value}', 'props.decoration.hintText': '${props.placeholder}'},
            'actions': _typed(),
        },
    },
))

# AuthInput (AuthInput.tsx): the field of a sign-in form: 32 px, a 1 px strong border (red on an error),
# radius 7, 10 px either side, the text 13; the error's words 11 in red 4 px under it.
add(component(
    'AuthInput',
    'A sign-in form field: email, password or a code. Its text is kept in your variable; an error turns it red with the reason under it. Fires onChanged and onSubmitted.',
    'column',
    props=[prop('value', var(STRING), '', 'The name of your text variable.'),
           prop('placeholder', STRING, 'Email', 'Shown while empty.'),
           prop('kind', enum('text', 'email', 'password'), 'text', 'email: the email keyboard. password: hidden text.'),
           prop('error', STRING, '', 'What is wrong (empty: nothing).')],
    events=[{'key': 'onChanged', 'payload': STRING}, {'key': 'onSubmitted', 'payload': STRING}],
    previews=[preview('Email', 260, 32, placeholder='you@company.com', kind='email'),
              preview('Error', 260, 50, value='nope', error='Enter a valid email address.')],
    nodes={
        'column': {'type': 'column', 'children': ['field', 'error'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 4},
                   'layout': {'width': {'fill': 260}, 'height': {'hug': 32}}},
        'field': {
            'type': 'textField', 'layout': {'width': {'fill': 260}, 'height': 32},
            'props': {'style': {'from': 'inputText', 'fontSize': 13},
                      'decoration': {'isDense': True, 'filled': True, 'fillColor': 'primaryBackground', 'contentPadding': [10, 7, 10, 7],
                                     'hintStyle': {'from': 'placeholder', 'fontSize': 13}, 'hoverColor': '#00000000',
                                     'border': outline('secondaryBorder'), 'enabledBorder': outline('secondaryBorder'),
                                     'focusedBorder': outline('primary')},
                      'cursorColor': 'primary'},
            'bind': {'props.initialValue': '${props.value}', 'props.decoration.hintText': '${props.placeholder}',
                     'props.obscureText': "${= props.kind == 'password'}",
                     'props.keyboardType': "${= props.kind == 'email' ? 'emailAddress' : 'text'}",
                     'props.decoration.enabledBorder.borderSide.color': "${= props.error != '' ? theme.error : theme.colors.secondaryBorder}",
                     'props.decoration.focusedBorder.borderSide.color': "${= props.error != '' ? theme.error : theme.primary}"},
            'actions': _typed(),
        },
        'error': {**text('${props.error}', style(11, 400, 'error', 1.35), {'fill': 260}, {'hug': 15}),
                  'bind': {'visible': "${= props.error != ''}"}},
    },
))

# NumberInput (NumberInput.tsx): a number in a field with a 1.5 px border, radius 7 (the focus ring's color
# while it is typed in): an optional prefix and suffix 13/500 in tertiary, the value 13 (15 large), and at its
# end two stacked step buttons (15 px wide, an 11 px chevron each). Small pads 5 x 10, medium 7 x 10, large 11 x 12.
NI = ['small', 'medium', 'large']
add(component(
    'NumberInput',
    'A number you type or step: a field with small up and down buttons, an optional prefix and suffix. The number is kept in your variable. Fires onChanged.',
    'box',
    props=[prop('value', var(NUMBER), '', 'The name of your number variable.'),
           prop('min', NUMBER, 0, 'The least it goes.'),
           prop('max', NUMBER, 1000000, 'The most it goes.'),
           prop('step', NUMBER, 1, 'How much a step button changes it.'),
           prop('prefix', STRING, '', 'Before the value ($).'),
           prop('suffix', STRING, '', 'After the value (px, %).'),
           prop('showStepper', BOOL, True, 'The up and down buttons.'),
           prop('size', enum(*NI), 'medium', 'small, medium or large.'),
           prop('enabled', BOOL, True, 'False dims it and stops input.')],
    events=[{'key': 'onChanged', 'payload': NUMBER}],
    previews=[preview('Plain', 140, 32, value=12), preview('With units', 140, 32, value=24, suffix='px')],
    nodes={
        'box': {'type': 'row', 'children': ['prefix', 'field', 'suffix', 'steps'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                'layout': {'width': {'fill': 140}, 'height': {'hug': 32}, 'padding': [10, 7, 4, 7]},
                'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeWidth': 1.5, 'radius': 7},
                'bind': {'layout.padding': by('size', {'small': [10, 5, 4, 5], 'medium': [10, 7, 4, 7], 'large': [12, 11, 4, 11]}),
                         'opacity': '${= props.enabled ? 1 : 0.5}'},
                'states': {'focused': {'box': {'decoration': {'strokes': [{'color': 'focusBorder'}]}}}}},
        'prefix': {**text('${props.prefix}', style(13, 500, 'tertiaryText', 1.0), {'hug': 10}, {'hug': 13}),
                   'bind': {'visible': "${= props.prefix != ''}", 'props.style.fontSize': by('size', {'small': 13, 'medium': 13, 'large': 15})}},
        'field': {**_bare_field(13, hint='0', keyboardType='number'),
                  'bind': {'props.initialValue': '${props.value}', 'props.enabled': '${props.enabled}',
                           'props.style.fontSize': by('size', {'small': 13, 'medium': 13, 'large': 15})},
                  'actions': [{'trigger': {'type': 'changed'}, 'actions': [
                      {'type': 'setVariable', 'variable': 'props.value', 'value': '${= clamp(number(result), props.min, props.max)}'},
                      {'type': 'componentEvent', 'event': 'onChanged', 'value': '${= clamp(number(result), props.min, props.max)}'}]}]},
        'suffix': {**text('${props.suffix}', style(13, 500, 'tertiaryText', 1.0), {'hug': 14}, {'hug': 13}),
                   'bind': {'visible': "${= props.suffix != ''}", 'props.style.fontSize': by('size', {'small': 13, 'medium': 13, 'large': 15})}},
        'steps': {'type': 'column', 'children': ['up', 'down'], 'layout': {'width': {'hug': 15}, 'height': {'hug': 18}},
                  'bind': {'visible': '${props.showStepper}'}},
        **{id_: {'type': 'row', 'children': [id_ + 'Glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                 'layout': {'width': 15, 'height': 9}, 'decoration': {'radius': 3},
                 'bind': {'layout.width': by('size', {'small': 14, 'medium': 15, 'large': 17}),
                          'layout.height': by('size', {'small': 9, 'medium': 9, 'large': 11})},
                 'states': {'hovered': {id_: {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}, id_ + 'Glyph': {'props': {'color': 'primaryText'}}}},
                 'actions': [{'trigger': {'type': 'click', 'when': 'props.enabled'}, 'actions': [
                     {'type': 'setVariable', 'variable': 'props.value', 'value': '${= clamp(props.value %s props.step, props.min, props.max)}' % op},
                     {'type': 'componentEvent', 'event': 'onChanged', 'value': '${props.value}'}]}]}
           for id_, op in (('up', '+'), ('down', '-'))},
        'upGlyph': icon('expand_less', 'tertiaryText', 11),
        'downGlyph': icon('expand_more', 'tertiaryText', 11),
    },
))

# ColorInput (ColorInput.tsx): a color as its hex code in a field: 32, 36 or 44 px high, a 1.5 px border
# (red on an error), radius 7; a swatch of the color first (22, 24 or 32 px, radius 7, a 1 px border), 5 px,
# then the code 13 (15 large). A label 14/500 over it; the error's words under it.
CI = {'small': 32, 'medium': 36, 'large': 44}
add(component(
    'ColorInput',
    'A color as its hex code, with a swatch of it. The code is kept in your variable. Fires onChanged, and onSwatch when the swatch is pressed.',
    'column',
    props=[prop('value', var(STRING), '', 'The name of your text variable holding the color (#RRGGBB).'),
           prop('label', STRING, '', 'Words over the field (empty: none).'),
           prop('error', STRING, '', 'What is wrong (empty: nothing).'),
           prop('showSwatch', BOOL, True, 'The swatch before the code.'),
           prop('size', enum(*CI), 'medium', 'small (32), medium (36) or large (44).'),
           prop('enabled', BOOL, True, 'False dims it and stops input.')],
    events=[{'key': 'onChanged', 'payload': STRING}, 'onSwatch'],
    previews=[preview('Blue', 160, 36, value='#2563EB'), preview('Labeled', 160, 62, value='#16A34A', label='Accent')],
    nodes={
        'column': {'type': 'column', 'children': ['label', 'box', 'error'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 6},
                   'layout': {'width': {'fill': 160}, 'height': {'hug': 36}}, 'bind': {'opacity': '${= props.enabled ? 1 : 0.5}'}},
        'label': {**text('${props.label}', style(14, 500, 'primaryText', 1.4), {'fill': 160}, {'hug': 20}),
                  'bind': {'visible': "${= props.label != ''}"}},
        'box': {'type': 'row', 'children': ['strut', 'swatch', 'field'], 'props': {'crossAxisAlignment': 'center', 'spacing': 5},
                'layout': {'width': {'fill': 160}, 'height': {'hug': 36}, 'padding': [5, 0, 10, 0]},
                'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeWidth': 1.5, 'radius': 7},
                'bind': {'layout.padding': by('size', {'small': [4, 0, 8, 0], 'medium': [5, 0, 10, 0], 'large': [6, 0, 12, 0]}),
                         'decoration.strokes[0].color': "${= props.error != '' ? theme.error : theme.colors.primaryBorder}"},
                'states': {'focused': {'box': {'decoration': {'strokes': [{'color': 'focusBorder'}]}}}}},
        'strut': strut(by('size', {k: v - 3 for k, v in CI.items()}), 33),
        'swatch': {'type': 'box', 'layout': {'width': 24, 'height': 24},
                   'decoration': {'fills': [{'color': '#FF2563EB'}], 'strokes': [{'color': 'secondaryBorder'}], 'radius': 7},
                   'bind': {'visible': '${props.showSwatch}',
                            'decoration.fills[0].color': "${= matches(props.value, '^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$') ? props.value : '#00000000'}",
                            'layout.width': by('size', {'small': 22, 'medium': 24, 'large': 32}),
                            'layout.height': by('size', {'small': 22, 'medium': 24, 'large': 32})},
                   'actions': [{'trigger': {'type': 'click', 'when': 'props.enabled'}, 'actions': [{'type': 'componentEvent', 'event': 'onSwatch'}]}]},
        'field': {**_bare_field(13, hint='#000000'),
                  'bind': {'props.initialValue': '${props.value}', 'props.enabled': '${props.enabled}',
                           'props.style.fontSize': by('size', {'small': 13, 'medium': 13, 'large': 15})},
                  'actions': [{'trigger': {'type': 'changed'}, 'actions': [
                      {'type': 'setVariable', 'variable': 'props.value', 'value': '${= upper(result)}'},
                      {'type': 'componentEvent', 'event': 'onChanged', 'value': '${= upper(result)}'}]}]},
        'error': {**text('${props.error}', style(12, 400, 'error', 1.35), {'fill': 160}, {'hug': 16}),
                  'bind': {'visible': "${= props.error != ''}"}},
    },
))

# ModelAvatarStack (ModelAvatarStack.tsx): who or what took part, as small round plates that overlap by a
# third: 16, 18 or 22 px, on the page color with a 1 px ring, each holding a first letter at half its size,
# weight 700; past the most it shows, a +n pill of the same height in secondary.
MAS = {'small': 16, 'medium': 18, 'large': 22}
add(component(
    'ModelAvatarStack',
    'Several people or models as small overlapping round plates with their first letters, and +n for the rest.',
    'stack',
    props=[prop('labels', STRINGS, ['Ada', 'Ben', 'Cy'], 'Their names: each plate shows a first letter.', required=True),
           prop('max', NUMBER, 4, 'How many plates at most; the rest become +n.'),
           prop('size', enum(*MAS), 'medium', 'small (16), medium (18) or large (22).')],
    previews=[preview('Three', 50, 18), preview('Many', 80, 22, labels=['Ada', 'Ben', 'Cy', 'Di', 'Eve', 'Flo'], max=3, size='large')],
    nodes={
        'stack': {'type': 'row', 'children': ['list', 'more'], 'props': {'crossAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 50}, 'height': {'hug': 18}}},
        'list': {'type': 'listView', 'children': ['plate'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': -6},
                 'layout': {'width': {'hug': 44}, 'height': 18},
                 'bind': {'data': '${= take(props.labels, props.max)}', 'layout.height': by('size', MAS),
                          'props.spacing': by('size', {'small': -5, 'medium': -6, 'large': -7})}},
        'plate': {'type': 'row', 'children': ['letter'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 18, 'height': {'fill': 18}},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 9999},
                  'tooltip': '${item}',
                  'bind': {'layout.width': by('size', MAS)}},
        'letter': {**text('${= upper(left(item, 1))}', style(9, 700, 'primaryText', 1.0), {'hug': 8}, {'hug': 9}),
                   'bind': {'props.style.fontSize': by('size', {'small': 8, 'medium': 9, 'large': 11})}},
        'more': {'type': 'row', 'children': ['count'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                 'layout': {'width': {'hug': 20}, 'height': 18, 'padding': [4, 0, 4, 0]}, 'motion': {'translateX': -5},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 9999},
                 'bind': {'visible': '${= length(props.labels) > props.max}', 'layout.height': by('size', MAS)}},
        'count': {**text('+${= length(props.labels) - props.max}', style(9, 700, 'secondaryText', 1.0), {'hug': 12}, {'hug': 9}),
                  'bind': {'props.style.fontSize': by('size', {'small': 8, 'medium': 9, 'large': 11})}},
    },
))

def _one_line(t, st, w, h):
    """A text on one line, cut with an ellipsis."""
    return {**text(t, st, w, h), 'props': {'text': t, 'style': st, 'maxLines': 1, 'overflow': 'ellipsis'}}


# SectionToolbar (SectionToolbar.tsx): the bar over a section: 36 px on the secondary background over a
# hairline, padding 4 4 4 12, 8 px apart: an icon in tertiary, the title 12/650, an 11 px turning arc while
# it loads, then the call's actions at the end, 4 px apart.
add(component(
    'SectionToolbar',
    'The bar over a section: an icon, a title, a spinner while it loads, and the call\'s actions at the end.',
    'bar',
    props=[prop('title', STRING, 'Section', 'The title.', required=True),
           prop('icon', STRING, '', 'An icon before the title (empty: none).'),
           prop('loading', BOOL, False, 'A small spinner after the title.')],
    slots=['actions'],
    previews=[preview('Default', 300, 36, title='Files', icon='folder'), preview('Loading', 300, 36, title='Runs', loading=True)],
    nodes={
        'bar': {'type': 'row', 'children': ['strut', 'glyph', 'title', 'spin', 'gap', 'actions'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                'layout': {'width': {'fill': 300}, 'height': {'hug': 36}, 'padding': [12, 0, 4, 0]},
                'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 35}},
        'glyph': {**icon('folder', 'tertiaryText', 14), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'title': _one_line('${props.title}', style(12, 600, 'primaryText', 1.3), {'hug': 60}, {'hug': 16}),
        'spin': {'type': 'circularProgressIndicator', 'layout': {'width': 11, 'height': 11}, 'props': {'color': 'tertiaryText', 'strokeWidth': 1.5},
                 'bind': {'visible': '${props.loading}'}},
        'gap': {'type': 'box', 'layout': {'width': {'fill': 20}, 'height': 1}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
    },
))

# PaneToolbar (PaneToolbar.tsx): the bar of a pane, the SectionToolbar's shape with a title you can press, a
# muted note 11 after it, the call's actions and a close button at the end.
add(component(
    'PaneToolbar',
    'The bar of a pane: an icon, a title, a muted note, the call\'s actions and a close button. Fires onTitle and onClose.',
    'bar',
    props=[prop('title', STRING, 'Pane', 'The title.', required=True),
           prop('meta', STRING, '', 'A muted note after the title (a count, a branch).'),
           prop('icon', STRING, '', 'An icon before the title (empty: none).'),
           prop('loading', BOOL, False, 'A small spinner after the title.'),
           prop('closable', BOOL, True, 'A close button at the end.')],
    events=['onTitle', 'onClose'],
    slots=['actions'],
    previews=[preview('Default', 300, 36, title='Preview', meta='main', icon='visibility')],
    nodes={
        'bar': {'type': 'row', 'children': ['strut', 'glyph', 'title', 'meta', 'spin', 'gap', 'actions', 'close'],
                'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                'layout': {'width': {'fill': 300}, 'height': {'hug': 36}, 'padding': [12, 0, 4, 0]},
                'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 35}},
        'glyph': {**icon('visibility', 'tertiaryText', 14), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'title': {**_one_line('${props.title}', style(12, 600, 'primaryText', 1.3), {'hug': 60}, {'hug': 16}),
                  'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onTitle'}]}]},
        'meta': {**_one_line('${props.meta}', style(11, 400, 'tertiaryText', 1.3), {'hug': 30}, {'hug': 15}),
                 'bind': {'visible': "${= props.meta != ''}"}},
        'spin': {'type': 'circularProgressIndicator', 'layout': {'width': 11, 'height': 11}, 'props': {'color': 'tertiaryText', 'strokeWidth': 1.5},
                 'bind': {'visible': '${props.loading}'}},
        'gap': {'type': 'box', 'layout': {'width': {'fill': 20}, 'height': 1}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
        'close': {'type': 'IconButton', 'props': {'icon': 'close', 'size': 'compact'}, 'layout': {'width': 28, 'height': 28},
                  'bind': {'visible': '${props.closable}'}, 'tooltip': 'Close',
                  'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'onClose'}]}]},
    },
))

# CompactAppBar (CompactAppBar.tsx): a small window's app bar: 46 px over a hairline, padding 0 6 0 12: a
# 24 px brand plate, radius 6, a 12 % tint of the brand color with a 14 px icon; 8 px on, the title 13/600
# (-0.2) over a status line 10 in tertiary with an optional 5 px dot; then the call's actions (28 px round
# ghost buttons, 16 px icons).
add(component(
    'CompactAppBar',
    'The app bar of a small window or a panel: a brand plate, a title over a status line, the call\'s actions at the end.',
    'bar',
    props=[prop('title', STRING, 'App', 'The title.', required=True),
           prop('status', STRING, '', 'The line under the title.'),
           prop('statusColor', STRING, '', 'A 5 px dot of this color before the status (empty: none).'),
           prop('icon', STRING, 'bolt', 'The brand plate\'s icon.')],
    slots=['actions'],
    previews=[preview('Default', 320, 46, title='Relay', status='Connected', statusColor='#FF22C55E')],
    nodes={
        'bar': {'type': 'row', 'children': ['strut', 'plate', 'texts', 'actions'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                'layout': {'width': {'fill': 320}, 'height': {'hug': 46}, 'padding': [12, 0, 6, 0]},
                'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 45}},
        'plate': {'type': 'row', 'children': ['glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 24, 'height': 24}, 'decoration': {'fills': [{'color': 'primaryTint'}], 'radius': 6}},
        'glyph': {**icon('bolt', 'primary', 14), 'bind': {'props.icon': '${props.icon}'}},
        'texts': {'type': 'column', 'children': ['title', 'line'], 'props': {'crossAxisAlignment': 'start', 'spacing': 2},
                  'layout': {'width': {'fill': 200}, 'height': {'hug': 28}}},
        'title': _one_line('${props.title}', style(13, 600, 'primaryText', 1.15, letterSpacing=-0.2), {'fill': 200}, {'hug': 15}),
        'line': {'type': 'row', 'children': ['dot', 'status'], 'props': {'crossAxisAlignment': 'center', 'spacing': 3},
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 12}}, 'bind': {'visible': "${= props.status != ''}"}},
        'dot': {'type': 'box', 'layout': {'width': 5, 'height': 5}, 'decoration': {'fills': [{'color': '#FF22C55E'}], 'radius': 9999},
                'bind': {'visible': "${= props.statusColor != ''}",
                         'decoration.fills[0].color': "${= props.statusColor != '' ? props.statusColor : '#00000000'}"}},
        'status': _one_line('${props.status}', style(10, 400, 'tertiaryText', 1.2, letterSpacing=-0.1), {'hug': 60}, {'hug': 12}),
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
    },
))

# StatusCategoryHeader (StatusCategoryHeader.tsx): the button over a group of items in one state, radius 6,
# 2 px above and below, 6 px apart: a 12 px state icon in the state's color (brand while running, red when
# failed, green when ready or passed, tertiary idle or cancelled), the label 11/650 (13 for a workflow), a
# count pill, and a 16 px chevron in tertiary: down when open, right when closed.
SC = ['running', 'failed', 'idle', 'ready', 'passed', 'cancelled']
add(component(
    'StatusCategoryHeader',
    'The header of a group of items in one state: a state icon, a label, how many, and a chevron that opens and closes the group. Fires onToggle.',
    'header',
    props=[prop('label', STRING, 'Running', 'The group\'s name.', required=True),
           prop('count', NUMBER, 0, 'How many items it holds.'),
           prop('status', enum(*SC), 'running', 'running, failed, idle, ready, passed or cancelled.'),
           prop('expanded', BOOL, True, 'Open: the chevron points down.'),
           prop('variant', enum('agents', 'workflow'), 'agents', 'workflow: a larger label.')],
    events=['onToggle'],
    previews=[preview('Running', 160, 22, label='Running', count=3), preview('Failed', 160, 22, label='Failed', count=1, status='failed', expanded=False)],
    nodes={
        'header': {'type': 'row', 'children': ['glyph', 'label', 'count', 'chevron'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'hug': 160}, 'height': {'hug': 22}, 'padding': [0, 2, 0, 2]}, 'decoration': {'radius': 6},
                   'states': {'hovered': {'chevron': {'props': {'color': 'primaryText'}}}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onToggle', 'value': '${= !props.expanded}'}]}]},
        'glyph': {**icon('autorenew', 'primary', 12),
                  'bind': {'props.icon': "${= props.status == 'running' ? 'autorenew' : (props.status == 'failed' ? 'error_outline' : (props.status == 'idle' ? 'new_releases' : (props.status == 'cancelled' ? 'pause' : 'check_circle_outline')))}",
                           'props.color': "${= props.status == 'running' ? theme.primary : (props.status == 'failed' ? theme.error : (props.status == 'ready' || props.status == 'passed' ? theme.success : theme.colors.tertiaryText))}"}},
        'label': {**text('${props.label}', style(11, 600, 'primaryText', 1.3, letterSpacing=-0.1), {'hug': 50}, {'hug': 15}),
                  'bind': {'props.style.fontSize': "${= props.variant == 'workflow' ? 13 : 11}"}},
        'count': {'type': 'CountBadge', 'props': {'count': 0, 'showZero': True}, 'layout': {'width': {'hug': 18}, 'height': {'hug': 16}},
                  'bind': {'props.count': '${props.count}'}},
        'chevron': {**icon('expand_more', 'tertiaryText', 16), 'bind': {'props.icon': "${= props.expanded ? 'expand_more' : 'chevron_right'}"}},
    },
))

# SectionCategoryHeaderFull (SectionCategoryHeaderFull.tsx): the full-width label over a group in a list: on
# the secondary background over a 70 % hairline, 6 x 10, its title 10/700 in tertiary, upper case, 0.06 em apart.
add(component(
    'SectionCategoryHeaderFull',
    'The full-width label over a group in a list: small upper-case letters on a soft band.',
    'band',
    props=[prop('title', STRING, 'Recent', 'The group\'s name.', required=True)],
    slots=['trailing'],
    previews=[preview('Default', 300, 26, title='Recent')],
    nodes={
        'band': {'type': 'row', 'children': ['title', 'trailing'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                 'layout': {'width': {'fill': 300}, 'height': {'hug': 26}, 'padding': [10, 6, 10, 6]},
                 'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'title': _one_line('${= upper(props.title)}', style(10, 700, 'tertiaryText', 1.3, letterSpacing=0.6), {'fill': 240}, {'hug': 13}),
        'trailing': {'type': 'slot', 'props': {'name': 'trailing'}},
    },
))

# ScrollToBottomFAB (ScrollToBottomFAB.tsx): the round button that takes a conversation back to its end:
# 30 px, on the page color with a 1 px 14 % border and a soft shadow (0 8 20 at 14 %), a 14 px chevron down.
add(component(
    'ScrollToBottomFAB',
    'The small round button over a conversation or a log that takes it back to its end. Fires onPressed.',
    'button',
    events=['onPressed'],
    previews=[preview('Default', 30, 30)],
    nodes={
        'button': {'type': 'row', 'children': ['glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                   'layout': {'width': {'hug': 30}, 'height': {'hug': 30}, 'padding': 8},
                   'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'secondaryBorder'}], 'radius': 9999,
                                  'effects': [shadow('#240F172A', 8, 20)]},
                   'tooltip': 'Scroll to bottom',
                   'states': {'hovered': {'button': HOVER, 'glyph': {'props': {'color': 'primaryText'}}}, 'pressed': {'button': PRESS}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPressed'}]}]},
        'glyph': icon('expand_more', 'secondaryText', 14),
    },
))

# TabBarWithBadges (TabBarWithBadges.tsx): the tab bar at the foot of an app: its tabs share the width, each
# 10 x 4 with a 20 px icon on a 40 x 32 plate, radius 8 (tinted when chosen), 3 px over a label 10 (600 and
# the brand color when chosen, tertiary otherwise); a badge at the plate's corner, 16 px high, 9/700 white on
# red for a count, blue for a word. Default: a hairline over it; floating: radius 14, a border and a shadow.
add(component(
    'TabBarWithBadges',
    'The tab bar at the foot of an app: icons over labels, with a badge on a tab that has news. The chosen tab is kept in your variable. Fires onChanged.',
    'bar',
    props=[prop('tabs', STRINGS, ['Home', 'Inbox', 'Profile'], 'The tabs\' labels.', required=True),
           prop('icons', STRINGS, ['home', 'inbox', 'person'], 'One icon per tab.', required=True),
           prop('badges', STRINGS, [], 'One badge per tab: a count, a word, or empty for none.'),
           prop('value', var(STRING), '', 'The name of your text variable holding the chosen tab\'s label.'),
           prop('variant', enum('default', 'floating'), 'default', 'default: edge to edge under a hairline. floating: a rounded bar with a shadow.')],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Default', 320, 62, tabs=['Home', 'Inbox', 'Profile'], icons=['home', 'inbox', 'person'], badges=['', '3', ''], value='Home')],
    nodes={
        'bar': {'type': 'column', 'children': ['list'], 'props': {'crossAxisAlignment': 'stretch'},
                'layout': {'width': {'fill': 320}, 'height': {'hug': 62}},
                'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'top',
                               'radius': 0, 'effects': []},
                'bind': {'decoration.radius': "${= props.variant == 'floating' ? 14 : 0}",
                         'decoration.strokeSides': "${= props.variant == 'floating' ? 'all' : 'top'}",
                         'decoration.effects': "${= props.variant == 'floating' ? theme.shadows.level3 : []}"}},
        'list': {'type': 'gridView', 'children': ['tab'],
                 'props': {'crossAxisCount': 3, 'mainAxisExtent': 62, 'physics': 'never', 'alwaysScroll': False},
                 'layout': {'width': {'fill': 320}, 'height': 62},
                 'bind': {'data': '${props.tabs}', 'props.crossAxisCount': '${= max(1, length(props.tabs))}'}},
        'tab': {'type': 'column', 'children': ['plate', 'label'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center', 'spacing': 3},
                'layout': {'width': {'fill': 100}, 'height': {'fill': 62}, 'padding': [4, 0, 4, 0]},
                'bind': {'selected': '${= item == props.value}'},
                'states': {'selected': {'plate': {'decoration': {'fills': [{'color': 'primaryTint'}]}},
                                        'glyph': {'props': {'color': 'primary'}},
                                        'label': {'props': {'style': {'color': 'primary', 'fontWeight': 600}}}},
                           'hovered': {'plate': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                'actions': [{'trigger': 'click', 'actions': [
                    {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                    {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'plate': {'type': 'stack', 'children': ['glyphBox', 'badge'], 'layout': {'width': 40, 'height': 32},
                  'decoration': {'fills': [{'color': '#00000000'}], 'radius': 8}},
        'glyphBox': {'type': 'row', 'children': ['glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                     'layout': {'width': 40, 'height': 32}},
        'glyph': {**icon('circle', 'tertiaryText', 20),
                  'bind': {'props.icon': "${= length(props.icons) > index ? props.icons[index] : 'circle'}"}},
        'badge': {'type': 'row', 'children': ['badgeText'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': {'hug': 16}, 'height': 16, 'padding': [4, 0, 4, 0], 'constraints': {'minWidth': 16},
                             'x': {'end': -4}, 'y': {'start': -2}},
                  'decoration': {'fills': [{'color': '#FFEF4444'}], 'radius': 9999},
                  'bind': {'visible': "${= length(props.badges) > index && props.badges[index] != ''}",
                           'decoration.fills[0].color': "${= length(props.badges) > index && matches(props.badges[index], '^[0-9+]+$') ? '#FFEF4444' : '#FF3B82F6'}"}},
        'badgeText': text("${= length(props.badges) > index ? props.badges[index] : ''}", style(9, 700, '#FFFFFFFF', 1.0), {'hug': 6}, {'hug': 9}),
        'label': text('${item}', style(10, 400, 'tertiaryText', 1.2), {'hug': 30}, {'hug': 12}),
    },
))

# MenuPopover (MenuPopover.tsx): the surface of a menu: on the page color, a 1 px border, radius 8 (7 small),
# the menu shadow; an optional heading over a hairline, 6 x 8, 10/700 in tertiary; then the call's items.
add(component(
    'MenuPopover',
    'The surface of a menu: bordered, rounded, with a shadow and an optional heading. Its children are MenuItem calls.',
    'menu',
    props=[prop('heading', STRING, '', 'A small heading over the items (empty: none).'),
           prop('size', enum('small', 'medium'), 'medium', 'small: radius 7. medium: radius 8.')],
    children='list',
    previews=[preview('Default', 228, 80, heading='Automation actions')],
    nodes={
        'menu': {'type': 'column', 'children': ['heading', 'content'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 228}, 'height': {'hug': 80}, 'padding': 1},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8,
                                'clip': 'antiAlias', 'effects': SHADOWS_LIGHT['level3']},
                 'bind': {'decoration.radius': "${= props.size == 'small' ? 7 : 8}", 'decoration.effects': '${theme.shadows.level3}'}},
        'heading': {'type': 'row', 'children': ['headingText'], 'layout': {'width': {'fill': 226}, 'height': {'hug': 25}, 'padding': [8, 6, 8, 6]},
                    'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'},
                    'bind': {'visible': "${= props.heading != ''}"}},
        'headingText': _one_line('${props.heading}', style(10, 700, 'tertiaryText', 1.3), {'fill': 200}, {'hug': 13}),
        'content': {'type': 'slot'},
    },
))

# MenuItem (MenuPopover.tsx, its item): a row of a menu, 6 x 8, 8 px apart: an icon, the title 11 over an
# optional subtitle 10 in tertiary, and a note at the end. Hovered: the secondary background; danger: red.
add(component(
    'MenuItem',
    'A row of a MenuPopover: an icon, a title, an optional subtitle and a note at the end. Fires onSelected.',
    'item',
    props=[prop('title', STRING, 'Action', 'The title.', required=True),
           prop('subtitle', STRING, '', 'A muted line under it.'),
           prop('icon', STRING, '', 'An icon before it (empty: none).'),
           prop('trailing', STRING, '', 'A short note at the end (a shortcut).'),
           prop('tone', enum('neutral', 'danger'), 'neutral', 'danger: red.'),
           prop('enabled', BOOL, True, 'False dims it and stops presses.')],
    events=['onSelected'],
    previews=[preview('Default', 226, 28, title='Copy command', icon='content_copy', trailing='Ctrl+C')],
    nodes={
        'item': {'type': 'row', 'children': ['glyph', 'texts', 'trailing'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                 'layout': {'width': {'fill': 226}, 'height': {'hug': 28}, 'padding': [8, 6, 8, 6]},
                 'decoration': {'fills': [{'color': '#00000000'}]},
                 'bind': {'opacity': '${= props.enabled ? 1 : 0.5}'},
                 'states': {'hovered': {'item': {'decoration': {'fills': [{'color': 'secondaryBackground'}]}}}},
                 'actions': [click('onSelected')]},
        'glyph': {**icon('circle', 'secondaryText', 13),
                  'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}',
                           'props.color': "${= props.tone == 'danger' ? theme.error : theme.colors.secondaryText}"}},
        'texts': {'type': 'column', 'children': ['title', 'subtitle'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 1},
                  'layout': {'width': {'fill': 160}, 'height': {'hug': 15}}},
        'title': {**_one_line('${props.title}', style(11, 500, 'primaryText', 1.35), {'fill': 160}, {'hug': 15}),
                  'bind': {'props.style.color': "${= props.tone == 'danger' ? theme.error : theme.colors.primaryText}"}},
        'subtitle': {**_one_line('${props.subtitle}', style(10, 400, 'tertiaryText', 1.3), {'fill': 160}, {'hug': 13}),
                     'bind': {'visible': "${= props.subtitle != ''}"}},
        'trailing': {**text('${props.trailing}', style(10, 400, 'tertiaryText', 1.3), {'hug': 20}, {'hug': 13}),
                     'bind': {'visible': "${= props.trailing != ''}"}},
    },
))

# ContextMenu (ContextMenu.tsx): the menu of a right click: radius 10, 4 px above and below, the menu shadow;
# each action 7 x 12 with a 13 px icon, 8 px, the label 12 and a shortcut 10 in tertiary at its end; a
# destructive one in red; "-" draws a hairline with 4 px either side.
add(component(
    'ContextMenu',
    'The menu of a right click or a "more" button: actions with icons and shortcuts, hairlines between groups. Fires onSelected with the label.',
    'menu',
    props=[prop('items', STRINGS, ['Rename', 'Duplicate', '-', 'Delete'], 'The actions\' labels; "-" is a hairline.', required=True),
           prop('icons', STRINGS, [], 'One icon per entry (empty: none).'),
           prop('shortcuts', STRINGS, [], 'One shortcut per entry (empty: none).'),
           prop('destructive', STRINGS, ['Delete'], 'The labels shown in red.')],
    events=[{'key': 'onSelected', 'payload': STRING}],
    previews=[preview('Default', 200, 110, icons=['edit', 'content_copy', '', 'delete'], shortcuts=['F2', 'Ctrl+D', '', 'Del'])],
    nodes={
        'menu': {'type': 'column', 'children': ['list'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 110}, 'padding': [1, 5, 1, 5]},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 10,
                                'clip': 'antiAlias', 'effects': SHADOWS_LIGHT['level3']},
                 'bind': {'decoration.effects': '${theme.shadows.level3}'}},
        'list': {'type': 'listView', 'children': ['entry'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 198}, 'height': {'hug': 100}}, 'bind': {'data': '${props.items}'}},
        'entry': {'type': 'column', 'children': ['rule', 'action'], 'props': {'crossAxisAlignment': 'stretch'},
                  'layout': {'width': {'fill': 198}, 'height': {'hug': 29}}},
        'rule': {'type': 'box', 'layout': {'width': {'fill': 198}, 'height': 1, 'margin': [0, 4, 0, 4]},
                 'decoration': {'fills': [{'color': 'primaryBorder'}]}, 'bind': {'visible': "${= item == '-'}"}},
        'action': {'type': 'row', 'children': ['glyph', 'label', 'shortcut'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 198}, 'height': {'hug': 29}, 'padding': [12, 7, 12, 7]},
                   'decoration': {'fills': [{'color': '#00000000'}]},
                   'bind': {'visible': "${= item != '-'}"},
                   'states': {'hovered': {'action': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onSelected', 'value': '${item}'}]}]},
        'glyph': {**icon('circle', 'primaryText', 13),
                  'bind': {'visible': "${= length(props.icons) > index && props.icons[index] != ''}",
                           'props.icon': "${= length(props.icons) > index && props.icons[index] != '' ? props.icons[index] : 'circle'}",
                           'props.color': '${= contains(props.destructive, item) ? theme.error : theme.colors.primaryText}'}},
        'label': {**_one_line('${item}', style(12, 400, 'primaryText', 1.25), {'fill': 120}, {'hug': 15}),
                  'bind': {'props.style.color': '${= contains(props.destructive, item) ? theme.error : theme.colors.primaryText}'}},
        'shortcut': {**text("${= length(props.shortcuts) > index ? props.shortcuts[index] : ''}", style(10, 400, 'tertiaryText', 1.3, letterSpacing=0.2), {'hug': 16}, {'hug': 13}),
                     'bind': {'visible': "${= length(props.shortcuts) > index && props.shortcuts[index] != ''}"}},
    },
))

# SortMenu (SortMenu.tsx): the menu that picks what a list is sorted by: radius 8, 4 px either side; each
# option 36 px, radius 5, padding 0 6 0 10: a 13 px check when chosen, 8 px, the label 13 (the brand color on
# a 14 % brand tint when chosen), and at its end a 24 px button that flips the direction.
add(component(
    'SortMenu',
    'The menu that picks what a list is sorted by and which way. The choice and the direction (asc or desc) are kept in your variables. Fires onChanged and onDirectionChanged.',
    'menu',
    props=[prop('options', STRINGS, ['Name', 'Date modified', 'Size'], 'What it can sort by.', required=True),
           prop('value', var(STRING), '', 'The name of your text variable holding the choice.'),
           prop('direction', var(STRING), '', 'The name of your text variable holding asc or desc.')],
    events=[{'key': 'onChanged', 'payload': STRING}, {'key': 'onDirectionChanged', 'payload': STRING}],
    previews=[preview('Default', 200, 118, value='Name', direction='asc')],
    nodes={
        'menu': {'type': 'column', 'children': ['list'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 118}, 'padding': [5, 5, 5, 5]},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8,
                                'effects': SHADOWS_LIGHT['level3']},
                 'bind': {'decoration.effects': '${theme.shadows.level3}'}},
        'list': {'type': 'listView', 'children': ['option'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 190}, 'height': {'hug': 108}}, 'bind': {'data': '${props.options}'}},
        'option': {'type': 'row', 'children': ['strut', 'tick', 'label', 'flip'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 190}, 'height': {'hug': 36}, 'padding': [10, 0, 6, 0]},
                   'decoration': {'fills': [{'color': '#00000000'}], 'radius': 5},
                   'bind': {'selected': '${= item == props.value}'},
                   'states': {'hovered': {'option': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}},
                              'selected': {'option': {'decoration': {'fills': [{'color': 'activeTint'}]}},
                                           'label': {'props': {'style': {'color': 'primary'}}},
                                           'arrow': {'props': {'color': 'primary'}}}},
                   'actions': [{'trigger': 'click', 'actions': [
                       {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                       {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 36}},
        'tick': {'type': 'row', 'children': ['check'], 'layout': {'width': 13, 'height': 13}},
        'check': {**icon('check', 'primary', 13), 'bind': {'visible': '${= item == props.value}'}},
        'label': _one_line('${item}', style(13, 400, 'primaryText', 1.3), {'fill': 110}, {'hug': 17}),
        'flip': {'type': 'row', 'children': ['arrow'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                 'layout': {'width': 24, 'height': 24}, 'decoration': {'radius': 5},
                 'tooltip': "${= props.direction == 'desc' ? 'Descending' : 'Ascending'}",
                 'bind': {'visible': '${= item == props.value}'},
                 'states': {'hovered': {'flip': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                 'actions': [{'trigger': 'click', 'actions': [
                     {'type': 'setVariable', 'variable': 'props.direction', 'value': "${= props.direction == 'desc' ? 'asc' : 'desc'}"},
                     {'type': 'componentEvent', 'event': 'onDirectionChanged', 'value': '${props.direction}'}]}]},
        'arrow': {**icon('arrow_upward', 'tertiaryText', 13),
                  'bind': {'props.icon': "${= props.direction == 'desc' ? 'arrow_downward' : 'arrow_upward'}"}},
    },
))

# UserMenu (UserMenu.tsx, its open panel): 200 px, radius 10, the menu shadow: a header over a hairline,
# 10 x 12, with a 32 px round plate (a blue to indigo gradient, a white first letter at 38 %, weight 600),
# the name 11/600 over the email 10 in tertiary; then the items, 4 px above and below, each 7 x 12 with a
# 13 px icon; a hairline, then Sign out in red.
add(component(
    'UserMenu',
    'The account menu: who is signed in, a few actions and Sign out. Fires onSelected with the label, and onSignOut.',
    'menu',
    props=[prop('name', STRING, 'Ada Lovelace', 'Who is signed in.', required=True),
           prop('email', STRING, '', 'Their email.'),
           prop('items', STRINGS, ['Settings', 'Sync now'], 'The actions\' labels.'),
           prop('icons', STRINGS, ['settings', 'sync'], 'One icon per action.'),
           prop('signOutLabel', STRING, 'Sign out', 'The last, red action (empty: none).')],
    events=[{'key': 'onSelected', 'payload': STRING}, 'onSignOut'],
    previews=[preview('Default', 200, 150, email='ada@analytical.io')],
    nodes={
        'menu': {'type': 'column', 'children': ['header', 'list', 'rule', 'signOut'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 200}, 'height': {'hug': 150}, 'padding': [1, 1, 1, 5]},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 10,
                                'clip': 'antiAlias', 'effects': SHADOWS_LIGHT['level3']},
                 'bind': {'decoration.effects': '${theme.shadows.level3}'}},
        'header': {'type': 'row', 'children': ['plate', 'who'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 198}, 'height': {'hug': 52}, 'padding': [12, 10, 12, 10], 'margin': [0, 0, 0, 4]},
                   'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'plate': {'type': 'row', 'children': ['letter'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 32, 'height': 32},
                  'decoration': {'fills': [{'type': 'linear', 'begin': [-1, -1], 'end': [1, 1],
                                            'stops': [{'color': '#FF3B82F6', 'position': 0}, {'color': '#FF6366F1', 'position': 1}]}],
                                 'radius': 9999}},
        'letter': text('${= upper(left(props.name, 1))}', style(12, 600, '#FFFFFFFF', 1.0), {'hug': 10}, {'hug': 12}),
        'who': {'type': 'column', 'children': ['name', 'email'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 1},
                'layout': {'width': {'fill': 130}, 'height': {'hug': 28}}},
        'name': _one_line('${props.name}', style(11, 600, 'primaryText', 1.3), {'fill': 130}, {'hug': 14}),
        'email': {**_one_line('${props.email}', style(10, 400, 'tertiaryText', 1.3), {'fill': 130}, {'hug': 13}),
                  'bind': {'visible': "${= props.email != ''}"}},
        'list': {'type': 'listView', 'children': ['action'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 198}, 'height': {'hug': 58}}, 'bind': {'data': '${props.items}'}},
        'action': {'type': 'row', 'children': ['glyph', 'label'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 198}, 'height': {'hug': 29}, 'padding': [12, 7, 12, 7]},
                   'decoration': {'fills': [{'color': '#00000000'}]},
                   'states': {'hovered': {'action': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onSelected', 'value': '${item}'}]}]},
        'glyph': {**icon('circle', 'secondaryText', 13),
                  'bind': {'visible': '${= length(props.icons) > index}',
                           'props.icon': "${= length(props.icons) > index ? props.icons[index] : 'circle'}"}},
        'label': _one_line('${item}', style(12, 400, 'primaryText', 1.25), {'fill': 140}, {'hug': 15}),
        'rule': {'type': 'box', 'layout': {'width': {'fill': 198}, 'height': 1, 'margin': [0, 4, 0, 4]},
                 'decoration': {'fills': [{'color': 'primaryBorder'}]}, 'bind': {'visible': "${= props.signOutLabel != ''}"}},
        'signOut': {'type': 'row', 'children': ['outGlyph', 'outLabel'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                    'layout': {'width': {'fill': 198}, 'height': {'hug': 29}, 'padding': [12, 7, 12, 7]},
                    'decoration': {'fills': [{'color': '#00000000'}]},
                    'bind': {'visible': "${= props.signOutLabel != ''}"},
                    'states': {'hovered': {'signOut': {'decoration': {'fills': [{'color': 'errorTint'}]}}}},
                    'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onSignOut'}]}]},
        'outGlyph': icon('logout', 'error', 13),
        'outLabel': text('${props.signOutLabel}', style(12, 400, 'error', 1.25), {'hug': 50}, {'hug': 15}),
    },
))

# StatusCard (StatusCardList.tsx, its row): one connection, 9 px above and below, 10 px apart: a 34 px plate,
# radius 8, bordered, holding a letter 14/700; the label 12.5/600 (-0.2) with a 6 px dot (green when
# connected), 2 px under it a line 11 in secondary; at the end a pill, radius 6, 3 x 8, 10.5/500 with a 10 px
# icon: green with a green border when connected, else secondary.
add(component(
    'StatusCard',
    'One connection in a StatusCardList: a letter plate, a name, a line about it and a pill telling whether it is connected. Fires onConfigure.',
    'row',
    props=[prop('label', STRING, 'Service', 'Its name.', required=True),
           prop('detail', STRING, '', 'A line under the name.'),
           prop('connected', BOOL, False, 'Connected: green.'),
           prop('letterColor', STRING, '', 'The plate letter\'s color (empty: secondary text).'),
           prop('divider', BOOL, False, 'A hairline over it (every row but the first).')],
    events=['onConfigure'],
    previews=[preview('Connected', 300, 52, label='GitHub', detail='2 repositories', connected=True)],
    nodes={
        'row': {'type': 'row', 'children': ['plate', 'texts', 'pill'], 'props': {'crossAxisAlignment': 'center', 'spacing': 10},
                'layout': {'width': {'fill': 300}, 'height': {'hug': 52}, 'padding': [2, 9, 2, 9]},
                'decoration': {'strokes': [{'color': 'primaryBorder', 'visible': False}], 'strokeSides': 'top'},
                'bind': {'decoration.strokes[0].visible': '${props.divider}'}},
        'plate': {'type': 'row', 'children': ['letter'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 34, 'height': 34},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8}},
        'letter': {**text('${= upper(left(props.label, 1))}', style(14, 700, 'secondaryText', 1.0), {'hug': 10}, {'hug': 14}),
                   'bind': {'props.style.color': "${= props.letterColor != '' ? props.letterColor : theme.colors.secondaryText}"}},
        'texts': {'type': 'column', 'children': ['line', 'detail'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 2},
                  'layout': {'width': {'fill': 160}, 'height': {'hug': 32}}},
        'line': {'type': 'row', 'children': ['label', 'dot'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                 'layout': {'width': {'fill': 160}, 'height': {'hug': 16}}},
        'label': _one_line('${props.label}', style(12.5, 600, 'primaryText', 1.25, letterSpacing=-0.2), {'hug': 60}, {'hug': 16}),
        'dot': {'type': 'box', 'layout': {'width': 6, 'height': 6}, 'decoration': {'fills': [{'color': 'secondaryText'}], 'radius': 9999},
                'bind': {'decoration.fills[0].color': '${= props.connected ? theme.success : theme.colors.tertiaryText}'}},
        'detail': {**_one_line('${props.detail}', style(11, 400, 'secondaryText', 1.3), {'fill': 160}, {'hug': 14}),
                   'bind': {'visible': "${= props.detail != ''}"}},
        'pill': {'type': 'row', 'children': ['pillIcon', 'pillText'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                 'layout': {'width': {'hug': 80}, 'height': {'hug': 22}, 'padding': [8, 3, 8, 3]},
                 'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 6},
                 'bind': {'decoration.strokes[0].color': '${= props.connected ? theme.colors.successTintBorder : theme.colors.primaryBorder}'},
                 'states': {'hovered': {'pill': HOVER}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onConfigure'}]}]},
        'pillIcon': {**icon('link', 'secondaryText', 10),
                     'bind': {'props.icon': "${= props.connected ? 'link' : 'key'}",
                              'props.color': '${= props.connected ? theme.success : theme.colors.secondaryText}'}},
        'pillText': {**text("${= props.connected ? 'Connected' : 'Set up'}", style(10.5, 500, 'secondaryText', 1.3), {'hug': 50}, {'hug': 14}),
                     'bind': {'props.style.color': '${= props.connected ? theme.success : theme.colors.secondaryText}'}},
    },
))

# StatusCardList (StatusCardList.tsx): connections one under another with hairlines between, and 10 px under
# them a line: when they were last checked, 11 in secondary, and a refresh button 12 with an 11 px icon.
add(component(
    'StatusCardList',
    'A list of connections with when they were last checked and a refresh button. Its children are StatusCard calls. Fires onRefresh.',
    'list',
    props=[prop('updatedLabel', STRING, '', 'When it was last checked (empty: no line).'),
           prop('refreshLabel', STRING, 'Refresh', 'The refresh button\'s label.')],
    events=['onRefresh'],
    children='list',
    previews=[preview('Default', 300, 40, updatedLabel='Checked 2 minutes ago')],
    nodes={
        'list': {'type': 'column', 'children': ['content', 'foot'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 300}, 'height': {'hug': 40}}},
        'content': {'type': 'slot'},
        'foot': {'type': 'row', 'children': ['updated', 'refresh'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                 'layout': {'width': {'fill': 300}, 'height': {'hug': 20}, 'margin': [0, 10, 0, 0]},
                 'bind': {'visible': "${= props.updatedLabel != ''}"}},
        'updated': text('${props.updatedLabel}', style(11, 400, 'secondaryText', 1.3, letterSpacing=-0.1), {'fill': 200}, {'hug': 14}),
        'refresh': {'type': 'row', 'children': ['refreshIcon', 'refreshText'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                    'layout': {'width': {'hug': 60}, 'height': {'hug': 20}, 'padding': [4, 2, 4, 2]}, 'decoration': {'radius': 4},
                    'states': {'hovered': {'refresh': HOVER}},
                    'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onRefresh'}]}]},
        'refreshIcon': icon('refresh', 'secondaryText', 11),
        'refreshText': text('${props.refreshLabel}', style(12, 400, 'secondaryText', 1.3), {'hug': 40}, {'hug': 16}),
    },
))

# RunHistoryList (RunHistoryList.tsx): past runs one under another (RunRecordRow calls, each after the first
# with its hairline), or, with none, a centered empty state: a 28 px list icon, 10 px, a title 13/600, 4 px,
# a line 12, all in tertiary.
add(component(
    'RunHistoryList',
    'A history of runs: its children are RunRecordRow calls (divider: true after the first). Empty shows a quiet message in their place.',
    'list',
    props=[prop('empty', BOOL, False, 'Nothing ran yet: the message shows.'),
           prop('emptyTitle', STRING, 'No runs yet', 'The message\'s title.'),
           prop('emptySubtitle', STRING, 'Runs will show here as they finish.', 'The line under it.')],
    children='list',
    previews=[preview('Empty', 300, 120, empty=True)],
    nodes={
        'list': {'type': 'column', 'children': ['content', 'blank'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 300}, 'height': {'hug': 120}}, 'decoration': {'fills': [{'color': 'primaryBackground'}]}},
        'content': {'type': 'slot'},
        'blank': {'type': 'column', 'children': ['blankIcon', 'blankTitle', 'blankLine'], 'props': {'crossAxisAlignment': 'center'},
                  'layout': {'width': {'fill': 300}, 'height': {'hug': 110}, 'padding': [16, 24, 16, 24]},
                  'bind': {'visible': '${props.empty}'}},
        'blankIcon': icon('list', 'tertiaryText', 28),
        'blankTitle': {**text('${props.emptyTitle}', style(13, 600, 'tertiaryText', 1.3), {'hug': 80}, {'hug': 17}),
                       'layout': {'width': {'hug': 80}, 'height': {'hug': 17}, 'margin': [0, 10, 0, 4]}},
        'blankLine': {**text('${props.emptySubtitle}', style(12, 400, 'tertiaryText', 1.4), {'hug': 200}, {'hug': 17}),
                      'props': {'text': '${props.emptySubtitle}', 'style': style(12, 400, 'tertiaryText', 1.4), 'textAlign': 'center'}},
    },
))

# StatsCarousel (StatsCarousel.tsx): one fact at a time: a label 10/700 in tertiary, upper case, with, at its
# end, an 18 px back button, a 6 px dot per fact (the shown one in secondary, the rest the border color) and
# an 18 px forward button (11 px chevrons); 8 px under, the fact 12 in secondary.
add(component(
    'StatsCarousel',
    'Several short facts shown one at a time, with arrows and dots to step through them. Which one shows is kept in your number variable.',
    'carousel',
    props=[prop('label', STRING, 'Stats', 'The small heading.'),
           prop('stats', STRINGS, ['12 files changed', '3 runs today', '98% passing'], 'The facts.', required=True),
           prop('index', var(NUMBER), '', 'The name of your number variable holding which fact shows (0 first).')],
    events=[{'key': 'onChanged', 'payload': NUMBER}],
    previews=[preview('First', 240, 44, index=0)],
    nodes={
        'carousel': {'type': 'column', 'children': ['head', 'fact'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 8},
                     'layout': {'width': {'fill': 240}, 'height': {'hug': 44}}},
        'head': {'type': 'row', 'children': ['label', 'back', 'dots', 'forward'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                 'layout': {'width': {'fill': 240}, 'height': {'hug': 18}}},
        'label': _one_line('${= upper(props.label)}', style(10, 700, 'tertiaryText', 1.3, letterSpacing=0.5), {'fill': 140}, {'hug': 13}),
        **{id_: {'type': 'row', 'children': [id_ + 'Glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                 'layout': {'width': 18, 'height': 18}, 'decoration': {'radius': 4},
                 'states': {'hovered': {id_: HOVER, id_ + 'Glyph': {'props': {'color': 'primaryText'}}}},
                 'actions': [{'trigger': 'click', 'actions': [
                     {'type': 'setVariable', 'variable': 'props.index', 'value': formula},
                     {'type': 'componentEvent', 'event': 'onChanged', 'value': '${props.index}'}]}]}
           for id_, formula in (('back', '${= (props.index - 1 + length(props.stats)) % max(1, length(props.stats))}'),
                                ('forward', '${= (props.index + 1) % max(1, length(props.stats))}'))},
        'backGlyph': icon('chevron_left', 'tertiaryText', 11),
        'forwardGlyph': icon('chevron_right', 'tertiaryText', 11),
        'dots': {'type': 'listView', 'children': ['dot'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False, 'spacing': 4},
                 'layout': {'width': {'hug': 26}, 'height': 6}, 'bind': {'data': '${props.stats}'}},
        'dot': {'type': 'box', 'layout': {'width': 6, 'height': {'fill': 6}}, 'decoration': {'fills': [{'color': 'primaryBorder'}], 'radius': 9999},
                'bind': {'selected': '${= index == props.index}'},
                'states': {'selected': {'dot': {'decoration': {'fills': [{'color': 'secondaryText'}]}}}},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'setVariable', 'variable': 'props.index', 'value': '${index}'}]}]},
        'fact': text("${= length(props.stats) > props.index ? props.stats[props.index] : ''}", style(12, 400, 'secondaryText', 1.4), {'fill': 240}, {'hug': 17}),
    },
))

# HistoryTimeline (HistoryTimeline.tsx): what happened, newest first, down a 2 px rail: each event an 8 px
# dot in the brand color (ringed in the secondary background) beside a card, radius 8, 8 x 10, bordered (the
# brand color when chosen): the event 11/700 with its time 11/600 in tertiary at the end, and 6 px under it
# a note 11 on a 1.4 line in secondary; 10 px between cards.
add(component(
    'HistoryTimeline',
    'What happened over time, as cards down a rail: an event, when, and a note each. The chosen event is kept in your variable. Fires onSelected.',
    'timeline',
    props=[prop('events', STRINGS, ['Published', 'Reviewed', 'Drafted'], 'The events, newest first.', required=True),
           prop('times', STRINGS, ['2h ago', 'Yesterday', 'Nov 12'], 'When each happened.'),
           prop('notes', STRINGS, [], 'A note under each (empty: none).'),
           prop('value', var(STRING), '', 'The name of your text variable holding the chosen event.')],
    events=[{'key': 'onSelected', 'payload': STRING}],
    previews=[preview('Default', 300, 150, notes=['Version 4 went live.', '', 'First outline.'], value='Published')],
    nodes={
        'timeline': {'type': 'stack', 'children': ['rail', 'list'], 'layout': {'width': {'fill': 300}, 'height': {'hug': 150}}},
        'rail': {'type': 'box', 'layout': {'width': 2, 'height': {'fill': 130}, 'x': {'start': 3}, 'y': {'start': 10, 'end': 18}},
                 'decoration': {'fills': [{'color': 'primaryBorder'}], 'radius': 9999}},
        'list': {'type': 'listView', 'children': ['event'], 'props': {'scrollable': False, 'spacing': 10},
                 'layout': {'width': {'fill': 300}, 'height': {'hug': 150}, 'padding': [0, 2, 0, 2]}, 'bind': {'data': '${props.events}'}},
        'event': {'type': 'row', 'children': ['dotBox', 'card'], 'props': {'crossAxisAlignment': 'start', 'spacing': 6},
                  'layout': {'width': {'fill': 300}, 'height': {'hug': 40}}},
        'dotBox': {'type': 'row', 'children': ['dot'], 'layout': {'width': 8, 'height': 18, 'padding': [0, 10, 0, 0]}},
        'dot': {'type': 'box', 'layout': {'width': 8, 'height': 8},
                'decoration': {'fills': [{'color': 'primary'}], 'strokes': [{'color': 'secondaryBackground'}], 'strokeWidth': 2, 'strokeAlign': 'outside', 'radius': 9999}},
        'card': {'type': 'column', 'children': ['line', 'note'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 6},
                 'layout': {'width': {'fill': 280}, 'height': {'hug': 32}, 'padding': [10, 8, 10, 8]},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8},
                 'bind': {'selected': '${= item == props.value}'},
                 'states': {'selected': {'card': {'decoration': {'strokes': [{'color': 'primary'}]}}},
                            'hovered': {'card': HOVER}},
                 'actions': [{'trigger': 'click', 'actions': [
                     {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                     {'type': 'componentEvent', 'event': 'onSelected', 'value': '${item}'}]}]},
        'line': {'type': 'row', 'children': ['name', 'time'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                 'layout': {'width': {'fill': 260}, 'height': {'hug': 15}}},
        'name': _one_line('${item}', style(11, 700, 'primaryText', 1.3), {'fill': 180}, {'hug': 15}),
        'time': {**text("${= length(props.times) > index ? props.times[index] : ''}", style(11, 600, 'tertiaryText', 1.3), {'hug': 40}, {'hug': 15}),
                 'bind': {'visible': '${= length(props.times) > index}'}},
        'note': {**text("${= length(props.notes) > index ? props.notes[index] : ''}", style(11, 400, 'secondaryText', 1.4), {'fill': 260}, {'hug': 16}),
                 'bind': {'visible': "${= length(props.notes) > index && props.notes[index] != ''}"}},
    },
))

# Terminal (Terminal.tsx): a log on a dark surface (#0D1117), padding 16, monospace 11.5 on a 1.5 line: each
# line a level in brackets at 60 % of its color and weight 600, then the message in the level's color: text
# #E6EDF3, debug #58A6FF, warn #D29922, error #FF7B72. With no lines, a centered message in #8B949E.
TERM = {'info': 'E6EDF3', 'debug': '58A6FF', 'warn': 'D29922', 'error': 'FF7B72'}
def _term(alpha):
    lv = "(length(props.levels) > index ? props.levels[index] : 'info')"
    return "${= %s == 'error' ? '#%s%s' : (%s == 'warn' ? '#%s%s' : (%s == 'debug' ? '#%s%s' : '#%s%s'))}" % (
        lv, alpha, TERM['error'], lv, alpha, TERM['warn'], lv, alpha, TERM['debug'], alpha, TERM['info'])
add(component(
    'Terminal',
    'A log on a dark surface in monospace: each line with its level (info, debug, warn or error) in color.',
    'terminal',
    props=[prop('lines', STRINGS, ['Started watcher', 'Scanning src/components'], 'The lines, oldest first.', required=True),
           prop('levels', STRINGS, [], 'One level per line: info, debug, warn or error (none: info).'),
           prop('emptyMessage', STRING, 'No logs yet.', 'Shown when there are no lines.')],
    previews=[preview('Mixed', 340, 110, lines=['Started watcher', 'Scanning src/components', 'Skipped generated file', 'Build failed'],
                      levels=['info', 'debug', 'warn', 'error'])],
    nodes={
        'terminal': {'type': 'column', 'children': ['list', 'empty'], 'props': {'crossAxisAlignment': 'stretch'},
                     'layout': {'width': {'fill': 340}, 'height': {'hug': 110}, 'padding': 16},
                     'decoration': {'fills': [{'color': '#FF0D1117'}], 'radius': 8, 'clip': 'antiAlias'}},
        'list': {'type': 'listView', 'children': ['line'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 308}, 'height': {'hug': 70}}, 'bind': {'data': '${props.lines}'}},
        'line': {'type': 'row', 'children': ['level', 'message'], 'props': {'crossAxisAlignment': 'start', 'spacing': 6},
                 'layout': {'width': {'fill': 308}, 'height': {'hug': 17}}},
        'level': {**text("[${= upper(length(props.levels) > index ? props.levels[index] : 'info')}]",
                         style(11.5, 600, '#99E6EDF3', 1.5, fontFamily='monospace'), {'hug': 44}, {'hug': 17}),
                  'bind': {'props.style.color': _term('99')}},
        'message': {**text('${item}', style(11.5, 400, '#FFE6EDF3', 1.5, fontFamily='monospace'), {'fill': 250}, {'hug': 17}),
                    'bind': {'props.style.color': _term('FF')}},
        'empty': {'type': 'row', 'children': ['emptyText'], 'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
                  'layout': {'width': {'fill': 308}, 'height': 120}, 'bind': {'visible': '${= length(props.lines) == 0}'}},
        'emptyText': text('${props.emptyMessage}', style(11.5, 400, '#FF8B949E', 1.5, fontFamily='monospace'), {'hug': 120}, {'hug': 17}),
    },
))

MONO_105 = style(10.5, 400, 'primaryText', 18 / 10.5, fontFamily='monospace')

# DiffViewer (DiffViewer.tsx, unified): what changed in a file, bordered, radius 5: a 28 px header on the
# secondary background, 7 px either side, 6 px apart: a 15 px letter for the change (9.5/700), the file name
# in monospace 10.5 and, at its end, +added in green and -removed in red; then the lines in monospace 10.5,
# 10 px either side: an added line on the green tint, a removed one on the red tint.
add(component(
    'DiffViewer',
    'What changed in a file: a header with the file\'s name and counts, then the lines, added ones green and removed ones red. A line starts with "+", "-" or a space.',
    'viewer',
    props=[prop('fileName', STRING, 'file.txt', 'The file\'s name.', required=True),
           prop('lines', STRINGS, [' unchanged', '-removed', '+added'], 'The lines, each starting with "+", "-" or a space.', required=True),
           prop('status', enum('modified', 'added', 'deleted'), 'modified', 'What happened to the file: the header\'s letter.')],
    previews=[preview('Modified', 340, 110, fileName='src/total.ts',
                      lines=[' const total = items', '-  .map((i) => i.cost)', '+  .map((i) => i.price)', '   .reduce((a, b) => a + b, 0);'])],
    nodes={
        'viewer': {'type': 'column', 'children': ['header', 'list'], 'props': {'crossAxisAlignment': 'stretch'},
                   'layout': {'width': {'fill': 340}, 'height': {'hug': 110}, 'padding': 1},
                   'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 5, 'clip': 'antiAlias'}},
        'header': {'type': 'row', 'children': ['strut', 'letterBox', 'name', 'added', 'removed'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'fill': 338}, 'height': {'hug': 28}, 'padding': [7, 0, 7, 0]},
                   'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 27}},
        'letterBox': {'type': 'row', 'children': ['letter'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                      'layout': {'width': 15, 'height': 15}, 'decoration': {'fills': [{'color': 'warningTint'}], 'radius': 3},
                      'bind': {'decoration.fills[0].color': "${= props.status == 'added' ? theme.colors.successTint : (props.status == 'deleted' ? theme.colors.errorTint : theme.colors.warningTint)}"}},
        'letter': {**text("${= props.status == 'added' ? 'A' : (props.status == 'deleted' ? 'D' : 'M')}", style(9.5, 700, 'warning', 1.0), {'hug': 7}, {'hug': 10}),
                   'bind': {'props.style.color': "${= props.status == 'added' ? theme.success : (props.status == 'deleted' ? theme.error : theme.warning)}"}},
        'name': _one_line('${props.fileName}', style(10.5, 400, 'primaryText', 1.3, fontFamily='monospace'), {'fill': 200}, {'hug': 14}),
        'added': text("+${= count(props.lines, l => startsWith(l, '+'))}", style(10.5, 600, 'success', 1.3, fontFamily='monospace'), {'hug': 14}, {'hug': 14}),
        'removed': text("-${= count(props.lines, l => startsWith(l, '-'))}", style(10.5, 600, 'error', 1.3, fontFamily='monospace'), {'hug': 14}, {'hug': 14}),
        'list': {'type': 'listView', 'children': ['line'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 338}, 'height': {'hug': 72}, 'padding': [0, 4, 0, 4]}, 'bind': {'data': '${props.lines}'}},
        'line': {'type': 'row', 'children': ['sign', 'code'], 'props': {'crossAxisAlignment': 'start', 'spacing': 6},
                 'layout': {'width': {'fill': 338}, 'height': {'hug': 18}, 'padding': [10, 0, 10, 0]},
                 'decoration': {'fills': [{'color': '#00000000'}]},
                 'bind': {'decoration.fills[0].color': "${= startsWith(item, '+') ? theme.colors.successTint : (startsWith(item, '-') ? theme.colors.errorTint : '#00000000')}"}},
        'sign': {**text("${= startsWith(item, '+') ? '+' : (startsWith(item, '-') ? '-' : ' ')}", {**MONO_105, 'color': 'tertiaryText'}, 8, {'hug': 18}),
                 'bind': {'props.style.color': "${= startsWith(item, '+') ? theme.success : (startsWith(item, '-') ? theme.error : theme.colors.tertiaryText)}"}},
        'code': text('${= substring(item, 1)}', MONO_105, {'fill': 300}, {'hug': 18}),
    },
))

# FileUploader (FileUploader.tsx): where files are dropped or picked: a dashed 1 px border, radius 12,
# padding 32, centered: a 48 px upload icon in tertiary, 16 px, a line 14, a hint 12 in tertiary. Compact: a
# solid border, radius 7, 7 x 12, a 16 px icon and the line 12. Under it the picked files, 8 px apart, each
# on the tertiary background, radius 8, padding 12, 12 px apart: a 20 px file icon, the name 14/500 over its
# size 12 in tertiary, and a 16 px x.
add(component(
    'FileUploader',
    'Where files are dropped or picked, with the picked files listed under it. Fires onPick when pressed and onRemove with a file\'s name.',
    'uploader',
    props=[prop('label', STRING, 'Drop files here or click to browse', 'What the drop area says.'),
           prop('hint', STRING, '', 'A muted line under it (accepted types, a size limit).'),
           prop('compact', BOOL, False, 'A small bordered button in place of the drop area.'),
           prop('files', STRINGS, [], 'The picked files\' names.'),
           prop('sizes', STRINGS, [], 'One size per file (empty: none).')],
    events=['onPick', {'key': 'onRemove', 'payload': STRING}],
    previews=[preview('Empty', 320, 160, hint='PDF or PNG, up to 10 MB'),
              preview('Compact', 200, 34, compact=True, label='Upload file')],
    nodes={
        'uploader': {'type': 'column', 'children': ['drop', 'button', 'list'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 16},
                     'layout': {'width': {'fill': 320}, 'height': {'hug': 160}},
                     'bind': {'props.spacing': '${= props.compact ? 8 : 16}'}},
        'drop': {'type': 'column', 'children': ['dropIcon', 'dropTexts'], 'props': {'crossAxisAlignment': 'center', 'spacing': 16},
                 'layout': {'width': {'fill': 320}, 'height': {'hug': 160}, 'padding': 32},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'secondaryBorder'}], 'radius': 12, 'dashPattern': [5, 4]},
                 'bind': {'visible': '${= !props.compact}'},
                 'states': {'hovered': {'drop': {'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primary'}]}}}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPick'}]}]},
        'dropIcon': icon('upload', 'tertiaryText', 48),
        'dropLabel': {**text('${props.label}', style(14, 400, 'primaryText', 1.4), {'hug': 200}, {'hug': 20}),
                      'props': {'text': '${props.label}', 'style': style(14, 400, 'primaryText', 1.4), 'textAlign': 'center'}},
        'dropHint': {**text('${props.hint}', style(12, 400, 'tertiaryText', 1.4), {'hug': 140}, {'hug': 17}),
                     'bind': {'visible': "${= props.hint != ''}"}},
        'dropTexts': {'type': 'column', 'children': ['dropLabel', 'dropHint'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                      'layout': {'width': {'hug': 200}, 'height': {'hug': 40}}},
        'button': {'type': 'row', 'children': ['buttonInner'], 'layout': {'width': {'fill': 320}, 'height': {'hug': 32}},
                   'bind': {'visible': '${props.compact}'}},
        'buttonInner': {'type': 'row', 'children': ['buttonIcon', 'buttonLabel'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                        'layout': {'width': {'hug': 140}, 'height': {'hug': 32}, 'padding': [12, 7, 12, 7]},
                        'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'secondaryBorder'}], 'radius': 7},
                        'states': {'hovered': {'buttonInner': HOVER}, 'pressed': {'buttonInner': PRESS}},
                        'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPick'}]}]},
        'buttonIcon': icon('upload', 'secondaryText', 16),
        'buttonLabel': text('${props.label}', style(12, 400, 'primaryText', 1.4), {'hug': 90}, {'hug': 17}),
        'list': {'type': 'listView', 'children': ['file'], 'props': {'scrollable': False, 'spacing': 8},
                 'layout': {'width': {'fill': 320}, 'height': {'hug': 48}},
                 'bind': {'data': '${props.files}', 'visible': '${= length(props.files) > 0}'}},
        'file': {'type': 'row', 'children': ['fileIcon', 'fileTexts', 'remove'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                 'layout': {'width': {'fill': 320}, 'height': {'hug': 48}, 'padding': 12},
                 'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 8}},
        'fileIcon': icon('description', 'secondaryText', 20),
        'fileTexts': {'type': 'column', 'children': ['fileName', 'fileSize'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 2},
                      'layout': {'width': {'fill': 200}, 'height': {'hug': 20}}},
        'fileName': _one_line('${item}', style(14, 500, 'primaryText', 1.4), {'fill': 200}, {'hug': 20}),
        'fileSize': {**text("${= length(props.sizes) > index ? props.sizes[index] : ''}", style(12, 400, 'tertiaryText', 1.4), {'fill': 200}, {'hug': 17}),
                     'bind': {'visible': "${= length(props.sizes) > index && props.sizes[index] != ''}"}},
        'remove': {'type': 'row', 'children': ['x'], 'layout': {'width': {'hug': 24}, 'height': {'hug': 24}, 'padding': 4}, 'decoration': {'radius': 4},
                   'tooltip': 'Remove',
                   'states': {'hovered': {'remove': HOVER}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onRemove', 'value': '${item}'}]}]},
        'x': icon('close', 'secondaryText', 16),
    },
))

# CommandPalette (CommandPalette.tsx): the surface that finds a command by typing: radius 12, bordered, a deep
# shadow: a search row over a hairline (padding 16, a 20 px search icon, 12 px, the text 16), then the
# commands, each 12 x 16 with 12 px between an icon and the label 14, and a shortcut at the end on a bordered
# chip (4 x 8, radius 6, 11/600); the one under the pointer on the hover wash. Nothing matches: a centered
# line 14 in secondary, padding 32.
add(component(
    'CommandPalette',
    'The surface that finds a command by typing: a search row over the commands that match. The typed text is kept in your variable. Fires onSelected with the command.',
    'palette',
    props=[prop('value', var(STRING), '', 'The name of your text variable holding what is typed.'),
           prop('placeholder', STRING, 'Type a command or search...', 'Shown while empty.'),
           prop('commands', STRINGS, ['New file', 'Open settings', 'Toggle theme'], 'The commands.', required=True),
           prop('icons', STRINGS, [], 'One icon per command (empty: none).'),
           prop('shortcuts', STRINGS, [], 'One shortcut per command (empty: none).'),
           prop('emptyMessage', STRING, 'No results found', 'Shown when nothing matches.')],
    events=[{'key': 'onSelected', 'payload': STRING}],
    previews=[preview('Default', 420, 200, icons=['note_add', 'settings', 'dark_mode'], shortcuts=['Ctrl+N', 'Ctrl+,', ''])],
    nodes={
        'palette': {'type': 'column', 'children': ['search', 'list', 'empty'], 'props': {'crossAxisAlignment': 'stretch'},
                    'layout': {'width': {'fill': 420}, 'height': {'hug': 200}, 'padding': 1},
                    'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12,
                                   'clip': 'antiAlias', 'effects': [shadow('#40000000', 20, 50, -12)]}},
        'search': {'type': 'row', 'children': ['searchIcon', 'field'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                   'layout': {'width': {'fill': 418}, 'height': {'hug': 56}, 'padding': 16},
                   'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'searchIcon': icon('search', 'secondaryText', 20),
        'field': {**_bare_field(16, autofocus=True), 'actions': [{'trigger': {'type': 'changed'}, 'actions': [
            {'type': 'setVariable', 'variable': 'props.value', 'value': '${result}'}]}]},
        'list': {'type': 'listView', 'children': ['command'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 418}, 'height': {'hug': 132}, 'padding': [0, 4, 0, 4]}, 'bind': {'data': '${props.commands}'}},
        'command': {'type': 'row', 'children': ['glyph', 'label', 'chip'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                    'layout': {'width': {'fill': 418}, 'height': {'hug': 44}, 'padding': [16, 12, 16, 12]},
                    'decoration': {'fills': [{'color': '#00000000'}]},
                    'bind': {'visible': "${= props.value == '' || contains(lower(item), lower(props.value))}"},
                    'states': {'hovered': {'command': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                    'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onSelected', 'value': '${item}'}]}]},
        'glyph': {**icon('circle', 'secondaryText', 18),
                  'bind': {'visible': "${= length(props.icons) > index && props.icons[index] != ''}",
                           'props.icon': "${= length(props.icons) > index && props.icons[index] != '' ? props.icons[index] : 'circle'}"}},
        'label': _one_line('${item}', style(14, 400, 'primaryText', 1.4), {'fill': 260}, {'hug': 20}),
        'chip': {'type': 'row', 'children': ['shortcut'], 'layout': {'width': {'hug': 40}, 'height': {'hug': 23}, 'padding': [8, 4, 8, 4]},
                 'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 6},
                 'bind': {'visible': "${= length(props.shortcuts) > index && props.shortcuts[index] != ''}"}},
        'shortcut': text("${= length(props.shortcuts) > index ? props.shortcuts[index] : ''}", style(11, 600, 'secondaryText', 1.3), {'hug': 30}, {'hug': 15}),
        'empty': {'type': 'row', 'children': ['emptyText'], 'props': {'mainAxisAlignment': 'center'},
                  'layout': {'width': {'fill': 418}, 'height': {'hug': 84}, 'padding': 32},
                  'bind': {'visible': "${= props.value != '' && !any(props.commands, c => contains(lower(c), lower(props.value)))}"}},
        'emptyText': text('${props.emptyMessage}', style(14, 400, 'secondaryText', 1.4), {'hug': 120}, {'hug': 20}),
    },
))

# NavigationMenu (NavigationMenu.tsx, vertical): a bordered panel, radius 12, padding 16, its entries 8 px
# apart: each padded 12, radius 8, with a 20 px icon, 12 px, the label 14/500 and a badge at its end
# (2 x 6, 12/700 white on red for a count, blue for a word); hovered: a soft wash; chosen: the brand tint.
add(component(
    'NavigationMenu',
    'A panel of places to go: icons and labels, with badges for news. The chosen one is kept in your variable. Fires onChanged.',
    'menu',
    props=[prop('items', STRINGS, ['Dashboard', 'Projects', 'Team'], 'The places\' labels.', required=True),
           prop('icons', STRINGS, ['dashboard', 'folder', 'group'], 'One icon per place.'),
           prop('badges', STRINGS, [], 'One badge per place: a count, a word, or empty.'),
           prop('value', var(STRING), '', 'The name of your text variable holding the chosen label.')],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Default', 240, 180, badges=['', '4', 'New'], value='Dashboard')],
    nodes={
        'menu': {'type': 'column', 'children': ['list'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 240}, 'height': {'hug': 180}, 'padding': 16},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12}},
        'list': {'type': 'listView', 'children': ['entry'], 'props': {'scrollable': False, 'spacing': 8},
                 'layout': {'width': {'fill': 208}, 'height': {'hug': 150}}, 'bind': {'data': '${props.items}'}},
        'entry': {'type': 'row', 'children': ['glyph', 'label', 'badge'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                  'layout': {'width': {'fill': 208}, 'height': {'hug': 44}, 'padding': 12},
                  'decoration': {'fills': [{'color': '#00000000'}], 'radius': 8},
                  'bind': {'selected': '${= item == props.value}'},
                  'states': {'hovered': {'entry': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}},
                             'selected': {'entry': {'decoration': {'fills': [{'color': 'primaryTint'}]}},
                                          'glyph': {'props': {'color': 'primary'}},
                                          'label': {'props': {'style': {'color': 'primary'}}}}},
                  'actions': [{'trigger': 'click', 'actions': [
                      {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                      {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'glyph': {**icon('circle', 'secondaryText', 20),
                  'bind': {'visible': '${= length(props.icons) > index}',
                           'props.icon': "${= length(props.icons) > index ? props.icons[index] : 'circle'}"}},
        'label': _one_line('${item}', style(14, 500, 'primaryText', 1.4), {'fill': 120}, {'hug': 20}),
        'badge': {'type': 'row', 'children': ['badgeText'], 'layout': {'width': {'hug': 20}, 'height': {'hug': 20}, 'padding': [6, 2, 6, 2]},
                  'decoration': {'fills': [{'color': '#FFEF4444'}], 'radius': 9999},
                  'bind': {'visible': "${= length(props.badges) > index && props.badges[index] != ''}",
                           'decoration.fills[0].color': "${= length(props.badges) > index && matches(props.badges[index], '^[0-9+]+$') ? '#FFEF4444' : '#FF3B82F6'}"}},
        'badgeText': text("${= length(props.badges) > index ? props.badges[index] : ''}", style(12, 700, '#FFFFFFFF', 1.3), {'hug': 8}, {'hug': 16}),
    },
))

# Sidebar (Sidebar.tsx, open): an app's side column, 256 px, a hairline at its edge: a header over a hairline
# (at least 68 px, padding 12) with the brand 13/650; a section label 10/650 in tertiary, upper case, 4 12 6;
# the entries 2 px apart, each 34 px, radius 7, 12 px either side, a 16 px icon, the label 13 in secondary
# and a count on a small chip (10, 2 x 5, radius 4); the chosen one on an 11 % brand tint in the brand color,
# weight 600; a footer over a hairline for what the call puts there.
add(component(
    'Sidebar',
    'An app\'s side column: a brand, a list of places with icons and counts, and a footer for what the call puts there. The chosen place is kept in your variable. Fires onChanged.',
    'sidebar',
    props=[prop('brand', STRING, 'Workspace', 'The name at the top.'),
           prop('sectionLabel', STRING, '', 'A small heading over the places (empty: none).'),
           prop('items', STRINGS, ['Home', 'Projects', 'Settings'], 'The places\' labels.', required=True),
           prop('icons', STRINGS, ['home', 'folder', 'settings'], 'One icon per place.'),
           prop('badges', STRINGS, [], 'One count per place (empty: none).'),
           prop('value', var(STRING), '', 'The name of your text variable holding the chosen label.')],
    events=[{'key': 'onChanged', 'payload': STRING}],
    slots=['footer'],
    previews=[preview('Default', 256, 300, sectionLabel='Workspace', badges=['', '12', ''], value='Home')],
    nodes={
        'sidebar': {'type': 'column', 'children': ['header', 'nav', 'foot'], 'props': {'crossAxisAlignment': 'stretch'},
                    'layout': {'width': 256, 'height': {'fill': 300}},
                    'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'right'}},
        'header': {'type': 'row', 'children': ['brand'], 'props': {'crossAxisAlignment': 'center', 'spacing': 6},
                   'layout': {'width': {'fill': 256}, 'height': {'hug': 68}, 'padding': 12, 'constraints': {'minHeight': 68}},
                   'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'brand': _one_line('${props.brand}', style(13, 600, 'primaryText', 1.3), {'fill': 220}, {'hug': 17}),
        'nav': {'type': 'column', 'children': ['section', 'list'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 2},
                'layout': {'width': {'fill': 256}, 'height': {'fill': 0}, 'padding': [8, 12, 8, 12]}},
        'section': {**text('${= upper(props.sectionLabel)}', style(10, 600, 'tertiaryText', 1.3, letterSpacing=0.7), {'fill': 216}, {'hug': 13}),
                    'layout': {'width': {'fill': 216}, 'height': {'hug': 13}, 'margin': [12, 4, 12, 6]},
                    'bind': {'visible': "${= props.sectionLabel != ''}"}},
        'list': {'type': 'listView', 'children': ['entry'], 'props': {'scrollable': False, 'spacing': 2},
                 'layout': {'width': {'fill': 240}, 'height': {'hug': 106}}, 'bind': {'data': '${props.items}'}},
        'entry': {'type': 'row', 'children': ['strut', 'glyph', 'label', 'badge'], 'props': {'crossAxisAlignment': 'center', 'spacing': 10},
                  'layout': {'width': {'fill': 240}, 'height': {'hug': 34}, 'padding': [12, 0, 12, 0]},
                  'decoration': {'fills': [{'color': '#00000000'}], 'radius': 7},
                  'bind': {'selected': '${= item == props.value}'},
                  'states': {'hovered': {'entry': {'decoration': {'fills': [{'color': 'tertiaryBackground'}]}}},
                             'selected': {'entry': {'decoration': {'fills': [{'color': 'primaryTint'}]}},
                                          'glyph': {'props': {'color': 'primary'}},
                                          'label': {'props': {'style': {'color': 'primary', 'fontWeight': 600}}}}},
                  'actions': [{'trigger': 'click', 'actions': [
                      {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                      {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 34}},
        'glyph': {**icon('circle', 'secondaryText', 16),
                  'bind': {'visible': '${= length(props.icons) > index}',
                           'props.icon': "${= length(props.icons) > index ? props.icons[index] : 'circle'}"}},
        'label': _one_line('${item}', style(13, 400, 'secondaryText', 1.3), {'fill': 140}, {'hug': 17}),
        'badge': {'type': 'row', 'children': ['badgeText'], 'layout': {'width': {'hug': 18}, 'height': {'hug': 17}, 'padding': [5, 2, 5, 2]},
                  'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 4},
                  'bind': {'visible': "${= length(props.badges) > index && props.badges[index] != ''}"}},
        'badgeText': text("${= length(props.badges) > index ? props.badges[index] : ''}", style(10, 400, 'secondaryText', 1.3), {'hug': 8}, {'hug': 13}),
        'foot': {'type': 'column', 'children': ['footer'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 2},
                 'layout': {'width': {'fill': 256}, 'height': {'hug': 20}, 'padding': [8, 10, 8, 10]},
                 'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'top'}},
        'footer': {'type': 'slot', 'props': {'name': 'footer'}},
    },
))

# PromptInput (PromptInput.tsx): where a prompt is written: radius 16, bordered, raised by a soft shadow; a
# row padded 16, 12 px apart, its parts at the bottom: a 20 px paperclip in tertiary, the text 14 over as
# many lines as it needs, and a 32 px send button, radius 8, the brand color with a 16 px white icon (muted
# while there is nothing to send); under it a hint 12 in tertiary, 16 px either side, 12 below.
add(component(
    'PromptInput',
    'Where a prompt is written: a growing text box with an attach button and a send button. Its text is kept in your variable. Fires onSubmitted with the text and onAttach.',
    'box',
    props=[prop('value', var(STRING), '', 'The name of your text variable.'),
           prop('placeholder', STRING, 'Ask anything...', 'Shown while empty.'),
           prop('hint', STRING, '', 'A muted line under the text (empty: none).'),
           prop('attachable', BOOL, True, 'The paperclip button.'),
           prop('busy', BOOL, False, 'Working: the send button shows a spinner and stops.')],
    events=[{'key': 'onChanged', 'payload': STRING}, {'key': 'onSubmitted', 'payload': STRING}, 'onAttach'],
    previews=[preview('Empty', 360, 66), preview('Hint', 360, 92, value='Summarize the launch plan', hint='Enter to send, Shift+Enter for a new line')],
    nodes={
        'box': {'type': 'column', 'children': ['row', 'hint'], 'props': {'crossAxisAlignment': 'stretch'},
                'layout': {'width': {'fill': 360}, 'height': {'hug': 66}},
                'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 16,
                               'effects': SHADOWS_LIGHT['level2']},
                'bind': {'decoration.effects': '${theme.shadows.level2}'},
                'states': {'focused': {'box': {'decoration': {'strokes': [{'color': 'focusBorder'}]}}}}},
        'row': {'type': 'row', 'children': ['attach', 'field', 'send'], 'props': {'crossAxisAlignment': 'end', 'spacing': 12},
                'layout': {'width': {'fill': 360}, 'height': {'hug': 64}, 'padding': 16}},
        'attach': {'type': 'row', 'children': ['clip'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                   'layout': {'width': {'hug': 28}, 'height': {'hug': 32}, 'padding': [4, 6, 4, 6]}, 'decoration': {'radius': 6},
                   'bind': {'visible': '${props.attachable}'}, 'tooltip': 'Attach',
                   'states': {'hovered': {'attach': HOVER, 'clip': {'props': {'color': 'primaryText'}}}},
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onAttach'}]}]},
        'clip': icon('attach_file', 'tertiaryText', 20),
        'field': {**_bare_field(14, maxLines=6, minLines=1, textInputAction='send'),
                  'layout': {'width': {'fill': 240}, 'height': {'hug': 20}, 'margin': [0, 0, 0, 6]},
                  'actions': _typed()},
        'send': {'type': 'row', 'children': ['spin', 'bolt'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                 'layout': {'width': 32, 'height': 32}, 'decoration': {'fills': [{'color': 'primary'}], 'radius': 8},
                 'bind': {'decoration.fills[0].color': "${= props.value != '' && !props.busy ? theme.primary : theme.colors.tertiaryBackground}"},
                 'tooltip': 'Send',
                 'states': {'hovered': {'send': HOVER}, 'pressed': {'send': PRESS}},
                 'actions': [{'trigger': {'type': 'click', 'when': "props.value != '' && !props.busy"}, 'actions': [
                     {'type': 'componentEvent', 'event': 'onSubmitted', 'value': '${props.value}'}]}]},
        'spin': {'type': 'circularProgressIndicator', 'layout': {'width': 14, 'height': 14}, 'props': {'color': 'tertiaryText', 'strokeWidth': 2},
                 'bind': {'visible': '${props.busy}'}},
        'bolt': {**icon('arrow_upward', '#FFFFFFFF', 16),
                 'bind': {'visible': '${= !props.busy}', 'props.color': "${= props.value != '' ? '#FFFFFFFF' : theme.colors.tertiaryText}"}},
        'hint': {**text('${props.hint}', style(12, 400, 'tertiaryText', 1.4), {'fill': 328}, {'hug': 17}),
                 'layout': {'width': {'fill': 328}, 'height': {'hug': 17}, 'margin': [16, 0, 16, 12]},
                 'bind': {'visible': "${= props.hint != ''}"}},
    },
))

# Tree (Tree.tsx): an outline: each row 8 px around, 16 px further in per level, 14: an 18 px chevron when it
# holds rows (else its room), then an 18 px icon in secondary, 8 px, the label; hovered: the hover wash.
add(component(
    'Tree',
    'An outline of nested rows: give each row its label and how deep it sits. A row followed by a deeper one shows a chevron. Fires onSelected with the label.',
    'tree',
    props=[prop('labels', STRINGS, ['src', 'components', 'Button.tsx', 'README.md'], 'The rows, top to bottom.', required=True),
           prop('depths', STRINGS, ['0', '1', '2', '0'], 'How deep each row sits: 0 at the edge.', required=True),
           prop('icons', STRINGS, [], 'One icon per row (empty: a folder for a row with rows under it, a file otherwise).'),
           prop('value', var(STRING), '', 'The name of your text variable holding the chosen label.')],
    events=[{'key': 'onSelected', 'payload': STRING}],
    previews=[preview('Default', 260, 140, value='Button.tsx')],
    nodes={
        'tree': {'type': 'listView', 'children': ['row'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 260}, 'height': {'hug': 140}}, 'bind': {'data': '${props.labels}'}},
        'row': {'type': 'row', 'children': ['indent', 'chevron', 'glyph', 'label'], 'props': {'crossAxisAlignment': 'center'},
                'layout': {'width': {'fill': 260}, 'height': {'hug': 35}, 'padding': 8},
                'decoration': {'fills': [{'color': '#00000000'}], 'radius': 6},
                'bind': {'selected': '${= item == props.value}'},
                'states': {'hovered': {'row': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}},
                           'selected': {'row': {'decoration': {'fills': [{'color': 'primaryTint'}]}}}},
                'actions': [{'trigger': 'click', 'actions': [
                    {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                    {'type': 'componentEvent', 'event': 'onSelected', 'value': '${item}'}]}]},
        'indent': {'type': 'box', 'layout': {'width': 0, 'height': 1},
                   'bind': {'layout.width': '${= 16 * (length(props.depths) > index ? number(props.depths[index]) : 0)}'}},
        'chevron': {**icon('expand_more', 'secondaryText', 18), 'layout': {'width': 18, 'height': 18, 'margin': [0, 0, 4, 0]},
                    'bind': {'opacity': '${= length(props.depths) > index + 1 && number(props.depths[index + 1]) > number(props.depths[index]) ? 1 : 0}'}},
        'glyph': {**icon('description', 'secondaryText', 18), 'layout': {'width': 18, 'height': 18, 'margin': [0, 0, 8, 0]},
                  'bind': {'props.icon': "${= length(props.icons) > index && props.icons[index] != '' ? props.icons[index] : (length(props.depths) > index + 1 && number(props.depths[index + 1]) > number(props.depths[index]) ? 'folder' : 'description')}"}},
        'label': _one_line('${item}', style(14, 400, 'primaryText', 1.35), {'fill': 160}, {'hug': 19}),
    },
))

# BrowserTabs (BrowserTabs.tsx): tabs as in a browser, over a hairline: each 6 x 12 (7 x 10 small), 12, 4 px
# between an icon and the label, a 1 px border round its top, corners 6 at the top; the chosen one on the
# page color in the primary text, weight 500; the rest on a 2 % wash in 40 % text; an x to close on a round
# 16 px button; an optional + after the last.
add(component(
    'BrowserTabs',
    'Tabs as in a browser: open documents side by side, each with an x. The chosen one is kept in your variable. Fires onChanged, onClose with the label, and onAdd.',
    'bar',
    props=[prop('tabs', STRINGS, ['Overview', 'Report.pdf', 'Notes'], 'The tabs\' labels.', required=True),
           prop('icons', STRINGS, [], 'One icon per tab (empty: none).'),
           prop('value', var(STRING), '', 'The name of your text variable holding the chosen label.'),
           prop('closable', BOOL, True, 'An x on each tab.'),
           prop('showAdd', BOOL, False, 'A + after the tabs.')],
    events=[{'key': 'onChanged', 'payload': STRING}, {'key': 'onClose', 'payload': STRING}, 'onAdd'],
    previews=[preview('Default', 340, 30, value='Report.pdf', showAdd=True)],
    nodes={
        'bar': {'type': 'row', 'children': ['list', 'add'], 'props': {'crossAxisAlignment': 'end', 'spacing': 4},
                'layout': {'width': {'fill': 340}, 'height': {'hug': 30}},
                'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'list': {'type': 'listView', 'children': ['tab'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False},
                 'layout': {'width': {'hug': 280}, 'height': 29}, 'bind': {'data': '${props.tabs}'}},
        'tab': {'type': 'row', 'children': ['glyph', 'label', 'close'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                'layout': {'width': {'hug': 90}, 'height': {'fill': 29}, 'padding': [12, 0, 8, 0]},
                'decoration': {'fills': [{'color': 'hoverOverlay'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'top',
                               'radius': [6, 6, 0, 0]},
                'bind': {'selected': '${= item == props.value}'},
                'states': {'selected': {'tab': {'decoration': {'fills': [{'color': 'primaryBackground'}]}},
                                        'label': {'props': {'style': {'color': 'primaryText', 'fontWeight': 500}}},
                                        'glyph': {'props': {'color': 'primaryText'}}},
                           'hovered': {'label': {'props': {'style': {'color': 'secondaryText'}}}}},
                'actions': [{'trigger': 'click', 'actions': [
                    {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                    {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'glyph': {**icon('description', 'tertiaryText', 14),
                  'bind': {'visible': "${= length(props.icons) > index && props.icons[index] != ''}",
                           'props.icon': "${= length(props.icons) > index && props.icons[index] != '' ? props.icons[index] : 'description'}"}},
        'label': _one_line('${item}', style(12, 400, 'tertiaryText', 1.3), {'hug': 60}, {'hug': 16}),
        'close': {'type': 'row', 'children': ['x'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 16, 'height': 16}, 'decoration': {'radius': 9999},
                  'bind': {'visible': '${props.closable}'},
                  'states': {'hovered': {'close': {'decoration': {'fills': [{'color': 'pressedOverlay'}]}}, 'x': {'props': {'color': 'primaryText'}}}},
                  'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onClose', 'value': '${item}'}]}]},
        'x': icon('close', 'tertiaryText', 12),
        'add': {'type': 'row', 'children': ['plus'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                'layout': {'width': 24, 'height': 24, 'margin': [0, 0, 0, 3]}, 'decoration': {'radius': 6},
                'bind': {'visible': '${props.showAdd}'}, 'tooltip': 'New tab',
                'states': {'hovered': {'add': HOVER, 'plus': {'props': {'color': 'primaryText'}}}},
                'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onAdd'}]}]},
        'plus': icon('add', 'tertiaryText', 14),
    },
))

# Combobox (Combobox.tsx): a choice you can search: a trigger 32, 40 or 48 px high, radius 12, bordered, 12 px
# either side, with the choice (or the placeholder in tertiary) and a 16 px chevron; pressed, a panel opens
# under it, radius 12, bordered, with a search row (8 px around a bordered field, radius 8, 6 x 10, a 16 px
# search icon) over the options, each 8 x 12 (6 small, 12 large), the chosen one on a 14 % brand tint with a
# 16 px check; nothing matches: a centered line, padding 16. Here the panel opens in place, under the trigger.
CB = {'small': 32, 'medium': 40, 'large': 48}
add(component(
    'Combobox',
    'A choice from a list you can search: press it and a panel with a search box opens under it, in place. The choice is kept in your variable. Fires onChanged.',
    'column',
    props=[prop('options', STRINGS, ['Apple', 'Banana', 'Cherry'], 'The choices.', required=True),
           prop('value', var(STRING), '', 'The name of your text variable holding the choice.'),
           prop('placeholder', STRING, 'Select an option...', 'Shown with no choice.'),
           prop('searchPlaceholder', STRING, 'Search...', 'Shown in the empty search box.'),
           prop('size', enum(*CB), 'medium', 'small (32), medium (40) or large (48).'),
           prop('open', BOOL, False, 'Whether the panel shows at first.'),
           prop('enabled', BOOL, True, 'False dims it and stops presses.')],
    events=[{'key': 'onChanged', 'payload': STRING}],
    variables=[{'name': 'toggled', 'type': 'boolean', 'value': False}, {'name': 'query', 'type': 'text', 'value': ''}],
    previews=[preview('Closed', 260, 40, value='Banana'), preview('Open', 260, 220, value='Banana', open=True)],
    nodes={
        'column': {'type': 'column', 'children': ['trigger', 'panel'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 4},
                   'layout': {'width': {'fill': 260}, 'height': {'hug': 40}}, 'bind': {'opacity': '${= props.enabled ? 1 : 0.5}'}},
        'trigger': {'type': 'row', 'children': ['strut', 'choice', 'chevron'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                    'layout': {'width': {'fill': 260}, 'height': {'hug': 40}, 'padding': [12, 0, 12, 0]},
                    'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12},
                    'bind': {'decoration.strokes[0].color': '${= (props.open != toggled) ? theme.primary : theme.colors.primaryBorder}'},
                    'states': {'hovered': {'trigger': HOVER}},
                    'actions': [{'trigger': {'type': 'click', 'when': 'props.enabled'}, 'actions': [
                        {'type': 'setVariable', 'variable': 'toggled', 'value': '${= !toggled}'}]}]},
        'strut': strut(by('size', {k: v - 2 for k, v in CB.items()}), 38),
        'choice': {**_one_line("${= props.value != '' ? props.value : props.placeholder}", style(14, 400, 'primaryText', 1.4), {'fill': 200}, {'hug': 20}),
                   'bind': {'props.style.color': "${= props.value != '' ? theme.colors.primaryText : theme.colors.tertiaryText}",
                            'props.style.fontSize': by('size', {'small': 14, 'medium': 14, 'large': 16})}},
        'chevron': {**icon('expand_more', 'tertiaryText', 16), 'bind': {'props.icon': "${= (props.open != toggled) ? 'expand_less' : 'expand_more'}"}},
        'panel': {'type': 'column', 'children': ['searchRow', 'list', 'none'], 'props': {'crossAxisAlignment': 'stretch'},
                  'layout': {'width': {'fill': 260}, 'height': {'hug': 170}, 'padding': 1},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12,
                                 'clip': 'antiAlias', 'effects': SHADOWS_LIGHT['level3']},
                  'bind': {'visible': '${= props.open != toggled}', 'decoration.effects': '${theme.shadows.level3}'}},
        'searchRow': {'type': 'row', 'children': ['searchBox'], 'layout': {'width': {'fill': 258}, 'height': {'hug': 50}, 'padding': 8},
                      'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'searchBox': {'type': 'row', 'children': ['searchIcon', 'field'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                      'layout': {'width': {'fill': 242}, 'height': {'hug': 34}, 'padding': [10, 6, 10, 6]},
                      'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8}},
        'searchIcon': icon('search', 'tertiaryText', 16),
        'field': {**_bare_field(14, hint='${props.searchPlaceholder}'),
                  'bind': {'props.initialValue': '${query}', 'props.decoration.hintText': '${props.searchPlaceholder}'},
                  'actions': [{'trigger': {'type': 'changed'}, 'actions': [{'type': 'setVariable', 'variable': 'query', 'value': '${result}'}]}]},
        'list': {'type': 'listView', 'children': ['option'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 258}, 'height': {'hug': 108}, 'padding': [0, 4, 0, 4]}, 'bind': {'data': '${props.options}'}},
        'option': {'type': 'row', 'children': ['optionLabel', 'tick'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 258}, 'height': {'hug': 36}, 'padding': [12, 8, 12, 8]},
                   'decoration': {'fills': [{'color': '#00000000'}]},
                   'bind': {'visible': "${= query == '' || contains(lower(item), lower(query))}", 'selected': '${= item == props.value}',
                            'layout.padding': by('size', {'small': [12, 6, 12, 6], 'medium': [12, 8, 12, 8], 'large': [12, 12, 12, 12]})},
                   'states': {'hovered': {'option': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}},
                              'selected': {'option': {'decoration': {'fills': [{'color': 'activeTint'}]}}}},
                   'actions': [{'trigger': 'click', 'actions': [
                       {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                       {'type': 'setVariable', 'variable': 'toggled', 'value': '${= props.open}'},
                       {'type': 'setVariable', 'variable': 'query', 'value': ''},
                       {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'optionLabel': {**_one_line('${item}', style(14, 400, 'primaryText', 1.4), {'fill': 200}, {'hug': 20}),
                        'bind': {'props.style.fontSize': by('size', {'small': 14, 'medium': 14, 'large': 16})}},
        'tick': {**icon('check', 'primary', 16), 'bind': {'visible': '${= item == props.value}'}},
        'none': {'type': 'row', 'children': ['noneText'], 'props': {'mainAxisAlignment': 'center'},
                 'layout': {'width': {'fill': 258}, 'height': {'hug': 52}, 'padding': 16},
                 'bind': {'visible': "${= query != '' && !any(props.options, o => contains(lower(o), lower(query)))}"}},
        'noneText': text('No options found', style(14, 400, 'tertiaryText', 1.4), {'hug': 110}, {'hug': 20}),
    },
))

# IconSegmentedControl (IconSegmentedControl.tsx): a choice between a few views as icons in a bordered well
# on the secondary background: 28 px high, radius 6, 2 px around items 28 x 24, radius 4, 14 px icons
# (toolbar density: 24 high, radius 4, 1 px around 22 x 20, radius 3, 12 px); the chosen one on the page
# color, bordered, a faint shadow, its icon in the primary text; the rest tertiary, a wash under the pointer.
add(component(
    'IconSegmentedControl',
    'A choice between a few views shown as icons in one well (list or grid, align left, center or right). The chosen icon\'s name is kept in your variable. Fires onChanged.',
    'well',
    props=[prop('icons', STRINGS, ['view_list', 'grid_view'], 'The choices, each an icon.', required=True),
           prop('value', var(STRING), '', 'The name of your text variable holding the chosen icon\'s name.'),
           prop('density', enum('compact', 'toolbar'), 'compact', 'compact: 28 high. toolbar: 24 high.')],
    events=[{'key': 'onChanged', 'payload': STRING}],
    previews=[preview('Two', 62, 28, value='view_list')],
    nodes={
        'well': {'type': 'row', 'children': ['list'], 'props': {'crossAxisAlignment': 'center'},
                 'layout': {'width': {'hug': 62}, 'height': {'hug': 28}, 'padding': 2},
                 'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 6},
                 'bind': {'layout.padding': "${= props.density == 'toolbar' ? 1 : 2}", 'decoration.radius': "${= props.density == 'toolbar' ? 4 : 6}"}},
        'list': {'type': 'listView', 'children': ['option'], 'props': {'scrollDirection': 'horizontal', 'scrollable': False},
                 'layout': {'width': {'hug': 56}, 'height': 24},
                 'bind': {'data': '${props.icons}', 'layout.height': "${= props.density == 'toolbar' ? 22 : 24}"}},
        'option': {'type': 'row', 'children': ['glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                   'layout': {'width': 28, 'height': {'fill': 24}},
                   'decoration': {'fills': [{'color': '#00000000'}], 'strokes': [{'color': 'primaryBorder', 'visible': False}], 'radius': 4, 'effects': []},
                   'bind': {'selected': '${= item == props.value}', 'layout.width': "${= props.density == 'toolbar' ? 22 : 28}",
                            'decoration.radius': "${= props.density == 'toolbar' ? 3 : 4}"},
                   'states': {'hovered': {'option': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}},
                              'selected': {'option': {'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}],
                                                                     'effects': SHADOWS_LIGHT['level1']}},
                                           'glyph': {'props': {'color': 'primaryText'}}}},
                   'actions': [{'trigger': 'click', 'actions': [
                       {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                       {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'glyph': {**icon('circle', 'tertiaryText', 14),
                  'bind': {'props.icon': '${item}', 'props.size': "${= props.density == 'toolbar' ? 12 : 14}",
                           'layout.width': "${= props.density == 'toolbar' ? 12 : 14}", 'layout.height': "${= props.density == 'toolbar' ? 12 : 14}"}},
    },
))

# ImageUpload (ImageUpload.tsx): where pictures are dropped or picked: a 2 px dashed border, radius 12,
# padding 32, centered, 16 px apart: a 64 px round plate with a 32 px icon, a title 18/500, a line 14 in
# secondary and a hint 12 in tertiary. Under it the pictures picked, 12 px apart in a row: each a square,
# radius 8, bordered, with an x at its corner.
add(component(
    'ImageUpload',
    'Where pictures are dropped or picked, with the picked ones shown as thumbnails under it. Fires onPick when pressed and onRemove with a picture\'s address.',
    'uploader',
    props=[prop('title', STRING, 'Upload images', 'The drop area\'s title.'),
           prop('description', STRING, 'Drag and drop or click to browse', 'The line under it.'),
           prop('hint', STRING, '', 'A muted line under that (formats, a size limit).'),
           prop('images', STRINGS, [], 'The picked pictures\' addresses.')],
    events=['onPick', {'key': 'onRemove', 'payload': STRING}],
    previews=[preview('Empty', 340, 220, hint='PNG, JPG or WebP, up to 5 MB each')],
    nodes={
        'uploader': {'type': 'column', 'children': ['drop', 'list'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 16},
                     'layout': {'width': {'fill': 340}, 'height': {'hug': 220}}},
        'drop': {'type': 'column', 'children': ['plate', 'texts'], 'props': {'crossAxisAlignment': 'center', 'spacing': 16},
                 'layout': {'width': {'fill': 340}, 'height': {'hug': 220}, 'padding': 32},
                 'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'secondaryBorder'}], 'strokeWidth': 2, 'radius': 12,
                                'dashPattern': [6, 5]},
                 'states': {'hovered': {'drop': {'decoration': {'fills': [{'color': 'primaryTint'}], 'strokes': [{'color': 'primary'}]}},
                                        'glyph': {'props': {'color': 'primary'}}}},
                 'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onPick'}]}]},
        'plate': {'type': 'row', 'children': ['glyph'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 64, 'height': 64}, 'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'radius': 9999}},
        'glyph': icon('image', 'tertiaryText', 32),
        'texts': {'type': 'column', 'children': ['title', 'description', 'hint'], 'props': {'crossAxisAlignment': 'center', 'spacing': 4},
                  'layout': {'width': {'hug': 220}, 'height': {'hug': 60}}},
        'title': text('${props.title}', style(18, 500, 'primaryText', 1.4), {'hug': 120}, {'hug': 25}),
        'description': text('${props.description}', style(14, 400, 'secondaryText', 1.4), {'hug': 200}, {'hug': 20}),
        'hint': {**text('${props.hint}', style(12, 400, 'tertiaryText', 1.4), {'hug': 180}, {'hug': 17}),
                 'bind': {'visible': "${= props.hint != ''}"}},
        'list': {'type': 'listView', 'children': ['thumb'], 'props': {'scrollDirection': 'horizontal', 'spacing': 12},
                 'layout': {'width': {'fill': 340}, 'height': 96},
                 'bind': {'data': '${props.images}', 'visible': '${= length(props.images) > 0}'}},
        'thumb': {'type': 'stack', 'children': ['remove'], 'layout': {'width': 96, 'height': {'fill': 96}},
                  'decoration': {'fills': [{'color': 'tertiaryBackground'}, {'type': 'image', 'image': {'url': '', 'fit': 'cover'}, 'visible': False}],
                                 'strokes': [{'color': 'primaryBorder'}], 'radius': 8, 'clip': 'antiAlias'},
                  'bind': {'decoration.fills[1].image.url': '${item}', 'decoration.fills[1].visible': "${= item != ''}"}},
        'remove': {'type': 'row', 'children': ['x'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                   'layout': {'width': 20, 'height': 20, 'x': {'end': 4}, 'y': {'start': 4}},
                   'decoration': {'fills': [{'color': '#99000000'}], 'radius': 9999}, 'tooltip': 'Remove',
                   'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onRemove', 'value': '${item}'}]}]},
        'x': icon('close', '#FFFFFFFF', 12),
    },
))

# CodePreview (CodePreview.tsx): text or code as it was written, on the page color: monospace 11.5 on a 1.6
# line (-0.1), padding 16, wrapping; with nothing to show, a centered empty state: a 28 px icon, 10 px, a
# title 13/600, 4 px, a line 12, all in tertiary.
add(component(
    'CodePreview',
    'Text or code shown as it was written, in monospace, wrapping. With none, a quiet message in its place.',
    'preview',
    props=[prop('code', STRING, '', 'The text.', required=True),
           prop('emptyTitle', STRING, 'Nothing to preview', 'The message\'s title when there is no text.'),
           prop('emptySubtitle', STRING, '', 'The line under it.')],
    previews=[preview('Text', 320, 90, code='name: nightly-export\nschedule: "0 2 * * *"\nsteps:\n  - run: export --all'),
              preview('Empty', 320, 110, emptySubtitle='Pick a file to see it here.')],
    nodes={
        'preview': {'type': 'column', 'children': ['code', 'blank'], 'props': {'crossAxisAlignment': 'stretch'},
                    'layout': {'width': {'fill': 320}, 'height': {'hug': 90}}, 'decoration': {'fills': [{'color': 'primaryBackground'}]}},
        'code': {**text('${props.code}', style(11.5, 400, 'primaryText', 1.6, letterSpacing=-0.1, fontFamily='monospace'), {'fill': 288}, {'hug': 18}),
                 'layout': {'width': {'fill': 288}, 'height': {'hug': 18}, 'margin': 16},
                 'bind': {'visible': "${= props.code != ''}"}},
        'blank': {'type': 'column', 'children': ['blankIcon', 'blankTitle', 'blankLine'], 'props': {'crossAxisAlignment': 'center'},
                  'layout': {'width': {'fill': 320}, 'height': {'hug': 110}, 'padding': [16, 24, 16, 24]},
                  'bind': {'visible': "${= props.code == ''}"}},
        'blankIcon': icon('code', 'tertiaryText', 28),
        'blankTitle': {**text('${props.emptyTitle}', style(13, 600, 'tertiaryText', 1.3), {'hug': 120}, {'hug': 17}),
                       'layout': {'width': {'hug': 120}, 'height': {'hug': 17}, 'margin': [0, 10, 0, 4]}},
        'blankLine': {**text('${props.emptySubtitle}', style(12, 400, 'tertiaryText', 1.4), {'hug': 160}, {'hug': 17}),
                      'bind': {'visible': "${= props.emptySubtitle != ''}"}},
    },
))

# NotePopover (NotePopover.tsx): words with a dotted underline that open a note when pressed: a bubble at
# most 240 px wide, radius 6, bordered, the menu shadow, 6 x 9, 11 on a 1.4 line (-0.1) in secondary. Here
# the note opens in place, under the words.
add(component(
    'NotePopover',
    'Words with a dotted underline that show a short note under them when pressed.',
    'column',
    props=[prop('label', STRING, 'What is this?', 'The words that open the note.', required=True),
           prop('note', STRING, '', 'The note.', required=True),
           prop('open', BOOL, False, 'Whether the note shows at first.')],
    variables=[{'name': 'toggled', 'type': 'boolean', 'value': False}],
    previews=[preview('Open', 240, 60, label='Why two keys?', note='One signs requests, the other reads results.', open=True)],
    nodes={
        'column': {'type': 'column', 'children': ['trigger', 'bubble'], 'props': {'crossAxisAlignment': 'start', 'spacing': 6},
                   'layout': {'width': {'hug': 240}, 'height': {'hug': 60}}},
        'trigger': {**text('${props.label}', {**style(11, 400, 'secondaryText', 1.4), 'decoration': 'underline', 'decorationStyle': 'dotted'}, {'hug': 80}, {'hug': 16}),
                    'actions': [{'trigger': 'click', 'actions': [{'type': 'setVariable', 'variable': 'toggled', 'value': '${= !toggled}'}]}]},
        'bubble': {'type': 'row', 'children': ['note'],
                   'layout': {'width': {'hug': 240}, 'height': {'hug': 28}, 'padding': [9, 6, 9, 6], 'constraints': {'maxWidth': 240}},
                   'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 6,
                                  'effects': SHADOWS_LIGHT['level3']},
                   'bind': {'visible': '${= props.open != toggled}', 'decoration.effects': '${theme.shadows.level3}'}},
        'note': text('${props.note}', style(11, 400, 'secondaryText', 1.4, letterSpacing=-0.1), {'hug': 200}, {'hug': 16}),
    },
))

# ViewerDialog (ViewerDialog.tsx): the frame that shows a document or a picture large: radius 8 on the page
# color, a header over a hairline, 12 x 16, with the title 14/500 and a small close button; its body, padded
# 16, holds the call's children.
add(component(
    'ViewerDialog',
    'The frame that shows a document or a picture large: a title bar with a close button over the call\'s children. Show it with a modal action. Fires onClose.',
    'dialog',
    props=[prop('title', STRING, 'Preview', 'The title.', required=True),
           prop('padded', BOOL, True, 'False: the children reach the frame\'s edges.')],
    events=['onClose'],
    slots=['actions'],
    children='list',
    previews=[preview('Default', 360, 120, title='brief.pdf')],
    nodes={
        'dialog': {'type': 'column', 'children': ['header', 'body'], 'props': {'crossAxisAlignment': 'stretch'},
                   'layout': {'width': {'fill': 360}, 'height': {'hug': 120}},
                   'decoration': {'fills': [{'color': 'primaryBackground'}], 'radius': 8, 'clip': 'antiAlias', 'effects': SHADOWS_LIGHT['level3']},
                   'bind': {'decoration.effects': '${theme.shadows.level3}'}},
        'header': {'type': 'row', 'children': ['title', 'actions', 'close'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                   'layout': {'width': {'fill': 360}, 'height': {'hug': 52}, 'padding': [16, 12, 16, 12]},
                   'decoration': {'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'title': _one_line('${props.title}', style(14, 500, 'primaryText', 1.4), {'fill': 260}, {'hug': 20}),
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
        'close': {'type': 'IconButton', 'props': {'icon': 'close', 'size': 'small'}, 'layout': {'width': {'hug': 32}, 'height': {'hug': 32}}, 'tooltip': 'Close',
                  'actions': [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': [{'type': 'componentEvent', 'event': 'onClose'}]}]},
        'body': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 360}, 'height': {'hug': 60}, 'padding': 16},
                 'bind': {'layout.padding': '${= props.padded ? 16 : 0}'}},
        'content': {'type': 'slot'},
    },
))

# SlidingPanel (SlidingPanel.tsx): the panel that rises from the foot of a pane: a hairline over it, a 44 px
# header on the secondary background over a hairline, padding 0 8 0 14: a 13 px icon in tertiary, 12 px, the
# title 12/600 with a subtitle 10.5 in tertiary 3 px under it, and a 28 px button, radius 6, with a 14 px
# chevron that lowers it; under it the call's children.
add(component(
    'SlidingPanel',
    'The panel that rises from the foot of a pane: a header with a title, a subtitle and a button that lowers it, over the call\'s children. Fires onCollapse.',
    'panel',
    props=[prop('title', STRING, 'Details', 'The title.', required=True),
           prop('subtitle', STRING, '', 'A muted line under it.'),
           prop('icon', STRING, '', 'An icon before the title (empty: none).')],
    events=['onCollapse'],
    slots=['actions'],
    children='list',
    previews=[preview('Default', 340, 110, title='Run log', subtitle='42 lines', icon='terminal')],
    nodes={
        'panel': {'type': 'column', 'children': ['header', 'body'], 'props': {'crossAxisAlignment': 'stretch'},
                  'layout': {'width': {'fill': 340}, 'height': {'hug': 110}},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'top'}},
        'header': {'type': 'row', 'children': ['strut', 'glyph', 'titles', 'actions', 'lower'], 'props': {'crossAxisAlignment': 'center', 'spacing': 12},
                   'layout': {'width': {'fill': 340}, 'height': {'hug': 44}, 'padding': [14, 0, 8, 0]},
                   'decoration': {'fills': [{'color': 'secondaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'strokeSides': 'bottom'}},
        'strut': {'type': 'box', 'layout': {'width': 0, 'height': 43}},
        'glyph': {**icon('terminal', 'tertiaryText', 13), 'bind': {'visible': "${= props.icon != ''}", 'props.icon': '${props.icon}'}},
        'titles': {'type': 'column', 'children': ['title', 'subtitle'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 3},
                   'layout': {'width': {'fill': 220}, 'height': {'hug': 15}}},
        'title': _one_line('${props.title}', style(12, 600, 'primaryText', 1.2), {'fill': 220}, {'hug': 15}),
        'subtitle': {**_one_line('${props.subtitle}', style(10.5, 400, 'tertiaryText', 1.2, letterSpacing=-0.1), {'fill': 220}, {'hug': 13}),
                     'bind': {'visible': "${= props.subtitle != ''}"}},
        'actions': {'type': 'slot', 'props': {'name': 'actions'}},
        'lower': {'type': 'row', 'children': ['chevron'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                  'layout': {'width': 28, 'height': 28}, 'decoration': {'radius': 6}, 'tooltip': 'Collapse',
                  'states': {'hovered': {'lower': HOVER}},
                  'actions': [{'trigger': 'click', 'actions': [{'type': 'componentEvent', 'event': 'onCollapse'}]}]},
        'chevron': icon('expand_more', 'tertiaryText', 14),
        'body': {'type': 'column', 'children': ['content'], 'props': {'crossAxisAlignment': 'stretch'},
                 'layout': {'width': {'fill': 340}, 'height': {'hug': 60}}},
        'content': {'type': 'slot'},
    },
))

# DropdownMultiselect (DropdownMultiselect.tsx): several choices from a list: a trigger 32, 40 or 48 px high,
# bordered, radius 12 (7 small), 12 px either side, saying what is chosen (or the placeholder in tertiary)
# with a 16 px chevron; pressed, a panel opens under it with the options, each 8 x 12 with a 16 px box,
# radius 4 (the brand color with a white check when chosen), 10 px, the label; a chosen row on the brand
# tint. Here the panel opens in place, under the trigger.
add(component(
    'DropdownMultiselect',
    'Several choices from a list: press it and the options open under it, in place, each with a checkbox. The chosen labels are kept in your list variable. Fires onChanged.',
    'column',
    props=[prop('options', STRINGS, ['Design', 'Engineering', 'Marketing'], 'The choices.', required=True),
           prop('value', var(STRINGS), '', 'The name of your list variable holding the chosen labels.'),
           prop('placeholder', STRING, 'Select options...', 'Shown with nothing chosen.'),
           prop('size', enum(*CB), 'medium', 'small (32), medium (40) or large (48).'),
           prop('open', BOOL, False, 'Whether the options show at first.'),
           prop('enabled', BOOL, True, 'False dims it and stops presses.')],
    events=[{'key': 'onChanged', 'payload': STRINGS}],
    variables=[{'name': 'toggled', 'type': 'boolean', 'value': False}],
    previews=[preview('Closed', 260, 40, value=['Design']), preview('Open', 260, 170, value=['Design', 'Marketing'], open=True)],
    nodes={
        'column': {'type': 'column', 'children': ['trigger', 'panel'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 4},
                   'layout': {'width': {'fill': 260}, 'height': {'hug': 40}}, 'bind': {'opacity': '${= props.enabled ? 1 : 0.5}'}},
        'trigger': {'type': 'row', 'children': ['strut', 'choice', 'chevron'], 'props': {'crossAxisAlignment': 'center', 'spacing': 8},
                    'layout': {'width': {'fill': 260}, 'height': {'hug': 40}, 'padding': [12, 0, 12, 0]},
                    'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12},
                    'bind': {'decoration.strokes[0].color': '${= (props.open != toggled) ? theme.primary : theme.colors.primaryBorder}',
                             'decoration.radius': by('size', {'small': 7, 'medium': 12, 'large': 12})},
                    'states': {'hovered': {'trigger': HOVER}},
                    'actions': [{'trigger': {'type': 'click', 'when': 'props.enabled'}, 'actions': [
                        {'type': 'setVariable', 'variable': 'toggled', 'value': '${= !toggled}'}]}]},
        'strut': strut(by('size', {k: v - 2 for k, v in CB.items()}), 38),
        'choice': {**_one_line("${= length(props.value) > 0 ? join(props.value, ', ') : props.placeholder}", style(14, 400, 'primaryText', 1.4), {'fill': 200}, {'hug': 20}),
                   'bind': {'props.style.color': '${= length(props.value) > 0 ? theme.colors.primaryText : theme.colors.tertiaryText}',
                            'props.style.fontSize': by('size', {'small': 14, 'medium': 14, 'large': 16})}},
        'chevron': {**icon('expand_more', 'tertiaryText', 16), 'bind': {'props.icon': "${= (props.open != toggled) ? 'expand_less' : 'expand_more'}"}},
        'panel': {'type': 'column', 'children': ['list'], 'props': {'crossAxisAlignment': 'stretch'},
                  'layout': {'width': {'fill': 260}, 'height': {'hug': 116}, 'padding': [1, 5, 1, 5]},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 12,
                                 'clip': 'antiAlias', 'effects': SHADOWS_LIGHT['level3']},
                  'bind': {'visible': '${= props.open != toggled}', 'decoration.effects': '${theme.shadows.level3}',
                           'decoration.radius': by('size', {'small': 7, 'medium': 12, 'large': 12})}},
        'list': {'type': 'listView', 'children': ['option'], 'props': {'scrollable': False},
                 'layout': {'width': {'fill': 258}, 'height': {'hug': 108}}, 'bind': {'data': '${props.options}'}},
        'option': {'type': 'row', 'children': ['box', 'optionLabel'], 'props': {'crossAxisAlignment': 'center', 'spacing': 10},
                   'layout': {'width': {'fill': 258}, 'height': {'hug': 36}, 'padding': [12, 8, 12, 8]},
                   'decoration': {'fills': [{'color': '#00000000'}]},
                   'bind': {'selected': '${= contains(props.value, item)}',
                            'layout.padding': by('size', {'small': [12, 6, 12, 6], 'medium': [12, 8, 12, 8], 'large': [12, 12, 12, 12]})},
                   'states': {'hovered': {'option': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}},
                              'selected': {'option': {'decoration': {'fills': [{'color': 'activeTint'}]}},
                                           'box': {'decoration': {'fills': [{'color': 'primary'}], 'strokes': [{'color': 'primary'}]}}}},
                   'actions': [{'trigger': 'click', 'actions': [
                       {'type': 'setVariable', 'variable': 'props.value',
                        'value': '${= contains(props.value, item) ? without(props.value, item) : append(props.value, item)}'},
                       {'type': 'componentEvent', 'event': 'onChanged', 'value': '${props.value}'}]}]},
        'box': {'type': 'row', 'children': ['tick'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
                'layout': {'width': 16, 'height': 16},
                'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'secondaryBorder'}], 'radius': 4}},
        'tick': {**icon('check', '#FFFFFFFF', 12), 'bind': {'visible': '${= contains(props.value, item)}'}},
        'optionLabel': {**_one_line('${item}', style(14, 400, 'primaryText', 1.4), {'fill': 200}, {'hug': 20}),
                        'bind': {'props.style.fontSize': by('size', {'small': 14, 'medium': 14, 'large': 16})}},
    },
))

# IconSelect (IconSelect.tsx): one choice from a few, each with a small plate: a trigger 28, 32 or 36 px
# high, radius 7, bordered (the brand color while open), with the choice's plate (16 or 18 px, radius 4 or 5,
# bordered, a letter), its label 12 to 13 and a chevron; pressed, the options open under it, each a row 24 to
# 32 px high, radius 5, with its plate and label, the chosen one with a check. Here they open in place.
IS = {'compact': 28, 'small': 32, 'medium': 36}
def _plate(id_, formula):
    return {
        id_: {'type': 'row', 'children': [id_ + 'Letter'], 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center'},
              'layout': {'width': 18, 'height': 18},
              'decoration': {'fills': [{'color': 'tertiaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 5},
              'bind': {'layout.width': by('size', {'compact': 16, 'small': 18, 'medium': 18}),
                       'layout.height': by('size', {'compact': 16, 'small': 18, 'medium': 18}),
                       'decoration.radius': by('size', {'compact': 4, 'small': 5, 'medium': 5})}},
        id_ + 'Letter': text(formula, style(9.5, 700, 'secondaryText', 1.0), {'hug': 7}, {'hug': 10}),
    }
add(component(
    'IconSelect',
    'One choice from a few, each shown with a small letter plate (a provider, a model, a workspace): press it and the options open under it, in place. The choice is kept in your variable. Fires onChanged.',
    'column',
    props=[prop('options', STRINGS, ['Claude', 'Gemini', 'Local'], 'The choices.', required=True),
           prop('value', var(STRING), '', 'The name of your text variable holding the choice.'),
           prop('placeholder', STRING, 'Select...', 'Shown with no choice.'),
           prop('size', enum(*IS), 'small', 'compact (28), small (32) or medium (36).'),
           prop('open', BOOL, False, 'Whether the options show at first.')],
    events=[{'key': 'onChanged', 'payload': STRING}],
    variables=[{'name': 'toggled', 'type': 'boolean', 'value': False}],
    previews=[preview('Closed', 200, 32, value='Claude'), preview('Open', 200, 140, value='Claude', open=True)],
    nodes={
        'column': {'type': 'column', 'children': ['trigger', 'panel'], 'props': {'crossAxisAlignment': 'stretch', 'spacing': 4},
                   'layout': {'width': {'fill': 200}, 'height': {'hug': 32}}},
        'trigger': {'type': 'row', 'children': ['strut', 'chosen', 'choice', 'chevron'], 'props': {'crossAxisAlignment': 'center', 'spacing': 7},
                    'layout': {'width': {'fill': 200}, 'height': {'hug': 32}, 'padding': [8, 0, 8, 0]},
                    'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 7},
                    'bind': {'decoration.strokes[0].color': '${= (props.open != toggled) ? theme.primary : theme.colors.primaryBorder}'},
                    'states': {'hovered': {'trigger': HOVER}},
                    'actions': [{'trigger': 'click', 'actions': [{'type': 'setVariable', 'variable': 'toggled', 'value': '${= !toggled}'}]}]},
        'strut': strut(by('size', {k: v - 2 for k, v in IS.items()}), 30),
        **_plate('chosen', '${= upper(left(props.value, 1))}'),
        'choice': {**_one_line("${= props.value != '' ? props.value : props.placeholder}", style(12.5, 400, 'primaryText', 1.3), {'fill': 120}, {'hug': 16}),
                   'bind': {'props.style.color': "${= props.value != '' ? theme.colors.primaryText : theme.colors.tertiaryText}",
                            'props.style.fontSize': by('size', {'compact': 12, 'small': 12.5, 'medium': 13})}},
        'chevron': {**icon('expand_more', 'tertiaryText', 14), 'bind': {'props.icon': "${= (props.open != toggled) ? 'expand_less' : 'expand_more'}"}},
        'panel': {'type': 'column', 'children': ['list'], 'props': {'crossAxisAlignment': 'stretch'},
                  'layout': {'width': {'fill': 200}, 'height': {'hug': 96}, 'padding': 4},
                  'decoration': {'fills': [{'color': 'primaryBackground'}], 'strokes': [{'color': 'primaryBorder'}], 'radius': 8,
                                 'effects': SHADOWS_LIGHT['level3']},
                  'bind': {'visible': '${= props.open != toggled}', 'decoration.effects': '${theme.shadows.level3}'}},
        'list': {'type': 'listView', 'children': ['option'], 'props': {'scrollable': False, 'spacing': 1},
                 'layout': {'width': {'fill': 190}, 'height': {'hug': 86}}, 'bind': {'data': '${props.options}'}},
        'option': {'type': 'row', 'children': ['optionStrut', 'plate', 'optionLabel', 'tick'], 'props': {'crossAxisAlignment': 'center', 'spacing': 7},
                   'layout': {'width': {'fill': 190}, 'height': {'hug': 28}, 'padding': [6, 0, 6, 0]},
                   'decoration': {'fills': [{'color': '#00000000'}], 'radius': 5},
                   'states': {'hovered': {'option': {'decoration': {'fills': [{'color': 'hoverOverlay'}]}}}},
                   'actions': [{'trigger': 'click', 'actions': [
                       {'type': 'setVariable', 'variable': 'props.value', 'value': '${item}'},
                       {'type': 'setVariable', 'variable': 'toggled', 'value': '${= props.open}'},
                       {'type': 'componentEvent', 'event': 'onChanged', 'value': '${item}'}]}]},
        'optionStrut': strut(by('size', {'compact': 24, 'small': 28, 'medium': 32}), 28),
        **_plate('plate', '${= upper(left(item, 1))}'),
        'optionLabel': {**_one_line('${item}', style(12, 400, 'primaryText', 1.3), {'fill': 120}, {'hug': 16}),
                        'bind': {'props.style.fontSize': by('size', {'compact': 11.5, 'small': 12, 'medium': 12.5})}},
        'tick': {**icon('check', 'primary', 14), 'bind': {'visible': '${= item == props.value}'}},
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

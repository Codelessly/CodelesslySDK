import 'package:a2ui_core/a2ui_core.dart';

/// The id of the Codelessly GenUI catalog: the A2UI v0.9 basic vocabulary
/// rendered by the Codelessly SDK, plus Codelessly extension components
/// (charts, gauges, metrics, tables, expandable visualizations) and the
/// side-effect-free `calc` formula function.
const String kGenUiCatalogId =
    'https://codelessly.com/a2ui/catalogs/genui/v1/catalog.json';

/// The A2UI protocol version agents write for this catalog.
const A2uiProtocolVersion kGenUiProtocolVersion = A2uiProtocolVersion.v0_9_1;

/// Version of this catalog document. Additive changes bump the minor
/// number; a removed or renamed component or property gets a new catalog id
/// (`.../genui/v2/...`).
const String kGenUiCatalogVersion = '1.0.0';

const String _common = 'https://a2ui.org/specification/v0_9/common_types.json';

Map<String, Object?> _ref(String def, [String? description]) => {
  r'$ref': '$_common#/\$defs/$def',
  'description': ?description,
};

/// The component names of the extension namespace. Every Codelessly
/// extension starts with `Codelessly`, so it can never collide with a name a
/// later basic catalog adds.
const List<String> kGenUiExtensionComponents = [
  'CodelesslyChart',
  'CodelesslyGauge',
  'CodelesslyProgress',
  'CodelesslyMetric',
  'CodelesslySwitch',
  'CodelesslyTable',
  'CodelesslyVisualization',
];

/// The basic components the catalog keeps. Video and AudioPlayer are left
/// out of the chat catalog: they load media from the network, which the
/// security model only allows when the host grants it.
const List<String> kGenUiBasicComponents = [
  'Text',
  'Image',
  'Icon',
  'Row',
  'Column',
  'List',
  'Card',
  'Tabs',
  'Modal',
  'Divider',
  'Button',
  'TextField',
  'CheckBox',
  'ChoicePicker',
  'Slider',
  'DateTimeInput',
];

/// Inputs that take an optional `action`, sent when the user commits a value
/// (a slider is released, a box is toggled, a choice is picked, a field is
/// submitted). Basic A2UI inputs only write the data model; the action is
/// what lets the agent react to a value without a separate submit button.
const Set<String> kCommitActionInputs = {
  'Slider',
  'CheckBox',
  'ChoicePicker',
  'TextField',
  'DateTimeInput',
};

Map<String, Object?> _component(
  String name,
  String description,
  Map<String, Object?> properties, {
  List<String> required = const [],
  bool checkable = false,
}) => {
  'type': 'object',
  'description': description,
  'allOf': [
    {r'$ref': '$_common#/\$defs/ComponentCommon'},
    {r'$ref': r'#/$defs/CatalogComponentCommon'},
    if (checkable) {r'$ref': '$_common#/\$defs/Checkable'},
    {
      'type': 'object',
      'properties': {
        'component': {'const': name},
        ...properties,
      },
      'required': ['component', ...required],
    },
  ],
  'unevaluatedProperties': false,
};

const Map<String, Object?> _color = {
  'type': 'string',
  'description': 'A hex color such as "#2E7D32".',
  'pattern': r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
};

final Map<String, Object?> _chartData = {
  'description':
      'The rows to plot: an array of objects, one per x position. Bind it '
      'with {"path": "/rows"} or compute it with {"call": "calc", "args": '
      '{"expr": "map(range(0, weeks + 1), w => object(\'week\', w, '
      '\'kg\', start - w * rate))"}}. calc needs no returnType.',
  'oneOf': [
    {
      'type': 'array',
      'items': {'type': 'object'},
    },
    _ref('DataBinding'),
    _ref('FunctionCall'),
  ],
};

Map<String, Object?> _extensionComponents() => {
  'CodelesslyChart': _component(
    'CodelesslyChart',
    'A Codelessly chart: lines, areas, bars or a donut over rows of data. '
        'Recomputes live when the bound data changes.',
    {
      'chartType': {
        'type': 'string',
        'enum': ['line', 'bar', 'donut'],
        'default': 'line',
      },
      'data': _chartData,
      'xField': {
        'type': 'string',
        'description': 'The row field shown as the x-axis label.',
      },
      'series': {
        'type': 'array',
        'minItems': 1,
        'items': {
          'type': 'object',
          'properties': {
            'field': {
              'type': 'string',
              'description': 'The numeric row field to plot.',
            },
            'name': {'type': 'string'},
            'kind': {
              'type': 'string',
              'enum': ['line', 'area', 'bar', 'tick'],
              'description': 'Default: line for line charts, bar for bars.',
            },
            'color': _color,
            'stack': {
              'type': 'string',
              'description': 'Bars sharing a stack name stack.',
            },
            'dashed': {'type': 'boolean'},
            'curved': {'type': 'boolean'},
          },
          'required': ['field'],
          'additionalProperties': false,
        },
      },
      'title': _ref('DynamicString'),
      'height': {
        'type': 'number',
        'description': 'Inline height in logical pixels. Default 200.',
      },
      'minY': _ref('DynamicNumber'),
      'maxY': _ref('DynamicNumber'),
      'yLabelSuffix': {'type': 'string'},
      'yLabelPrefix': {'type': 'string'},
      'xLabelEvery': {
        'type': 'integer',
        'description': 'Show every nth x label. Default: chosen to fit.',
      },
      'selectedIndex': _ref(
        'DynamicNumber',
        'The highlighted row. Bind it to a path to let the user scrub the '
            'chart: dragging over it writes the row index there.',
      ),
      'showLegend': {'type': 'boolean', 'default': true},
    },
    required: ['data', 'series'],
  ),
  'CodelesslyGauge': _component(
    'CodelesslyGauge',
    'A Codelessly radial gauge with colored zones, for one value on a '
        'scale (body fat %, efficiency, budget used).',
    {
      'value': _ref('DynamicNumber'),
      'min': {'type': 'number', 'default': 0},
      'max': {'type': 'number', 'default': 100},
      'label': _ref('DynamicString', 'Caption under the value.'),
      'unit': {'type': 'string', 'description': 'Suffix such as "%".'},
      'target': _ref('DynamicNumber', 'Optional target mark.'),
      'zones': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'to': {
              'type': 'number',
              'description': 'Upper end of the zone on the min..max scale.',
            },
            'color': _color,
          },
          'required': ['to', 'color'],
          'additionalProperties': false,
        },
      },
      'size': {'type': 'number', 'description': 'Diameter. Default 180.'},
    },
    required: ['value'],
  ),
  'CodelesslyProgress': _component(
    'CodelesslyProgress',
    'A Codelessly progress bar for a share between 0 and 1.',
    {
      'value': _ref('DynamicNumber', 'Progress from 0 to 1.'),
      'label': _ref('DynamicString'),
      'color': _color,
    },
    required: ['value'],
  ),
  'CodelesslyMetric': _component(
    'CodelesslyMetric',
    'A key figure: a small label over a large value, with an optional '
        'caption. Use a Row of metrics for a summary strip.',
    {
      'label': _ref('DynamicString'),
      'value': _ref(
        'DynamicString',
        'Usually a formatNumber, formatCurrency or calc call.',
      ),
      'caption': _ref('DynamicString'),
      'tone': {
        'type': 'string',
        'enum': ['neutral', 'positive', 'negative', 'accent'],
        'default': 'neutral',
      },
    },
    required: ['label', 'value'],
  ),
  'CodelesslySwitch': _component(
    'CodelesslySwitch',
    'A Codelessly on/off switch bound to a boolean.',
    {
      'label': _ref('DynamicString'),
      'value': _ref('DynamicBoolean'),
      'action': _ref('Action', 'Sent when the user flips the switch.'),
    },
    required: ['label', 'value'],
    checkable: true,
  ),
  'CodelesslyTable': _component(
    'CodelesslyTable',
    'A table of rows with typed columns, e.g. a bill of materials. Optional '
        'checkboxes write each row\'s checkField, and a totals row sums '
        'columns.',
    {
      'rows': {
        'description': 'An array of row objects, usually {"path": "/items"}.',
        'oneOf': [
          {
            'type': 'array',
            'items': {'type': 'object'},
          },
          _ref('DataBinding'),
          _ref('FunctionCall'),
        ],
      },
      'columns': {
        'type': 'array',
        'minItems': 1,
        'items': {
          'type': 'object',
          'properties': {
            'field': {'type': 'string'},
            'header': {'type': 'string'},
            'format': {
              'type': 'string',
              'enum': ['text', 'number', 'currency', 'percent'],
              'default': 'text',
            },
            'decimals': {'type': 'integer'},
            'expr': {
              'type': 'string',
              'description':
                  'A calc formula over the row\'s fields, used instead of '
                  'field, e.g. "qty * unitCost".',
            },
            'total': {
              'type': 'boolean',
              'description': 'Sum this column in the totals row.',
            },
          },
          'required': ['header'],
          'additionalProperties': false,
        },
      },
      'checkField': {
        'type': 'string',
        'description':
            'A boolean row field shown as a checkbox the user can toggle; '
            'the row in the data model is updated.',
      },
      'currency': {'type': 'string', 'default': 'USD'},
      'action': _ref(
        'Action',
        'Sent after the user toggles a row. Its context may use the '
            'paths of the data model; it also gets row and checked.',
      ),
    },
    required: ['rows', 'columns'],
  ),
  'CodelesslyVisualization': _component(
    'CodelesslyVisualization',
    'An interactive visualization card shown inline in the chat that the '
        'user can expand to fullscreen and collapse back, keeping its state. '
        'Inline it shows child; fullscreen it shows detail (or child) large, '
        'with the controls in a side panel. All values recompute live from '
        'the data model through calc formulas, without asking the agent.',
    {
      'title': _ref('DynamicString'),
      'subtitle': _ref('DynamicString'),
      'child': _ref(
        'ComponentId',
        'The inline content, e.g. a Column with a chart and a few metrics.',
      ),
      'controls': {
        'type': 'array',
        'items': _ref('ComponentId'),
        'description':
            'Inputs (sliders, choice pickers) shown in the fullscreen side '
            'panel. List the most important ones in inlineControls too.',
      },
      'inlineControls': {
        'type': 'array',
        'items': _ref('ComponentId'),
        'description':
            'Controls shown inline under the child (keep to 1-3). The same '
            'ids may also be listed in controls.',
      },
      'detail': _ref(
        'ComponentId',
        'Optional larger content for fullscreen. Defaults to child.',
      ),
    },
    required: ['title', 'child'],
  ),
};

/// Adds the optional commit `action` (and a slider `step`) to a basic input
/// schema.
Map<String, Object?> _withCommitAction(String name, Map<String, Object?> s) {
  final schema = Map<String, Object?>.from(s);
  final allOf = List<Object?>.from(schema['allOf']! as List);
  allOf.add({
    'type': 'object',
    'properties': {
      'action': _ref(
        'Action',
        'Codelessly extension: sent when the user commits a value (slider '
            'released, box toggled, option picked, field submitted).',
      ),
      if (name == 'Slider') ...{
        'step': {
          'type': 'number',
          'description': 'Codelessly extension: the value snaps to steps.',
        },
        'unit': {
          'type': 'string',
          'description': 'Codelessly extension: suffix shown after the value.',
        },
      },
    },
  });
  schema['allOf'] = allOf;
  return schema;
}

Map<String, Object?> _calcFunction() => {
  'type': 'object',
  'description':
      'Codelessly formula, evaluated on the device, live, whenever the data '
      'it reads changes. Pure: no network, no writes, no clock. Identifiers '
      'name data model fields (inside a List template, the item\'s fields '
      'first): `weight * 2`, `items[0].qty`, `sum(items, i => i.qty * '
      'i.cost)`. Operators: + - * / % (unary minus too), == != < <= > >=, && || !, a ? b : c; + also joins text. A ChoicePicker value is a list: read it with first(sex) or sex[0]. Functions: if, min, '
      'max, round(x, d), floor, ceil, abs, sqrt, pow, exp, ln, log, clamp, '
      'sum, count, map, where, range(start, end, step), object(k, v, ...), '
      "first, last, fixed(x, d), formatNumber(x), formatCurrency(x, 'USD'). "
      'Use map and '
      'range to build chart rows. Do not give calc a returnType.',
  'properties': {
    'call': {'const': 'calc'},
    'args': {
      'type': 'object',
      'properties': {
        'expr': {'type': 'string'},
        'vars': {
          'type': 'object',
          'description':
              'Optional extra names for the formula; values may be dynamic.',
          'additionalProperties': true,
        },
      },
      'required': ['expr'],
      'additionalProperties': false,
    },
  },
  'required': ['call', 'args'],
  'unevaluatedProperties': false,
};

/// Instructions every agent prompted with this catalog gets.
const String kGenUiCatalogInstructions = '''
Write A2UI v0.9.1 messages for the Codelessly GenUI catalog.
- One surface per answer that needs UI. Start with createSurface (catalogId exactly as given, sendDataModel true), then updateDataModel with all initial values at path "/", then one updateComponents with every component.
- Components are a flat list. Exactly one has id "root". Children are referenced by id, never nested. Every referenced id must exist.
- Bind inputs to data model paths ({"path": "/weightKg"}) so the user's values are kept and sent back.
- Derived values (totals, projections, chart rows) must use {"call": "calc", ...} formulas so they update on the device when inputs change. Never hard-code numbers that depend on inputs.
- For anything the user may want to explore (charts with inputs), wrap it in a CodelesslyVisualization with its inputs in controls.
- Give every input the user is meant to change (sliders, pickers, toggles, checklists) an action (event) whose context carries its value, so you hear each committed value and can respond; the UI still updates live through formulas. Give Buttons an action with a context that reads the relevant paths.
- Keep labels short. Use Text variant h2/h3 for headings, caption for notes.
''';

/// Builds the catalog document (JSON Schema 2020-12, A2UI v0.9 catalog
/// format) from the official basic catalog and the Codelessly extensions.
Map<String, Object?> buildGenUiCatalogJson() {
  final Map<String, Object?> basic = BasicCatalog.v0_9().toJson();
  final basicComponents = basic['components']! as Map<String, Object?>;
  final components = <String, Object?>{
    for (final name in kGenUiBasicComponents)
      name: kCommitActionInputs.contains(name)
          ? _withCommitAction(
              name,
              basicComponents[name]! as Map<String, Object?>,
            )
          : basicComponents[name],
    ..._extensionComponents(),
  };
  final functions = <String, Object?>{
    ...(basic['functions']! as Map<String, Object?>),
    'calc': _calcFunction(),
  };
  final defs = Map<String, Object?>.from(basic[r'$defs']! as Map);
  defs['anyComponent'] = {
    'oneOf': [
      for (final name in components.keys) {r'$ref': '#/components/$name'},
    ],
    'discriminator': {'propertyName': 'component'},
  };
  defs['anyFunction'] = {
    'oneOf': [
      for (final name in functions.keys) {r'$ref': '#/functions/$name'},
    ],
  };
  return {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    r'$id': kGenUiCatalogId,
    'title': 'Codelessly GenUI catalog',
    'description':
        'A2UI v0.9 basic components rendered with the Codelessly SDK, plus '
        'Codelessly extensions (Codelessly* components, calc). Catalog '
        'version $kGenUiCatalogVersion.',
    'catalogId': kGenUiCatalogId,
    'components': components,
    'functions': functions,
    r'$defs': defs,
  };
}

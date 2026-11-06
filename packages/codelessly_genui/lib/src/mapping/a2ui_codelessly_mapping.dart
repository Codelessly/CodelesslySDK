import 'package:codelessly_api/codelessly_api.dart';

import '../functions/calc_function.dart';
import '../render/genui_theme.dart';
import 'node_mapping.dart';

/// A Codelessly layout made from an A2UI surface: node JSON keyed by id
/// (the A2UI component ids), the root id, and the variables the data model
/// became.
class CodelesslyLayoutJson {
  const CodelesslyLayoutJson({
    required this.nodes,
    required this.rootId,
    required this.variables,
    this.warnings = const [],
  });

  final Map<String, Map<String, Object?>> nodes;
  final String rootId;
  final List<VariableData> variables;

  /// Components the mapping could not carry over.
  final List<String> warnings;
}

/// An A2UI surface made from a Codelessly layout.
class A2uiSurfaceJson {
  const A2uiSurfaceJson({
    required this.components,
    required this.dataModel,
    this.warnings = const [],
  });

  final List<Map<String, Object?>> components;
  final Map<String, Object?> dataModel;
  final List<String> warnings;
}

/// The name of the Codelessly function an A2UI action becomes. The host
/// that renders the layout registers it; its params carry the A2UI action.
const String kA2uiActionFunction = 'a2ui_action';

/// Maps between A2UI components and Codelessly nodes, both ways.
///
/// | A2UI | Codelessly node |
/// |---|---|
/// | Text (variant) | text (font size and weight per variant) |
/// | Row / Column (justify, align) | row / column (main/cross alignment) |
/// | Card | frame (white fill, border, radius 14) |
/// | Button (child Text, variant, action) | filledButton / outlinedButton / textButton, click reaction |
/// | Slider (min, max, step, value, action) | slider (divisions), value binding, changeEnd reaction |
/// | CheckBox (label, value) | checkbox (label in the node name), value binding |
/// | TextField (label, value, variant) | textField (labelText, keyboard), inputValue binding |
/// | ChoicePicker (options, value) | segmentedButton (segments), selected binding |
/// | Divider | divider |
/// | CodelesslyChart | chart (series) |
/// | CodelesslyGauge | gauge (radial) |
/// | CodelesslyProgress | progressBar |
/// | CodelesslySwitch | switch |
///
/// Dynamic values become Codelessly variable bindings:
/// `{"path": "/a/b/0"}` ↔ `${a.b[0]}`, and `{"call": "calc", "args":
/// {"expr": e}}` ↔ the formula `${= e}`. The data model's top-level keys
/// become variables of the matching type.
class A2uiCodelesslyMapping {
  const A2uiCodelesslyMapping({this.theme = const GenUiTheme()});

  final GenUiTheme theme;

  static const double _width = 360;

  // -------------------------------------------------------------------------
  // Values
  // -------------------------------------------------------------------------

  /// A dynamic value as a Codelessly binding, or null for a literal.
  static String? bindingOf(Object? value) {
    if (value is Map) {
      final Object? path = value['path'];
      if (path is String) return '\${${pointerToFormulaPath(path)}}';
      if (value['call'] == 'calc') {
        final Object? args = value['args'];
        if (args is Map && args['expr'] is String) {
          return '\${= ${args['expr']}}';
        }
      }
    }
    return null;
  }

  /// A Codelessly binding as an A2UI dynamic value.
  static Object? dynamicOf(String binding, {String returnType = 'any'}) {
    final String inner = binding.substring(2, binding.length - 1).trim();
    if (inner.startsWith('=')) {
      return {
        'call': 'calc',
        'args': {'expr': inner.substring(1).trim()},
      };
    }
    final String? pointer = formulaPathToPointer(inner);
    return {'path': pointer == null ? '/$inner' : '/$pointer'};
  }

  static bool _isBinding(String? s) =>
      s != null && s.startsWith(r'${') && s.endsWith('}');

  static Object? _literal(Object? value) => value is Map ? null : value;

  static VariableType _typeOf(Object? value) => switch (value) {
    final int _ => VariableType.integer,
    final double _ => VariableType.decimal,
    final bool _ => VariableType.boolean,
    final List _ => VariableType.list,
    final Map _ => VariableType.map,
    _ => VariableType.text,
  };

  // -------------------------------------------------------------------------
  // A2UI → Codelessly
  // -------------------------------------------------------------------------

  /// Maps A2UI [components] (one surface) and its [dataModel] to Codelessly
  /// node JSON and variables.
  CodelesslyLayoutJson toCodelessly(
    List<Map<String, Object?>> components, {
    Map<String, Object?> dataModel = const {},
    String rootId = 'root',
  }) {
    final Map<String, Map<String, Object?>> byId = {
      for (final c in components) '${c['id']}': c,
    };
    final Map<String, Map<String, Object?>> nodes = {};
    final List<String> warnings = [];
    final Set<String> absorbed = {};
    for (final Map<String, Object?> c in components) {
      final String id = '${c['id']}';
      if (c['component'] == 'Button' &&
          byId[c['child']]?['component'] == 'Text') {
        absorbed.add('${c['child']}');
      }
      final Map<String, Object?>? node = _toNode(c, byId);
      if (node == null) {
        warnings.add('$id: ${c['component']} has no Codelessly node mapping.');
        continue;
      }
      nodes[id] = node;
    }
    for (final String id in absorbed) {
      nodes.remove(id);
    }
    for (final MapEntry<String, Map<String, Object?>> e in nodes.entries) {
      for (final Object? child in (e.value['children'] as List?) ?? const []) {
        nodes['$child']?['parentID'] = e.key;
      }
    }
    return CodelesslyLayoutJson(
      nodes: nodes,
      rootId: rootId,
      warnings: warnings,
      variables: [
        for (final MapEntry<String, Object?> e in dataModel.entries)
          VariableData(
            id: e.key,
            name: e.key,
            value: e.value,
            type: _typeOf(e.value),
          ),
      ],
    );
  }

  Map<String, Object?>? _toNode(
    Map<String, Object?> c,
    Map<String, Map<String, Object?>> byId,
  ) {
    final String id = '${c['id']}';
    final Map<String, String> variables = {};
    void bind(String property, Object? value) {
      final String? binding = bindingOf(value);
      if (binding != null) variables[property] = binding;
    }

    List<Map<String, Object?>> reactions(String trigger) {
      final Object? action = c['action'];
      if (action is! Map || action['event'] is! Map) return const [];
      final Map event = action['event'] as Map;
      return [
        Reaction(
          trigger: TriggerModel(type: TriggerType.values.byName(trigger)),
          action: CallFunctionAction(
            name: kA2uiActionFunction,
            params: {
              'name': event['name'],
              if (event['context'] != null) 'context': event['context'],
              if (c['component'] == 'Button') 'labelComponentId': c['child'],
            },
          ),
        ).toJson().cast<String, Object?>(),
      ];
    }

    Map<String, Object?> finish(Map<String, Object?> node) => {
      ...node,
      if (variables.isNotEmpty) 'variables': variables,
    };

    final Object? weight = c['weight'];
    final Map<String, Object?> flex = weight is num
        ? {'horizontalFit': 'expanded', 'flex': weight.round()}
        : const {};

    switch (c['component']) {
      case 'Text':
        bind('data', c['text']);
        final node = CodelesslyNodes.text(
          id: id,
          text: '${_literal(c['text']) ?? ''}',
          width: _width,
          theme: theme,
          variant: c['variant'] as String?,
        );
        return finish({...node, ...flex});
      case 'Row':
      case 'Column':
        final bool row = c['component'] == 'Row';
        final Object? children = c['children'];
        return finish({
          'id': id,
          'name': c['component'],
          'type': row ? 'row' : 'column',
          'basicBoxLocal': [0, 0, _width, 40],
          'horizontalFit': row ? 'expanded' : 'expanded',
          'verticalFit': 'shrinkWrap',
          'spacing': 8,
          'mainAxisAlignment': switch (c['justify']) {
            'center' => 'center',
            'end' => 'end',
            'spaceBetween' => 'spaceBetween',
            'spaceAround' => 'spaceAround',
            'spaceEvenly' => 'spaceEvenly',
            _ => 'start',
          },
          'crossAxisAlignment': switch (c['align']) {
            'start' => 'start',
            'center' => 'center',
            'end' => 'end',
            _ => 'stretch',
          },
          'children': children is List ? [...children] : <String>[],
          if (children is Map) 'a2uiTemplate': children,
          ...flex,
        });
      case 'Card':
        return finish({
          'id': id,
          'name': 'Card',
          'type': 'frame',
          'basicBoxLocal': [0, 0, _width, 80],
          'horizontalFit': 'expanded',
          'verticalFit': 'shrinkWrap',
          'padding': const EdgeInsetsModel.all(14).toJson(),
          'fills': [
            PaintModel.solid(
              id: 'fill',
              color: ColorRGB.fromHex(CodelesslyNodes.hex(theme.surface)),
            ).toJson(),
          ],
          'strokes': [
            PaintModel.solid(
              id: 'stroke',
              color: ColorRGB.fromHex(CodelesslyNodes.hex(theme.border)),
            ).toJson(),
          ],
          'strokeWeight': 1,
          'cornerRadius': CornerRadius.all(const RadiusModel.circular(14))
              .toJson(),
          'children': [if (c['child'] != null) '${c['child']}'],
        });
      case 'Button':
        final Map<String, Object?>? label = byId['${c['child']}'];
        final Object? text = label?['text'];
        final node = CodelesslyNodes.button(
          id: id,
          label: '${_literal(text) ?? ''}',
          theme: theme,
          variant: c['variant'] as String?,
        );
        if (bindingOf(text) case final String b) variables['label'] = b;
        return finish({...node, 'reactions': reactions('click')});
      case 'Slider':
        bind('value', c['value']);
        final double min = (c['min'] as num?)?.toDouble() ?? 0;
        final double max = (c['max'] as num?)?.toDouble() ?? 100;
        final double? step = (c['step'] as num?)?.toDouble();
        final node = CodelesslyNodes.slider(
          id: id,
          value: (_literal(c['value']) as num?)?.toDouble() ?? min,
          min: min,
          max: max,
          width: _width,
          theme: theme,
          divisions: step == null || step <= 0
              ? null
              : ((max - min) / step).round(),
        );
        final props = {...node['properties']! as Map<String, Object?>};
        if (_literal(c['label']) case final String label)
          props['label'] = label;
        return finish({
          ...node,
          'name': 'Slider',
          'properties': props,
          'reactions': reactions('changeEnd'),
        });
      case 'CheckBox':
        bind('value', c['value']);
        return finish({
          ...CodelesslyNodes.checkbox(
            id: id,
            value: _literal(c['value']) == true,
            theme: theme,
          ),
          'name': '${_literal(c['label']) ?? 'Checkbox'}',
          'reactions': reactions('changed'),
        });
      case 'CodelesslySwitch':
        bind('value', c['value']);
        return finish({
          ...CodelesslyNodes.toggle(
            id: id,
            value: _literal(c['value']) == true,
            theme: theme,
          ),
          'name': '${_literal(c['label']) ?? 'Switch'}',
          'reactions': reactions('changed'),
        });
      case 'TextField':
        bind('inputValue', c['value']);
        return finish({
          ...CodelesslyNodes.textField(
            id: id,
            label: '${_literal(c['label']) ?? ''}',
            width: _width,
            theme: theme,
            variant: (c['variant'] as String?) ?? 'shortText',
          ),
          'reactions': reactions('submitted'),
        });
      case 'ChoicePicker':
        bind('selected', c['value']);
        final List<({String value, String label})> options = [
          for (final Object? o in (c['options'] as List?) ?? const [])
            if (o is Map)
              (
                value: '${o['value']}',
                label: '${_literal(o['label']) ?? o['value']}',
              ),
        ];
        return finish({
          ...CodelesslyNodes.segmented(
            id: id,
            options: options,
            selected: [
              for (final v in (_literal(c['value']) as List?) ?? const []) '$v',
            ],
            width: _width,
            theme: theme,
            multi: c['variant'] == 'multipleSelection',
          ),
          'reactions': reactions('changed'),
        });
      case 'Divider':
        return CodelesslyNodes.divider(id: id, width: _width, theme: theme);
      case 'CodelesslyChart':
        bind('data', c['data']);
        final Object? data = _literal(c['data']);
        return finish(
          CodelesslyNodes.chart(
            id: id,
            chartType: (c['chartType'] as String?) ?? 'line',
            rows: [
              if (data is List)
                for (final r in data)
                  if (r is Map)
                    {for (final e in r.entries) '${e.key}': e.value},
            ],
            xField: (c['xField'] as String?) ?? 'label',
            series: [
              for (final s in (c['series'] as List?) ?? const [])
                if (s is Map) {for (final e in s.entries) '${e.key}': e.value},
            ],
            width: _width,
            height: (c['height'] as num?)?.toDouble() ?? 200,
            theme: theme,
          ),
        );
      case 'CodelesslyGauge':
        bind('value', c['value']);
        return finish(
          CodelesslyNodes.gauge(
            id: id,
            value: (_literal(c['value']) as num?)?.toDouble() ?? 0,
            min: (c['min'] as num?)?.toDouble() ?? 0,
            max: (c['max'] as num?)?.toDouble() ?? 100,
            size: (c['size'] as num?)?.toDouble() ?? 180,
            theme: theme,
            zones: [
              for (final z in (c['zones'] as List?) ?? const [])
                if (z is Map) {for (final e in z.entries) '${e.key}': e.value},
            ],
          ),
        );
      case 'CodelesslyProgress':
        bind('currentValue', c['value']);
        final node = CodelesslyNodes.progress(
          id: id,
          value: (_literal(c['value']) as num?)?.toDouble() ?? 0,
          width: _width,
          theme: theme,
        );
        return finish({
          ...node,
          'currentValue': (_literal(c['value']) as num?)?.toDouble() ?? 0,
          'properties': {
            ...node['properties']! as Map<String, Object?>,
            'maxValue': 1,
          },
        });
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Codelessly → A2UI
  // -------------------------------------------------------------------------

  /// Maps Codelessly node JSON and variables to A2UI components and a data
  /// model. Text nodes inside buttons become the button's child Text again.
  A2uiSurfaceJson toA2ui(
    Map<String, Map<String, Object?>> nodes, {
    List<VariableData> variables = const [],
  }) {
    final List<Map<String, Object?>> components = [];
    final List<String> warnings = [];
    for (final Map<String, Object?> node in nodes.values) {
      final List<Map<String, Object?>>? mapped = _toComponents(node);
      if (mapped == null) {
        warnings.add('${node['id']}: ${node['type']} has no A2UI mapping.');
        continue;
      }
      components.addAll(mapped);
    }
    return A2uiSurfaceJson(
      components: components,
      warnings: warnings,
      dataModel: {for (final v in variables) v.name: v.getValue()},
    );
  }

  static Object? _value(
    Map<String, Object?> node,
    String property,
    Object? literal, {
    String returnType = 'any',
  }) {
    final Map? variables = node['variables'] as Map?;
    final Object? binding = variables?[property];
    if (binding is String && _isBinding(binding)) {
      return dynamicOf(binding, returnType: returnType);
    }
    return literal;
  }

  static Map<String, Object?>? _actionOf(Map<String, Object?> node) {
    for (final Object? r in (node['reactions'] as List?) ?? const []) {
      if (r is! Map) continue;
      final Object? action = r['action'];
      if (action is Map && action['name'] == kA2uiActionFunction) {
        final Map params = (action['params'] as Map?) ?? const {};
        return {
          'event': {
            'name': params['name'],
            if (params['context'] != null) 'context': params['context'],
          },
        };
      }
    }
    return null;
  }

  static String? _variantOfSize(num? size) => switch (size) {
    26 => 'h1',
    21 => 'h2',
    18 => 'h3',
    16 => 'h4',
    12 => 'caption',
    _ => null,
  };

  List<Map<String, Object?>>? _toComponents(Map<String, Object?> node) {
    final String id = '${node['id']}';
    final Map<String, Object?> props =
        (node['properties'] as Map?)?.cast<String, Object?>() ?? const {};
    final Map<String, Object?>? action = _actionOf(node);
    final Object? flexValue = node['flex'];
    final Map<String, Object?> weight =
        node['horizontalFit'] == 'expanded' &&
            flexValue is num &&
            node['type'] != 'row' &&
            node['type'] != 'column'
        ? {'weight': flexValue}
        : (node['type'] == 'row' || node['type'] == 'column') &&
              flexValue is num
        ? {'weight': flexValue}
        : const {};
    switch (node['type']) {
      case 'text':
        final List? styles = node['textMixedProps'] as List?;
        final num? size = styles != null && styles.isNotEmpty
            ? (styles.first as Map)['fontSize'] as num?
            : null;
        final String? variant = _variantOfSize(size);
        return [
          {
            'id': id,
            'component': 'Text',
            'text': _value(
              node,
              'data',
              node['data'] ?? '',
              returnType: 'string',
            ),
            'variant': ?variant,
            ...weight,
          },
        ];
      case 'row':
      case 'column':
        return [
          {
            'id': id,
            'component': node['type'] == 'row' ? 'Row' : 'Column',
            'children':
                node['a2uiTemplate'] ??
                [...(node['children'] as List? ?? const [])],
            if (node['mainAxisAlignment'] != null &&
                node['mainAxisAlignment'] != 'start')
              'justify': node['mainAxisAlignment'],
            if (node['crossAxisAlignment'] != null &&
                node['crossAxisAlignment'] != 'stretch')
              'align': node['crossAxisAlignment'],
            ...weight,
          },
        ];
      case 'frame':
        final List children = (node['children'] as List?) ?? const [];
        return [
          {
            'id': id,
            'component': 'Card',
            'child': children.isEmpty ? '' : '${children.first}',
          },
        ];
      case 'filledButton':
      case 'outlinedButton':
      case 'textButton':
        final String labelId = () {
          for (final Object? r in (node['reactions'] as List?) ?? const []) {
            final Object? a = r is Map ? r['action'] : null;
            if (a is Map &&
                a['params'] is Map &&
                (a['params'] as Map)['labelComponentId'] != null) {
              return '${(a['params'] as Map)['labelComponentId']}';
            }
          }
          return '${id}_label';
        }();
        return [
          {
            'id': id,
            'component': 'Button',
            'child': labelId,
            if (node['type'] == 'filledButton') 'variant': 'primary',
            if (node['type'] == 'textButton') 'variant': 'borderless',
            'action':
                action ??
                {
                  'event': {'name': id},
                },
          },
          {
            'id': labelId,
            'component': 'Text',
            'text': _value(
              node,
              'label',
              props['label'] ?? '',
              returnType: 'string',
            ),
          },
        ];
      case 'slider':
        final num min = (props['min'] as num?) ?? 0;
        final num max = (props['max'] as num?) ?? 1;
        final num? divisions = props['divisions'] as num?;
        return [
          {
            'id': id,
            'component': 'Slider',
            if (props['label'] != null) 'label': props['label'],
            'min': min,
            'max': max,
            if (divisions != null && divisions > 0)
              'step': _clean((max - min) / divisions),
            'value': _value(
              node,
              'value',
              node['value'] ?? min,
              returnType: 'number',
            ),
            'action': ?action,
          },
        ];
      case 'checkbox':
        return [
          {
            'id': id,
            'component': 'CheckBox',
            'label': node['name'] ?? '',
            'value': _value(
              node,
              'value',
              node['value'] ?? false,
              returnType: 'boolean',
            ),
            'action': ?action,
          },
        ];
      case 'switch':
        return [
          {
            'id': id,
            'component': 'CodelesslySwitch',
            'label': node['name'] ?? '',
            'value': _value(
              node,
              'value',
              node['value'] ?? false,
              returnType: 'boolean',
            ),
            'action': ?action,
          },
        ];
      case 'textField':
        final Map decoration = (props['decoration'] as Map?) ?? const {};
        final bool long = props['keyboardType'] == 'multiline';
        final bool number = props['keyboardType'] == 'number';
        final bool obscured = props['obscureText'] == true;
        return [
          {
            'id': id,
            'component': 'TextField',
            'label': decoration['labelText'] ?? '',
            'value': _value(node, 'inputValue', '', returnType: 'string'),
            if (long) 'variant': 'longText',
            if (number) 'variant': 'number',
            if (obscured) 'variant': 'obscured',
            'action': ?action,
          },
        ];
      case 'segmentedButton':
        return [
          {
            'id': id,
            'component': 'ChoicePicker',
            if (props['multiSelectionEnabled'] == true)
              'variant': 'multipleSelection',
            'options': [
              for (final s in (props['segments'] as List?) ?? const [])
                if (s is Map) {'label': s['label'], 'value': s['value']},
            ],
            'value': _value(node, 'selected', [
              ...(props['selectedSegments'] as List? ?? const []),
            ]),
            'action': ?action,
          },
        ];
      case 'divider':
        return [
          {'id': id, 'component': 'Divider'},
        ];
      case 'chart':
        final List series = (props['series'] as List?) ?? const [];
        return [
          {
            'id': id,
            'component': 'CodelesslyChart',
            'chartType': props['chartType'] ?? 'bar',
            'data': _value(
              node,
              'data',
              props['sampleData'] ?? const [],
              returnType: 'array',
            ),
            'xField': props['labelField'] ?? 'label',
            'series': [
              for (final s in series)
                if (s is Map)
                  {
                    'field': s['field'],
                    if (s['name'] != null && s['name'] != s['field'])
                      'name': s['name'],
                    if (s['kind'] != null &&
                        s['kind'] !=
                            (props['chartType'] == 'bar' ? 'bar' : 'line'))
                      'kind': s['kind'],
                    if (s['color'] != null) 'color': s['color'],
                    if (s['stack'] != null) 'stack': s['stack'],
                    if (s['dashed'] == true) 'dashed': true,
                    if (s['curved'] == true) 'curved': true,
                  },
            ],
            'height': _clean(
              (node['basicBoxLocal'] as List?)?[3] as num? ?? 200,
            ),
          },
        ];
      case 'gauge':
        final num min = (props['min'] as num?) ?? 0;
        final num max = (props['max'] as num?) ?? 100;
        final List zones = (props['zones'] as List?) ?? const [];
        return [
          {
            'id': id,
            'component': 'CodelesslyGauge',
            'value': _value(
              node,
              'value',
              node['value'] ?? 0,
              returnType: 'number',
            ),
            'min': min,
            'max': max,
            if (zones.isNotEmpty)
              'zones': [
                for (final z in zones)
                  if (z is Map)
                    {
                      'to': _clean(
                        min + ((z['to'] as num) / 100) * (max - min),
                      ),
                      'color': z['color'],
                    },
              ],
            'size': _clean((node['basicBoxLocal'] as List?)?[2] as num? ?? 180),
          },
        ];
      case 'progressBar':
        final num maxValue = (props['maxValue'] as num?) ?? 100;
        final num current = (node['currentValue'] as num?) ?? 0;
        return [
          {
            'id': id,
            'component': 'CodelesslyProgress',
            'value': _value(
              node,
              'currentValue',
              _clean(current / maxValue),
              returnType: 'number',
            ),
          },
        ];
    }
    return null;
  }

  static num _clean(num v) {
    final double r = double.parse(v.toDouble().toStringAsFixed(6));
    return r == r.roundToDouble() ? r.toInt() : r;
  }
}

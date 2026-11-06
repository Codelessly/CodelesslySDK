import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_genui/codelessly_genui.dart';
import 'package:flutter_test/flutter_test.dart';

/// One component of every mapped type, with literals, paths, formulas and
/// actions, as an agent would write them.
final List<Map<String, Object?>> components = [
  {'id': 'root', 'component': 'Column', 'children': ['title', 'row', 'card', 'divider', 'chart', 'gauge', 'progress']},
  {'id': 'title', 'component': 'Text', 'text': 'Trip budget', 'variant': 'h2'},
  {'id': 'row', 'component': 'Row', 'justify': 'spaceBetween', 'align': 'center', 'children': ['name', 'nights', 'save']},
  {'id': 'name', 'component': 'TextField', 'label': 'Name', 'value': {'path': '/name'}},
  {'id': 'nights', 'component': 'Slider', 'label': 'Nights', 'min': 1, 'max': 14, 'step': 1, 'value': {'path': '/nights'},
   'action': {'event': {'name': 'nights_changed', 'context': {'nights': {'path': '/nights'}}}}},
  {'id': 'save', 'component': 'Button', 'child': 'saveLabel', 'variant': 'primary',
   'action': {'event': {'name': 'submit', 'context': {'name': {'path': '/name'}}}}},
  {'id': 'saveLabel', 'component': 'Text', 'text': 'Save'},
  {'id': 'card', 'component': 'Card', 'child': 'cardBody'},
  {'id': 'cardBody', 'component': 'Column', 'children': ['agree', 'mode', 'alerts', 'total']},
  {'id': 'agree', 'component': 'CheckBox', 'label': 'Include taxes', 'value': {'path': '/tax'}},
  {'id': 'mode', 'component': 'ChoicePicker', 'options': [{'label': 'Car', 'value': 'car'}, {'label': 'Train', 'value': 'train'}], 'value': {'path': '/mode'}},
  {'id': 'alerts', 'component': 'CodelesslySwitch', 'label': 'Price alerts', 'value': {'path': '/alerts'}},
  {'id': 'total', 'component': 'Text', 'text': {'call': 'calc', 'args': {'expr': 'nights * 120'}, 'returnType': 'any'}},
  {'id': 'divider', 'component': 'Divider'},
  {'id': 'chart', 'component': 'CodelesslyChart', 'chartType': 'bar', 'data': {'path': '/days'}, 'xField': 'day',
   'series': [{'field': 'cost', 'name': 'Cost', 'color': '#3D5AFE'}], 'height': 180},
  {'id': 'gauge', 'component': 'CodelesslyGauge', 'value': {'path': '/used'}, 'min': 0, 'max': 100,
   'zones': [{'to': 60, 'color': '#26A69A'}, {'to': 100, 'color': '#EF5350'}], 'size': 180},
  {'id': 'progress', 'component': 'CodelesslyProgress', 'value': {'path': '/share'}},
];

final Map<String, Object?> dataModel = {
  'name': 'Ada',
  'nights': 3,
  'tax': true,
  'mode': ['car'],
  'alerts': false,
  'days': [
    {'day': 'Mon', 'cost': 120},
  ],
  'used': 42.5,
  'share': 0.4,
};

void main() {
  const mapping = A2uiCodelesslyMapping();

  test('every A2UI component maps to Codelessly node JSON the SDK reads', () {
    final layout = mapping.toCodelessly(components, dataModel: dataModel);
    expect(layout.warnings, isEmpty);
    // The button's label Text is absorbed into the button node.
    expect(layout.nodes.keys, isNot(contains('saveLabel')));
    for (final json in layout.nodes.values) {
      final BaseNode node = NodeJsonConverter.instance.fromJson({...json})!;
      expect(node.id, json['id']);
    }
    expect(layout.nodes['nights']!['type'], 'slider');
    expect(layout.nodes['nights']!['variables'], {'value': r'${nights}'});
    expect(layout.nodes['total']!['variables'], {'data': r'${= nights * 120}'});
    expect(layout.nodes['name']!['variables'], {'inputValue': r'${name}'});
    expect(layout.nodes['mode']!['variables'], {'selected': r'${mode}'});
    expect(layout.nodes['save']!['type'], 'filledButton');
    expect(layout.nodes['chart']!['type'], 'chart');
    expect(layout.nodes['gauge']!['gaugeKind'], 'radial');
    expect(layout.nodes['nights']!['parentID'], 'row');
  });

  test('the data model becomes typed variables', () {
    final layout = mapping.toCodelessly(components, dataModel: dataModel);
    final byName = {for (final v in layout.variables) v.name: v};
    expect(byName['nights']!.type, VariableType.integer);
    expect(byName['used']!.type, VariableType.decimal);
    expect(byName['tax']!.type, VariableType.boolean);
    expect(byName['mode']!.type, VariableType.list);
    expect(byName['days']!.type, VariableType.list);
    expect(byName['name']!.type, VariableType.text);
  });

  test('A2UI → Codelessly → A2UI round-trips every mapped component', () {
    final layout = mapping.toCodelessly(components, dataModel: dataModel);
    final back = mapping.toA2ui(layout.nodes, variables: layout.variables);
    expect(back.warnings, isEmpty);
    final Map<String, Map<String, Object?>> original = {
      for (final c in components) '${c['id']}': GenUiSession.normalize(c) as Map<String, Object?>,
    };
    final Map<String, Map<String, Object?>> restored = {
      for (final c in back.components) '${c['id']}': c,
    };
    expect(restored.keys.toSet(), original.keys.toSet());
    for (final id in original.keys) {
      expect(restored[id], original[id], reason: id);
    }
    expect(back.dataModel['nights'], 3);
    expect(back.dataModel['mode'], ['car']);
  });

  test('Codelessly → A2UI → Codelessly keeps node types and bindings', () {
    final first = mapping.toCodelessly(components, dataModel: dataModel);
    final a2ui = mapping.toA2ui(first.nodes, variables: first.variables);
    final second = mapping.toCodelessly(a2ui.components, dataModel: a2ui.dataModel);
    expect(second.nodes.keys.toSet(), first.nodes.keys.toSet());
    for (final id in first.nodes.keys) {
      expect(second.nodes[id]!['type'], first.nodes[id]!['type'], reason: id);
      expect(second.nodes[id]!['variables'], first.nodes[id]!['variables'], reason: id);
    }
  });

  test('bindings convert both ways', () {
    expect(A2uiCodelesslyMapping.bindingOf({'path': '/a/b/0'}), r'${a.b[0]}');
    expect(A2uiCodelesslyMapping.dynamicOf(r'${a.b[0]}'), {'path': '/a/b/0'});
    expect(A2uiCodelesslyMapping.bindingOf({'call': 'calc', 'args': {'expr': 'x+1'}}), r'${= x+1}');
    expect(A2uiCodelesslyMapping.bindingOf('literal'), isNull);
  });

  test('components without a node mapping are reported, not dropped silently', () {
    final layout = mapping.toCodelessly([
      {'id': 'root', 'component': 'Tabs', 'tabs': []},
    ]);
    expect(layout.warnings.single, contains('Tabs'));
  });
}

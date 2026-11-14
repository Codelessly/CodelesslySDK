// scrollTo takes an expression for its node, and says when the node it
// names is not on screen; a text field's suffix icon with a tap reaction
// (the guide's clear "×") clears the field.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';
import '../support/fields.dart';

class _Recorder implements AnalyticsService {
  final errors = <Object>[];
  @override
  void logError(Object error, {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) => errors.add(error);
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}
  @override
  void logScreen(String name, {String? layoutId}) {}
}

void main() {
  testWidgets('scroll-to can name its node with a formula, and a node not on screen is reported', (tester) async {
    final recorder = _Recorder();
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['strip', 'next', 'bad'], 'layout': {'width': 300, 'height': {'hug': 200}}},
      'strip': {'type': 'row', 'children': ['col-1', 'col-2', 'col-3'], 'layout': {'width': 300, 'height': 50},
        'props': {'scrollable': true, 'scrollDirection': 'horizontal'}},
      for (var i = 1; i <= 3; i++) 'col-$i': {'type': 'box', 'layout': {'width': 280, 'height': 50}},
      'next': {'type': 'box', 'layout': {'width': 100, 'height': 40},
        'actions': [reaction('click', [
          {'type': 'setVariable', 'variable': 'step', 'op': 'add', 'value': '1'},
          {'type': 'scrollTo', 'node': r'col-${step}', 'axis': 'horizontal', 'durationMs': 0},
        ])]},
      'bad': {'type': 'box', 'layout': {'width': 100, 'height': 40},
        'actions': [reaction('click', [{'type': 'scrollTo', 'node': r'col-${step + 10}', 'durationMs': 0}])]},
    }, variables: [v('step', 1, VariableType.integer)], services: Services(analytics: recorder));
    await tester.tapAt(s.center('next'));
    await tester.pumpAndSettle();
    final strip = s.tree.boxOf('col-3')!;
    expect(strip.localToGlobal(Offset.zero).dx, lessThan(300), reason: 'col-3 scrolled into view');
    expect(recorder.errors, isEmpty);
    await tester.tapAt(s.center('bad'));
    await tester.pumpAndSettle();
    expect('${recorder.errors.single}', contains('no node "col-12" is on screen'));
  });

  testWidgets('a suffix icon with a tap reaction clears the field; bound to no name it hides', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['search'], 'layout': {'width': 300, 'height': {'hug': 60}}},
      'search': {
        'type': 'textField',
        'layout': {'width': 280, 'height': 48},
        'bind': {'props.initialValue': r'${query}', 'props.decoration.suffixIcon.icon': r"${= query == '' ? '' : 'close'}"},
        'props': {
          'decoration': {
            'hintText': 'Search',
            'suffixIcon': {
              'icon': 'close',
              'size': 18,
              'actions': [reaction('click', [{'type': 'setVariable', 'variable': 'query', 'value': ''}])],
            },
          },
        },
      },
    }, variables: [v('query', '')]);
    await tester.pumpAndSettle();
    expect(textField(tester).decoration.suffix?.hasIcon ?? false, isFalse, reason: 'no text: no ×');
    await typeInto(tester, 'cauliflower');
    await tester.pumpAndSettle();
    expect(s['query'], 'cauliflower');
    final f = textField(tester);
    expect(f.decoration.suffix?.tappable, isTrue);
    final suffix = f.localToGlobal(Offset.zero) & f.size;
    await tester.tapAt(Offset(suffix.right - 20, suffix.center.dy));
    await tester.pumpAndSettle();
    expect(s['query'], '');
    expect(textField(tester).editor.text, '');
  });
}

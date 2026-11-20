// scrollTo takes an expression for its node, and says when the node it
// names is not on screen; a text field's suffix icon with a tap reaction
// (the guide's clear "×") clears the field.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  group('scrollTo of a copy by its item, in a list that builds the items near its view only', () {
    // A chat: a list that opens at its end, 60 messages of 40 px in 400, and
    // a pinned bar that goes to the second message, which is not built.
    Map<String, Json> chat() => {
          'col': {'type': 'column', 'children': ['bar', 'list'], 'layout': {'width': 300, 'height': 460}},
          'bar': {'type': 'box', 'layout': {'width': 300, 'height': 40},
            'actions': [reaction('click', [{'type': 'scrollTo', 'node': 'msg', 'item': r'${pinId}', 'durationMs': 0}])]},
          'list': {'type': 'listView', 'children': ['msg'], 'layout': {'width': 300, 'height': 400},
            'bind': {'data': r'${messages}'}, 'props': {'stickToEnd': true}},
          'msg': {'type': 'text', 'layout': {'width': 300, 'height': 40}, 'props': {'text': r'${item.text}'}},
        };
    List<Object?> messages() => [for (var i = 1; i <= 60; i++) {'id': 'm$i', 'text': 'M$i'}];
    double topOf(Screen s) => s.tree.boxOf('list')!.localToGlobal(Offset.zero).dy;
    // Where message [text] is drawn (null: not built).
    double? yOf(WidgetTester tester, String text) {
      double? at;
      void visit(RenderObject o) {
        if (o is RenderParagraph && o.attached && o.hasSize && o.text.toPlainText() == text) at = o.localToGlobal(Offset.zero).dy;
        o.visitChildren(visit);
      }

      visit(tester.binding.renderViews.first);
      return at;
    }

    testWidgets('the copy is built and scrolled to the start of the view', (tester) async {
      final recorder = _Recorder();
      final s = await show(tester, chat(), variables: [v('messages', messages(), VariableType.list), v('pinId', 'm2')], services: Services(analytics: recorder));
      await tester.pumpAndSettle();
      expect(yOf(tester, 'M2'), isNull, reason: 'not built: the list opened at its end');
      await tester.tapAt(s.center('bar'));
      await tester.pumpAndSettle();
      expect(recorder.errors, isEmpty);
      expect(yOf(tester, 'M2'), moreOrLessEquals(topOf(s), epsilon: 1));
    });

    testWidgets('an item no copy is of is said, and nothing else is revealed in its place', (tester) async {
      final recorder = _Recorder();
      final s = await show(tester, chat(), variables: [v('messages', messages(), VariableType.list), v('pinId', 'gone')], services: Services(analytics: recorder));
      await tester.pumpAndSettle();
      await tester.tapAt(s.center('bar'));
      await tester.pumpAndSettle();
      expect('${recorder.errors.single}', contains('no node "msg" (item gone)'));
      expect(yOf(tester, 'M60'), moreOrLessEquals(topOf(s) + 360, epsilon: 1), reason: 'still at its end');
    });

    testWidgets('an item\'s key named as the node is said with the way to reach it', (tester) async {
      final recorder = _Recorder();
      final doc = chat()
        ..['bar'] = {
          'type': 'box',
          'layout': {'width': 300, 'height': 40},
          'actions': [reaction('click', [{'type': 'scrollTo', 'node': r'${pinId}', 'durationMs': 0}])],
        };
      final s = await show(tester, doc, variables: [v('messages', messages(), VariableType.list), v('pinId', 'm2')], services: Services(analytics: recorder));
      await tester.pumpAndSettle();
      await tester.tapAt(s.center('bar'));
      await tester.pumpAndSettle();
      expect('${recorder.errors.single}', allOf(contains('no node "m2"'), contains('"node": "msg", "item": "m2"')));
    });
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

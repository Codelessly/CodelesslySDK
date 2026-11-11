import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' show show, v;

void main() {
  testWidgets(
    'collapsed decorated nodes can rebind after a skipped child layout',
    (tester) async {
      final screen = await show(
        tester,
        {
          'col': {
            'type': 'column',
            'layout': {'width': 200, 'height': 200},
            'children': ['card'],
          },
          'card': {
            'type': 'column',
            'layout': {
              'width': 150,
              'height': 100,
              'padding': [8, 8, 8, 8],
            },
            'decoration': {
              'fills': [
                {'color': '#FAF9F1'},
              ],
              'radius': 8,
              'strokes': [
                {'color': '#CDD3C7'},
              ],
              'strokeWidth': 1,
            },
            'bind': {'visible': r'${shown}'},
            'children': ['label', 'field'],
          },
          'field': {
            'type': 'textField',
            'layout': {'width': 100, 'height': 40},
            'bind': {'props.initialValue': r'${label}'},
          },
          'label': {
            'type': 'text',
            'props': {'text': r'${label}'},
            'layout': {'width': 100, 'height': 20},
          },
        },
        variables: [
          v('shown', true, VariableType.boolean),
          v('label', 'first'),
        ],
      );
      screen.scope.set('shown', false);
      await tester.pump();
      expect(screen.tree.boxOf('card')!.collapsed, isTrue);
      expect(screen.tree.boxOf('card')!.child, isNull,
          reason: 'runtime hiding retains cached layers outside the pipeline');
      for (var i = 0; i < 3; i++) {
        screen.scope.set('label', 'hidden $i');
        screen.scope.define(v('shown', false, VariableType.boolean));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      screen.scope.set('shown', true);
      await tester.pump();
      expect(screen.tree.boxOf('card')!.child, isNotNull);
      expect(screen.tree.boxOf('label')!.node!.prop(TextProps.text), 'hidden 2');
      expect(tester.takeException(), isNull);
    },
  );
}

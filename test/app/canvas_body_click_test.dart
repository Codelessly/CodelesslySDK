// A canvas's body slot runs its own click reactions, whatever its type: a
// plain box as the body is clickable like a stack.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final bodyType in ['stack', 'box']) {
    for (final size in ['fill', 'fixed']) {
      testWidgets('a $bodyType as the canvas body ($size size) runs its click reactions', (tester) async {
        final layout = PublishLayout.fromJson({
          'schema': 2,
          'id': 'home',
          'roots': ['c'],
          'nodes': {
            'c': {
              'type': 'canvas',
              'slots': {'body': 'b'},
              'layout': {'width': 400, 'height': 600},
            },
            'b': {
              'type': bodyType,
              'layout': size == 'fill'
                  ? {'width': {'fill': 400}, 'height': {'fill': 600}}
                  : {'width': 400, 'height': 600},
              'decoration': {
                'fills': [
                  {'type': 'solid', 'color': '#FF336699'},
                ],
              },
              'actions': [
                {
                  'trigger': {'type': 'click'},
                  'actions': [
                    {'type': 'setVariable', 'variable': 'taps', 'op': 'add', 'value': '1'},
                  ],
                },
              ],
            },
          },
          'variables': {
            'c': [const Variable(name: 'taps', type: VariableType.integer, value: 0).toJson()],
          },
        });
        final app = Codelessly.fromBundle(
          PublishBundle(
            model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
            layouts: {'home': layout},
          ),
          config: CodelesslyConfig(services: Services(analytics: const NoAnalytics())),
          fonts: const NoFontFetcher(),
        );
        final controller = CodelesslyWidgetController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, layoutId: 'home', controller: controller)));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(200, 300));
        await tester.pumpAndSettle();
        expect(controller.read('taps'), 1);
        await tester.pumpWidget(const SizedBox());
        app.dispose();
      });
    }
  }
}

import 'dart:async';
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  testWidgets('a modal destination chooses its responsive canvas by width', (tester) async {
    setScreen(tester, const Size(1000, 900));
    final home = PublishLayout.fromJson({
      'schema': 2,
      'id': 'home',
      'roots': ['h'],
      'nodes': {
        'h': {
          'type': 'canvas',
          'slots': {'body': 'button'},
          'layout': {'width': 1000, 'height': 900},
        },
        'button': {
          'type': 'box',
          'layout': {'width': 100, 'height': 40},
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'openModal', 'to': 'm', 'barrierBlur': 1},
              ],
            },
          ],
        },
      },
    });
    final dialog = PublishLayout.fromJson({
      'schema': 2,
      'id': 'dialog',
      'roots': ['m', 'd'],
      'nodes': {
        'm': {
          'type': 'canvas',
          'layout': {'width': 360, 'height': 500},
        },
        'd': {
          'type': 'canvas',
          'layout': {'width': 900, 'height': 500},
        },
      },
      'breakpoints': [
        {'canvas': 'm', 'minWidth': 0},
        {'canvas': 'd', 'minWidth': 700},
      ],
    });
    final app = Codelessly.fromBundle(
      PublishBundle(
        model: PublishModel(
          projectId: 'p',
          entryLayoutId: 'home',
          layouts: {'home': PublishLayoutInfo.of(home), 'dialog': PublishLayoutInfo.of(dialog)},
        ),
        layouts: {'home': home, 'dialog': dialog},
      ),
    );
    addTearDown(app.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: app, controller: controller),
      ),
    );
    await settle(tester);
    unawaited(controller.trigger('button', 'click'));
    await settle(tester);
    final views = find.byType(NodeView).evaluate().map((e) => e.widget as NodeView).toList();
    expect(views.last.rootId, 'd');
    expect(tester.getSize(find.byType(NodeView).last).width, 900);
    expect(tester.takeException(), isNull);
  });
}

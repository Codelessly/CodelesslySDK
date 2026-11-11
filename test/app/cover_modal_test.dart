// A modal that covers the screen: its one canvas fills the screen, so its
// root (a fill) and its responsive layouts follow the device, not the
// canvas's narrow design size.
import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

Future<NodeView> _open(WidgetTester tester, {required bool cover}) async {
  setScreen(tester, const Size(1194, 834));
  final home = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['h'],
    'nodes': {
      'h': {'type': 'canvas', 'slots': {'body': 'button'}, 'layout': {'width': 1194, 'height': 834}},
      'button': {
        'type': 'box',
        'layout': {'width': 100, 'height': 40},
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'openModal', 'to': 'm', 'cover': cover, 'barrierColor': '#00000000'},
            ],
          },
        ],
      },
    },
  });
  final flash = PublishLayout.fromJson({
    'schema': 2,
    'id': 'flash',
    'roots': ['m'],
    'nodes': {
      'm': {'type': 'canvas', 'slots': {'body': 'screen'}, 'layout': {'width': 390, 'height': 844}},
      'screen': {
        'type': 'box',
        'layout': {
          'width': {'fill': 390},
          'height': {'fill': 844},
        },
      },
    },
  });
  final app = Codelessly.fromBundle(
    PublishBundle(
      model: PublishModel(
        projectId: 'p',
        entryLayoutId: 'home',
        layouts: {'home': PublishLayoutInfo.of(home), 'flash': PublishLayoutInfo.of(flash)},
      ),
      layouts: {'home': home, 'flash': flash},
    ),
  );
  addTearDown(app.dispose);
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
  await settle(tester);
  unawaited(controller.trigger('button', 'click'));
  await settle(tester);
  return find.byType(NodeView).evaluate().map((e) => e.widget as NodeView).last;
}

void main() {
  testWidgets('a covering modal fills the screen', (tester) async {
    final view = await _open(tester, cover: true);
    expect(view.rootId, 'm');
    expect(tester.getSize(find.byType(NodeView).last), const Size(1194, 834));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dialog keeps its design size', (tester) async {
    await _open(tester, cover: false);
    expect(tester.getSize(find.byType(NodeView).last), const Size(390, 834));
    expect(tester.takeException(), isNull);
  });
}

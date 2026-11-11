// A screen's load actions can open a modal, decided by a link parameter that
// sets an app variable (`/?learn=1` opens the tutorial sheet).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  testWidgets('a load action opens a modal when a link param sets the app variable it reads', (tester) async {
    setScreen(tester, const Size(1000, 900));
    final home = PublishLayout.fromJson({
      'schema': 2,
      'id': 'home',
      'roots': ['h'],
      'nodes': {
        'h': {
          'type': 'canvas',
          'slots': {'body': 'label'},
          'layout': {'width': 1000, 'height': 900},
          'actions': [
            {
              'trigger': {'type': 'load'},
              'actions': [
                {
                  'type': 'if',
                  'condition': {'left': r'${learn}', 'op': 'isTrue'},
                  'then': [
                    {'type': 'openModal', 'to': 'm', 'presentation': 'adaptive', 'showDragHandle': true},
                  ],
                },
              ],
            },
          ],
        },
        'label': {'type': 'text', 'props': {'text': 'Library'}},
      },
    });
    final sheet = PublishLayout.fromJson({
      'schema': 2,
      'id': 'tutorial',
      'roots': ['m'],
      'nodes': {
        'm': {'type': 'canvas', 'slots': {'body': 't'}, 'layout': {'width': 600, 'height': 400}},
        't': {'type': 'text', 'props': {'text': 'Timeline basics'}},
      },
    });
    final app = Codelessly.fromBundle(
      PublishBundle(
        model: PublishModel(
          projectId: 'p',
          entryLayoutId: 'home',
          layouts: {'home': PublishLayoutInfo.of(home), 'tutorial': PublishLayoutInfo.of(sheet)},
          variables: {
            'l': {'id': 'l', 'name': 'learn', 'type': 'boolean', 'value': false},
          },
        ),
        layouts: {'home': home, 'tutorial': sheet},
      ),
    );
    addTearDown(app.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, params: const {'learn': '1'})));
    await settle(tester);
    final shown = find.byType(NodeView).evaluate().map((e) => (e.widget as NodeView).rootId).toList();
    expect(shown, ['h', 'm']);
    expect(tester.takeException(), isNull);
  });
}

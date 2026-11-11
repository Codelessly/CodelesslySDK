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

  testWidgets('a sheet asking for a drag handle draws it over the top of the screen', (tester) async {
    setScreen(tester, const Size(390, 844));
    final home = PublishLayout.fromJson({
      'schema': 2,
      'id': 'home',
      'roots': ['h'],
      'nodes': {
        'h': {
          'type': 'canvas',
          'slots': {'body': 'label'},
          'layout': {'width': 390, 'height': 844},
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
    final handle = find.byKey(const ValueKey('Codelessly sheet drag handle'));
    expect(handle, findsOneWidget);
    final shown = tester.getRect(find.byType(NodeView).last);
    final grip = tester.getRect(handle);
    expect(shown.contains(grip.center), isTrue, reason: 'on the screen, not above it: $grip in $shown');
    expect(grip.top - shown.top, lessThan(16));
    expect(tester.takeException(), isNull);
  });

  Future<String?> shownAs(WidgetTester tester, Size size) async {
    setScreen(tester, size);
    final home = PublishLayout.fromJson({
      'schema': 2,
      'id': 'home',
      'roots': ['h'],
      'nodes': {
        'h': {
          'type': 'canvas',
          'layout': {'width': size.width, 'height': size.height},
          'actions': [
            {
              'trigger': {'type': 'load'},
              'actions': [
                {'type': 'openModal', 'to': 'm', 'presentation': 'adaptive', 'showDragHandle': true},
              ],
            },
          ],
        },
      },
    });
    final sheet = PublishLayout.fromJson({
      'schema': 2,
      'id': 'tutorial',
      'roots': ['m'],
      'nodes': {
        'm': {
          'type': 'canvas',
          'layout': {'width': 600, 'height': {'hug': 400}},
          'actions': [
            {
              'trigger': {'type': 'load'},
              'actions': [
                {'type': 'setVariable', 'variable': 'shownAs', 'value': r"${= screen.sheet ? 'sheet' : (screen.modal ? 'dialog' : 'screen')}"},
              ],
            },
          ],
        },
      },
    });
    final app = Codelessly.fromBundle(
      PublishBundle(
        model: PublishModel(
          projectId: 'p',
          entryLayoutId: 'home',
          layouts: {'home': PublishLayoutInfo.of(home), 'tutorial': PublishLayoutInfo.of(sheet)},
          variables: {
            's': {'id': 's', 'name': 'shownAs', 'type': 'text', 'value': ''},
          },
        ),
        layouts: {'home': home, 'tutorial': sheet},
      ),
    );
    addTearDown(app.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app)));
    await settle(tester);
    return app.appVariables.read('shownAs') as String?;
  }

  testWidgets('a modal screen reads how it is shown: screen.sheet on a phone, a dialog on a wide screen', (tester) async {
    expect(await shownAs(tester, const Size(390, 844)), 'sheet');
    expect(await shownAs(tester, const Size(1000, 900)), 'dialog');
  });
}

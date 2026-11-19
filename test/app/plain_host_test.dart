import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/shell_controls.dart';
import 'support.dart';

// A host app that is not a Material app: a plain WidgetsApp, with no
// MaterialLocalizations and no Theme above the SDK. A dialog, a sheet, a
// presented sheet, a full-screen modal, a confirm dialog and a toast open in
// it without an error, as they do under a MaterialApp.

Json _button(Json action) => {
      'type': 'box',
      'layout': {'width': 100, 'height': 40},
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [action],
        },
      ],
    };

Codelessly _app(Json action) {
  final home = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['h'],
    'nodes': {
      'h': {'type': 'canvas', 'slots': {'body': 'button'}, 'layout': {'width': 390, 'height': 844}},
      'button': _button(action),
    },
  });
  final sheet = PublishLayout.fromJson({
    'schema': 2,
    'id': 'sheet',
    'roots': ['m'],
    'nodes': {
      'm': {'type': 'canvas', 'slots': {'body': 'screen'}, 'layout': {'width': 300, 'height': 200}},
      'screen': {
        'type': 'box',
        'layout': {'width': 300, 'height': 200},
        'children': ['label'],
      },
      'label': {'type': 'text', 'props': {'text': 'In the modal'}},
    },
  });
  return Codelessly.fromBundle(
    PublishBundle(
      model: PublishModel(
        projectId: 'p',
        entryLayoutId: 'home',
        layouts: {'home': PublishLayoutInfo.of(home), 'sheet': PublishLayoutInfo.of(sheet)},
      ),
      layouts: {'home': home, 'sheet': sheet},
    ),
  );
}

/// The two hosts: a plain widgets app (a navigator, and nothing of
/// Material's) and a Material app.
final Map<String, Widget Function(Widget home)> hosts = {
  'WidgetsApp': (home) => WidgetsApp(
        color: const Color(0xFF2196F3),
        onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => home),
      ),
  'MaterialApp': (home) => MaterialApp(home: home),
};

Future<void> _press(WidgetTester tester, Widget Function(Widget) host, Json action) async {
  setScreen(tester, const Size(390, 844));
  final app = _app(action);
  addTearDown(app.dispose);
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(host(CodelesslyWidget(codelessly: app, controller: controller)));
  await settle(tester);
  unawaited(controller.trigger('button', 'click'));
  await settle(tester);
}

void main() {
  for (final MapEntry(key: name, value: host) in hosts.entries) {
    group('under a $name', () {
      testWidgets('the host has ${name == 'WidgetsApp' ? 'no' : 'its'} Material localizations', (tester) async {
        late BuildContext inside;
        await tester.pumpWidget(host(Builder(builder: (c) {
          inside = c;
          return const SizedBox();
        })));
        final found = Localizations.of<MaterialLocalizations>(inside, MaterialLocalizations);
        expect(found, name == 'WidgetsApp' ? isNull : isNotNull);
        if (name == 'WidgetsApp') expect(inside.findAncestorWidgetOfExactType<Theme>(), isNull);
      });

      for (final presentation in ['dialog', 'bottomSheet', 'sideSheet', 'fullScreen', 'adaptive']) {
        testWidgets('a modal opens as a $presentation, and closes', (tester) async {
          await _press(tester, host, {'type': 'openModal', 'to': 'm', 'presentation': presentation});
          expect(tester.takeException(), isNull);
          // A full-screen modal is a page: the screen under it is off stage.
          expect(
            find.byType(NodeView, skipOffstage: false),
            findsNWidgets(2),
            reason: 'the screen and the modal over it',
          );
          final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
          expect(navigator.canPop(), isTrue);
          navigator.pop();
          await settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(NodeView), findsOneWidget);
        });
      }

      testWidgets('a modal that covers the screen opens', (tester) async {
        await _press(tester, host, {'type': 'openModal', 'to': 'm', 'cover': true});
        expect(tester.takeException(), isNull);
        expect(find.byType(NodeView), findsNWidgets(2));
      });

      testWidgets('a modal with a blurred barrier opens (the presented dialog)', (tester) async {
        await _press(tester, host, {'type': 'openModal', 'to': 'm', 'barrierBlur': 8});
        expect(tester.takeException(), isNull);
        expect(find.byType(NodeView), findsNWidgets(2));
      });

      testWidgets('a confirm dialog opens, and its answer closes it', (tester) async {
        await _press(tester, host, {'type': 'confirm', 'title': 'Remove it?', 'message': 'It cannot be undone.'});
        expect(tester.takeException(), isNull);
        expect(find.text('Remove it?'), findsOneWidget);
        await tester.tap(shellButton('Cancel'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Remove it?'), findsNothing);
      });

      testWidgets('a confirm dialog opens as a sheet', (tester) async {
        await _press(tester, host, {'type': 'confirm', 'title': 'Remove it?', 'presentation': 'bottomSheet'});
        expect(tester.takeException(), isNull);
        expect(find.text('Remove it?'), findsOneWidget);
      });

      testWidgets('a toast shows, with a button and a close button', (tester) async {
        await _press(tester, host, {
          'type': 'showToast',
          'message': 'Saved',
          'actionLabel': 'View',
          'showClose': true,
          'durationMs': 4000,
        });
        expect(tester.takeException(), isNull);
        expect(find.text('Saved'), findsOneWidget);
        expect(shellButton('View'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Saved'), findsNothing);
      });

      testWidgets('the loading screen spins', (tester) async {
        await tester.pumpWidget(host(const CodelesslyLoadingScreen()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(CodelesslyLoadingScreen)), isNot(Size.zero));
      });
    });
  }
}

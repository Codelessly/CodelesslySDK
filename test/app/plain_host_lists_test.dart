import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/features/media/players.dart' show MediaPlayerButton, MediaSeekBar;
import 'package:codelessly_sdk/src/widgets/collections_data_list.dart' show PullToRefresh;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/shell_controls.dart';
import 'plain_host_test.dart' show hosts;
import 'support.dart';

// The chrome of a list and of a player in a host app that is not a Material
// app (a plain WidgetsApp), and in one that is: a swiped row's Undo bar, a
// chat list's jump-to-latest button, pull to refresh, and the audio player's
// button and seek bar.

Json _text(String bind) => {
      'type': 'text',
      'layout': {'width': {'hug': 60}, 'height': {'hug': 20}},
      'bind': {'props.text': bind},
      'props': {
        'text': 'Row',
        'style': {'fontSize': 13, 'color': '#FF14181F'},
      },
    };

Json _row(String child) => {
      'type': 'row',
      'children': [child],
      'layout': {'width': {'fill': 358}, 'height': 40},
      'decoration': {
        'fills': [
          {'color': '#FFF1F3F5'},
        ],
      },
    };

Codelessly _app() {
  final home = PublishLayout.fromJson({
    'schema': 3,
    'id': 'home',
    'roots': ['h'],
    'variables': {
      'h': [
        {'id': 'v1', 'name': 'trees', 'type': 'list', 'value': [for (final t in ['Elm', 'Fir', 'Gum']) {'id': t, 't': t}]},
        {'id': 'v2', 'name': 'chat', 'type': 'list', 'value': [for (var i = 0; i < 12; i++) {'id': 'm$i', 't': 'Message $i'}]},
        {'id': 'v3', 'name': 'refreshed', 'type': 'integer', 'value': 0},
      ],
    },
    'nodes': {
      'h': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': 844}},
      'col': {
        'type': 'column',
        'children': ['swipes', 'chat', 'pulled', 'audio'],
        'layout': {'width': {'fill': 390}, 'height': {'fill': 844}, 'padding': {'left': 16, 'top': 16, 'right': 16, 'bottom': 16}},
        'props': {'spacing': 12},
      },
      'swipes': {
        'type': 'listView',
        'props': {
          'swipeActions': {
            'endActions': [
              {'id': 'delete', 'label': 'Delete'},
            ],
            'apply': 'variable',
            'undoMs': 2000,
          },
        },
        'layout': {'width': {'fill': 358}, 'height': 180},
        'bind': {'data': r'${trees}'},
        'children': ['swipeRow'],
      },
      'swipeRow': _row('swipeText'),
      'swipeText': _text(r'${item.t}'),
      'chat': {
        'type': 'listView',
        'props': {'stickToEnd': true},
        'layout': {'width': {'fill': 358}, 'height': 160},
        'bind': {'data': r'${chat}'},
        'children': ['chatRow'],
      },
      'chatRow': _row('chatText'),
      'chatText': _text(r'${item.t}'),
      'pulled': {
        'type': 'listView',
        'props': {'pullToRefresh': true},
        'layout': {'width': {'fill': 358}, 'height': 160},
        'bind': {'data': r'${chat}'},
        'children': ['pulledRow'],
        'actions': [
          {
            'trigger': {'type': 'refresh'},
            'actions': [
              {'type': 'setVariable', 'variable': 'refreshed', 'op': 'add', 'value': '1'},
            ],
          },
        ],
      },
      'pulledRow': _row('pulledText'),
      'pulledText': _text(r'${item.t}'),
      'audio': {
        'type': 'audioPlayer',
        'props': {'url': '', 'description': 'Morning brief'},
        'layout': {'width': {'fill': 358}, 'height': 64},
      },
    },
  });
  return Codelessly.fromBundle(
    PublishBundle(
      model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(home)}),
      layouts: {'home': home},
    ),
  );
}

Future<CodelesslyWidgetController> _show(WidgetTester tester, Widget Function(Widget) host) async {
  setScreen(tester, const Size(390, 844));
  final app = _app();
  addTearDown(app.dispose);
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(host(CodelesslyWidget(codelessly: app, controller: controller)));
  await settle(tester);
  return controller;
}

Rect _rectOf(CodelesslyWidgetController controller, String id) {
  final box = controller.tree!.boxOf(id)!;
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  for (final MapEntry(key: name, value: host) in hosts.entries) {
    group('under a $name', () {
      testWidgets('a swiped row shows the Undo bar, and Undo puts the row back', (tester) async {
        final controller = await _show(tester, host);
        final list = _rectOf(controller, 'swipes');
        await tester.dragFrom(list.topCenter + const Offset(0, 60), const Offset(-250, 0));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(shellButton('Undo'), findsOneWidget);
        expect((controller.read('trees') as List).length, 3, reason: 'not taken out until the bar goes');
        await tester.tap(shellButton('Undo'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(shellButton('Undo'), findsNothing);
        // (The bar's own time runs out.)
        await tester.pump(const Duration(seconds: 3));
        expect((controller.read('trees') as List).length, 3);
      });

      testWidgets('a chat list scrolled back shows the jump-to-latest button, which goes back to the end', (tester) async {
        final controller = await _show(tester, host);
        final latest = find.byKey(const ValueKey('followListLatest'));
        expect(latest, findsNothing, reason: 'it opens at its end');
        final list = _rectOf(controller, 'chat');
        await tester.dragFrom(list.center, const Offset(0, 200));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(latest, findsOneWidget);
        expect(tester.getSize(latest), const Size(48, 48));
        await tester.tap(latest);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(latest, findsNothing);
      });

      testWidgets('a list pulled past its start shows the indicator and refreshes', (tester) async {
        final controller = await _show(tester, host);
        expect(find.byType(PullToRefresh), findsOneWidget);
        final indicator = find.byKey(const ValueKey('Codelessly pull to refresh'));
        final list = _rectOf(controller, 'pulled');
        // A short pull lets go without refreshing.
        final short = await tester.startGesture(list.topCenter + const Offset(0, 20));
        await short.moveBy(const Offset(0, 30));
        await tester.pump();
        expect(indicator, findsOneWidget);
        await short.up();
        await settle(tester);
        expect(indicator, findsNothing);
        expect(controller.read('refreshed'), 0);
        // A long one refreshes, and the indicator leaves when it is done.
        final long = await tester.startGesture(list.topCenter + const Offset(0, 20));
        for (var i = 0; i < 8; i++) {
          await long.moveBy(const Offset(0, 15));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(indicator, findsOneWidget);
        await long.up();
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(controller.read('refreshed'), 1);
        expect(indicator, findsNothing);
      });

      testWidgets('the audio player shows its button and its seek bar', (tester) async {
        await _show(tester, host);
        expect(tester.takeException(), isNull);
        expect(find.byType(MediaPlayerButton), findsOneWidget);
        expect(tester.getSize(find.byType(MediaPlayerButton)), const Size(40, 40));
        expect(find.byType(MediaSeekBar), findsOneWidget);
        expect(tester.getSize(find.byType(MediaSeekBar)).height, 24);
      });
    });
  }
}

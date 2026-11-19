// The stop an overlay sheet rests at, kept in a variable (`Sheet#id
// stops=[0.5,1] stop=@name`, an openModal's `stopVariable`): the sheet
// writes it as it opens and when it is dragged or stepped to another stop,
// setting it moves the open sheet, a sheet opened while it holds a stop
// opens there, and it is 0 while the sheet is closed.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart' show boxesOf, centerOf, settle, textOf;

const _page = '''
state sheetStop=0
Column gap=12 pad=16
  Text#at "{sheetStop}"
  Button#open "Read" onTap={open story}
  Button#openFull "Read it all" onTap={sheetStop=1; open story}
Sheet#story "The tide tables" stops=[0.5,1] stop=@sheetStop
  Text#summary "A summary" visible={sheetStop < 1}
  Button#all "All of it" onTap={sheetStop=1}
  Button#less "Less" onTap={sheetStop=0.5}
  Button#near "Nearly all" onTap={sheetStop=0.8}
''';

Future<UiSession> _show(WidgetTester tester, String notation) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.reset);
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(notation), options: const NotationOptions(width: 390));
  await settle(tester);
  expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

final _handle = find.byKey(const ValueKey('Codelessly sheet drag handle'));

/// The top of the open sheet (its handle is drawn 8 px below it).
double _top(WidgetTester tester) => tester.getTopLeft(_handle).dy - 8;

void main() {
  testWidgets('the sheet writes the stop it opens at, and 0 when it closes', (tester) async {
    await _show(tester, _page);
    expect(textOf(tester, 'at'), '0');
    await tester.tapAt(centerOf(tester, 'open'));
    await settle(tester);
    expect(_top(tester), closeTo(400, 2), reason: 'half of 800');
    expect(textOf(tester, 'at'), '0.5');
    expect(boxesOf(tester, 'summary').any((b) => b.drawn), isTrue);
    // A tap outside closes it.
    await tester.tapAt(const Offset(195, 40));
    await settle(tester);
    expect(_handle, findsNothing);
    expect(textOf(tester, 'at'), '0');
  });

  testWidgets('a drag to another stop, the handle and the keyboard write the stop', (tester) async {
    await _show(tester, _page);
    await tester.tapAt(centerOf(tester, 'open'));
    await settle(tester);
    await tester.drag(_handle, const Offset(0, -340));
    await settle(tester);
    expect(_top(tester), closeTo(0, 2), reason: 'the whole window');
    expect(textOf(tester, 'at'), '1');
    await tester.drag(_handle, const Offset(0, 340));
    await settle(tester);
    expect(_top(tester), closeTo(400, 2));
    expect(textOf(tester, 'at'), '0.5');
    // A tap on the handle steps to the next stop.
    await tester.tap(find.byKey(const ValueKey('Codelessly sheet drag area')));
    await settle(tester);
    expect(textOf(tester, 'at'), '1');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    expect(_top(tester), closeTo(400, 2));
    expect(textOf(tester, 'at'), '0.5');
  });

  testWidgets('setting the variable moves the open sheet, to the nearest stop', (tester) async {
    await _show(tester, _page);
    await tester.tapAt(centerOf(tester, 'open'));
    await settle(tester);
    expect(_top(tester), closeTo(400, 2));
    await tester.tapAt(centerOf(tester, 'all'));
    await settle(tester);
    expect(_top(tester), closeTo(0, 2));
    expect(textOf(tester, 'at'), '1');
    await tester.tapAt(centerOf(tester, 'less'));
    await settle(tester);
    expect(_top(tester), closeTo(400, 2));
    expect(textOf(tester, 'at'), '0.5');
    // 0.8 is no stop: the sheet goes to the nearest (1) and the variable takes it.
    await tester.tapAt(centerOf(tester, 'near'));
    await settle(tester);
    expect(_top(tester), closeTo(0, 2));
    expect(textOf(tester, 'at'), '1');
  });

  testWidgets('a sheet opened while the variable holds one of its stops opens there', (tester) async {
    await _show(tester, _page);
    await tester.tapAt(centerOf(tester, 'openFull'));
    await settle(tester);
    expect(_top(tester), closeTo(0, 2));
    expect(textOf(tester, 'at'), '1');
    expect(boxesOf(tester, 'summary').any((b) => b.drawn), isFalse);
  });

  testWidgets('a sheet with stops and no variable is as before', (tester) async {
    await _show(tester, _page.replaceFirst(' stop=@sheetStop', ''));
    await tester.tapAt(centerOf(tester, 'open'));
    await settle(tester);
    expect(_top(tester), closeTo(400, 2));
    expect(textOf(tester, 'at'), '0');
    await tester.drag(_handle, const Offset(0, -340));
    await settle(tester);
    expect(_top(tester), closeTo(0, 2));
    expect(textOf(tester, 'at'), '0');
  });
}

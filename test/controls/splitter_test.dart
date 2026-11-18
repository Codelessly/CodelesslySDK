import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/splitter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';

const _page = '''
state paneWidth=300
Page
  Section
    Row
      Column w={paneWidth} clip visible={paneWidth>0}
        Text "Map"
      Splitter#splitGrip @paneWidth min=0 max=700 step=20 collapseAt=48 label="Resize map and stations"
      Column grow
        Text "Stations"
''';

RenderSplitter _splitter(WidgetTester tester) {
  RenderSplitter? found;
  void visit(RenderObject o) {
    if (o is RenderSplitter) found = o;
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return found!;
}

Future<void> _show(
  WidgetTester tester, {
  String source = _page,
  Size size = const Size(1280, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: CodelesslyView(session: session)),
    ),
  );
  final result = await session.applyNotation(Stream.value(source.trimLeft()));
  await tester.pump();
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
}

void main() {
  testWidgets(
    'one Tab stop, arrows and bounds, collapse/restore, pointer drag and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _show(tester);
      final keys = Keyboard(tester);
      await keys.tab();
      expect(keys.focusedId, 'splitGrip');
      expect(keys.stopIds(_splitter(tester)), ['splitGrip']);
      expect(keys.ringShown, isTrue);
      expect(keys.semantics!.label, 'Resize map and stations');
      expect(keys.semantics!.data.flagsCollection.isSlider, isTrue);
      expect(keys.semantics!.value, contains('300 pixels'));
      await keys.right();
      expect(_splitter(tester).value, 320);
      await keys.left();
      expect(_splitter(tester).value, 300);
      await keys.press(LogicalKeyboardKey.pageUp);
      expect(_splitter(tester).value, 500);
      await keys.press(LogicalKeyboardKey.pageDown);
      expect(_splitter(tester).value, 300);
      await keys.home();
      expect(_splitter(tester).value, 0);
      expect(keys.focusedId, 'splitGrip');
      expect(keys.semantics!.value, contains('leading pane collapsed'));
      await keys.space();
      expect(_splitter(tester).value, 300);
      await keys.end();
      expect(_splitter(tester).value, 700);
      expect(keys.semantics!.value, contains('trailing pane collapsed'));
      await keys.enter();
      expect(_splitter(tester).value, 300);

      final grip = _splitter(tester);
      final start = grip.localToGlobal(grip.size.center(Offset.zero));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(82, 0));
      await gesture.up();
      await tester.pump();
      expect(_splitter(tester).value, greaterThan(350));
      expect(
        keys.ringShown,
        isFalse,
        reason: 'a pointer must not draw a keyboard focus ring',
      );
      expect(keys.semantics!.value, contains('pixels'));
      final beforeCancel = _splitter(tester).value;
      final cancel = await tester.startGesture(
        _splitter(tester).localToGlobal(_splitter(tester).size.center(Offset.zero)),
      );
      await cancel.moveBy(const Offset(60, 0));
      await keys.escape();
      await cancel.up();
      expect(
        _splitter(tester).value,
        beforeCancel,
        reason: 'Escape cancels a drag in progress',
      );
      final beforeCollapse = _splitter(tester).value;
      final collapse = await tester.startGesture(
        _splitter(tester).localToGlobal(_splitter(tester).size.center(Offset.zero)),
      );
      await collapse.moveBy(const Offset(-600, 0));
      await collapse.up();
      await tester.pump();
      expect(_splitter(tester).value, 0);
      await keys.space();
      expect(
        _splitter(tester).value,
        beforeCollapse,
        reason: 'a collapsed pane restores its last settled width',
      );
      semantics.dispose();
    },
  );

  testWidgets('right-to-left reverses horizontal arrows', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(
      tester,
      source: _page.replaceFirst('Page', 'Page {"textDirection":"rtl"}'),
    );
    final keys = Keyboard(tester);
    await keys.tab();
    expect(keys.focusedId, 'splitGrip');
    expect(keys.semantics!.data.textDirection, TextDirection.rtl);
    await keys.right();
    expect(_splitter(tester).value, 280);
    await keys.left();
    expect(_splitter(tester).value, 300);
    final grip = _splitter(tester);
    final drag = await tester.startGesture(
      grip.localToGlobal(grip.size.center(Offset.zero)),
    );
    await drag.moveBy(const Offset(60, 0));
    await drag.up();
    await tester.pump();
    expect(_splitter(tester).value, lessThan(300));
    semantics.dispose();
  });

  testWidgets('a vertical split fits a phone and moves by touch and Down', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _show(
      tester,
      size: const Size(390, 844),
      source: '''
state paneHeight=220
Page
  Section
    Column
      Column h={paneHeight}
        Text "Map"
      Splitter#splitGrip @paneHeight orientation=vertical min=0 max=500 step=20 label="Resize map height" w=fill
      Column
        Text "Stations"
''',
    );
    final keys = Keyboard(tester);
    await keys.tab();
    expect(keys.focusedId, 'splitGrip');
    await keys.down();
    expect(_splitter(tester).value, 240);
    final grip = _splitter(tester);
    expect(grip.size.height, greaterThanOrEqualTo(44));
    expect(grip.size.width, greaterThanOrEqualTo(44));
    final start = grip.localToGlobal(grip.size.center(Offset.zero));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 80));
    await gesture.up();
    await tester.pump();
    expect(_splitter(tester).value, greaterThan(280));
    expect(keys.semantics!.value, contains('pixels'));
    semantics.dispose();
  });

  // Test 9 (mail, admin): a Splitter between panes drew a 44 px stub at the
  // row's top beside the panes' own full-height borders. It is as tall as
  // its row, and one line runs the whole height: the pane's border where
  // the pane draws one (no second line beside it), else its own hairline.
  for (final paneBorder in [true, false]) {
    testWidgets('between panes a splitter is one full-height line (${paneBorder ? 'the pane\'s border' : 'its own hairline'})', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);
      final session = UiSession();
      addTearDown(session.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key: key, child: Scaffold(backgroundColor: Colors.white, body: CodelesslyView(session: session)))));
      await session.applyNotation(Stream.value("""
state w=300
Row#win w=fill h=fill fill=#FFFFFFFF
  Column#list w={w} h=fill${paneBorder ? ' border-right=#FF000000' : ''}
    Text "List"
  Splitter#split @w min=200 max=500 w=9
  Column#reader grow h=fill
    Text "Reader"
"""));
      await tester.pump();
      expect(session.notationIssues, isEmpty);
      final s = _splitter(tester);
      final row = tester.binding.renderViews.first.size.height;
      expect(s.size.height, greaterThan(row - 2), reason: 'as tall as its row');
      final image = await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage();
        final bytes = (await img.toByteData())!;
        final w = img.width, h = img.height;
        img.dispose();
        return (bytes, w, h);
      });
      final (bytes, w, h) = image!;
      bool dark(int x, int y) {
        final at = 4 * (y * w + x);
        return bytes.getUint8(at) < 235 || bytes.getUint8(at + 1) < 235 || bytes.getUint8(at + 2) < 235;
      }

      final left = s.localToGlobal(Offset.zero).dx.round();
      // The columns that carry a line, at mid height, within 12 px of it.
      final mid = h ~/ 2;
      final lines = [for (var x = left - 12; x <= left + 9 + 12; x++) if (dark(x, mid)) x];
      expect(lines, hasLength(1), reason: 'one line, not two: $lines');
      for (var y = 0; y < h; y += 10) {
        expect(dark(lines.single, y), isTrue, reason: 'the line runs from top to bottom (y $y)');
      }
    });
  }

  testWidgets('pane=after: its value is the width of the pane after it (an inspector at the end)', (tester) async {
    await _show(tester, source: """
state inspector=300
Page
  Section
    Row
      Column grow
        Text "List"
      Splitter#splitGrip @inspector min=200 max=500 step=20 pane=after label="Resize the inspector"
      Column w={inspector}
        Text "Inspector"
""");
    final keys = Keyboard(tester);
    await keys.tab();
    expect(keys.focusedId, 'splitGrip');
    await keys.right();
    expect(_splitter(tester).value, 280, reason: 'the divider moves toward the end: the pane after it narrows');
    await keys.left();
    await keys.left();
    expect(_splitter(tester).value, 320);
    final grip = _splitter(tester);
    final drag = await tester.startGesture(grip.localToGlobal(grip.size.center(Offset.zero)));
    await drag.moveBy(const Offset(-60, 0));
    await drag.up();
    await tester.pump();
    expect(_splitter(tester).value, greaterThan(350));
  });
}

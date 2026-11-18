// Desktop defaults the native web builds have (experiments dsl-api-9: kanban, admin console, mail client):
// a box's border drawn over what it holds (a table's sides, a field between two buttons), a number field's own
// minus and plus buttons (NumberInput), a splitter that is a hairline at rest on a desktop.
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart' hide captureImage;
import 'package:codelessly_sdk/src/render/controls/field_frame.dart';
import 'package:codelessly_sdk/src/render/controls/splitter.dart';
import 'package:codelessly_sdk/src/render/controls/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _shot = Key('shot');

Future<void> _show(WidgetTester tester, String source, {Size size = const Size(1280, 800)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: RepaintBoundary(key: _shot, child: CodelesslyView(session: session))),
  ));
  final result = await session.applyNotation(Stream.value(source.trimLeft()));
  await tester.pump();
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
}

T _find<T extends RenderObject>(WidgetTester tester) {
  T? found;
  void visit(RenderObject o) {
    if (found == null && o is T) found = o;
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return found!;
}

Future<Color> _pixel(WidgetTester tester, Offset at) async {
  final image = await tester.runAsync(() => captureImage(tester.element(find.byKey(_shot))));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
  final i = (at.dy.floor() * image!.width + at.dx.floor()) * 4;
  final b = bytes!;
  return Color.fromARGB(b.getUint8(i + 3), b.getUint8(i), b.getUint8(i + 1), b.getUint8(i + 2));
}

void main() {
  testWidgets('a box\'s border is drawn over the fills of what it holds: its sides stay whole', (tester) async {
    await _show(tester, '''
Column pad=0
  Column#frame w=200 h=80 fill=#FFFFFFFF border=#FFFF0000 radius=8
    Row w=fill h=40 fill=#FF0000FF
    Row w=fill h=40 fill=#FF00FF00
''');
    final frame = tester.getRect(find.byKey(_shot));
    // The frame's left edge, halfway down its first row: the border's red, not the row's blue.
    final topLeft = frame.topLeft;
    final left = await _pixel(tester, topLeft + const Offset(0.5, 20));
    expect(left.r, greaterThan(0.8), reason: 'the side of the border shows: $left');
    expect(left.b, lessThan(0.2));
    // Inside, the row's own fill.
    final inside = await _pixel(tester, topLeft + const Offset(20, 20));
    expect(inside.b, greaterThan(0.8));
  });

  testWidgets('NumberInput: its minus and plus buttons step the value within its bounds, a button at its bound is disabled',
      (tester) async {
    await _show(tester, '''
state seats=48
Column pad=16
  NumberInput#seat @seats min=47 max=49
''');
    final field = _find<RenderTextField>(tester);
    expect(field.decoration.prefix?.button, isTrue);
    expect(field.decoration.suffix?.button, isTrue);
    expect(field.size.width, 112);
    final origin = field.localToGlobal(Offset.zero);
    Future<void> press({required bool plus}) async {
      await tester.tapAt(origin + field.buttonSlot(prefix: !plus).center);
      await tester.pump();
    }

    await press(plus: true);
    expect(field.editor.text, '49');
    expect(field.affixDisabled(prefix: false), isTrue);
    await press(plus: true);
    expect(field.editor.text, '49', reason: 'no press past its bound');
    await press(plus: false);
    await press(plus: false);
    expect(field.editor.text, '47');
    expect(field.affixDisabled(prefix: true), isTrue);
    expect(field.affixDisabled(prefix: false), isFalse);
    // The keyboard steps it too.
    field.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(field.editor.text, '48');
    expect(field.partAt(field.buttonSlot(prefix: true).center), FieldFramePart.prefixIcon);
  });

  testWidgets('a splitter is a hairline at rest on a desktop and shows its grip on a phone', (tester) async {
    const page = '''
state w=300
Row h=200
  Column w={w}
    Text "A"
  Splitter#grip @w min=100 max=600
  Column grow
    Text "B"
''';
    await _show(tester, page);
    expect(_find<RenderSplitter>(tester).gripShown, isFalse);
    await _show(tester, page, size: const Size(390, 800));
    expect(_find<RenderSplitter>(tester).gripShown, isTrue);
  });
}

// Lines of an app that are read as written (codelessly_api
// notation_read_as_written_test.dart), run: a row at its end while a
// condition holds, what a page does once when it opens, what a sheet runs
// once it has closed, a press as it starts and as it ends, a box drawn
// scaled, a scroll to the copy of an each named by its item, and a drawing
// with a condition and a list in it. Each does what it says, with nothing
// shown wrong.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [notation] shown 600 × 600 at the window's corner; [app]: in an app (what
/// opens over the page needs its navigator).
Future<UiSession> _show(WidgetTester tester, String notation, {bool app = false}) async {
  final session = UiSession();
  addTearDown(session.dispose);
  final view = Align(alignment: Alignment.topLeft, child: SizedBox(width: 600, height: 600, child: CodelesslyView(session: session)));
  await tester.pumpWidget(app
      ? MaterialApp(home: Scaffold(body: view))
      : Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(textDirection: TextDirection.ltr, child: view),
        ));
  final result = await session.applyNotation(Stream.value(notation));
  await tester.pumpAndSettle();
  expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
  expect(result.errors, isEmpty, reason: '${result.errors}');
  expect([for (final d in session.shownDiagnostics()) if (d.error) '${d.code}: ${d.message}'], isEmpty);
  return session;
}

List<RenderParagraph> _paragraphs(WidgetTester tester) {
  final out = <RenderParagraph>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o);
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return out;
}

List<String> _texts(WidgetTester tester) => [for (final p in _paragraphs(tester)) p.text.toPlainText()];

RenderParagraph _text(WidgetTester tester, String text) => _paragraphs(tester).lastWhere((p) => p.text.toPlainText() == text);

/// The middle of the node [id], wherever it is drawn.
Offset _center(WidgetTester tester, String id) {
  Offset? at;
  void visit(RenderObject o) {
    if (at == null && o is NodeBox && o.id == id && o.hasSize) at = o.localToGlobal(o.size.center(Offset.zero));
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return at!;
}

Rect _rect(RenderBox box) => MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

void main() {
  testWidgets('Row end={m.mine}: the row of an item that is mine is at its end, the others at their start', (tester) async {
    await _show(tester, '''
state msgs=[{"mine":true,"t":"mine"},{"mine":false,"t":"theirs"}]
Column w=400
  each m in msgs
    Row w=fill end={m.mine}
      Text "{m.t}"
''');
    final mine = _rect(_text(tester, 'mine')), theirs = _rect(_text(tester, 'theirs'));
    expect(theirs.left, lessThan(20));
    expect(mine.right, greaterThan(380));
  });

  testWidgets('on load={…} has run when the page is first shown', (tester) async {
    await _show(tester, 'state boot=false\nstate cur=0\non load={boot=true; cur=5}\nColumn\n  Text "day {cur} {boot}"\n');
    expect(_texts(tester), contains('day 5 true'));
  });

  testWidgets('a Sheet\'s onClose runs once the sheet has closed, after the open that showed it', (tester) async {
    await _show(tester, '''
state read=[]
state cur={"id":7}
Column pad=16 gap=8
  Button#open "Open" onTap={open story}
  Text "read {length(read)}"
Sheet#story "Story" onClose={read=append(read,cur.id)}
  Button#done "Done" onTap={close}
''', app: true);
    await tester.tapAt(_center(tester, 'open'));
    await tester.pumpAndSettle();
    expect(_texts(tester), contains('read 0'), reason: 'nothing runs while the sheet is open');
    await tester.tapAt(_center(tester, 'done'));
    await tester.pumpAndSettle();
    expect(_texts(tester), contains('read 1'));
  });

  testWidgets('onPointerDown runs as the press starts, onPointerUp as it ends', (tester) async {
    await _show(tester, '''
state paused=false
Column
  Stack w=300 h=200 fill=#FFEEEEEE onPointerDown={paused=true} onPointerUp={paused=false}
    Text "story"
  Text "paused {paused}"
''');
    final press = await tester.startGesture(const Offset(150, 100));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_texts(tester), contains('paused true'));
    await press.up();
    await tester.pumpAndSettle();
    expect(_texts(tester), contains('paused false'));
  });

  testWidgets('Box scale={zoom}: what is in the box is drawn at that scale, and laid out as written', (tester) async {
    await _show(tester, '''
state zoom=1
Column pad=40
  Box w=200 h=100 fill=#FFEEEEEE scale={zoom} onTap={zoom=2}
    Text "p"
  Text "after"
''');
    final before = _rect(_text(tester, 'p'));
    final after = _rect(_text(tester, 'after'));
    await tester.tapAt(const Offset(140, 90));
    await tester.pumpAndSettle();
    expect(_rect(_text(tester, 'p')).width, closeTo(before.width * 2, 0.5));
    expect(_rect(_text(tester, 'after')), after, reason: 'a motion lays nothing out again');
  });

  testWidgets('id={m.name} under an each: scroll {name} reaches the copy whose item has that name', (tester) async {
    final names = [for (var i = 0; i < 30; i++) '{"id":${(i + 7) % 30},"name":"m$i"}'].join(',');
    await _show(tester, '''
state methods=[$names]
state target="m20"
Column h=600 scroll
  Button#go "Go" onTap={scroll {target}}
  each m in methods
    Box h=120 id={m.name}
      Text "{m.name}"
''');
    expect(_rect(_text(tester, 'm20')).top, greaterThan(600));
    await tester.tapAt(_center(tester, 'go'));
    await tester.pumpAndSettle();
    final top = _rect(_text(tester, 'm20')).top;
    expect(top, inInclusiveRange(0, 200), reason: 'the copy at position 20, not the item whose id is 20 (m13)');
  });

  testWidgets('a drawing with if, else and each under its customPaint is drawn with nothing shown wrong', (tester) async {
    final session = await _show(tester, '''
state kind="pie"
state bars=[{"v":3},{"v":7}]
Column pad=16
  Box w=240 h=140
    customPaint viewBox=[240,140] fit=contain
      if kind=="pie"
        circle c=[120,80] radius=50 fill=#FF3B3B3B
      else
        rect rect=[0,0,20,20] fill=#FF000000
      each b in bars
        rect rect=[{index*10},0,6,{b.v}] fill=#FF2563EB
  Box shadow=small pad=8
    Text "Count {0}"
    Text "Use \\{name\\} for the name"
''');
    expect(session.shownDiagnostics().where((d) => d.code == 'value_not_computed'), isEmpty);
    expect(_texts(tester), containsAll(['Count 0', 'Use {name} for the name']));
  });
}

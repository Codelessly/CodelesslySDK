// A view keeps a box for each node while its session's document is edited.
// An edit that puts a node under one that was inside it (a row and the
// column in it change places, as a text being written again does to the ids
// it gives its lines) must leave the render tree a tree: each box is placed
// by its new holder only once the box on the way has left its old one.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<UiSession> _show(WidgetTester tester, String notation) async {
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 320, height: 600, child: CodelesslyView(session: session))),
  ));
  final result = await session.applyNotation(Stream.value(notation));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pump();
  return session;
}

/// Turns [session]'s document into what [notation] expands to, by edit
/// operations in one step.
Future<void> _become(WidgetTester tester, UiSession session, String notation) async {
  final other = UiSession();
  addTearDown(other.dispose);
  final read = await other.applyNotation(Stream.value(notation));
  expect(read.errors, isEmpty, reason: '${read.errors}');
  final ops = api.inverseOps(other.document, session.document);
  final result = session.apply(ops, author: 'test', atomic: true);
  expect(result.ok, isTrue, reason: '${result.errors}');
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
  expect(tester.takeException(), isNull);
}

/// The ids of the node boxes above the box of [id], innermost first.
List<String> _above(WidgetTester tester, String id) {
  NodeBox? found;
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == id) found = o;
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(CodelesslyView)));
  expect(found, isNotNull, reason: 'the box of $id is in the view');
  return [
    for (RenderObject? p = found!.parent; p != null; p = p.parent)
      if (p is NodeBox && p.id != 'screen') p.id,
  ];
}

String _texts(WidgetTester tester) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(CodelesslyView)));
  return out.join('|');
}

void main() {
  testWidgets('a node and the node inside it change places', (tester) async {
    final session = await _show(tester, 'Column#a\n  Row#b\n    Column#c\n      Text#t "hi"\n');
    expect(_above(tester, 't'), ['c', 'b', 'a']);
    await _become(tester, session, 'Column#a\n  Column#c\n    Row#b\n      Text#t "hi"\n');
    expect(_above(tester, 't'), ['b', 'c', 'a']);
    expect(_texts(tester), 'hi');
    // And back.
    await _become(tester, session, 'Column#a\n  Row#b\n    Column#c\n      Text#t "hi"\n');
    expect(_above(tester, 't'), ['c', 'b', 'a']);
  });

  testWidgets('a chain of four turned over, with other content on the way', (tester) async {
    final session = await _show(
      tester,
      'Column#a\n  Text#one "one"\n  Row#b\n    Column#c\n      Text#two "two"\n      Row#d\n        Text#t "hi"\n',
    );
    await _become(
      tester,
      session,
      'Column#d\n  Row#c\n    Text#two "two"\n    Column#b\n      Row#a\n        Text#t "hi"\n      Text#one "one"\n',
    );
    expect(_above(tester, 't'), ['a', 'b', 'c', 'd']);
    expect(_texts(tester).split('|').toSet(), {'one', 'two', 'hi'});
  });

  testWidgets('the outer node goes under a node deep inside it, which moves out', (tester) async {
    final session = await _show(tester, 'Column#root\n  Column#a\n    Row#b\n      Column#c\n        Text#t "hi"\n');
    await _become(tester, session, 'Column#root\n  Column#c\n    Column#a\n      Text#t "hi"\n  Row#b\n    Text#u "new"\n');
    expect(_above(tester, 't'), ['a', 'c', 'root']);
    expect(_above(tester, 'u'), ['b', 'root']);
  });

  // The places differ in kind (a stack's child, a row's, a column's): a box
  // given another kind of place is applied at once, inside its new holder's
  // own pass, while it still sits where it was.
  testWidgets('they change places between a stack, a row and a column', (tester) async {
    final session = await _show(tester, 'Stack#a w=300 h=200\n  Row#b\n    Column#c\n      Text#t "hi"\n');
    expect(_above(tester, 't'), ['c', 'b', 'a']);
    await _become(tester, session, 'Stack#a w=300 h=200\n  Column#c\n    Row#b\n      Text#t "hi"\n');
    expect(_above(tester, 't'), ['b', 'c', 'a']);
    expect(_texts(tester), 'hi');
    await _become(tester, session, 'Row#c\n  Stack#b w=300 h=200\n    Column#a\n      Text#t "hi"\n');
    expect(_above(tester, 't'), ['a', 'b', 'c']);
    expect(_texts(tester), 'hi');
  });

  // A grid's cell and a list's item are placed when the grid is laid out,
  // not when the document changes: a node that moved into one is still where
  // it was when it is told of its new children.
  testWidgets('the inner node moves into a grid cell and takes the outer one', (tester) async {
    final session = await _show(tester, 'Column#a\n  Row#b\n    Column#mid\n      Column#c\n        Text#t "hi"\n');
    expect(_above(tester, 't'), ['c', 'mid', 'b', 'a']);
    await _become(tester, session, 'Column#a\n  Grid#g cols=2 gap=8\n    Column#c\n      Row#b\n        Column#mid\n          Text#t "hi"\n    Text#other "other"\n');
    expect(_above(tester, 't').take(3), ['mid', 'b', 'c']);
    expect(_texts(tester).split('|').toSet(), {'hi', 'other'});
  });

  testWidgets('the inner node moves into a list item and takes the list that held it', (tester) async {
    final session = await _show(
      tester,
      'state rows=[{"n":"one"},{"n":"two"}]\nColumn#a\n  Row#b\n    Column#c\n      Text#t "hi"\n',
    );
    await _become(
      tester,
      session,
      'state rows=[{"n":"one"},{"n":"two"}]\nColumn#a\n  each r in rows\n    Column#c\n      Row#b\n        Text#t "{r.n}"\n',
    );
    expect(_texts(tester).split('|'), containsAll(['one', 'two']));
    await _become(
      tester,
      session,
      'state rows=[{"n":"one"},{"n":"two"}]\nColumn#c\n  Text#t "hi"\n  Row#b\n    Column#l\n      each r in rows\n        Column#a\n          Text#u "{r.n}"\n',
    );
    expect(_texts(tester).split('|'), containsAll(['hi', 'one', 'two']));
  });

  testWidgets('a text default above them changes too', (tester) async {
    final session = await _show(tester, 'Column#a\n  Row#b\n    Column#c\n      Stack#d w=100 h=100\n        Text#t "hi"\n');
    await _become(tester, session, 'Row#d\n  Stack#c w=200 h=200\n    Column#b\n      Row#a\n        Text#t "hi"\n');
    expect(_above(tester, 't'), ['a', 'b', 'c', 'd']);
    expect(_texts(tester), 'hi');
  });
}

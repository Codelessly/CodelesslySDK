// A host app moves a view with a GlobalKey (a page's view goes from the
// preview into a tile and back). Where it lands may be out of the semantics
// tree (a tile under ExcludeSemantics), and the place it left may be gone.
// Flutter keeps a moved subtree's semantics as they were built in the old
// place, each node naming the node above it there, and does not read them
// again while the new place is excluded: the next layout inside the view then
// asked the node that is gone for its children's geometry, and asserted that
// a child's render object is under its parent's. A view that leaves the
// pipeline forgets its semantics, and is read whole where it comes back.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a view moved out of a scrolling pane into a place with no semantics, then edited', (tester) async {
    final session = UiSession();
    addTearDown(session.dispose);
    final key = GlobalKey();
    Widget host({required bool tile}) {
      final view = SizedBox(key: key, width: 320, height: 400, child: CodelesslyView(session: session));
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: tile
              ? ExcludeSemantics(child: IgnorePointer(child: view))
              : SizedBox(width: 320, height: 300, child: SingleChildScrollView(child: view)),
        ),
      );
    }

    await tester.pumpWidget(host(tile: false));
    final result = await session.applyNotation(Stream.value(
        'Column#page h=fill scroll gap=8\n  Row#row gap=8\n    Text#a "one"\n    Text#b "two"\n  Column#list h=200 scroll\n    Text#c "three"\n'));
    expect(result.errors, isEmpty, reason: '${result.errors}');
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Into the tile; the scrolling pane is gone.
    await tester.pumpWidget(host(tile: true));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // An edit that lays the view's content out again.
    for (final text in ['a much longer first text', 'x']) {
      final other = UiSession();
      addTearDown(other.dispose);
      await other.applyNotation(Stream.value(
          'Column#page h=fill scroll gap=8\n  Row#row gap=8\n    Text#a "$text"\n    Text#b "two"\n  Column#list h=200 scroll\n    Text#c "three"\n    Text#d "$text"\n'));
      expect(session.apply(inverseOpsOf(other, session), author: 'test', atomic: true).ok, isTrue);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    // And back into a scrolling pane: its semantics are read again.
    await tester.pumpWidget(host(tile: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final labels = <String>[];
    bool visit(SemanticsNode n) {
      labels.add(n.label);
      n.visitChildren(visit);
      return true;
    }

    visit(tester.renderObject(find.byType(CodelesslyView)).owner!.semanticsOwner!.rootSemanticsNode!);
    expect(labels.join('|'), allOf(contains('x'), contains('three')));
  });
}

List<EditOp> inverseOpsOf(UiSession next, UiSession now) => inverseOps(next.document, now.document);

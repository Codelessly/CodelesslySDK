// A view removed from the widget tree while a dialog of it is open: the
// dialog is a route beside the page, unmounted after it, and it has the
// focus. The view's render tree is released as the page is unmounted, with
// the dialog's elements still mounted and no longer active. An island in
// the dialog (its pages) asked whether the focus was inside it by walking
// up from the focused element, which a deactivated element refuses:
// "Looking up a deactivated widget's ancestor is unsafe", thrown while the
// widget tree was finalized.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/islands.dart' show IslandHost;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _board = '''
state cards=["Design","Build","Ship"]
Column pad=16 gap=8
  Button#go "Open" onTap={open card}
Dialog#card "A card"
  Pages h=120
    each c in cards
      Text "{c}"
''';

List<T> _all<T extends RenderObject>(WidgetTester tester) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o);
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return out;
}

Future<void> _openDialog(WidgetTester tester, UiSession session) async {
  final result = await session.applyNotation(Stream.value(_board));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pumpAndSettle();
  final go = _all<NodeBox>(tester).firstWhere((b) => b.id == 'go');
  await tester.tapAt(go.localToGlobal(go.size.center(Offset.zero)));
  await tester.pumpAndSettle();
  expect(_all<IslandHost>(tester), isNotEmpty, reason: 'the dialog is open, with its pages (an island)');
}

void main() {
  testWidgets('the view leaves the tree with its dialog open: nothing is thrown', (tester) async {
    final session = UiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
    await _openDialog(tester, session);

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

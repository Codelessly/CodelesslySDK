// Cards' ReorderableList with addable=false is a fixed set of items: no +
// in its header and no x on its rows; with addable (the default) both show
// and the x removes its row.
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';

String _page(String more) => '''
state steps=["Mix","Rest","Bake"]
Page
  Section
    ReorderableList#list "Steps" @steps $more
    Text#count "{length(steps)} steps"
''';

void main() {
  testWidgets('addable=false: no + and no x', (tester) async {
    await showCards(tester, _page('addable=false'));
    expect(shown(tester, 'list/grip'), isTrue, reason: 'the rows are there, with their grips');
    expect(boxesOf(tester, 'list/add').where((b) => !b.size.isEmpty), isEmpty);
    expect(boxesOf(tester, 'list/remove').where((b) => !b.size.isEmpty), isEmpty);
    expect(boxesOf(tester, 'list/remove#1').where((b) => !b.size.isEmpty), isEmpty);
    expect(textOf(tester, 'count'), '3 steps');
    expect(tester.takeException(), isNull);
  });

  testWidgets('addable (the default): the x removes its row', (tester) async {
    await showCards(tester, _page(''));
    expect(boxesOf(tester, 'list/add').where((b) => !b.size.isEmpty), isNotEmpty);
    final remove = boxesOf(tester, 'list/remove').where((b) => !b.size.isEmpty);
    expect(remove, isNotEmpty);
    await tester.tapAt(remove.first.localToGlobal(remove.first.size.center(Offset.zero)));
    await settle(tester);
    expect(textOf(tester, 'count'), '2 steps');
  });
}

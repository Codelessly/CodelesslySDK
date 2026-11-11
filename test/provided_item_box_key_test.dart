// Rows a list keys by their item (no id) are told apart by that item's
// identity, as their scopes are: a row of an equal item from a newer answer
// (a script answering again for new inputs) gets its own box. Their box keys
// printed the item's contents, so the new row found the old row's box,
// still reading the old row's scope, which the list then let go: Chordbook's
// next-chord cards fell back to their template texts.
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rows keyed by equal but distinct items have distinct box keys', () {
    final older = ProvidedItem('row', null, 'list', {'label': 'Down a fifth'});
    final newer = ProvidedItem('row', null, 'list', {'label': 'Down a fifth'});
    expect(older == newer, isFalse, reason: 'map keys compare by identity');
    expect(NodeTree.keyOf('item', older), isNot(NodeTree.keyOf('item', newer)));
    // The same item, the same box.
    final item = {'label': 'Down a fifth'};
    expect(NodeTree.keyOf('item', ProvidedItem('row', null, 'list', item)),
        NodeTree.keyOf('item', ProvidedItem('row', null, 'list', item)));
    // Ids, texts and numbers still print as themselves.
    expect(ProvidedItem('row', null, 'list', 'p-1').toString(), contains('p-1'));
    expect(ProvidedItem('row', null, 'list', 3).toString(), contains('3'));
  });

  testWidgets('the newer row gets its own box, in its own scope', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['item'],
      'nodes': {
        'item': {'type': 'text', 'props': {'text': 'PLACEHOLDER'}, 'layout': {'width': 100, 'height': 20}, 'bind': {'props.text': r'${item.label}'}},
      },
    });
    final values = NodeValues(DocumentSource(doc));
    final binder = NodeBinder(scope: VariableScope(const []));
    final tree = NodeTree(values, binder: binder);
    addTearDown(tree.dispose);
    final older = ProvidedItem('row', null, 'list', {'label': 'Down a fifth'});
    final newer = ProvidedItem('row', null, 'list', {'label': 'Down a fifth'});
    binder.provideItem(values, older, index: 0, item: {'label': 'Down a fifth'});
    final first = tree.obtain('item', const Slot.root(), instance: older);
    binder.provideItem(values, newer, index: 0, item: {'label': 'Down a fifth'});
    final second = tree.obtain('item', const Slot.root(), instance: newer);
    expect(identical(first, second), isFalse);
    expect(second.instance, newer);
  });
}

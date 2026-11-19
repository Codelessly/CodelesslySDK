// `parent` in a list's item is the item around it; in a list three deep
// `parent.parent.item` is the outermost (it read as nothing).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parent.parent.item reaches the item two lists out', () {
    final slot = ItemScope(index: 1, item: '10:00', parent: VariableScope(const []));
    final lane = ItemScope(index: 0, item: 'Design', parent: slot);
    final session = ItemScope(index: 3, item: {'title': 'A'}, parent: lane);
    expect(readPath(session, 'item.title'), 'A');
    expect(readPath(session, 'parent.item'), 'Design');
    expect(readPath(session, 'parent.index'), 0);
    expect(readPath(session, 'parent.parent.item'), '10:00');
    expect(readPath(session, 'parent.parent.index'), 1);
    // In a list two deep there is no item beyond the parent.
    expect(readPath(lane, 'parent.parent.item'), isNull);
  });
}

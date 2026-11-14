// A screen that goes away with a popup still open (test 4: three builds
// saw "A disposed RenderObject was mutated" after opening a date picker in
// the render tool, which tears the screen down while the calendar shows).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/dropdown.dart' show RenderDropdown;
import 'package:codelessly_sdk/src/render/controls/pickers.dart' show RenderPickerField;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

T _find<T extends RenderObject>(WidgetTester tester) {
  T? found;
  void visit(RenderObject o) {
    if (o is T) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return found!;
}

void main() {
  testWidgets('an open date picker and an open dropdown menu go away with their screen, raising nothing', (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'date': hugging('datePicker'),
      'pick': hugging('dropdown', {'items': ['One', 'Two']}),
    }));
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    final picker = _find<RenderPickerField>(tester);
    await tester.tapAt(picker.localToGlobal(picker.size.center(Offset.zero)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
    expect(tester.takeException(), isNull);

    final (tree2, _) = runningTree(columnDoc({
      'pick': hugging('dropdown', {'items': ['One', 'Two']}),
    }));
    await tester.pumpWidget(NodeView(tree: tree2, rootId: 'col', interactive: true));
    final dropdown = _find<RenderDropdown>(tester);
    await tester.tapAt(dropdown.localToGlobal(dropdown.size.center(Offset.zero)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    tree2.dispose();
    expect(tester.takeException(), isNull);
  });
}

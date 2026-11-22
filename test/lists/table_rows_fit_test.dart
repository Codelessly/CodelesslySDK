// A running table that hugs its height is as tall as its rows (at most the
// height it is capped to), a row whose cell's text wraps to more lines than
// the row has grows to it, and the columns of a table that fills a width
// narrower than they are give way before the table scrolls sideways.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/collections_table.dart' show RenderRunningTable;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' as lists;

Map<String, Json> _page({required double width, required Object height, Json? constraints, int columns = 3}) => {
      'col': {
        'type': 'column',
        'layout': {'width': width, 'height': {'hug': 0}},
        'props': {'scrollable': true},
        'children': ['table'],
      },
      'table': {
        'type': 'tableView',
        'layout': {'width': {'fill': 0}, 'height': height, 'constraints': ?constraints},
        'bind': {'data': r'${rows}'},
        'slots': {'cell': 'cell', 'columnHeader': 'head'},
        'props': {
          'columns': [
            for (var c = 0; c < columns; c++) {'key': 'c$c', 'label': 'Col $c'},
          ],
          'rowHeight': 48,
          'headerHeight': 48,
          'fillWidth': true,
        },
      },
      'cell': {
        'type': 'text',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'props': {'text': r'${item.value}', 'style': {'fontSize': 10, 'height': 1.4}},
      },
      'head': {
        'type': 'text',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'props': {'text': r'${item.label}', 'style': {'fontSize': 10, 'height': 1.4}},
      },
    };

Variable _rows(int count, {String last = 'x'}) => lists.v('rows', [
      for (var r = 0; r < count; r++) {'c0': 'a', 'c1': 'b', 'c2': r == count - 1 ? last : 'c', 'c3': 'd'},
    ], VariableType.list);

RenderRunningTable _table(WidgetTester tester) {
  RenderRunningTable? found;
  void visit(RenderObject o) {
    if (o is RenderRunningTable) found = o;
    o.visitChildren(visit);
  }

  tester.binding.renderViews.first.visitChildren(visit);
  return found!;
}

Map<String, Rect> _texts(WidgetTester tester) {
  final out = <String, Rect>{};
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.attached) out[o.text.toPlainText()] = o.localToGlobal(Offset.zero) & o.size;
    o.visitChildren(visit);
  }

  visit(_table(tester));
  return out;
}

void main() {
  testWidgets('a table that hugs its height is as tall as its rows, at most its cap', (tester) async {
    await lists.show(tester, _page(width: 600, height: {'hug': 0}, constraints: {'maxHeight': 320}), variables: [_rows(3)]);
    await tester.pump();
    // A header and three rows of 48.
    expect(_table(tester).size, const Size(600, 192));
    await tester.pumpWidget(const SizedBox());
    await lists.show(tester, _page(width: 600, height: {'hug': 0}, constraints: {'maxHeight': 320}), variables: [_rows(30)]);
    await tester.pump();
    expect(_table(tester).size, const Size(600, 320));
    await tester.pumpWidget(const SizedBox());
    // A height of its own is kept whatever its rows.
    await lists.show(tester, _page(width: 600, height: 320), variables: [_rows(3)]);
    await tester.pump();
    expect(_table(tester).size, const Size(600, 320));
  });

  testWidgets('a row whose text wraps to more lines than it has grows to the text', (tester) async {
    const long = 'Granularity of comparison, one of char, word or line, with char as the default when none is given at all';
    await lists.show(tester, _page(width: 360, height: {'hug': 0}, constraints: {'maxHeight': 600}), variables: [_rows(3, last: long)]);
    await tester.pump();
    final table = _table(tester);
    final text = _texts(tester)[long]!;
    final box = table.localToGlobal(Offset.zero) & table.size;
    // The whole of the wrapped text is inside the table, and the table is
    // taller than four rows of 48 by what the text needs.
    expect(text.height, greaterThan(48));
    expect(text.top, greaterThanOrEqualTo(box.top + 48 * 3));
    expect(text.bottom, lessThanOrEqualTo(box.bottom));
    expect(table.size.height, greaterThan(192));
    expect(table.size.height, closeTo(48 * 3 + text.height + 16, 0.5));
  });

  testWidgets('the columns of a table that fills a width narrower than they are give way alike', (tester) async {
    // Four columns of 120 in 400: 100 each, none cut.
    await lists.show(tester, _page(width: 400, height: {'hug': 0}, columns: 4), variables: [_rows(2)]);
    await tester.pump();
    final texts = _texts(tester);
    expect([for (final c in ['Col 0', 'Col 1', 'Col 2', 'Col 3']) texts[c]!.left], [0.0, 100.0, 200.0, 300.0]);
    await tester.pumpWidget(const SizedBox());
    // Not below a width a word fits in: then it scrolls sideways, as before.
    await lists.show(tester, _page(width: 200, height: {'hug': 0}, columns: 4), variables: [_rows(2)]);
    await tester.pump();
    final narrow = _texts(tester);
    expect(narrow['Col 1']!.left - narrow['Col 0']!.left, 72);
  });
}

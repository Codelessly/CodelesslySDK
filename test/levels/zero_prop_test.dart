// Level 1 of the vocabulary (design 12 §3): every widget-catalog type is
// complete with nothing written. A node that is only its type, in a column,
// has a size, draws without an exception, and validates.
import 'package:codelessly_api/src/core/levels.dart';
import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';

import '../controls/support.dart';

/// The content a type has nothing to show without: its one required thing,
/// never a size or a style.
const _content = <String, Map<String, Object?>>{
  'badge': {'props': {'label': 'New'}},
  'segmentedButton': {'props': {'segments': [{'value': 'a', 'label': 'A'}, {'value': 'b', 'label': 'B'}]}},
  'tableView': {'props': {'columns': [{'key': 'name', 'label': 'Name'}]}, 'bind': {'data': r"${= [{'name': 'Ada'}]}"}},
  'pageView': {'children': ['page']},
};

/// Shown over the page when opened: no box of its own until then.
const _overlays = {'modal'};

void main() {
  final types = [
    for (final e in widgetLevels.entries)
      if (e.value == Level.widgets && !_overlays.contains(e.key)) e.key,
  ]..sort();

  testWidgets('every widget-catalog type, with nothing written, has a size and draws', (tester) async {
    final bare = <String>[], threw = <String>[], invalid = <String>[];
    for (final type in types) {
      final doc = {
        'schema': 3,
        'id': 'doc',
        'roots': ['col'],
        'nodes': {
          'col': {
            'type': 'column',
            'layout': {'width': 400, 'height': 600, 'padding': 16},
            'children': ['n'],
          },
          'n': {'type': type, ...?_content[type]},
          if (type == 'pageView') 'page': {'type': 'text', 'props': {'text': 'Page'}, 'layout': {'width': {'fill': 0}, 'height': 40}},
        },
      };
      final problems = Catalog.run(standardCatalog, () => validateDocument(doc)).where((d) => d.severity == Severity.error).toList();
      if (problems.isNotEmpty) invalid.add('$type: ${problems.first.code.name} ${problems.first.message}');
      final (tree, _) = runningTree(doc);
      await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
      final e = tester.takeException();
      if (e != null) threw.add('$type: ${'$e'.split('\n').first}');
      final box = tree.boxOf('n');
      if (box == null || !box.hasSize || box.size.width < 4 || box.size.height < 4) bare.add('$type: ${box?.hasSize == true ? box!.size : 'no box'}');
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    }
    printOnFailure('no size: $bare\nthrew: $threw\ninvalid: $invalid');
    expect(threw, isEmpty);
    expect(invalid, isEmpty);
    // Known gap, tracked here: a page view and a table are viewports that
    // do not measure their content yet, so with no height written they have
    // none (they go when lists come off Flutter's Scrollable, design 11 §12).
    expect([for (final b in bare) b.split(':').first], ['pageView', 'tableView']);
  });
}

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

void main() {
  testWidgets('reveal.when scrolls a newly requested node into a container viewport', (tester) async {
    final s = await support.show(
      tester,
      {
        'col': {
          'type': 'column',
          'layout': {'width': 200, 'height': 120},
          'props': {'scrollable': true},
          'children': ['spacer', 'target', 'tail'],
        },
        'spacer': {
          'type': 'box',
          'layout': {'width': 200, 'height': 300},
        },
        'target': {
          'type': 'box',
          'layout': {'width': 200, 'height': 40},
          'reveal': {'when': false, 'alignment': 0, 'duration': 100},
          'bind': {'reveal.when': r'${reveal}'},
        },
        'tail': {
          'type': 'box',
          'layout': {'width': 200, 'height': 200},
        },
      },
      variables: [support.v('reveal', false, VariableType.boolean)],
    );
    RenderDesignScroll? viewport;
    void find(RenderObject r) {
      if (r is RenderDesignScroll) viewport = r;
      r.visitChildren(find);
    }

    find(s.tree.boxOf('col')!);
    expect(viewport!.offset, 0);
    setVariableIn(s.scope, 'reveal', true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(viewport!.offset, closeTo(300, .1));
    // A false-to-true request can reveal it again after manual scrolling.
    setVariableIn(s.scope, 'reveal', false);
    viewport!.jumpBy(-300);
    await tester.pump();
    setVariableIn(s.scope, 'reveal', true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(viewport!.offset, closeTo(300, .1));
    expect(tester.takeException(), isNull);
  });
}

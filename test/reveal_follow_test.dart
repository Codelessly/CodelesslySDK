// reveal.follow keeps an end marker in view while the content above it
// grows (a transcript pinned to its newest line), until the user scrolls.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

Future<(support.Screen, RenderDesignScroll)> _show(WidgetTester tester, {required bool follow}) async {
  final s = await support.show(
    tester,
    {
      'col': {
        'type': 'column',
        'layout': {'width': 200, 'height': 120},
        'props': {'scrollable': true},
        'children': ['lines', 'end'],
      },
      'lines': {
        'type': 'box',
        'layout': {'width': 200, 'height': 300},
        'bind': {'layout.height': r'${h}'},
      },
      'end': {
        'type': 'box',
        'layout': {'width': 200, 'height': 10},
        'reveal': {'alignment': 1, 'duration': 0, 'follow': follow},
      },
    },
    variables: [support.v('h', 300, VariableType.integer)],
  );
  RenderDesignScroll? viewport;
  void find(RenderObject r) {
    if (r is RenderDesignScroll) viewport = r;
    r.visitChildren(find);
  }

  find(s.tree.boxOf('col')!);
  await tester.pump();
  await tester.pump();
  return (s, viewport!);
}

void main() {
  testWidgets('follow keeps the end in view as the content grows, until the user scrolls', (tester) async {
    final (s, viewport) = await _show(tester, follow: true);
    expect(viewport.offset, closeTo(190, .1), reason: 'revealed at the bottom: 310 - 120');

    setVariableIn(s.scope, 'h', 500);
    await tester.pump();
    await tester.pump();
    expect(viewport.offset, closeTo(390, .1), reason: 'followed the end down');

    // Shorter content clamps the offset: still following.
    setVariableIn(s.scope, 'h', 400);
    await tester.pump();
    await tester.pump();
    setVariableIn(s.scope, 'h', 450);
    await tester.pump();
    await tester.pump();
    expect(viewport.offset, closeTo(340, .1));

    // A program scrolls (a scrollTo action) as the content grows: still
    // following.
    viewport.jumpBy(-30);
    setVariableIn(s.scope, 'h', 480);
    await tester.pump();
    await tester.pump();
    expect(viewport.offset, closeTo(370, .1));

    // The user drags it down (scrolling up): it stops following.
    await tester.drag(find.byType(NodeView), const Offset(0, 100));
    await tester.pump();
    final left = viewport.offset;
    expect(left, lessThan(370));
    setVariableIn(s.scope, 'h', 700);
    await tester.pump();
    await tester.pump();
    expect(viewport.offset, closeTo(left, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without follow the reveal happens once', (tester) async {
    final (s, viewport) = await _show(tester, follow: false);
    expect(viewport.offset, closeTo(190, .1));
    setVariableIn(s.scope, 'h', 500);
    await tester.pump();
    await tester.pump();
    expect(viewport.offset, closeTo(190, .1));
  });
}

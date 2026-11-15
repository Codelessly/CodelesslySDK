// A child that reaches past its row's edge is reported by the view's own
// check; one that fits, and one under a sideways scroller, is not.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _shown(WidgetTester tester, String notation, {double width = 320}) async {
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: 600, child: CodelesslyView(session: session))),
  ));
  final result = await session.applyNotation(Stream.value(notation));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pumpAndSettle();
  tester.takeException(); // the debug-mode overflow report of the same thing
  return [for (final d in session.shownDiagnostics()) if (d.code == 'content_overflows') d.message];
}

void main() {
  testWidgets('fixed cells wider than the row are reported, with by how much', (tester) async {
    final found = await _shown(tester, 'Column\n  Row gap:8\n    Box w:140 h:40 fill:#FF111827\n    Box w:140 h:40 fill:#FF111827\n    Box w:140 h:40 fill:#FF111827\n');
    expect(found, isNotEmpty);
    expect(found.join('\n'), contains('past the right edge'));
  });

  testWidgets('a row that fits, and a row that scrolls sideways, are not', (tester) async {
    expect(await _shown(tester, 'Column\n  Row gap:8\n    Box w:80 h:40 fill:#FF111827\n    Box w:80 h:40 fill:#FF111827\n'), isEmpty);
    expect(await _shown(tester, 'Column\n  Row scroll gap:8\n    Box w:140 h:40 fill:#FF111827\n    Box w:140 h:40 fill:#FF111827\n    Box w:140 h:40 fill:#FF111827\n'), isEmpty);
  });
}

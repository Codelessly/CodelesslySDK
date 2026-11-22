// A text drawn in a color too close to the fill it is on is reported by the
// view's own check (`low_contrast`); one that reads, one on a picture or in
// a Stack (where what is under it is not known), is not.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _shown(WidgetTester tester, String notation) async {
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 480, height: 600, child: CodelesslyView(session: session))),
  ));
  final result = await session.applyNotation(Stream.value(notation));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pumpAndSettle();
  tester.takeException();
  return [for (final d in session.shownDiagnostics()) if (d.code == 'low_contrast') d.message];
}

void main() {
  testWidgets('white on a white box, and a dark ink on a dark band, are reported with both colors and the box', (tester) async {
    final white = await _shown(tester, 'Column fill=#FF0B0B0B\n  Box#card fill=#FFFFFFFF pad=12\n    Text#title "Push Day A" color=#FFFFFFFF\n');
    expect(white, hasLength(1));
    expect(white.single, allOf(contains('"title"'), contains('#FFFFFFFF on #FFFFFFFF'), contains('"card"'), contains('1.0 to 1')));
    final dark = await _shown(tester, 'Column#band fill=#FF0A0B0E pad=12\n  Text#copy "Body copy" color=#FF18181B\n');
    expect(dark.single, allOf(contains('"copy"'), contains('"band"')));
    // A pale grey on white.
    expect(await _shown(tester, 'Column fill=#FFFFFFFF\n  Text "11 min" color=#FFE6E8EC\n'), hasLength(1));
  });

  testWidgets('a text that reads, a quiet one, and one whose ground is not known are not', (tester) async {
    expect(await _shown(tester, 'Column fill=#FFFFFFFF\n  Text "Reads" color=#FF18181B\n  Text "Quiet" color=#FFA1A1AA\n'), isEmpty);
    expect(await _shown(tester, 'Column fill=#FF0B0B0B\n  Text "Light on dark" color=#FFFFFFFF\n'), isEmpty);
    // On a gradient, and in a Stack over something else.
    expect(await _shown(tester, 'Column fill=#FFFFFFFF\n  Box gradient=["#FF16222E","#FF2E4A62"] pad=12\n    Text "On a gradient" color=#FFFFFFFF\n'), isEmpty);
    expect(await _shown(tester, 'Column fill=#FFFFFFFF\n  Stack h=120\n    Box w=fill h=120 fill=#FF101418\n    Text "Over a dark box" color=#FFFFFFFF\n'), isEmpty);
    // A wash over a dark ground is not the ground.
    expect(await _shown(tester, 'Column fill=#FF0B0B0B\n  Box fill=#14FFFFFF pad=12\n    Text "On a wash" color=#FFFFFFFF\n'), isEmpty);
  });
}

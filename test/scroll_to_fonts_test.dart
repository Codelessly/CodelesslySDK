// scrollTo waits for fonts in flight (Strata v2: the wall's load jump ran
// before the project's uploaded fonts arrived; the text above re-measured
// and the jump landed 73 px off).
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;
import 'interactive_scroll_test.dart' show viewport;
import 'scroll_to_item_test.dart' show page, rows;

void main() {
  test('settled completes once the loads in flight finish, at once with none', () async {
    expect(CodelesslyFonts.loading, isFalse);
    await CodelesslyFonts.settled;
    final load = Completer<void>();
    CodelesslyFonts.track(load.future);
    expect(CodelesslyFonts.loading, isTrue);
    var done = false;
    unawaited(CodelesslyFonts.settled.then((_) => done = true));
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    load.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
    expect(CodelesslyFonts.loading, isFalse);
  });

  testWidgets('a scrollTo waits for a font load in flight, then lands', (tester) async {
    final load = Completer<void>();
    CodelesslyFonts.track(load.future);
    final screen = await wiring.show(tester, page('d'), variables: [rows]);
    final view = viewport(screen.tree);
    await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(view.pixels, 0, reason: 'still waiting for the font');
    load.complete();
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(view.pixels, 340);
  });
}

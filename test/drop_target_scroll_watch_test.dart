import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drop targets watch the scroll views around them for auto-scrolling. A
/// static list of those scroll views kept every one it had seen (and its
/// whole screen) until the next drag: on the editor's design canvas, never.
void main() {
  testWidgets('a scroll view stops being watched once it is gone', (
    tester,
  ) async {
    late ScrollableState scrollable;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(
          children: [
            Builder(
              builder: (context) {
                scrollable = Scrollable.of(context);
                DropTargetBox.watchScrollable(scrollable);
                // Watching again is a no-op.
                DropTargetBox.watchScrollable(scrollable);
                return const SizedBox(height: 40);
              },
            ),
          ],
        ),
      ),
    );
    expect(DropTargetBox.watchedCount, 1);

    await tester.pumpWidget(const SizedBox());
    expect(scrollable.mounted, isFalse);
    expect(DropTargetBox.watchedCount, 0);
    // Auto-scrolling with nothing left to watch does nothing.
    DropTargetBox.autoScroll(Offset.zero);
    DropTargetBox.stopAutoScroll();
  });
}

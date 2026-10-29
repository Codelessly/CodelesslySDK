import 'dart:ui';

import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';
import 'package:flutter_test/flutter_test.dart';

/// A popover opens below its anchor, left-aligned, and flips to stay on the
/// screen.
void main() {
  const Size screen = Size(390, 844);
  const Size menu = Size(240, 300);

  test('below and left-aligned', () {
    expect(
      popoverPosition(const Rect.fromLTWH(20, 100, 120, 40), screen, menu),
      const Offset(20, 146),
    );
  });

  test('right-aligned near the right edge', () {
    expect(
      popoverPosition(const Rect.fromLTWH(330, 10, 44, 44), screen, menu),
      const Offset(134, 60),
    );
  });

  test('above when there is no room below', () {
    expect(
      popoverPosition(const Rect.fromLTWH(20, 700, 120, 40), screen, menu),
      const Offset(20, 394),
    );
  });

  test('aligned to the end, right edges line up', () {
    expect(
      popoverPosition(
        const Rect.fromLTWH(300, 100, 30, 30),
        screen,
        menu,
        alignEnd: true,
      ),
      const Offset(90, 136),
    );
  });

  test('aligned to the end, left-aligned near the left edge', () {
    expect(
      popoverPosition(
        const Rect.fromLTWH(10, 100, 30, 30),
        screen,
        menu,
        alignEnd: true,
      ),
      const Offset(10, 136),
    );
  });

  test('centered without an anchor', () {
    expect(popoverPosition(null, screen, menu), const Offset(75, 272));
  });
}

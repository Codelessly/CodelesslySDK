import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Size screen = Size(1440, 900);
  const Size menu = Size(300, 420);
  Offset place(Rect anchor, DialogPlacement placement) => PopoverLayoutDelegate(
    anchor: anchor,
    placement: placement,
    gap: 8,
  ).getPositionForChild(screen, menu);

  test('beside opens to the right, bottoms aligned', () {
    // The sidebar's Demo controls button.
    const Rect button = Rect.fromLTWH(16, 828, 216, 56);
    expect(place(button, DialogPlacement.beside), const Offset(240, 464));
  });

  test('below opens under the anchor, left edges aligned', () {
    const Rect selector = Rect.fromLTWH(300, 200, 250, 40);
    expect(place(selector, DialogPlacement.below), const Offset(300, 248));
  });

  test('below flips above when there is no room under the anchor', () {
    const Rect low = Rect.fromLTWH(300, 800, 250, 40);
    expect(place(low, DialogPlacement.below), const Offset(300, 372));
  });

  test('beside falls back to below without room on the right', () {
    const Rect right = Rect.fromLTWH(1300, 100, 120, 40);
    // Below, clamped to the right edge with an 8 px margin.
    expect(place(right, DialogPlacement.beside), const Offset(1132, 148));
  });

  test('center centers', () {
    expect(place(Rect.zero, DialogPlacement.center), const Offset(570, 240));
  });
}

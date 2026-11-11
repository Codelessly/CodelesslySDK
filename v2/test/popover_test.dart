// A popover sits beside the node that opened it, as its placement says,
// flipping and staying on screen when it doesn't fit.
import 'package:codelessly_api_v2/codelessly_api.dart' show PopoverPlacement;
import 'package:codelessly_sdk_v2/src/runtime/actions/ui.dart' show PopoverLayout;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(1440, 900);
  const menu = Size(200, 112);
  // A 28×28 "⋯" button at the right of a table row.
  const button = Rect.fromLTWH(1300, 360, 28, 28);

  Offset place(PopoverPlacement p, {Rect? anchor = button, double gap = 6, double offset = 0}) =>
      PopoverLayout(anchor: anchor, placement: p, gap: gap, offset: offset).getPositionForChild(screen, menu);

  test('below the trigger, aligned to its start, center or end', () {
    expect(place(PopoverPlacement.belowStart), const Offset(1232, 394)); // clamped: 1300 + 200 > 1432
    expect(place(PopoverPlacement.belowEnd), const Offset(1128, 394));
    expect(place(PopoverPlacement.belowCenter), const Offset(1214, 394));
    expect(place(PopoverPlacement.belowStart, anchor: const Rect.fromLTWH(100, 100, 40, 30)), const Offset(100, 136));
  });

  test('above, right and left of the trigger', () {
    expect(place(PopoverPlacement.aboveEnd), const Offset(1128, 242));
    expect(place(PopoverPlacement.leftStart), const Offset(1094, 360));
    expect(place(PopoverPlacement.rightStart, anchor: const Rect.fromLTWH(100, 100, 40, 30)), const Offset(146, 100));
  });

  test('flips above when it would run off the bottom, and stays on screen', () {
    const low = Rect.fromLTWH(600, 850, 28, 28);
    expect(place(PopoverPlacement.belowStart, anchor: low), const Offset(600, 732));
    expect(place(PopoverPlacement.belowStart, anchor: const Rect.fromLTWH(1430, 10, 4, 4)).dx, 1232);
  });

  test('no anchor or center: the middle of the screen', () {
    expect(place(PopoverPlacement.belowStart, anchor: null), const Offset(620, 394));
    expect(place(PopoverPlacement.center), const Offset(620, 394));
  });
}

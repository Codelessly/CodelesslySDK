import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'freeform_layout_test.dart' show frame, pump, rect, screens;

const Size design = Size(390, 844);

/// One child of every placement rule, built from [box], [pins] and
/// [alignment] so a test can rebuild it with the properties of a move.
typedef ChildSpec = ({
  String id,
  PositioningMode mode,
  EdgePinsModel pins,
  AlignmentModel alignment,
  NodeBox box,
});

final List<ChildSpec> specs = [
  // Dropped: align mode, its design x/y as left/top pins (relative).
  (
    id: 'dropped',
    mode: PositioningMode.align,
    pins: const EdgePinsModel(left: 50, top: 100, right: null, bottom: null),
    alignment: AlignmentModel.none,
    box: NodeBox(50, 100, 120, 60),
  ),
  (
    id: 'pinnedStart',
    mode: PositioningMode.pin,
    pins: const EdgePinsModel(left: 30, top: 200, right: null, bottom: null),
    alignment: AlignmentModel.none,
    box: NodeBox(30, 200, 100, 40),
  ),
  (
    id: 'pinnedEnd',
    mode: PositioningMode.pin,
    pins: const EdgePinsModel(left: null, top: null, right: 20, bottom: 30),
    alignment: AlignmentModel.none,
    box: NodeBox(design.width - 20 - 90, design.height - 30 - 50, 90, 50),
  ),
  (
    id: 'stretched',
    mode: PositioningMode.pin,
    pins: const EdgePinsModel(left: 40, top: 320, right: 40, bottom: null),
    alignment: AlignmentModel.none,
    box: NodeBox(40, 320, design.width - 80, 50),
  ),
  (
    id: 'aligned',
    mode: PositioningMode.align,
    pins: EdgePinsModel.standard,
    alignment: AlignmentModel.center,
    box: NodeBox((design.width - 80) / 2, (design.height - 80) / 2, 80, 80),
  ),
];

RectangleNode build(ChildSpec spec) => rect(
  spec.id,
  spec.box,
  pins: spec.pins,
  mode: spec.mode,
  alignment: spec.alignment,
);

void main() {
  for (final screen in screens) {
    for (final spec in specs) {
      testWidgets(
        '${spec.id} lands where it was moved at ${screen.width.toInt()}',
        (tester) async {
          final RectangleNode before = build(spec);
          final root = frame(
            'frame',
            NodeBox(0, 0, design.width, design.height),
            [before],
          );
          final Map<String, Rect> rects = await pump(tester, root, [
            before,
          ], screen: screen);
          final Rect parent = rects['frame']!;
          final Rect child = rects[spec.id]!;
          final Offset target =
              child.topLeft - parent.topLeft + const Offset(31, -17);

          final FreeformMove move = FreeformMove.resolve(
            node: before,
            parent: root,
            outerStart: target,
            innerSize: parent.size,
            outerSize: child.size,
          );
          final RectangleNode after = build((
            id: spec.id,
            mode: spec.mode,
            pins: move.edgePins,
            alignment: move.alignment,
            box: NodeBox(
              move.outerOrigin.dx,
              move.outerOrigin.dy,
              spec.box.width,
              spec.box.height,
            ),
          ));
          final Map<String, Rect> moved = await pump(
            tester,
            frame('frame', NodeBox(0, 0, design.width, design.height), [after]),
            [after],
            screen: screen,
          );
          final Rect result = moved[spec.id]!;
          expect(result.left - parent.left, moreOrLessEquals(target.dx));
          expect(result.top - parent.top, moreOrLessEquals(target.dy));
          expect(result.width, moreOrLessEquals(child.width));
          expect(result.height, moreOrLessEquals(child.height));
        },
      );
    }
  }
}

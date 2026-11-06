import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A thermometer pin on a ridge drawn in a 1000 x 300 box: from the bottom
// left to the top right.
DragTrackModel ridge() => DragTrackModel(
  shape: DragTrackShape.path,
  variable: 'pin',
  path: 'M0 300 L1000 0',
  viewBoxWidth: 1000,
  viewBoxHeight: 300,
);

void main() {
  test('a viewBox track follows its frame wherever the node rests', () {
    final g = DragTrackGeometry(ridge());
    // A 500 x 150 frame (the box at half size), the pin resting at (10, 135).
    g.setFrame(const Size(500, 150), const Offset(10, 135));
    expect(g.offsetAt(0), const Offset(-10, 15));
    expect(g.offsetAt(1), const Offset(490, -135));
    expect(g.offsetAt(0.5).dx, closeTo(240, 1));
    // The same track in a frame stretched to 800 x 300.
    g.setFrame(const Size(800, 300), const Offset(10, 135));
    expect(g.offsetAt(1), const Offset(790, -135));
    expect(g.nearest(g.offsetAt(0.25)), closeTo(0.25, 0.01));
  });

  test('without a viewBox the path is relative pixels, as before', () {
    final g = DragTrackGeometry(
      DragTrackModel(shape: DragTrackShape.path, variable: 'v', path: 'M0 0 L100 0'),
    );
    expect(g.setFrame(const Size(500, 150), const Offset(10, 135)), isFalse);
    expect(g.offsetAt(1), const Offset(100, 0));
  });

  test('viewBox round-trips through JSON', () {
    final DragTrackModel t = DragTrackModel.fromJson(ridge().toJson());
    expect(t.viewBoxWidth, 1000);
    expect(t.usesViewBox, isTrue);
    expect(
      DragTrackModel(variable: 'v').toJson().containsKey('viewBoxWidth'),
      isFalse,
    );
  });

  test('a dial jumps to the angle tapped; the gap snaps to the nearer end', () {
    final g = DragTrackGeometry(
      DragTrackModel(
        shape: DragTrackShape.arc,
        variable: 'goal',
        startAngle: -135,
        endAngle: 135,
        jumpOnTap: true,
      ),
    );
    expect(g.progressAtAngle(-135), 0);
    expect(g.progressAtAngle(0), closeTo(0.5, 1e-9));
    expect(g.progressAtAngle(90), closeTo(225 / 270, 1e-9));
    expect(g.progressAtAngle(170), 1); // just past the end
    expect(g.progressAtAngle(-170), 0); // just before the start
    // The angle straight up from a tap above the knob's centre.
    expect(g.angleOf(const Offset(0, -50)), closeTo(0, 1e-9));
  });
}

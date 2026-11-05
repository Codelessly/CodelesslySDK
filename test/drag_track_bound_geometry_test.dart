import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a track takes its geometry and range from bindings', () {
    const DragTrackModel track = DragTrackModel(
      shape: DragTrackShape.line,
      variable: 'volume',
      min: 0,
      max: 1,
      x2: 100,
    );
    final RectangleNode thumb = RectangleNode(
      id: 'thumb',
      name: 'thumb',
      basicBoxLocal: NodeBox(0, 0, 28, 28),
    )
      ..variables['dragTrack.x2'] = r'${= 300 - 28}'
      ..variables['dragTrack.max'] = '0.5';
    final DragTrackModel resolved = WidgetNodeTransformerManager.resolveTrack(
      thumb,
      track,
      ScopedValues.empty(),
    );
    expect(resolved.x2, 272);
    expect(resolved.max, 0.5);
    expect(resolved.variable, 'volume');
    final RectangleNode plain = RectangleNode(
      id: 'p',
      name: 'p',
      basicBoxLocal: NodeBox(0, 0, 1, 1),
    );
    expect(
      identical(WidgetNodeTransformerManager.resolveTrack(plain, track, ScopedValues.empty()), track),
      isTrue,
    );
  });
}

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Darkroom's countdown arc: its thumb runs 0 → the stage's length in 5 s
/// steps, so the track's max follows `tSeconds`, and it shows the computed
/// `tRemaining` without writing it (write: false; reactions seek).
void main() {
  test('bindings set a track\'s min, max, step and reset value', () {
    final FrameNode thumb = FrameNode(
      id: 'thumb',
      name: 'Thumb',
      basicBoxLocal: NodeBox(0, 0, 24, 24),
      children: const [],
    )..variables = {
        DragTrackModel.maxVariableKey: r'${tSeconds}',
        DragTrackModel.stepVariableKey: r'${= 5}',
        DragTrackModel.defaultValueVariable: r'${tSeconds}',
      };
    const DragTrackModel track = DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'tRemaining',
      min: 0,
      max: 1,
      write: false,
    );
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'tSeconds': VariableData(id: 's', name: 'tSeconds', type: VariableType.integer, value: '530'),
      },
    );
    final DragTrackModel resolved = WidgetNodeTransformerManager.resolvedTrack(thumb, track, scope);
    expect(resolved.max, 530);
    expect(resolved.step, 5);
    expect(resolved.defaultValue, 530);
    expect(resolved.min, 0);
    expect(resolved.write, isFalse);
    expect(resolved.snap(263), 265);
    // No bindings: the track as saved.
    expect(
      WidgetNodeTransformerManager.resolvedTrack(
        FrameNode(id: 'k', name: 'K', basicBoxLocal: NodeBox(0, 0, 10, 10), children: const []),
        track,
        scope,
      ),
      same(track),
    );
  });

  test('write round-trips and defaults to true', () {
    expect(const DragTrackModel(variable: 'v').toJson().containsKey('write'), isFalse);
    final json = const DragTrackModel(variable: 'v', write: false).toJson();
    expect(json['write'], isFalse);
    expect(DragTrackModel.fromJson(json).write, isFalse);
  });
}

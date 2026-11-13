// controlTrack animateTo (DragTracks.animateTo): a track moves to a value as a whole change,
// reporting changed and changeEnd (the typed action replacing controlDrag).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/drag_track.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drag_track_test.dart' as support;

void main() {
  testWidgets('controlTrack animateTo moves a track to a value, snapped, and reports it', (tester) async {
    final s = await support.plate(
      tester,
      {'variable': 'level', 'min': 0, 'max': 10, 'step': 1, 'y2': -200},
      variables: [support.v('level', 2), support.v('changes', 0, VariableType.integer), support.v('ends', 0, VariableType.integer)],
      actions: [
        support.reaction('changed', [support.add('changes')]),
        support.reaction('changeEnd', [support.add('ends')]),
      ],
    );
    // What the controlTrack animateTo handler runs (runtime/actions/handlers.dart).
    expect(await DragTracks.animateTo(s.tree, 'other, k', 6.6), isTrue);
    await tester.pumpAndSettle();
    expect(s['level'], 7);
    expect(s['changes'], 1);
    expect(s['ends'], 1);
  });
}

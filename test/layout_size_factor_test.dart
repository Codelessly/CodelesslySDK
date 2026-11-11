// Layout.widthFactor / heightFactor: a share of the room the parent gives
// (FractionallySizedBox), as a progress bar's fill in its track.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart' as support;

void main() {
  test('round-trips; negative factors read as 0', () {
    final l = api.Layout.fromJson({'width': 10, 'height': 10, 'widthFactor': 0.6, 'heightFactor': -1});
    expect(l.widthFactor, 0.6);
    expect(l.heightFactor, 0);
    expect(api.Layout.fromJson(l.toJson()), l);
    expect(api.Layout.fromJson({'width': 10}).widthFactor, isNull);
  });

  for (final interactive in [false, true]) {
    testWidgets('a fill a share of its track, bound to progress (${interactive ? 'runtime' : 'design'})', (tester) async {
      final screen = await support.show(
        tester,
        {
          'col': {'type': 'stack', 'children': ['fill'], 'layout': {'width': 200, 'height': 12}},
          'fill': {
            'type': 'box',
            'layout': {'width': 50, 'height': {'fill': 12}, 'heightFactor': 0.5, 'x': {'start': 0}, 'y': {'start': 0}},
            'decoration': {'fills': [{'color': '#FF00AA00'}]},
            'bind': {'layout.widthFactor': r'${progress}'},
          },
        },
        interactive: interactive,
        variables: [support.v('progress', 0.6, api.VariableType.decimal)],
      );
      final view = tester.renderObject(find.byType(NodeView));
      expect(screen.tree.boxOf('fill')!.rectIn(view)!.size, const Size(120, 6));
      screen.scope.set('progress', 0.25);
      await tester.pump();
      expect(screen.tree.boxOf('fill')!.rectIn(view)!.width, 50);
    });
  }
}

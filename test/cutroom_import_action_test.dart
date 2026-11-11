import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lists/support.dart' as support;

void main() {
  for (final name in ['media.probe', 'media.import']) {
    testWidgets('$name returns a recoverable error for unavailable source/backend', (tester) async {
      final screen = await support.show(
        tester,
        {
          'col': {
            'type': 'box',
            'layout': {'width': 200, 'height': 100},
            'actions': [
              support.reaction('click', [
                {
                  'type': 'callFunction',
                  'name': name,
                  'params': {'url': 'http://localhost/private.mp4'},
                },
                {'type': 'setVariable', 'variable': 'output', 'value': r'${result}'},
              ]),
            ],
          },
        },
        variables: [support.v('output', {}, VariableType.map)],
        services: Services(),
      );
      await tester.tapAt(screen.center('col'));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      final output = screen['output'] as Map;
      expect(output['ok'], false);
      expect(output['error'], isNotEmpty);
      expect(output['error'], contains(name == 'media.probe' ? 'public HTTPS MP4' : 'cloud file storage'));
      await tester.pumpWidget(const SizedBox());
    });
  }
}

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

const png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR4nGP4z8DwHxkzoAsAAA8hD/EEN8afAAAAAElFTkSuQmCC';
void main() {
  testWidgets('actual image failure and successful replacement drive lifecycle reactions', (tester) async {
    final s = await support.show(
      tester,
      {
        'col': {
          'type': 'column',
          'layout': {'width': 200, 'height': 200},
          'children': ['photo'],
        },
        'photo': {
          'type': 'box',
          'layout': {'width': 100, 'height': 100},
          'decoration': {
            'fills': [
              {
                'type': 'image',
                'image': {'url': ''},
              },
            ],
          },
          'bind': {'decoration.fills[0].image.url': r'${url}'},
          'actions': [
            support.reaction('imageLoading', [
              {'type': 'setVariable', 'variable': 'state', 'value': 'loading'},
            ]),
            support.reaction('imageLoaded', [
              {'type': 'setVariable', 'variable': 'state', 'value': 'loaded'},
            ]),
            support.reaction('imageError', [
              {'type': 'setVariable', 'variable': 'state', 'value': 'error'},
            ]),
          ],
        },
      },
      variables: [support.v('url', 'data:image/png;base64,broken'), support.v('state', '')],
    );
    Future<void> decode() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
    }

    await decode();
    expect(s['state'], 'error');
    setVariableIn(s.scope, 'url', png);
    await tester.pump();
    await decode();
    expect(s['state'], 'loaded');
    expect(tester.takeException(), isNull);
  });
}

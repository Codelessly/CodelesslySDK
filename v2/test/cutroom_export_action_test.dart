import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lists/support.dart' as support;

class Exporter implements MediaExportEngine {
  @override
  bool get available => true;
  @override
  Future<Map<String, Object?>> export(MediaExportRequest request, {required void Function(double) onProgress}) async {
    onProgress(.5);
    return {'bytes': 123, 'downloaded': true};
  }

  @override
  void cancel() {}
}

void main() {
  testWidgets('media.export callFunction reports progress and a result through normal actions', (tester) async {
    final services = Services(mediaExport: MediaExportService(engine: Exporter()));
    final screen = await support.show(
      tester,
      {
        'col': {
          'type': 'box',
          'layout': {'width': 200, 'height': 100},
          'decoration': {
            'fills': [
              {'color': '#FF203638'},
            ],
          },
          'actions': [
            support.reaction('click', [
              {
                'type': 'callFunction',
                'name': 'media.export',
                'params': {
                  'project': {
                    'clips': [
                      {'url': 'https://example.com/clip.mp4', 'start': 0, 'end': 2},
                    ],
                    'captions': [],
                  },
                  'progressVariable': 'progress',
                },
              },
              {'type': 'setVariable', 'variable': 'output', 'value': r'${result}'},
            ]),
          ],
        },
      },
      variables: [support.v('progress', 0, VariableType.decimal), support.v('output', {}, VariableType.map)],
      services: services,
    );
    await tester.tapAt(screen.center('col'));
    for (var i = 0; i < 8; i++) await tester.pump();
    expect(screen['progress'], .5);
    expect((screen['output'] as Map)['ok'], true);
    expect((screen['output'] as Map)['bytes'], 123);
    await tester.pumpWidget(const SizedBox());
  });
}

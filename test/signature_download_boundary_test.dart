import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'gauge without kind download fails closed with original canvases',
    () async {
      final raw = <String, dynamic>{
        'id': 'layout',
        'pageId': 'page',
        'projectId': 'project',
        'owner': 'owner',
        'roles': <String, dynamic>{},
        'canvases': {
          'first': {'radial': GaugeNode.empty().toJson()},
          'second': {
            'ambiguous': {
              'id': 'ambiguous',
              'name': 'Gauge',
              'type': 'gauge',
              'basicBoxLocal': [0, 0, 220, 185],
              'properties': <String, dynamic>{},
            },
          },
        },
      };
      final repository = WebDataRepository(
        config: CodelesslyConfig(authToken: 'token'),
        client: MockClient((_) async => http.Response(jsonEncode(raw), 200)),
      );
      await expectLater(
        repository.downloadLayoutModel(
          projectID: 'project',
          layoutID: 'layout',
          source: PublishSource.publish,
        ),
        throwsA(
          isA<UnresolvedDocumentSchema>()
              .having((error) => error.reason, 'reason', 'missing-gaugeKind')
              .having((error) => error.nodeKey, 'nodeKey', 'ambiguous')
              .having(
                (error) => error.raw.keys,
                'full canvas map',
                containsAll(['first', 'second']),
              ),
        ),
      );
    },
  );

  test('signature without kind download throws with context, never returns empty layout', () async {
    final raw = <String, dynamic>{
      'id': 'layout',
      'pageId': 'page',
      'projectId': 'project',
      'owner': 'owner',
      'roles': <String, dynamic>{},
      'canvases': {
        'canvas': {
          'unresolved': {
            'type': 'signature',
            'id': 'unresolved',
            'name': 'Signature',
            'basicBoxLocal': [0, 0, 320, 140],
            'properties': {'inkColor': '#000000'},
          },
        },
      },
    };
    final repository = WebDataRepository(
      config: CodelesslyConfig(authToken: 'token'),
      client: MockClient(
        (request) async => http.Response(jsonEncode(raw), 200),
      ),
    );
    await expectLater(
      repository.downloadLayoutModel(
        projectID: 'project',
        layoutID: 'layout',
        source: PublishSource.publish,
      ),
      throwsA(
        isA<UnresolvedDocumentSchema>()
            .having((error) => error.nodeKey, 'nodeKey', 'unresolved')
            .having((error) => error.reason, 'reason', 'missing-signatureKind')
            .having(
              (error) => error.raw.keys,
              'retained canvas keys',
              contains('canvas'),
            ),
      ),
    );
    // No SDKPublishLayout was returned to be stored over a cached version.
    expect((raw['canvases'] as Map)['canvas'], contains('unresolved'));
  });
}

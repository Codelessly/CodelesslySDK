import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ambiguous raw layout download throws with context, never returns empty layout', () async {
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
            .having(
              (error) => error.reason,
              'reason',
              'ambiguous-signature-schema',
            )
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

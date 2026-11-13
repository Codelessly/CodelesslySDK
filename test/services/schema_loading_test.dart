// Published apps in production hold schema 2: every loader (Firestore, HTTP,
// an asset bundle, memory) loads it, migrated to schema 3 in memory, and
// loads schema 3 the same; nothing is written back. A stored document in a
// schema newer than this SDK reads is refused, saying so.
import 'dart:convert';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/firebase.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

typedef Json = Map<String, Object?>;

const layoutId = 'home';

/// A schema-2 layout, with keys only schema 2 has (read through the
/// migration).
Json layout2() => {
      'schema': 2,
      'id': layoutId,
      'roots': ['canvas'],
      'nodes': {
        'canvas': {
          'type': 'canvas',
          'layout': {'width': 390, 'height': 844},
          'children': ['card', 'label'],
        },
        'card': {
          'type': 'box',
          'layout': {'width': 120, 'height': 80},
          'loops': [
            {'type': 'pulse', 'scaleTo': 1.1, 'duration': 800},
          ],
          'drag': {'release': 'dismiss', 'directions': ['left', 'right']},
          'actions': [
            {
              'trigger': {'type': 'clock', 'every': 1000},
              'actions': [
                {'type': 'playAnimation', 'node': 'card', 'animation': 'loop0'},
              ],
            },
          ],
        },
        'label': {
          'type': 'text',
          'layout': {'width': 100},
          'props': {'text': 'Hi'},
        },
      },
    };

Json model2() => {
      'schema': 2,
      'projectId': 'p1',
      'entryLayoutId': layoutId,
      'entryCanvasId': 'canvas',
      'layouts': {
        layoutId: {'canvases': {'canvas': {'name': 'Home'}}},
      },
    };

Json bundle(int schema) {
  final b = {'schema': 2, 'model': model2(), 'layouts': {layoutId: layout2()}};
  return schema == 2 ? b : migratePublish2to3(b);
}

/// What schema 2 must decode to: the migrated document, as JSON.
Json expected() => LayoutDocument.fromJson(migrate2to3(layout2()), catalog: standardCatalog).toJson();

class _Assets extends CachingAssetBundle {
  _Assets(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));
}

void main() {
  test('the expected document is schema 3 and has no legacy key', () {
    final json = expected();
    expect(json['schema'], 3);
    final card = (json['nodes'] as Map)['card'] as Map;
    expect(card.keys, isNot(contains('loops')));
    expect(card.keys, isNot(contains('drag')));
  });

  for (final schema in [2, 3]) {
    group('schema $schema', () {
      test('memory', () async {
        final loader = MemoryPublishLoader(PublishBundle.fromJson(bundle(schema), catalog: standardCatalog));
        final layout = await loader.loadLayout(PublishSource.publish, layoutId);
        expect(layout.document.toJson(), expected());
        expect((await loader.loadModel(PublishSource.publish)).toJson()['schema'], 3);
      });

      test('asset bundle', () async {
        final loader = AssetPublishLoader('a.json', bundle: _Assets({'a.json': jsonEncode(bundle(schema))}));
        expect((await loader.loadLayout(PublishSource.publish, layoutId)).document.toJson(), expected());
      });

      test('http, files and bundle', () async {
        final b = bundle(schema);
        for (final asBundle in [false, true]) {
          final client = MockClient((r) async {
            final path = r.url.path;
            final body = path.endsWith('/layouts/$layoutId.json')
                ? (b['layouts'] as Map)[layoutId]
                : asBundle
                    ? b
                    : b['model'];
            return http.Response(jsonEncode(body), 200);
          });
          final loader = HttpPublishLoader(projectId: 'p1', baseUrl: 'https://x.test/', bundle: asBundle, client: client);
          expect((await loader.loadModel(PublishSource.publish)).projectId, 'p1');
          expect((await loader.loadLayout(PublishSource.publish, layoutId)).document.toJson(), expected(), reason: 'bundle: $asBundle');
        }
      });

      test('firestore, migrated in memory and not written back', () async {
        final db = FakeFirebaseFirestore();
        final b = bundle(schema);
        await db.doc('publish/p1').set(b['model'] as Json);
        await db.doc('publish/p1/layouts/$layoutId').set((b['layouts'] as Map)[layoutId] as Json);
        final loader = FirestorePublishLoader(db, projectId: 'p1');
        expect((await loader.loadModel(PublishSource.publish)).projectId, 'p1');
        expect((await loader.loadLayout(PublishSource.publish, layoutId)).document.toJson(), expected());
        final stored = (await db.doc('publish/p1/layouts/$layoutId').get()).data()!;
        expect(stored['schema'], schema);
      });
    });
  }

  test('a stored document newer than this SDK reads is refused, saying so', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('publish/p1').set({...model2(), 'schema': 4});
    await expectLater(FirestorePublishLoader(db, projectId: 'p1').loadModel(PublishSource.publish),
        throwsA(isA<PublishLoadException>().having((e) => e.message, 'message', contains('newer than this SDK'))));
  });
}

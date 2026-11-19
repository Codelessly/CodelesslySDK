// Every loader (Firestore, HTTP, an asset bundle, memory) loads schema 3,
// the one schema this SDK reads. A stored document of any other schema, or
// with none, is refused with a PublishLoadException that names the schema
// found and the one read (a newer one also names the update).
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

Json layout({Object? schema = 3}) => {
      'schema': ?schema,
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
          'animations': [
            {'id': 'pulse', 'preset': 'pulse', 'params': {'scaleTo': 1.1}, 'duration': 800},
          ],
        },
        'label': {
          'type': 'text',
          'layout': {'width': 100},
          'props': {'text': 'Hi'},
        },
      },
    };

Json model({Object? schema = 3}) => {
      'schema': ?schema,
      'projectId': 'p1',
      'entryLayoutId': layoutId,
      'entryCanvasId': 'canvas',
      'layouts': {
        layoutId: {'canvases': {'canvas': {'name': 'Home'}}},
      },
    };

Json bundle({Object? schema = 3}) => {'schema': ?schema, 'model': model(schema: schema), 'layouts': {layoutId: layout(schema: schema)}};

Json expected() => LayoutDocument.fromJson(layout(), catalog: standardCatalog).toJson();

class _Assets extends CachingAssetBundle {
  _Assets(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));
}

HttpPublishLoader _http(Json b, {required bool asBundle}) => HttpPublishLoader(
    projectId: 'p1',
    baseUrl: 'https://x.test/',
    bundle: asBundle,
    client: MockClient((r) async {
      final path = r.url.path;
      final body = path.endsWith('/layouts/$layoutId.json')
          ? (b['layouts'] as Map)[layoutId]
          : asBundle
              ? b
              : b['model'];
      return http.Response(jsonEncode(body), 200);
    }));

Matcher _refused(String message) => throwsA(isA<PublishLoadException>().having((e) => e.message, 'message', message));

void main() {
  group('a schema-3 document', () {
    test('loads from memory', () async {
      final loader = MemoryPublishLoader(PublishBundle.fromJson(bundle(), catalog: standardCatalog));
      expect((await loader.loadLayout(PublishSource.publish, layoutId)).document.toJson(), expected());
      expect((await loader.loadModel(PublishSource.publish)).toJson()['schema'], 3);
    });

    test('loads from the asset bundle', () async {
      final loader = AssetPublishLoader('a.json', bundle: _Assets({'a.json': jsonEncode(bundle())}));
      expect((await loader.loadLayout(PublishSource.publish, layoutId)).document.toJson(), expected());
    });

    test('loads over HTTP, from files and from a bundle', () async {
      for (final asBundle in [false, true]) {
        final loader = _http(bundle(), asBundle: asBundle);
        expect((await loader.loadModel(PublishSource.publish)).projectId, 'p1');
        expect((await loader.loadLayout(PublishSource.publish, layoutId)).document.toJson(), expected(), reason: 'bundle: $asBundle');
      }
    });

    test('loads from Firestore', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('publish/p1').set(model());
      await db.doc('publish/p1/layouts/$layoutId').set(layout());
      final loader = FirestorePublishLoader(db, projectId: 'p1');
      expect((await loader.loadModel(PublishSource.publish)).projectId, 'p1');
      expect((await loader.loadLayout(PublishSource.publish, layoutId)).document.toJson(), expected());
    });
  });

  group('a schema-2 document is refused, naming the schema found and the one read', () {
    test('from Firestore', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('publish/p1').set(model(schema: 2));
      await db.doc('publish/p1/layouts/$layoutId').set(layout(schema: 2));
      final loader = FirestorePublishLoader(db, projectId: 'p1');
      await expectLater(loader.loadModel(PublishSource.publish),
          _refused('The publish model of project [p1] is in schema 2; codelessly_api reads schema 3 only.'));
      await expectLater(loader.loadLayout(PublishSource.publish, layoutId),
          _refused('Layout [home] is in schema 2; codelessly_api reads schema 3 only.'));
    });

    test('over HTTP, from files and from a bundle', () async {
      await expectLater(_http(bundle(schema: 2), asBundle: false).loadModel(PublishSource.publish),
          _refused('The publish model of project [p1] is in schema 2; codelessly_api reads schema 3 only.'));
      await expectLater(_http(bundle(schema: 2), asBundle: true).loadModel(PublishSource.publish),
          _refused('The bundle is in schema 2; codelessly_api reads schema 3 only.'));
    });

    test('from the asset bundle, and a bundle whose model or layout is schema 2', () async {
      final loader = AssetPublishLoader('a.json', bundle: _Assets({'a.json': jsonEncode(bundle(schema: 2))}));
      await expectLater(loader.loadModel(PublishSource.publish), _refused('The bundle is in schema 2; codelessly_api reads schema 3 only.'));
      expect(() => decodeBundleJson({'model': model(schema: 2), 'layouts': {layoutId: layout()}}),
          _refused("The bundle's publish model is in schema 2; codelessly_api reads schema 3 only."));
      expect(() => decodeBundleJson({'model': model(), 'layouts': {layoutId: layout(schema: 2)}}),
          _refused('Layout [home] of the bundle is in schema 2; codelessly_api reads schema 3 only.'));
    });

    test('in memory, by codelessly_api as it decodes', () {
      expect(() => PublishBundle.fromJson(bundle(schema: 2), catalog: standardCatalog),
          throwsA(isA<UnsupportedSchemaException>().having((e) => e.message, 'message', 'The bundle is in schema 2; codelessly_api reads schema 3 only.')));
    });
  });

  test('a stored document with no schema is refused, saying so', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('publish/p1').set(model(schema: null));
    await expectLater(FirestorePublishLoader(db, projectId: 'p1').loadModel(PublishSource.publish),
        _refused('The publish model of project [p1] has no "schema"; codelessly_api reads schema 3 only ("schema": 3).'));
  });

  test('a stored document newer than this SDK reads is refused, naming the update', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('publish/p1').set(model(schema: 4));
    await expectLater(FirestorePublishLoader(db, projectId: 'p1').loadModel(PublishSource.publish),
        _refused('The publish model of project [p1] is in schema 4; codelessly_api reads schema 3 only. Update codelessly_sdk.'));
  });

  test('a bundle newer than this SDK reads is refused, naming the update', () async {
    await expectLater(_http(bundle(schema: 4), asBundle: true).loadModel(PublishSource.publish),
        _refused('The bundle is in schema 4; codelessly_api reads schema 3 only. Update codelessly_sdk.'));
  });
}

// FirestorePublishLoader over fake_cloud_firestore, with documents written
// in the conversion job's and the v2 editor's exact format
// (CodelesslyEditor/packages/codelessly_v2_storage, publish.dart): the model
// at `publish/{p}` with `schema: 2` and privacy fields, each layout at
// `publish/{p}/layouts/{id}` with `schema: 2`, a large one with its nodes
// gzipped in `compressedNodes`.
import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart' show GZipEncoder;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/firebase.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/support.dart';

typedef Json = Map<String, Object?>;

/// codelessly_v2_storage `encodeGzipJson`.
String encodeGzipJson(Object? json) => base64Encode(const GZipEncoder().encodeBytes(utf8.encode(jsonEncode(json))));

/// codelessly_v2_storage `encodeStoredLayout` (with [compress] forcing what
/// it does past 900 KiB).
Json encodeStoredLayout(Json layout, {bool compress = false}) {
  final out = {...layout, 'schema': 2};
  if (!compress) return out;
  final nodes = out.remove('nodes');
  out['compressedNodes'] = encodeGzipJson({'nodes': nodes});
  return out;
}

const privacy = {'owner': 'u1', 'teams': <String>[], 'users': ['u1'], 'roles': {'u1': 'owner'}, 'public': false};

/// Writes [bundle] where the job writes a converted publish ([collection]:
/// `publish` or `publish_preview`).
Future<void> writePublish(FakeFirebaseFirestore db, String projectId, PublishBundle bundle,
    {String collection = 'publish', Set<String> compressed = const {}, Json extraModel = const {}}) async {
  for (final l in bundle.layouts.values) {
    await db
        .doc('$collection/$projectId/layouts/${l.id}')
        .set(encodeStoredLayout({...l.toJson(), ...privacy}, compress: compressed.contains(l.id)));
  }
  await db.doc('$collection/$projectId').set({...bundle.model.toJson(), 'schema': 2, ...privacy, ...extraModel});
}

class FakeProjectAuth implements ProjectAuth {
  FakeProjectAuth(this.granted);
  final ProjectAccess granted;
  int calls = 0;
  ProjectAccess? _access;
  @override
  ProjectAccess? get access => _access;
  @override
  Stream<ProjectAccess?> get changes => const Stream.empty();
  @override
  Future<ProjectAccess> authenticate() async {
    calls++;
    return _access = granted;
  }

  @override
  Future<void> reauthenticate() async {}
  @override
  void dispose() {}
}

void main() {
  final rigcheck = fixture('rigcheck');
  final layoutId = rigcheck.layouts.keys.first;

  test('reads the model and layouts at publish/{project}, as the job writes them', () async {
    final db = FakeFirebaseFirestore();
    await writePublish(db, 'p1', rigcheck, extraModel: {'publishedAt': Timestamp.fromMillisecondsSinceEpoch(1000)});
    final loader = FirestorePublishLoader(db, projectId: 'p1');

    final model = await loader.loadModel(PublishSource.publish);
    expect(model.projectId, rigcheck.model.projectId);
    expect(model.layouts.keys, rigcheck.model.layouts.keys);
    expect(model.extra['owner'], 'u1');
    expect(model.extra['publishedAt'], 1000, reason: 'Firestore timestamps read as milliseconds');

    final layout = await loader.loadLayout(PublishSource.publish, layoutId);
    expect(layout.id, layoutId);
    expect(layout.document.nodes.keys, rigcheck.layouts[layoutId]!.document.nodes.keys);
  });

  test('a large layout: its nodes gzipped in compressedNodes', () async {
    final db = FakeFirebaseFirestore();
    await writePublish(db, 'p1', rigcheck, compressed: {layoutId});
    final stored = (await db.doc('publish/p1/layouts/$layoutId').get()).data()!;
    expect(stored.containsKey('nodes'), isFalse);
    expect(stored['compressedNodes'], isA<String>());

    final layout = await FirestorePublishLoader(db, projectId: 'p1').loadLayout(PublishSource.publish, layoutId);
    final want = rigcheck.layouts[layoutId]!;
    expect(layout.document.nodes.keys, want.document.nodes.keys);
    expect(jsonEncode(layout.document.toJson()), jsonEncode(want.document.toJson()));
  });

  test('the preview reads publish_preview', () async {
    final db = FakeFirebaseFirestore();
    await writePublish(db, 'p1', rigcheck, collection: 'publish_preview');
    final loader = FirestorePublishLoader(db, projectId: 'p1');
    expect((await loader.loadModel(PublishSource.preview)).layouts, isNotEmpty);
    await expectLater(loader.loadModel(PublishSource.publish), throwsA(isA<PublishLoadException>()));
  });

  test('the project token names the project; a template reads templates', () async {
    final db = FakeFirebaseFirestore();
    await writePublish(db, 'p1', rigcheck);
    await writePublish(db, 't1', rigcheck, collection: 'templates');
    final auth = FakeProjectAuth(const ProjectAccess(projectId: 'p1', authToken: 'tok'));
    final loader = FirestorePublishLoader(db, auth: auth);
    expect((await loader.loadModel(PublishSource.publish)).layouts, isNotEmpty);
    await loader.loadLayout(PublishSource.publish, layoutId);
    expect(auth.calls, 1, reason: 'authenticates once');

    final template = FirestorePublishLoader(db,
        auth: FakeProjectAuth(const ProjectAccess(projectId: 't1', authToken: 'tok', isTemplate: true)));
    expect((await template.loadModel(PublishSource.publish)).layouts, isNotEmpty);
  });

  test('a v1 publish (not converted) fails, saying so', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('publish/old').set({'projectId': 'old', 'layouts': {}, 'updates': {}});
    await db.doc('publish/old/layouts/l').set({'id': 'l', 'canvases': {}});
    final loader = FirestorePublishLoader(db, projectId: 'old');
    await expectLater(
        loader.loadModel(PublishSource.publish),
        throwsA(isA<PublishLoadException>().having((e) => e.message, 'message', contains('not v2'))));
    await expectLater(loader.loadLayout(PublishSource.publish, 'l'), throwsA(isA<PublishLoadException>()));
    await expectLater(loader.loadLayout(PublishSource.publish, 'missing'),
        throwsA(isA<PublishLoadException>().having((e) => e.message, 'message', contains('does not exist'))));
    await expectLater(FirestorePublishLoader(db, projectId: 'none').loadModel(PublishSource.publish),
        throwsA(isA<PublishLoadException>().having((e) => e.message, 'message', contains('nothing published'))));
  });

  test('Codelessly follows the publish live, reloading republished layouts', () async {
    final db = FakeFirebaseFirestore();
    await writePublish(db, 'p1', rigcheck);
    final cache = MemoryPublishCache();
    final c = codelesslyOnFirebase(
      firestore: db,
      config: const CodelesslyConfig(authToken: 'tok'),
      projectAuth: FakeProjectAuth(const ProjectAccess(projectId: 'p1', authToken: 'tok')),
      cache: cache,
      fonts: const NoFontFetcher(),
    );
    expect(c.loader, isA<FirestorePublishLoader>());
    final first = await c.loadLayout(layoutId);
    expect(c.layout(layoutId), same(first));
    expect(cache.entries.keys, containsAll(['publish/tok', 'publish/tok/layouts/$layoutId']));

    // A republish of the layout: newer times in the layout and the model.
    final t = DateTime.utc(2030).millisecondsSinceEpoch;
    final republished = PublishLayout.fromJson({...first.toJson(), 'lastUpdated': t});
    await db.doc('publish/p1/layouts/$layoutId').set(encodeStoredLayout({...republished.toJson(), ...privacy}));
    var notified = 0;
    c.addListener(() => notified++);
    final model = rigcheck.model.toJson();
    final layouts = {...(model['layouts']! as Map).cast<String, Object?>()};
    layouts[layoutId] = {...(layouts[layoutId]! as Map).cast<String, Object?>(), 'lastUpdated': t};
    await db.doc('publish/p1').set({...model, 'layouts': layouts, 'lastUpdated': t, 'schema': 2, ...privacy});
    await pumpEventQueue();

    expect(notified, greaterThan(0));
    expect(c.publishModel!.layouts[layoutId]!.lastUpdated, DateTime.fromMillisecondsSinceEpoch(t, isUtc: true));
    expect(c.layout(layoutId), isNull, reason: 'the stale layout is dropped');
    expect((await c.loadLayout(layoutId)).lastUpdated, DateTime.fromMillisecondsSinceEpoch(t, isUtc: true));
    c.dispose();
  });

  test('live updates can be turned off', () async {
    final db = FakeFirebaseFirestore();
    await writePublish(db, 'p1', rigcheck);
    final c = codelesslyOnFirebase(
        firestore: db, config: const CodelesslyConfig(projectId: 'p1', liveUpdates: false), fonts: const NoFontFetcher());
    await c.initialize();
    var notified = 0;
    c.addListener(() => notified++);
    await db.doc('publish/p1').update({'lastUpdated': DateTime.utc(2031).millisecondsSinceEpoch});
    await pumpEventQueue();
    expect(notified, 0);
    c.dispose();
  });

  test('without Firebase, a project id alone says how to load it', () async {
    final c = Codelessly(config: const CodelesslyConfig(projectId: 'p1'));
    await expectLater(c.initialize(),
        throwsA(isA<PublishLoadException>().having((e) => e.message, 'message', contains('codelesslyOnFirebase'))));
  });
}

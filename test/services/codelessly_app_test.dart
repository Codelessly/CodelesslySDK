// A Codelessly instance from a project token alone: Codelessly's Firebase
// options per platform, the secondary Firebase app, and codelesslyWithToken
// reading a publish (Firestore and the project's access faked).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/firebase.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/support.dart';
import 'firestore_publish_loader_test.dart' show FakeProjectAuth, writePublish;

void main() {
  group('CodelesslyFirebaseOptions', () {
    test('every platform is the codeless-app project, with its own app id', () {
      const all = {
        'web': CodelesslyFirebaseOptions.web,
        'android': CodelesslyFirebaseOptions.android,
        'ios': CodelesslyFirebaseOptions.ios,
        'macos': CodelesslyFirebaseOptions.macos,
        'windows': CodelesslyFirebaseOptions.windows,
      };
      for (final e in all.entries) {
        expect(e.value.projectId, 'codeless-app', reason: e.key);
        expect(e.value.storageBucket, kCodelesslyStorageBucket, reason: e.key);
        expect(e.value.apiKey, startsWith('AIza'), reason: e.key);
        expect(e.value.appId, startsWith('1:1008464357540:'), reason: e.key);
      }
      expect(CodelesslyFirebaseOptions.android.appId, contains(':android:'));
      expect(CodelesslyFirebaseOptions.ios.appId, contains(':ios:'));
      expect(CodelesslyFirebaseOptions.web.appId, contains(':web:'));
    });

    test('picks by platform; the web wins', () {
      expect(CodelesslyFirebaseOptions.forPlatform(TargetPlatform.android), CodelesslyFirebaseOptions.android);
      expect(CodelesslyFirebaseOptions.forPlatform(TargetPlatform.iOS), CodelesslyFirebaseOptions.ios);
      expect(CodelesslyFirebaseOptions.forPlatform(TargetPlatform.macOS), CodelesslyFirebaseOptions.macos);
      expect(CodelesslyFirebaseOptions.forPlatform(TargetPlatform.windows), CodelesslyFirebaseOptions.windows);
      expect(CodelesslyFirebaseOptions.forPlatform(TargetPlatform.linux, isWeb: true), CodelesslyFirebaseOptions.web);
    });

    test('Linux has no Firebase: an error that says what to do instead', () {
      expect(
        () => CodelesslyFirebaseOptions.forPlatform(TargetPlatform.linux),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', allOf(contains('slug'), contains('bundle')))),
      );
    });

    test('currentPlatform follows the running platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(CodelesslyFirebaseOptions.currentPlatform, CodelesslyFirebaseOptions.android);
    });
  });

  group('codelesslyFirebaseApp', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();

    test('creates the secondary app once, with Codelessly\'s options', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(Firebase.apps.where((a) => a.name == kCodelesslyFirebaseAppName), isEmpty);
      final app = await codelesslyFirebaseApp();
      expect(app.name, kCodelesslyFirebaseAppName);
      expect(app.name, isNot(defaultFirebaseAppName), reason: 'the app\'s own default Firebase app is left alone');
      expect((await codelesslyFirebaseApp()).name, app.name);
      expect(Firebase.apps.where((a) => a.name == kCodelesslyFirebaseAppName), hasLength(1));
    });

    test('another name is another app', () async {
      final other = await codelesslyFirebaseApp(name: 'staging', options: CodelesslyFirebaseOptions.web);
      expect(other.name, 'staging');
    });
  });

  group('codelesslyWithToken', () {
    final rigcheck = fixture('rigcheck');

    test('reads the project the token names, from Firestore', () async {
      final db = FakeFirebaseFirestore();
      await writePublish(db, 'p1', rigcheck);
      final access = FakeProjectAuth(const ProjectAccess(projectId: 'p1', authToken: 'tok'));
      final codelessly = await codelesslyWithToken(
        'tok',
        firestore: db,
        projectAuth: access,
        fonts: const NoFontFetcher(),
        data: const {'user': 'Ada'},
      );
      addTearDown(codelessly.dispose);
      expect(codelessly.config.authToken, 'tok');
      expect(codelessly.loader, isA<FirestorePublishLoader>());
      expect(access.calls, 0, reason: 'nothing loads until the instance is initialized');

      await codelessly.initialize();
      expect(access.calls, 1);
      expect(codelessly.status, isA<CLoaded>());
      expect(codelessly.publishModel!.layouts.keys, rigcheck.model.layouts.keys);
      final layout = await codelessly.loadLayout(rigcheck.model.entryLayoutId!);
      expect(layout.id, rigcheck.model.entryLayoutId);
      expect(codelessly.data.read('data.user'), 'Ada');
    });

    test('keeps the rest of the config', () async {
      final codelessly = await codelesslyWithToken(
        'tok',
        config: const CodelesslyConfig(preload: true, liveUpdates: false, publishSource: PublishSource.preview),
        firestore: FakeFirebaseFirestore(),
        projectAuth: FakeProjectAuth(const ProjectAccess(projectId: 'p1')),
      );
      addTearDown(codelessly.dispose);
      expect(codelessly.config.authToken, 'tok');
      expect(codelessly.config.preload, isTrue);
      expect(codelessly.config.liveUpdates, isFalse);
      expect(codelessly.config.isPreview, isTrue);
    });

    test('with cloud services: authenticates first, cloud data under the project', () async {
      final db = FakeFirebaseFirestore();
      await writePublish(db, 'p1', rigcheck);
      final access = FakeProjectAuth(const ProjectAccess(projectId: 'p1', authToken: 'tok'));
      final codelessly = await codelesslyWithToken('tok', cloudServices: true, firestore: db, projectAuth: access);
      addTearDown(codelessly.dispose);
      expect(access.calls, 1);
      final services = codelessly.services as Services;
      final cloud = services.cloud as BackendCloudDatabase;
      expect(cloud.root, 'data/p1');
      expect(cloud.backend, isA<FirestoreDocumentBackend>());
      // No Firebase Auth or Storage given: those keep their defaults.
      expect(services.auth, isA<SignedOutAuthService>());
      expect(services.files, isA<MemoryFileStorage>());
    });

    test('the app\'s own services win over cloud services', () async {
      final mine = Services();
      final access = FakeProjectAuth(const ProjectAccess(projectId: 'p1'));
      final codelessly = await codelesslyWithToken(
        'tok',
        config: CodelesslyConfig(services: mine),
        cloudServices: true,
        firestore: FakeFirebaseFirestore(),
        projectAuth: access,
      );
      addTearDown(codelessly.dispose);
      expect(identical(codelessly.services, mine), isTrue);
      expect(access.calls, 0);
    });

    test('an empty token is refused', () {
      expect(codelesslyWithToken(''), throwsArgumentError);
    });
  });

  test('codelesslyCloudServices: the project\'s data root, storage kept where given', () {
    final storage = MemoryLocalStorage();
    final services = codelesslyCloudServices(projectId: 'p9', firestore: FakeFirebaseFirestore(), localStorage: storage);
    expect((services.cloud as BackendCloudDatabase).root, firestoreRoot('p9'));
    expect(identical(services.storage, storage), isTrue);
    services.dispose();
  });
}

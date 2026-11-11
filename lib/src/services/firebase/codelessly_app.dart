// Codelessly's own Firebase project (codeless-app), where the Codelessly
// Editor publishes: its client options, the Firebase app an SDK instance
// uses for it, and a Codelessly instance from a project token alone.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../app/codelessly.dart';
import '../../app/config.dart';
import '../../app/fonts.dart';
import '../../app/loader.dart';
import '../auth.dart';
import '../cloud/database.dart';
import '../services.dart' show Services;
import '../test_store.dart' show TestStoreMode;
import '../storage.dart';
import 'auth.dart';
import 'codelessly_firebase.dart';
import 'firestore.dart';
import 'paywall.dart';
import 'project_auth.dart';
import 'storage.dart';

/// The name of the Firebase app [codelesslyFirebaseApp] creates. It is a
/// secondary app: an app's own default Firebase app (if it has one) is left
/// alone.
const String kCodelesslyFirebaseAppName = 'codelessly';

/// The client options of Codelessly's Firebase project (`codeless-app`),
/// where the Codelessly Editor publishes.
///
/// These are public client identifiers (the same ones every web page that
/// shows a published Codelessly app carries), not secrets: what an app may
/// read is decided by the project's security rules and its project token.
abstract final class CodelesslyFirebaseOptions {
  /// The options for the platform the app runs on.
  ///
  /// Throws an [UnsupportedError] on Linux and Fuchsia, where the Firebase
  /// plugins don't run: load by slug or from a bundle there
  /// ([CodelesslyConfig.slug], [Codelessly.asset]).
  static FirebaseOptions get currentPlatform => forPlatform(defaultTargetPlatform, isWeb: kIsWeb);

  /// The options for [platform] ([web] when [isWeb]).
  static FirebaseOptions forPlatform(TargetPlatform platform, {bool isWeb = false}) {
    if (isWeb) return web;
    return switch (platform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      TargetPlatform.linux || TargetPlatform.fuchsia => throw UnsupportedError(
          'Firebase has no ${platform.name} support, so a project token cannot be used here. '
          'Load the project by its slug (CodelesslyConfig(slug: ...)) or from a bundle (Codelessly.asset).'),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBR92IoT_1kwBYOLBbPvln48DwaXTeTrxk',
    appId: '1:1008464357540:web:1aee4cb376ddd458a6de31',
    messagingSenderId: '1008464357540',
    projectId: 'codeless-app',
    authDomain: 'codeless-app.firebaseapp.com',
    databaseURL: 'https://codeless-app-default-rtdb.firebaseio.com',
    storageBucket: 'codeless-app.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-_acaGPk23JdiwqqHqzYgJGSbKPP7bXI',
    appId: '1:1008464357540:android:a67369aaaae42a92a6de31',
    messagingSenderId: '1008464357540',
    projectId: 'codeless-app',
    databaseURL: 'https://codeless-app-default-rtdb.firebaseio.com',
    storageBucket: 'codeless-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAehrT8nR7iJHtANJAA3AZi_SwCN1Z2ryU',
    appId: '1:1008464357540:ios:17b5c319b8ec753aa6de31',
    messagingSenderId: '1008464357540',
    projectId: 'codeless-app',
    databaseURL: 'https://codeless-app-default-rtdb.firebaseio.com',
    storageBucket: 'codeless-app.appspot.com',
    iosClientId: '1008464357540-quq84tmv8e0b7qo3jo2r3148pd9snfni.apps.googleusercontent.com',
    iosBundleId: 'com.codelessly',
  );

  /// macOS uses the Apple app's options.
  static const FirebaseOptions macos = ios;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBR92IoT_1kwBYOLBbPvln48DwaXTeTrxk',
    appId: '1:1008464357540:web:ed36d3c5f17fe57ea6de31',
    messagingSenderId: '1008464357540',
    projectId: 'codeless-app',
    authDomain: 'codeless-app.firebaseapp.com',
    databaseURL: 'https://codeless-app-default-rtdb.firebaseio.com',
    storageBucket: 'codeless-app.appspot.com',
  );
}

/// The Firebase app for Codelessly's backend: the app named [name] when it
/// exists, else a new one with [options] (default:
/// [CodelesslyFirebaseOptions.currentPlatform]). Safe to call again.
///
/// It needs no `google-services.json`, `GoogleService-Info.plist` or
/// `flutterfire configure`: the options are given in Dart. The app's own
/// Firebase project, if it has one, is not involved.
Future<FirebaseApp> codelesslyFirebaseApp({
  String name = kCodelesslyFirebaseAppName,
  FirebaseOptions? options,
}) async {
  for (final app in Firebase.apps) {
    if (app.name == name) return app;
  }
  return Firebase.initializeApp(name: name, options: options ?? CodelesslyFirebaseOptions.currentPlatform);
}

/// A [Codelessly] for the project [authToken] names, on Codelessly's
/// Firebase, with live updates: all an app needs is its project token.
///
/// ```dart
/// final codelessly = await codelesslyWithToken('<project token>');
/// runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
/// ```
///
/// It opens [codelesslyFirebaseApp] (unless [app], or [firestore] and
/// [auth], are given) and returns [codelesslyOnFirebase] on it, with
/// [config]'s token set to [authToken]. Nothing is loaded yet: the first
/// [CodelesslyWidget] (or [Codelessly.initialize]) signs in anonymously,
/// exchanges the token for access to its project and reads the publish.
///
/// With [cloudServices], the project's Codelessly cloud data, app user
/// accounts, cloud files and managed paywalls (`codelessly.paywall`;
/// purchases verified by Codelessly) work too ([codelesslyCloudServices]): the token
/// is authenticated first (the project's id is needed), so the future
/// completes with an error when that fails. Ignored when [config] has its
/// own `services`. [testStore] is when their paywalls run on the test store
/// ([Services.testStore]; [TestStoreMode.force] for a run preview).
///
/// A project on another Codelessly backend (a staging one) gives that
/// backend's Firebase [app] and its [functionsBaseUrl]
/// ([ProjectAuthConfig.functionsBaseUrl]).
///
/// On Linux, where Firebase doesn't run, this throws an [UnsupportedError]:
/// load by slug or from a bundle there.
Future<Codelessly> codelesslyWithToken(
  String authToken, {
  CodelesslyConfig config = const CodelesslyConfig(),
  bool cloudServices = false,
  TestStoreMode testStore = TestStoreMode.auto,
  FirebaseApp? app,
  FirebaseFirestore? firestore,
  FirebaseAuth? auth,
  FirebaseStorage? storage,
  ProjectAuth? projectAuth,
  String? functionsBaseUrl,
  PublishCache? cache,
  FontFetcher? fonts,
  Map<String, Object?> data = const {},
}) async {
  if (authToken.isEmpty) throw ArgumentError.value(authToken, 'authToken', 'A project token is needed');
  if (app == null && (firestore == null || (auth == null && projectAuth == null))) {
    app = await codelesslyFirebaseApp();
  }
  final db = firestore ?? FirebaseFirestore.instanceFor(app: app!);
  var resolved = config.copyWith(authToken: authToken);
  final access = projectAuth ??
      FirebaseProjectAuth(
        config: functionsBaseUrl == null
            ? ProjectAuthConfig(authToken: authToken, slug: config.slug)
            : ProjectAuthConfig(authToken: authToken, slug: config.slug, functionsBaseUrl: functionsBaseUrl),
        auth: auth ?? FirebaseAuth.instanceFor(app: app!),
      );
  if (cloudServices && config.services == null) {
    final projectId = config.projectId ?? (await access.authenticate()).projectId;
    resolved = resolved.copyWith(
      services: codelesslyCloudServices(
        projectId: projectId,
        firestore: db,
        auth: auth ?? (app == null ? null : FirebaseAuth.instanceFor(app: app)),
        storage: storage ?? (app == null ? null : FirebaseStorage.instanceFor(app: app)),
        functions: app == null ? null : FirebaseFunctions.instanceFor(app: app),
        testStore: testStore,
      ),
    );
  }
  return codelesslyOnFirebase(
    firestore: db,
    auth: auth,
    config: resolved,
    projectAuth: access,
    cache: cache,
    fonts: fonts,
    data: data,
  );
}

/// The [Services] of project [projectId] on Firebase: its cloud data on
/// [firestore] (under `data/{projectId}`, with the project's data rules),
/// app user accounts on [auth], cloud files on [storage] and managed
/// paywalls on [functions] ([codelesslyPaywalls]), each only when given.
/// [localStorage] is where the app keeps `storage` values (default:
/// memory; [PreferencesLocalStorage] keeps them between runs) and the store
/// purchases waiting for verification. [testStore] is when paywalls run on
/// the test store instead ([Services.testStore]: by default, on the web for
/// a paywall published with `"testStore": true`).
///
/// Everything else keeps [Services]' defaults.
Services codelesslyCloudServices({
  required String projectId,
  required FirebaseFirestore firestore,
  FirebaseAuth? auth,
  FirebaseStorage? storage,
  FirebaseFunctions? functions,
  LocalStorage? localStorage,
  TestStoreMode testStore = TestStoreMode.auto,
}) {
  final root = firestoreRoot(projectId);
  final local = localStorage ?? MemoryLocalStorage();
  final managed = functions == null ? null : codelesslyPaywalls(projectId: projectId, functions: functions, storage: local);
  final users = auth == null ? null : FirebaseAuthService(auth, storage: local);
  final backend = FirestoreDocumentBackend(firestore);
  // The role in the user's profile (users/{uid}), as the rules read it.
  final audience = users == null
      ? null
      : AuthAudience(
          users: users.userChanges,
          currentUser: () => users.currentUser,
          profile: (uid) => backend.watch('$root/${AuthProfiles.collection}', uid),
        );
  final cloud = BackendCloudDatabase(
    backend: backend,
    root: root,
    rulesSource: firestoreDataRules(firestore, projectId),
    userId: () => auth?.currentUser?.uid,
    // Live owner-only and audience queries follow sign in and out, and a
    // change of the user's role.
    userChanges: audience?.changes,
    audience: audience?.call,
  );
  return Services(
    storage: local,
    paywalls: managed?.paywalls,
    purchases: managed?.purchases,
    testStore: testStore,
    auth: users,
    cloud: cloud,
    files: storage == null ? null : FirebaseFileStorage(storage, root: root),
  );
}

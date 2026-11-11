// Codelessly's user store on Firebase: the backend (codeless-editor) the
// store lives in, the per-project Firebase Auth instance that keeps an app's
// session, and the user-record watch.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_auth.dart';
import '../storage.dart' show LocalStorage;
import 'codelessly_app.dart' show CodelesslyFirebaseOptions;
import 'project_auth.dart' show idTokenClaims;

/// The client options of the Firebase project `codeless-editor`, where the Codelessly
/// Editor, its publishes and the per-project user stores live (owner decision,
/// 2026-11-11).
///
/// Only the web app is registered there today (the editor's own); the SDK uses it on the
/// web. Android, iOS/macOS and Windows need apps registered in `codeless-editor` (see
/// the guide, "Codelessly accounts"); until then those platforms stay on
/// [CodelesslyFirebaseOptions] (`codeless-app`) and [forPlatform] is null.
abstract final class CodelesslyEditorFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCecNnIv_X-F1uFPJT2y8XPCLpxXdD3etk',
    appId: '1:945980228772:web:7d092a75773524dd5f1231',
    messagingSenderId: '945980228772',
    projectId: 'codeless-editor',
    authDomain: 'codeless-editor.firebaseapp.com',
    databaseURL: 'https://codeless-editor-default-rtdb.firebaseio.com',
    storageBucket: 'codeless-editor.firebasestorage.app',
  );

  /// Android, iOS (macOS) and Windows: not registered yet.
  static const FirebaseOptions? android = null;
  static const FirebaseOptions? ios = null;
  static const FirebaseOptions? windows = null;

  /// The options for [platform] ([web] when [isWeb]), or null where no app is registered.
  static FirebaseOptions? forPlatform(TargetPlatform platform, {bool isWeb = false}) {
    if (isWeb) return web;
    return switch (platform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS || TargetPlatform.macOS => ios,
      TargetPlatform.windows => windows,
      TargetPlatform.linux || TargetPlatform.fuchsia => null,
    };
  }
}

/// Which Codelessly backend an app talks to: its Firebase project's client options and
/// its functions.
@immutable
class CodelesslyBackend {
  const CodelesslyBackend({
    required this.name,
    required this.options,
    required this.functionsBaseUrl,
    this.userStore = false,
  });

  /// `codeless-editor`: the editor, publishes and Codelessly accounts (the user store).
  static const editor = CodelesslyBackend(
    name: 'codeless-editor',
    options: CodelesslyEditorFirebaseOptions.forPlatform,
    functionsBaseUrl: 'https://us-central1-codeless-editor.cloudfunctions.net',
    userStore: true,
  );

  /// `codeless-app`: the old backend (Firebase Auth accounts, anonymous sessions with a
  /// `project_ids` claim).
  static const app = CodelesslyBackend(
    name: 'codeless-app',
    options: _appOptions,
    functionsBaseUrl: 'https://us-central1-codeless-app.cloudfunctions.net',
  );

  static FirebaseOptions? _appOptions(TargetPlatform platform, {bool isWeb = false}) =>
      CodelesslyFirebaseOptions.forPlatform(platform, isWeb: isWeb);

  /// The default for the platform the app runs on: [editor] where `codeless-editor` has
  /// an app registered for it, else [app].
  static CodelesslyBackend get preferred => forPlatform(defaultTargetPlatform, isWeb: kIsWeb);

  static CodelesslyBackend forPlatform(TargetPlatform platform, {bool isWeb = false}) =>
      editor.options(platform, isWeb: isWeb) != null ? editor : app;

  final String name;

  /// The client options for a platform, or null where the backend has no app for it.
  final FirebaseOptions? Function(TargetPlatform platform, {bool isWeb}) options;

  final String functionsBaseUrl;

  /// Whether app accounts are Codelessly's user store (the `appAuth` function).
  final bool userStore;

  /// The user store's base URL.
  String get appAuthUrl => '$functionsBaseUrl/appAuth';

  /// The options for the platform the app runs on; throws [UnsupportedError] where the
  /// backend has none.
  FirebaseOptions get currentOptions =>
      options(defaultTargetPlatform, isWeb: kIsWeb) ??
      (throw UnsupportedError('The Codelessly backend $name has no Firebase app for '
          '${kIsWeb ? 'web' : defaultTargetPlatform.name} yet.'));

  @override
  String toString() => 'CodelesslyBackend($name)';
}

/// [TokenSession] on a Firebase Auth instance (one per project: the app
/// `codelessly.{projectId}`), which keeps the session between runs and refreshes it.
class FirebaseTokenSession implements TokenSession {
  FirebaseTokenSession(this.auth, {bool? claimsFromToken})
      : claimsFromToken = claimsFromToken ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  final FirebaseAuth auth;

  /// Reads claims from the token's payload (Windows, where the plugin doesn't give them).
  final bool claimsFromToken;

  @override
  String? get uid => auth.currentUser?.uid;

  @override
  Future<void> signInWithCustomToken(String customToken) => auth.signInWithCustomToken(customToken);

  @override
  Future<IdToken?> idToken({bool refresh = false}) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final result = await user.getIdTokenResult(refresh);
    final token = result.token;
    if (token == null) return null;
    return IdToken(token, claims: idTokenClaims(result, fromToken: claimsFromToken), expiresAt: result.expirationTime);
  }

  @override
  Future<void> signOut() => auth.signOut();
}

/// Codelessly accounts of [projectId]: a [CodelesslyAuthService] on the user store at
/// [baseUrl] (`CodelesslyBackend.appAuthUrl`), with the session on [auth] (that project's
/// own Firebase app) and, with [firestore] (the same app's), the user's record followed
/// so a role change or a disabled account takes effect at once. [storage] keeps the guest
/// session's uid (memory when null).
CodelesslyAuthService codelesslyUserStore({
  required String projectId,
  required FirebaseAuth auth,
  required String baseUrl,
  FirebaseFirestore? firestore,
  String env = 'publish',
  http.Client? client,
  LocalStorage? storage,
  void Function(Object error, StackTrace stack)? onError,
}) =>
    CodelesslyAuthService(
      projectId: projectId,
      client: HttpAppAuthClient(baseUrl: baseUrl, client: client),
      session: FirebaseTokenSession(auth),
      env: env,
      storage: storage,
      onError: onError,
      watchRecord: firestore == null
          ? null
          : (uid) => firestore.doc('projects/$projectId/appUsers/$uid').snapshots().map((s) => s.data()),
    );

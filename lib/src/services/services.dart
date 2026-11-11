// The services a running app uses, configured by the app: one object, no
// globals. Every service has a default that works without a backend (memory,
// silence, signed out), so previews and tests need no setup; an app plugs in
// Firebase (package:codelessly_sdk/firebase.dart), the stores
// (package:codelessly_sdk/store.dart) or its own implementations.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show Json, ServiceConfig;
import 'package:flutter/foundation.dart';

import '../runtime/contracts.dart';
import 'analytics.dart';
import 'api.dart';
import 'auth.dart';
import 'cache.dart';
import 'cloud/backend.dart';
import 'cloud/database.dart';
import 'links.dart';
import 'file_exports.dart';
import 'media_export.dart';
import 'purchases.dart';
import 'printing.dart';
import '../scripting/script_runner.dart';
import 'scripts.dart';
import 'sound.dart';
import 'speech.dart';
import 'storage.dart';

export 'analytics.dart';
export 'api.dart';
export 'auth.dart';
export 'cache.dart';
export 'cloud/backend.dart';
export 'cloud/database.dart';
export 'cloud/fields.dart';
export 'cloud/query.dart';
export 'cloud/resolve.dart';
export 'links.dart';
export 'file_exports.dart';
export 'media_export.dart';
export 'media_probe.dart';
export 'purchases.dart';
export 'printing.dart';
export 'scripts.dart';
export 'sound.dart';
export 'speech.dart';
export 'storage.dart';

/// The app's services. Implements the runtime's [CodelesslyServices] seam;
/// actions and data sources reach the rest through the typed fields.
class Services implements CodelesslyServices {
  Services({
    ServiceConfig? config,
    ApiService? api,
    KeyValueCache? cache,
    FileCache? fileCache,
    LocalStorage? storage,
    AuthService? auth,
    CloudDatabase? cloud,
    CloudFileStorage? files,
    AnalyticsService? analytics,
    PurchaseService? purchases,
    this.paywalls,
    SoundService? sound,
    SpeechService? speech,
    LinkOpener? links,
    FileExporter? exports,
    ScriptRunner? scripts,
    MediaExportService? mediaExport,
    PrintService? printing,
  })  : config = config ?? ServiceConfig.empty,
        api = api ?? HttpApiService(),
        cache = cache ?? MemoryKeyValueCache(),
        fileCache = fileCache ?? MemoryFileCache(),
        storage = storage ?? MemoryLocalStorage(),
        auth = auth ?? const SignedOutAuthService(),
        cloud = cloud ?? BackendCloudDatabase(backend: MemoryDocumentBackend()),
        files = files ?? MemoryFileStorage(),
        analytics = analytics ?? (kDebugMode ? const DebugAnalytics() : const NoAnalytics()),
        purchases = purchases ?? const NoPurchaseService(),
        sound = sound ?? SoundService(),
        speech = speech ?? SpeechService(),
        links = links ?? const PlatformLinkOpener(),
        exports = exports ?? const PlatformFileExporter(),
        scripts = scripts ?? const SandboxScriptRunner(),
        mediaExport = mediaExport ?? MediaExportService(),
        printing = printing ?? const PlatformPrintService();

  /// What the publish model configures (APIs, paywall setup); the app
  /// shell sets it when a publish model loads.
  ServiceConfig config;

  /// HTTP API calls.
  final ApiService api;

  /// Cached values (publish models, auth data, paywalls).
  final KeyValueCache cache;

  /// Cached files (fonts, images).
  final FileCache fileCache;

  /// The app's values on the device (storage actions, the `storage` value).
  final LocalStorage storage;

  /// App user accounts (the `auth` value, auth actions).
  final AuthService auth;

  /// Cloud documents and queries (data-bound lists, cloud data actions).
  final CloudDatabase cloud;

  /// Cloud files (uploads).
  final CloudFileStorage files;
  final AnalyticsService analytics;

  /// Store purchases.
  final PurchaseService purchases;

  /// Server-resolved paywalls and entitlements, when the app has a paywall
  /// backend.
  final PaywallRuntime? paywalls;
  final SoundService sound;

  /// Text-to-speech (speak actions, the `speech` value).
  final SpeechService speech;

  /// Browser WebM export, or an encoder supplied by a native host.
  final MediaExportService mediaExport;
  final LinkOpener links;
  final PrintService printing;

  /// Saves generated files with the browser or platform save picker.
  final FileExporter exports;

  /// Runs scripts (run script actions): the platform's sandbox by default
  /// (no engine without package:codelessly_quickjs on a device).
  final ScriptRunner scripts;

  /// Calls the API [apiId] of [config] with input values [params] (already
  /// evaluated). Returns its response value ([ApiResponse.toValue]), 2xx or
  /// not; [onState] gets the loading state and then the result (an API's
  /// variable). Throws [ApiRequestFailed] (carrying the error value) when the
  /// request didn't complete, and a [StateError] for an unknown API.
  @override
  Future<Object?> callApi(String apiId,
      {Json params = const {}, Object? previousData, void Function(ApiResponse state)? onState}) async {
    final definition = config.apis[apiId];
    if (definition == null) {
      final error = StateError('API [$apiId] does not exist.');
      analytics.logError(error, message: 'API not found', type: 'api_not_found', context: {'apiId': apiId});
      throw error;
    }
    final response = await api.call(definition, params: params, previousData: previousData, onState: onState);
    return response.toValue();
  }

  @override
  Future<bool> openUrl(String url) => links.open(url);

  /// The `auth` value ([authValue]): the user and their profile document,
  /// now and on every change of either.
  Stream<Map<String, Object?>> watchAuth() {
    late StreamController<Map<String, Object?>> controller;
    StreamSubscription<AppUser?>? users;
    StreamSubscription<Map<String, Object?>?>? profiles;
    AppUser? user;
    var generation = 0;
    controller = StreamController(
      onListen: () {
        users = auth.userChanges.listen((u) {
          user = u;
          final currentGeneration = ++generation;
          profiles?.cancel();
          controller.add(authValue(u));
          if (u == null || u.isAnonymous) return;
          profiles = AuthProfiles.watch(cloud, u).listen(
            (profile) {
              if (currentGeneration == generation) controller.add(authValue(user, profile: profile));
            },
            onError: (Object error, StackTrace stack) =>
                analytics.logError(error, stackTrace: stack, message: 'Could not read the user profile', type: 'profile'),
          );
        }, onError: (Object error, StackTrace stack) {
          generation++;
          user = null;
          profiles?.cancel();
          profiles = null;
          controller.addError(error, stack);
        });
      },
      onCancel: () async {
        generation++;
        await profiles?.cancel();
        await users?.cancel();
      },
    );
    return controller.stream;
  }

  /// Releases what the services hold.
  Future<void> dispose() async {
    final audioClosing = sound.dispose();
    cloud.dispose();
    speech.dispose();
    mediaExport.dispose();
    paywalls?.dispose();
    await purchases.dispose();
    if (storage case final ChangeNotifier n) n.dispose();
    await audioClosing;
  }
}

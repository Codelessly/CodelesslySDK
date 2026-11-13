// Linked, Codelessly-managed components at run time (CodelesslyAPI
// DESIGN.md §4.3).
//
// A published layout carries each managed instance's snapshot: its nodes,
// built by the editor from the version it resolved, with the instance's
// settings, slots, theme tokens and events applied. When the layout loads,
// [ManagedComponentResolver] asks the component's master whether the
// instance's channel offers a newer version of the same major (a blocked
// snapshot moves to the channel's version too), fetches it, checks its
// digest and rebuilds the instance from it with the same customization.
// Anything that fails (offline, a timeout, a bad digest, an SDK too old)
// leaves the snapshot on screen.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:crypto/crypto.dart' show sha256;

import 'loader.dart';

/// This SDK's version (pubspec.yaml's): what managed component versions'
/// `minSdk` is checked against.
const String kCodelesslySdkVersion = '30.0.0';

/// Where managed component masters and versions come from
/// (`managed_components/{id}` and its `versions/{n}`): Firestore in
/// `package:codelessly_sdk/firebase.dart`
/// (FirestoreManagedComponentSource), memory in tests.
abstract interface class ManagedComponentSource {
  /// Master [id], or null when there's none.
  Future<ManagedComponentMaster?> loadMaster(String id);

  /// Version [version] of [id], or null when there's none.
  Future<ManagedComponentVersion?> loadVersion(String id, int version);
}

/// A [ManagedComponentSource] in memory, for tests and offline apps.
class MemoryManagedComponentSource implements ManagedComponentSource {
  MemoryManagedComponentSource({Map<String, ManagedComponentMaster>? masters, List<ManagedComponentVersion>? versions})
      : masters = masters ?? {},
        versions = {for (final v in versions ?? const <ManagedComponentVersion>[]) '${v.id}/${v.version}': v};

  final Map<String, ManagedComponentMaster> masters;

  /// By `"id/version"`.
  final Map<String, ManagedComponentVersion> versions;

  /// Calls made: `master:<id>`, `version:<id>/<n>`.
  final List<String> calls = [];

  /// Set to make every call fail with it.
  Object? failWith;

  /// Set to delay every call.
  Duration? delay;

  Future<void> _call(String what) async {
    calls.add(what);
    final d = delay;
    if (d != null) await Future<void>.delayed(d);
    final e = failWith;
    if (e != null) throw e;
  }

  @override
  Future<ManagedComponentMaster?> loadMaster(String id) async {
    await _call('master:$id');
    return masters[id];
  }

  @override
  Future<ManagedComponentVersion?> loadVersion(String id, int version) async {
    await _call('version:$id/$version');
    return versions['$id/$version'];
  }
}

/// A managed component version's payload doesn't match its digest.
class ManagedDigestException implements Exception {
  const ManagedDigestException(this.id, this.version);

  final String id;
  final int version;

  @override
  String toString() => 'ManagedDigestException: managed component [$id] version $version does not match its digest';
}

/// Brings a layout's managed instances to the version their channel offers
/// now (see the library comment), falling back to each instance's snapshot
/// on any failure.
///
/// Masters are fetched at most once per [masterTtl] per component and kept
/// in [cache] (an offline run uses the last one); versions are immutable,
/// so a cached one is used as is. Every fetch gives up after [timeout].
class ManagedComponentResolver {
  ManagedComponentResolver({
    required this.source,
    PublishCache? cache,
    this.timeout = const Duration(seconds: 3),
    this.masterTtl = const Duration(minutes: 5),
    this.sdkVersion = kCodelesslySdkVersion,
    DateTime Function()? clock,
    this.onError,
  })  : cache = cache ?? MemoryPublishCache(),
        _clock = clock ?? DateTime.now;

  final ManagedComponentSource source;
  final PublishCache cache;
  final Duration timeout;
  final Duration masterTtl;
  final String sdkVersion;
  final DateTime Function() _clock;

  /// Told of each failure that kept a snapshot (logging, tests).
  final void Function(String instanceId, Object error)? onError;

  final Map<String, ({DateTime at, Future<ManagedComponentMaster?> master})> _masters = {};

  static String masterKey(String id) => '$kManagedComponentsCollection/$id';
  static String versionKey(String id, int n) => '$kManagedComponentsCollection/$id/versions/$n';

  /// Forgets the fetched masters: the next [resolve] asks again.
  void refresh() => _masters.clear();

  /// [layout] with each managed instance on the version its channel offers
  /// project [projectId] now, built with the instance's customization and
  /// [theme] (the project's tokens); an instance stays on its snapshot when
  /// nothing newer applies or anything fails.
  Future<PublishLayout> resolve(PublishLayout layout, {String projectId = '', ThemeTokens? theme}) async {
    final instances = managedInstancesOf(layout.document).toList();
    if (instances.isEmpty) return layout;
    var document = layout.document;
    var variables = layout.variables;
    for (final top in instances) {
      try {
        final link = top.component!;
        final master = await _master(link.id);
        if (master == null) continue;
        final target = managedUpdateTarget(link, master, projectId: projectId, sdkVersion: sdkVersion);
        if (target == null) continue;
        final version = await _version(link.id, target);
        if (version == null) continue;
        final current = document[top.id];
        if (current == null) continue;
        final build = buildManagedInstance(
          version: version,
          topId: top.id,
          ref: current.component!.managed!,
          layout: current.layout,
          theme: theme,
          catalog: document.catalog,
        );
        document = replaceManagedInstance(document, top.id, build);
        variables = _declare(variables, _canvasOf(document, top.id), build.variables);
      } catch (e) {
        onError?.call(top.id, e);
      }
    }
    return layout.copyWith(document: document, variables: variables);
  }

  Future<ManagedComponentMaster?> _master(String id) {
    final now = _clock();
    final memo = _masters[id];
    if (memo != null && now.difference(memo.at) < masterTtl) return memo.master;
    final future = () async {
      try {
        final fresh = await source.loadMaster(id).timeout(timeout);
        if (fresh != null) await cache.write(masterKey(id), fresh.toJson());
        return fresh;
      } catch (e) {
        // Offline: the last master fetched, if any.
        final cached = await cache.read(masterKey(id));
        final master = cached == null ? null : ManagedComponentMaster.fromJson(cached, id: id);
        if (master == null) {
          _masters.remove(id);
          rethrow;
        }
        return master;
      }
    }();
    _masters[id] = (at: now, master: future);
    return future;
  }

  Future<ManagedComponentVersion?> _version(String id, int n) async {
    final key = versionKey(id, n);
    final cached = await cache.read(key);
    if (cached != null) {
      final v = ManagedComponentVersion.fromJson(cached, id: id, version: n);
      if (v != null && _digestHolds(v)) return v;
    }
    final fresh = await source.loadVersion(id, n).timeout(timeout);
    if (fresh == null) return null;
    if (!_digestHolds(fresh)) throw ManagedDigestException(id, n);
    await cache.write(key, fresh.toJson());
    return fresh;
  }

  /// Whether [v]'s stored payload has its digest (one read without a
  /// payload or a digest is taken as is).
  static bool _digestHolds(ManagedComponentVersion v) {
    final payload = v.payload;
    if (payload == null || v.digest.isEmpty) return true;
    return sha256.convert(utf8.encode(payload)).toString() == v.digest;
  }

  static String? _canvasOf(LayoutDocument document, String id) {
    var at = id;
    for (var parent = document.parentOf(at); parent != null; parent = document.parentOf(at)) {
      at = parent;
    }
    return document.roots.contains(at) ? at : null;
  }

  /// [variables] with [declared] added to canvas [canvasId] where it has no
  /// variable of that name.
  static Json _declare(Json variables, String? canvasId, List<Variable> declared) {
    if (canvasId == null || declared.isEmpty) return variables;
    final canvas = {...?readMap(variables[canvasId])};
    final names = {
      for (final v in canvas.values)
        if (Variable.fromJson(v) case final Variable x) x.name,
    };
    var changed = false;
    for (final v in declared) {
      if (names.contains(v.name)) continue;
      final id = v.id.isNotEmpty ? v.id : 'managed_${v.name}';
      canvas[id] = (v.id.isNotEmpty ? v : Variable.fromJson({...v.toJson(), 'id': id})!).toJson();
      changed = true;
    }
    return changed ? {...variables, canvasId: canvas} : variables;
  }
}

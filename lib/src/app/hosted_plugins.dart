// Loading hosted plugins: the versions a publish lists (PluginRef), read
// from the PublishCache first (offline), else from a PluginSource; checked
// against the digest the publish carries (sha256 of the stored payload) and
// the SDK version (minSdk); checked against the app's catalog
// (PluginPackage.problems); then installed as features
// (features/hosted/hosted.dart). A plugin that fails any check is skipped,
// with its reason, and its node types render as empty boxes of their size,
// its actions are skipped: what an unknown type does.
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:crypto/crypto.dart' show sha256;

import '../features/hosted/hosted.dart';
import '../runtime/actions/feature.dart';
import 'loader.dart' show PublishCache;
import 'managed_components.dart' show kCodelesslySdkVersion;

/// Where hosted plugin versions come from (`plugins/{id}/versions/{n}`).
abstract interface class PluginSource {
  /// Version [version] of plugin [id]; null when there's none.
  Future<PluginVersion?> loadPlugin(String id, int version);
}

/// A [PluginSource] over versions in memory: tests, and bundles that embed
/// the pinned payloads (a first run offline).
class MemoryPluginSource implements PluginSource {
  MemoryPluginSource(Iterable<PluginVersion> versions) : versions = {for (final v in versions) (v.id, v.version): v};

  final Map<(String, int), PluginVersion> versions;

  @override
  Future<PluginVersion?> loadPlugin(String id, int version) async => versions[(id, version)];
}

/// The sha256 hex digest of [payload]'s UTF-8 bytes: what a plugin
/// version's `digest` is.
String pluginDigest(String payload) => sha256.convert(utf8.encode(payload)).toString();

/// What loading one [PluginRef] gave.
sealed class HostedPluginLoad {
  const HostedPluginLoad(this.ref);
  final PluginRef ref;
}

/// Installed: [feature] declares and implements its types.
final class HostedPluginInstalled extends HostedPluginLoad {
  const HostedPluginInstalled(super.ref, this.package, this.feature);
  final PluginPackage package;
  final CodelesslyFeature feature;

  @override
  String toString() => 'HostedPluginInstalled(${ref.id} ${package.semver})';
}

/// Not installed, and why.
final class HostedPluginSkipped extends HostedPluginLoad {
  const HostedPluginSkipped(super.ref, this.reason);
  final String reason;

  @override
  String toString() => 'HostedPluginSkipped(${ref.id}: $reason)';
}

/// The cache key of a plugin version: `plugins/{id}/versions/{n}`.
String pluginCacheKey(String id, int version) => '$kPluginsCollection/$id/versions/$version';

/// Loads, checks and installs [refs] (a publish's [PublishModelPlugins.plugins]).
/// [host] is the app's catalog (the runner's, without plugins); [allowed]
/// the capabilities the app lets plugins use (null: any). Never throws.
Future<List<HostedPluginLoad>> loadHostedPlugins(
  List<PluginRef> refs, {
  required PluginSource source,
  required Catalog host,
  PublishCache? cache,
  String sdkVersion = kCodelesslySdkVersion,
  Set<String>? allowed,
}) async => [
      for (final ref in refs) await _load(ref, source, host, cache, sdkVersion, allowed),
    ];

Future<HostedPluginLoad> _load(
    PluginRef ref, PluginSource source, Catalog host, PublishCache? cache, String sdkVersion, Set<String>? allowed) async {
  final key = pluginCacheKey(ref.id, ref.version);
  bool verified(PluginVersion v) =>
      (ref.digest.isEmpty || pluginDigest(v.payload) == ref.digest) && (v.digest.isEmpty || pluginDigest(v.payload) == v.digest);
  PluginVersion? version;
  try {
    final cached = await cache?.read(key);
    final v = cached == null ? null : PluginVersion.fromJson(cached);
    if (v != null && verified(v)) version = v;
  } catch (_) {}
  if (version == null) {
    PluginVersion? fetched;
    try {
      fetched = await source.loadPlugin(ref.id, ref.version);
    } catch (e) {
      return HostedPluginSkipped(ref, 'it could not be loaded: $e');
    }
    if (fetched == null) return HostedPluginSkipped(ref, 'version ${ref.version} does not exist');
    if (!verified(fetched)) {
      return HostedPluginSkipped(ref, 'its payload does not match its digest (${ref.digest.isEmpty ? fetched.digest : ref.digest})');
    }
    version = fetched;
    try {
      await cache?.write(key, version.toJson());
    } catch (_) {}
  }
  if (!sdkSatisfies(sdkVersion, version.minSdk)) {
    return HostedPluginSkipped(ref, 'it needs SDK ${version.minSdk} or newer (this is $sdkVersion)');
  }
  final package = version.package;
  if (package == null) return HostedPluginSkipped(ref, 'its payload is not a plugin package');
  final problems = package.problems(host, allowed: allowed);
  if (problems.isNotEmpty) return HostedPluginSkipped(ref, problems.join('; '));
  return HostedPluginInstalled(ref, package, hostedPluginFeature(package, host: host));
}

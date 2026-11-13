// Where published data comes from: a loader interface with network, asset
// and in-memory implementations, and a cache interface. Firebase plugs in as
// another [PublishLoader] (FirestorePublishLoader in
// package:codelessly_sdk/firebase.dart, the default of a Firebase app); the
// core has no backend dependency.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show GZipDecoder;
import 'package:codelessly_api/codelessly_api.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;

import 'hosted_plugins.dart' show PluginSource;

/// Loading published data failed.
class PublishLoadException implements Exception {
  const PublishLoadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'PublishLoadException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Loads a project's publish model, its layouts and its components from
/// [PublishSource]s.
abstract interface class PublishLoader {
  /// The project's publish model.
  Future<PublishModel> loadModel(PublishSource source);

  /// Layout [layoutId] (a layout id the model lists).
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId);

  /// Component [type] (a type name the model's `components` lists): the
  /// definition stored at [PublishSource.componentPath]. Throws a
  /// [PublishLoadException] when there is none.
  Future<PublishComponent> loadComponent(PublishSource source, String type);
}

/// A [PublishLoader] that also watches the publish model: each publish (or
/// preview save) arrives as a new model, as the
/// `publish/{projectId}` document changes. [Codelessly] follows it while
/// [CodelesslyConfig.liveUpdates] is on: layouts republished since are
/// dropped and load again when shown; components republished since (their
/// entry's digest changed) load again at once and every instance on screen
/// updates in place.
abstract interface class LivePublishLoader implements PublishLoader {
  /// The project's publish model, now and on every change.
  Stream<PublishModel> watchModel(PublishSource source);
}

/// The stored-document marker of publish data (`schema`): a document at a
/// publish path without it is in an older format, which this SDK can't
/// read. Schemas 2 (what published apps hold), 3 and 4 load; a schema-2 or
/// schema-3 document is migrated to 4 in memory when it decodes
/// (`migrate2to3`, `migrate3to4`), never written back.
const String kStoredSchemaField = 'schema';

/// The stored schemas this SDK loads: 2 and 3 (migrated in memory) and 4.
const Set<int> kLoadableSchemas = {2, 3, kSchemaVersion};

/// Where a stored layout too large for one Firestore document keeps its
/// nodes: `{"nodes": {...}}` (and any field Firestore couldn't store as it
/// was) as JSON, gzipped, base64 encoded. Written by the editor's publish
/// (the editor's page storage, `encodeStoredLayout`).
const String kCompressedNodesField = 'compressedNodes';

/// Throws unless [data] (a stored publish document) is in the current format.
void _requireCurrentFormat(Map<String, Object?> data, String what) {
  final schema = data[kStoredSchemaField];
  if (schema is num && kLoadableSchemas.contains(schema.toInt())) return;
  if (schema is num && schema.toInt() > kSchemaVersion) {
    throw PublishLoadException('$what is in schema ${schema.toInt()}, newer than this SDK reads (2, 3 and 4). '
        'Update codelessly_sdk.');
  }
  throw PublishLoadException('$what is not in the current format (no "schema": 2, 3 or 4). Publish the project '
      'again from the Codelessly Editor.');
}

/// A stored publish model document ([PublishSource.modelPath]) as a
/// [PublishModel]: current format only (see [kStoredSchemaField]). [projectId] fills an
/// empty `projectId`.
PublishModel decodeStoredPublishModel(Map<String, Object?> data, {String? projectId}) {
  if (data.isEmpty) throw PublishLoadException('No publish model${projectId == null ? '' : ' for project [$projectId]'}');
  _requireCurrentFormat(data, 'The publish model${projectId == null ? '' : ' of project [$projectId]'}');
  final model = PublishModel.fromJson(data);
  return model.projectId.isEmpty && projectId != null ? PublishModel.fromJson({...data, 'projectId': projectId}) : model;
}

/// [stored] (a layout document) with its [kCompressedNodesField] expanded
/// into `nodes`: `PublishLayout` JSON.
Map<String, Object?> expandStoredLayout(Map<String, Object?> stored) {
  final zipped = stored[kCompressedNodesField];
  if (zipped is! String) return stored;
  final Object? unzipped;
  try {
    unzipped = decodeJsonBytes(base64Decode(zipped));
  } catch (e) {
    throw PublishLoadException('Layout [${stored['id']}] has unreadable compressed nodes', e);
  }
  // The blob holds the nodes, and any other field Firestore couldn't store
  // as it was (arrays inside arrays): every field of it comes back.
  return {
    for (final e in stored.entries)
      if (e.key != kCompressedNodesField) e.key: e.value,
    if (unzipped is Map) ...unzipped.cast<String, Object?>() else 'nodes': null,
  };
}

/// A stored layout document ([PublishSource.layoutPath]) as a
/// [PublishLayout]: current format only, compressed nodes expanded. [layoutId] (the
/// document's id) fills a missing `id`.
PublishLayout decodeStoredPublishLayout(Map<String, Object?> data, {String? layoutId}) {
  if (data.isEmpty) throw PublishLoadException('Layout [${layoutId ?? '?'}] does not exist');
  _requireCurrentFormat(data, 'Layout [${layoutId ?? data['id']}]');
  final json = expandStoredLayout(data);
  final id = json['id'];
  return PublishLayout.fromJson(id is String && id.isNotEmpty || layoutId == null ? json : {...json, 'id': layoutId},
      catalog: standardCatalog);
}

/// Where a stored component too large for one Firestore document keeps its
/// document: its JSON, gzipped, base64 encoded (as [kCompressedNodesField]
/// keeps a layout's nodes).
const String kCompressedDocumentField = 'compressedDocument';

/// A stored component document ([PublishSource.componentPath]) as a
/// [PublishComponent]: current format only, a compressed document expanded,
/// its document decoded with [catalog] (default: the standard catalog).
/// [type] (the document's id) fills a missing `id`. Throws a
/// [PublishLoadException] when it isn't a component definition.
PublishComponent decodeStoredPublishComponent(Map<String, Object?> data, {String? type, Catalog? catalog}) {
  if (data.isEmpty) throw PublishLoadException('Component [${type ?? '?'}] does not exist');
  _requireCurrentFormat(data, 'Component [${type ?? data['id']}]');
  var json = data;
  final zipped = data[kCompressedDocumentField];
  if (zipped is String) {
    try {
      json = {
        for (final e in data.entries)
          if (e.key != kCompressedDocumentField) e.key: e.value,
        'document': decodeJsonBytes(base64Decode(zipped)),
      };
    } catch (e) {
      throw PublishLoadException('Component [${type ?? data['id']}] has an unreadable compressed document', e);
    }
  }
  final component = PublishComponent.fromJson(json, catalog: catalog ?? standardCatalog, id: type);
  if (!component.isComponent) {
    throw PublishLoadException('Component [${component.id}] is not a component definition (one root and a "widget" declaration)');
  }
  return component;
}

/// The sha256 hex digest of [component]'s document ([PublishComponent.digestInput]):
/// what its `digest` is, set by the publish that wrote it.
String componentDigest(PublishComponent component) => sha256.convert(utf8.encode(component.digestInput)).toString();

/// Whether [component] is what its publisher wrote: its digest (when it
/// carries one) is its document's.
bool componentIntact(PublishComponent component) => component.digest.isEmpty || componentDigest(component) == component.digest;

/// Version [version] of plugin [id], as [bundle] embeds it; null when it
/// doesn't.
PluginVersion? _bundledPlugin(PublishBundle bundle, String id, int version) {
  for (final v in bundle.pluginVersions) {
    if (v.id == id && v.version == version) return v;
  }
  return null;
}

/// Component [type] of [bundle], or a [PublishLoadException] naming [where].
PublishComponent _bundled(PublishBundle bundle, String type, String where) {
  final c = bundle.components[type];
  if (c == null) throw PublishLoadException('Component [$type] is not in $where');
  return c;
}

/// A [PublishLoader] over bundles in memory: tests, previews, and apps that
/// ship their layouts. [bundles] holds one bundle per source; a source
/// without one uses [PublishSource.publish]'s.
class MemoryPublishLoader implements PublishLoader, PluginSource {
  MemoryPublishLoader(PublishBundle bundle, {Map<PublishSource, PublishBundle> others = const {}})
      : bundles = {PublishSource.publish: bundle, ...others};

  final Map<PublishSource, PublishBundle> bundles;

  /// Calls made, for tests: `model:<source>`, `layout:<source>:<id>` and
  /// `component:<source>:<type>`.
  final List<String> calls = [];

  PublishBundle _bundle(PublishSource source) => bundles[source] ?? bundles[PublishSource.publish]!;

  @override
  Future<PublishModel> loadModel(PublishSource source) async {
    calls.add('model:${source.name}');
    return _bundle(source).model;
  }

  @override
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId) async {
    calls.add('layout:${source.name}:$layoutId');
    final layout = _bundle(source).layouts[layoutId];
    if (layout == null) throw PublishLoadException('Layout [$layoutId] is not in the bundle');
    return layout;
  }

  @override
  Future<PublishComponent> loadComponent(PublishSource source, String type) async {
    calls.add('component:${source.name}:$type');
    return _bundled(_bundle(source), type, 'the bundle');
  }

  /// The plugin versions the publish bundle embeds.
  @override
  Future<PluginVersion?> loadPlugin(String id, int version) async {
    calls.add('plugin:$id:$version');
    return _bundledPlugin(_bundle(PublishSource.publish), id, version);
  }
}

/// Decodes a bundle file: JSON, gzipped or not.
PublishBundle decodeBundle(List<int> bytes) => decodeBundleJson(decodeJsonBytes(bytes));

/// A bundle's JSON as a [PublishBundle]. A bundle (or its model) in a schema
/// newer than this SDK reads is refused, as a stored document is.
PublishBundle decodeBundleJson(Object? json) {
  if (json is Map) {
    final model = json['model'];
    for (final schema in [json[kStoredSchemaField], if (model is Map) model[kStoredSchemaField]]) {
      if (schema is num && schema.toInt() > kSchemaVersion) {
        throw PublishLoadException('The bundle is in schema ${schema.toInt()}, newer than this SDK reads (2, 3 and 4). '
            'Update codelessly_sdk.');
      }
    }
  }
  return PublishBundle.fromJson(json, catalog: standardCatalog);
}

/// [bytes] as JSON, gunzipped first when they're gzipped.
Object? decodeJsonBytes(List<int> bytes) {
  final gzipped = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  final raw = gzipped ? const GZipDecoder().decodeBytes(bytes) : bytes;
  return jsonDecode(utf8.decode(raw));
}

/// A [PublishLoader] over a bundle shipped as an asset (`.json` or
/// `.json.gz`): runs offline. Loaded once.
class AssetPublishLoader implements PublishLoader, PluginSource {
  AssetPublishLoader(this.asset, {AssetBundle? bundle}) : _assets = bundle;

  final String asset;
  final AssetBundle? _assets;
  Future<PublishBundle>? _bundle;

  Future<PublishBundle> get bundle => _bundle ??= () async {
        try {
          final data = await (_assets ?? rootBundle).load(asset);
          return decodeBundle(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        } catch (e) {
          _bundle = null;
          throw PublishLoadException('Could not load bundle asset [$asset]', e);
        }
      }();

  @override
  Future<PublishModel> loadModel(PublishSource source) async => (await bundle).model;

  @override
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId) async {
    final layout = (await bundle).layouts[layoutId];
    if (layout == null) throw PublishLoadException('Layout [$layoutId] is not in [$asset]');
    return layout;
  }

  @override
  Future<PublishComponent> loadComponent(PublishSource source, String type) async => _bundled(await bundle, type, '[$asset]');

  /// The plugin versions the bundle embeds.
  @override
  Future<PluginVersion?> loadPlugin(String id, int version) async => _bundledPlugin(await bundle, id, version);
}

/// A [PublishLoader] over HTTP. With [bundle] set (a slug), the whole
/// publish is one file ([PublishSource.bundlePath], `publish/{slug}.json`
/// in Codelessly's storage bucket), its components in its `components` map:
/// what a project's slug serves. Without it, the publish model, each layout
/// and each component are JSON files under [baseUrl] at the publish paths
/// ([PublishSource.modelPath], [PublishSource.layoutPath],
/// [PublishSource.componentPath], with `.json`):
/// for a self-hosted mirror; Codelessly itself keeps them in Firestore
/// (FirestorePublishLoader).
///
/// [urlFor] maps a storage path to a URL; the default joins it to
/// [baseUrl] (a Firebase Storage bucket's `.../o/` endpoint encodes the
/// path, see [HttpPublishLoader.firebaseStorage]).
class HttpPublishLoader implements PublishLoader, PluginSource {
  HttpPublishLoader({
    required this.projectId,
    this.baseUrl = '',
    this.bundle = false,
    Uri Function(String path)? urlFor,
    http.Client? client,
    this.headers = const {},
  // ignore: prefer_initializing_formals
  })  : _urlFor = urlFor,
        // ignore: prefer_initializing_formals
        _client = client;

  /// Files in a Firebase Storage [bucket] (`<project>.appspot.com`).
  factory HttpPublishLoader.firebaseStorage({
    required String projectId,
    required String bucket,
    bool bundle = false,
    http.Client? client,
  }) =>
      HttpPublishLoader(
        projectId: projectId,
        bundle: bundle,
        client: client,
        urlFor: (path) => Uri.parse(
            'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(path)}?alt=media'),
      );

  /// The project id, or the slug for a [bundle].
  final String projectId;
  final String baseUrl;
  final bool bundle;
  final Map<String, String> headers;
  final Uri Function(String path)? _urlFor;
  final http.Client? _client;
  final Map<PublishSource, Future<PublishBundle>> _bundles = {};

  Uri urlFor(String path) {
    final f = _urlFor;
    if (f != null) return f(path);
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse('$base$path');
  }

  Future<Object?> _get(String path) async {
    final url = urlFor(path);
    final client = _client ?? http.Client();
    try {
      final res = await client.get(url, headers: headers);
      if (res.statusCode != 200) throw PublishLoadException('GET $url: ${res.statusCode}');
      return decodeJsonBytes(res.bodyBytes);
    } on PublishLoadException {
      rethrow;
    } catch (e) {
      throw PublishLoadException('GET $url failed', e);
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<PublishBundle> _bundle(PublishSource source) => _bundles[source] ??= () async {
        try {
          return decodeBundleJson(await _get(source.bundlePath(projectId)));
        } catch (_) {
          _bundles.remove(source);
          rethrow;
        }
      }();

  @override
  Future<PublishModel> loadModel(PublishSource source) async {
    if (bundle) return (await _bundle(source)).model;
    return PublishModel.fromJson(await _get('${source.modelPath(projectId)}.json'));
  }

  @override
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId) async {
    if (bundle) {
      final layout = (await _bundle(source)).layouts[layoutId];
      if (layout == null) throw PublishLoadException('Layout [$layoutId] is not in the bundle');
      return layout;
    }
    return PublishLayout.fromJson(await _get('${source.layoutPath(projectId, layoutId)}.json'), catalog: standardCatalog);
  }

  @override
  Future<PublishComponent> loadComponent(PublishSource source, String type) async {
    if (bundle) return _bundled(await _bundle(source), type, 'the bundle');
    final json = await _get('${source.componentPath(projectId, type)}.json');
    if (json is! Map) throw PublishLoadException('Component [$type] is not a JSON object');
    return decodeStoredPublishComponent(json.cast<String, Object?>(), type: type);
  }

  /// A [bundle]'s embedded version, else `plugins/{id}/versions/{n}.json`
  /// under [baseUrl] (null when there is none).
  @override
  Future<PluginVersion?> loadPlugin(String id, int version) async {
    if (bundle) {
      final embedded = _bundledPlugin(await _bundle(PublishSource.publish), id, version);
      if (embedded != null) return embedded;
    }
    try {
      return PluginVersion.fromJson(await _get('$kPluginsCollection/$id/versions/$version.json'), id: id, version: version);
    } on PublishLoadException {
      return null;
    }
  }
}

/// Stores published JSON between runs, so an app opens on its last publish
/// and works offline. Keys are storage paths ([PublishSource.modelPath],
/// [PublishSource.layoutPath], [PublishSource.componentPath]...).
abstract interface class PublishCache {
  Future<Json?> read(String key);
  Future<void> write(String key, Json value);
  Future<void> clear();
}

/// A [PublishCache] in memory: for one run (the default) and tests.
class MemoryPublishCache implements PublishCache {
  final Map<String, Json> entries = {};

  @override
  Future<Json?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, Json value) async => entries[key] = value;

  @override
  Future<void> clear() async => entries.clear();
}

/// Bytes of [data] (from an asset or a response) as a list.
Uint8List bytesOf(ByteData data) => data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

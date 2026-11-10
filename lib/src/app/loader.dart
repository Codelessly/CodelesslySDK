// Where published data comes from: a loader interface with network, asset
// and in-memory implementations, and a cache interface. Firebase plugs in as
// another [PublishLoader] (FirestorePublishLoader in
// package:codelessly_sdk/firebase.dart, the default of a Firebase app); the
// core has no backend dependency.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show GZipDecoder;
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;

/// Loading published data failed.
class PublishLoadException implements Exception {
  const PublishLoadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'PublishLoadException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Loads a project's publish model and its layouts from [PublishSource]s.
abstract interface class PublishLoader {
  /// The project's publish model.
  Future<PublishModel> loadModel(PublishSource source);

  /// Layout [layoutId] (a layout id the model lists).
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId);
}

/// A [PublishLoader] that also watches the publish model: each publish (or
/// preview save) arrives as a new model, as SDK 8.x streamed
/// `publish/{projectId}`. [Codelessly] follows it while
/// [CodelesslyConfig.liveUpdates] is on: layouts republished since are
/// dropped and load again when shown.
abstract interface class LivePublishLoader implements PublishLoader {
  /// The project's publish model, now and on every change.
  Stream<PublishModel> watchModel(PublishSource source);
}

/// The stored-document marker of publish data (`schema: 2`): a document
/// at a publish path without it is 10.x, written by the classic editor or SDK
/// 8.x's publish, which this SDK can't read.
const String kStoredSchemaField = 'schema';

/// Where a stored layout too large for one Firestore document keeps its
/// nodes: `{"nodes": {...}}` as JSON, gzipped, base64 encoded (as 10.x kept
/// `compressedCanvases`). Written by the editor's publish
/// (the editor's page storage, `encodeStoredLayout`).
const String kCompressedNodesField = 'compressedNodes';

/// Throws unless [data] (a stored publish document) is in the current format.
void _requireCurrentFormat(Map<String, Object?> data, String what) {
  final schema = data[kStoredSchemaField];
  if (schema is num && schema.toInt() >= 2) return;
  throw PublishLoadException('$what is not in the current format (no "schema": 2): SDK 21 reads that format '
      'only. Publish the '
      'project again from the Codelessly Editor.');
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
  return {
    for (final e in stored.entries)
      if (e.key != kCompressedNodesField) e.key: e.value,
    'nodes': unzipped is Map ? unzipped['nodes'] : null,
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
  return PublishLayout.fromJson(id is String && id.isNotEmpty || layoutId == null ? json : {...json, 'id': layoutId});
}

/// A [PublishLoader] over bundles in memory: tests, previews, and apps that
/// ship their layouts. [bundles] holds one bundle per source; a source
/// without one uses [PublishSource.publish]'s.
class MemoryPublishLoader implements PublishLoader {
  MemoryPublishLoader(PublishBundle bundle, {Map<PublishSource, PublishBundle> others = const {}})
      : bundles = {PublishSource.publish: bundle, ...others};

  final Map<PublishSource, PublishBundle> bundles;

  /// Calls made, for tests: `model:<source>` and `layout:<source>:<id>`.
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
}

/// Decodes a bundle file: JSON, gzipped or not.
PublishBundle decodeBundle(List<int> bytes) => PublishBundle.fromJson(decodeJsonBytes(bytes));

/// [bytes] as JSON, gunzipped first when they're gzipped.
Object? decodeJsonBytes(List<int> bytes) {
  final gzipped = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  final raw = gzipped ? const GZipDecoder().decodeBytes(bytes) : bytes;
  return jsonDecode(utf8.decode(raw));
}

/// A [PublishLoader] over a bundle shipped as an asset (`.json` or
/// `.json.gz`): runs offline. Loaded once.
class AssetPublishLoader implements PublishLoader {
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
}

/// A [PublishLoader] over HTTP. With [bundle] set (a slug), the whole
/// publish is one file ([PublishSource.bundlePath], `publish/{slug}.json`
/// in Codelessly's storage bucket): what a project's slug serves, as SDK
/// 8.x's `downloadCompletePublishBundle`. Without it, the publish model and
/// each layout are JSON files under [baseUrl] at the publish paths
/// ([PublishSource.modelPath], [PublishSource.layoutPath], with `.json`):
/// for a self-hosted mirror; Codelessly itself keeps them in Firestore
/// (FirestorePublishLoader).
///
/// [urlFor] maps a storage path to a URL; the default joins it to
/// [baseUrl] (a Firebase Storage bucket's `.../o/` endpoint encodes the
/// path, see [HttpPublishLoader.firebaseStorage]).
class HttpPublishLoader implements PublishLoader {
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
          return PublishBundle.fromJson(await _get(source.bundlePath(projectId)));
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
    return PublishLayout.fromJson(await _get('${source.layoutPath(projectId, layoutId)}.json'));
  }
}

/// Stores published JSON between runs, so an app opens on its last publish
/// and works offline. Keys are storage paths ([PublishSource.modelPath]...).
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

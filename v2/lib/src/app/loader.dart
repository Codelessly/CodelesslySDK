// Where published data comes from: a loader interface with network, asset
// and in-memory implementations, and a cache interface. Firebase (or any
// backend) plugs in as another [PublishLoader]; the core has no backend
// dependency.
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

/// A [PublishLoader] over HTTP: the publish model and each layout as JSON
/// files under [baseUrl], at the v2 storage paths ([PublishSource.modelPath],
/// [PublishSource.layoutPath], with `.json`). With [bundle] set, the whole
/// publish comes from one file ([PublishSource.bundlePath]) instead: what a
/// project's slug serves.
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

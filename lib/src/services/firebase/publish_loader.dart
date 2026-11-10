// Published apps on Cloud Firestore: the publish model and its layouts at
// the publish paths, in the current format the editor's publish writes (`schema: 2`; a large layout's nodes gzipped in `compressedNodes`).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';

import '../../app/loader.dart';
import '../auth.dart';

/// A [LivePublishLoader] on Cloud Firestore: the publish model is the
/// document [PublishSource.modelPath] (`publish/{projectId}`;
/// `publish_preview/...` for the editor's preview), each layout
/// [PublishSource.layoutPath] (`.../layouts/{layoutId}`). [watchModel]
/// follows the model document.
///
/// The project is [projectId], else the one [auth] grants access to: the
/// app's project token ([CodelesslyConfig.authToken]) resolves to its
/// project through the Codelessly backend ([FirebaseProjectAuth]), whose
/// claim the security rules of the publish paths check. [auth]
/// authenticates before the first read. A template project (its access says
/// so) reads [PublishSource.template] whatever source is asked.
///
/// A document not in the current format fails with a [PublishLoadException]
/// saying so.
class FirestorePublishLoader implements LivePublishLoader {
  FirestorePublishLoader(this.firestore, {this.projectId, this.auth})
      : assert(projectId != null || auth != null, 'A project id or a ProjectAuth is needed');

  final FirebaseFirestore firestore;

  /// The project, when known up front; else [auth]'s.
  final String? projectId;

  /// Authenticates the app with its project (and names it).
  final ProjectAuth? auth;

  Future<ProjectAccess?>? _authenticating;

  Future<({String projectId, PublishSource source})> _target(PublishSource source) async {
    final a = auth;
    ProjectAccess? access = a?.access;
    if (a != null && access == null) {
      try {
        access = await (_authenticating ??= a.authenticate());
      } catch (e) {
        _authenticating = null;
        throw PublishLoadException('Could not authenticate the project token', e);
      }
    }
    final id = projectId ?? access?.projectId;
    if (id == null || id.isEmpty) throw const PublishLoadException('No project: the project token named none');
    return (projectId: id, source: access?.isTemplate == true ? PublishSource.template : source);
  }

  @override
  Future<PublishModel> loadModel(PublishSource source) async {
    final t = await _target(source);
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await firestore.doc(t.source.modelPath(t.projectId)).get();
    } catch (e) {
      throw PublishLoadException('Could not read ${t.source.modelPath(t.projectId)}', e);
    }
    return _model(snapshot, t.projectId, t.source);
  }

  @override
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId) async {
    final t = await _target(source);
    final path = t.source.layoutPath(t.projectId, layoutId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await firestore.doc(path).get();
    } catch (e) {
      throw PublishLoadException('Could not read $path', e);
    }
    final data = snapshot.data();
    if (!snapshot.exists || data == null) throw PublishLoadException('Layout [$layoutId] does not exist ($path)');
    return decodeStoredPublishLayout(storedJson(data), layoutId: snapshot.id);
  }

  @override
  Stream<PublishModel> watchModel(PublishSource source) async* {
    final t = await _target(source);
    yield* firestore
        .doc(t.source.modelPath(t.projectId))
        .snapshots()
        .where((s) => s.exists && (s.data()?.isNotEmpty ?? false))
        .map((s) => _model(s, t.projectId, t.source));
  }

  PublishModel _model(DocumentSnapshot<Map<String, dynamic>> snapshot, String projectId, PublishSource source) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null || data.isEmpty) {
      throw PublishLoadException('Project [$projectId] has nothing published (${source.modelPath(projectId)})');
    }
    return decodeStoredPublishModel(storedJson(data), projectId: projectId);
  }
}

/// A Firestore document's data as plain JSON: timestamps as milliseconds
/// since the epoch (what the publish JSON stores), blobs as bytes,
/// references as their path.
Map<String, Object?> storedJson(Map<String, Object?> data) => {for (final e in data.entries) e.key: _plain(e.value)};

Object? _plain(Object? v) => switch (v) {
      Timestamp() => v.millisecondsSinceEpoch,
      DateTime() => v.millisecondsSinceEpoch,
      Blob() => v.bytes,
      DocumentReference() => v.path,
      GeoPoint() => {'latitude': v.latitude, 'longitude': v.longitude},
      Map() => {for (final e in v.entries) '${e.key}': _plain(e.value)},
      List() => [for (final x in v) _plain(x)],
      _ => v,
    };

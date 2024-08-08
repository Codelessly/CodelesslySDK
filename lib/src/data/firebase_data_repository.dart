import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../codelessly_sdk.dart';

/// Handles the data flow of [SDKPublishModel] from the server.
class FirebaseDataRepository extends NetworkDataRepository {
  /// The firestore instance to fetch the published model from.
  final FirebaseFirestore firestore;

  /// Creates a new [FirebaseDataRepository] instance with the given [firestore]
  /// instance.
  FirebaseDataRepository({
    required this.firestore,
    required super.config,
    required super.tracker,
  });

  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required PublishSource source,
  }) {
    final publishModelDoc =
        firestore.collection(source.serverPath).doc(projectID);

    return publishModelDoc.snapshots().map((event) {
      tracker.trackRead();

      final Map<String, dynamic>? data = event.data();
      if (data == null || data.isEmpty) {
        throw CodelesslyException(
            'Failed to stream publish model for [$projectID] with source [${source.name}].');
      }
      final SDKPublishModel model = SDKPublishModel.fromJson(
        {...data, 'id': event.id},
      );
      return model;
    });
  }

  @override
  Future<SDKPublishLayout?> downloadLayoutModel({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) async {
    final layoutDoc = firestore
        .collection(source.serverPath)
        .doc(projectID)
        .collection('layouts')
        .doc(layoutID);

    return layoutDoc.get().then((value) {
      tracker.trackRead();

      final Map<String, dynamic> data = value.data() ?? {};

      // Layout does not exist or there's a network error.
      if (data.isEmpty) {
        throw CodelesslyException('Failed to download layout [$layoutID].');
      }

      final SDKPublishLayout layout = SDKPublishLayout.fromJson(
        {...data, 'id': value.id},
      );
      return layout;
    });
  }

  @override
  Future<SDKPublishFont?> downloadFontModel({
    required String projectID,
    required String fontID,
    required PublishSource source,
  }) {
    final fontDoc = firestore
        .collection(source.serverPath)
        .doc(projectID)
        .collection('fonts')
        .doc(fontID);

    return fontDoc.get().then((value) {
      tracker.trackRead();

      final Map<String, dynamic> data = value.data() ?? {};

      // Font does not exist or there's a network error.
      if (data.isEmpty) {
        throw CodelesslyException('Failed to download font [$fontID].');
      }

      final SDKPublishFont font = SDKPublishFont.fromJson(
        {...data, 'id': value.id},
      );
      return font;
    });
  }

  @override
  Future<HttpApiData?> downloadApi({
    required String projectID,
    required String apiId,
    required PublishSource source,
  }) {
    final apiDoc = firestore
        .collection(source.serverPath)
        .doc(projectID)
        .collection('apis')
        .doc(apiId);

    return apiDoc.get().then((value) {
      tracker.trackRead();

      final Map<String, dynamic> data = value.data() ?? {};

      // Api does not exist or there's a network error.
      if (data.isEmpty) {
        throw CodelesslyException('Failed to download api [$apiId].');
      }

      final HttpApiData api = HttpApiData.fromJson(
        {...data, 'id': value.id},
      );
      return api;
    });
  }

  @override
  Future<SDKLayoutVariables?> downloadLayoutVariables({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) {
    final variablesDoc = firestore
        .collection(source.serverPath)
        .doc(projectID)
        .collection('variables')
        .doc(layoutID);

    return variablesDoc.get().then((value) {
      tracker.trackRead();

      final Map<String, dynamic> data = value.data() ?? {};

      // Variables do not exist or there's a network error.
      if (data.isEmpty) {
        throw CodelesslyException(
            'Failed to download variables for layout/canvas [$layoutID].');
      }

      final SDKLayoutVariables layoutVariables = SDKLayoutVariables.fromJson(
        {...data, 'id': value.id},
      );
      return layoutVariables;
    });
  }

  @override
  Future<SDKLayoutConditions?> downloadLayoutConditions({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) {
    final conditionsDoc = firestore
        .collection(source.serverPath)
        .doc(projectID)
        .collection('conditions')
        .doc(layoutID);

    return conditionsDoc.get().then((value) {
      tracker.trackRead();

      final Map<String, dynamic> data = value.data() ?? {};

      // Conditions do not exist or there's a network error.
      if (data.isEmpty) {
        throw CodelesslyException(
            'Failed to download conditions for canvas/layout [$layoutID].');
      }

      final SDKLayoutConditions layoutConditions = SDKLayoutConditions.fromJson(
        {...data, 'id': value.id},
      );
      return layoutConditions;
    });
  }
}

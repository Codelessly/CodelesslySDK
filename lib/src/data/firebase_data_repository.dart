import 'dart:async';

import '../../codelessly_sdk.dart';
import '../../firedart.dart';

/// Handles the data flow of [SDKPublishModel] from the server.
class FirebaseDataRepository extends NetworkDataRepository {
  /// The firestore instance to fetch the published model from.
  final Firestore firestore;

  /// Creates a new [FirebaseDataRepository] instance with the given [firestore]
  /// instance.
  FirebaseDataRepository({required this.firestore});

  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required PublishSource source,
  }) {
    final DocumentReference publishModelDoc =
        firestore.collection(source.serverPath).document(projectID);

    return publishModelDoc.stream.map((event) {
      final Map<String, dynamic>? data = event?.map;
      if (data == null) {
        return null;
      }
      final SDKPublishModel model = SDKPublishModel.fromJson(
        {...data, 'id': event?.id},
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
    final DocumentReference layoutDoc = firestore
        .collection(source.serverPath)
        .document(projectID)
        .collection('layouts')
        .document(layoutID);

    return layoutDoc.get().then((value) {
      final Map<String, dynamic> data = value.map;
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
    final DocumentReference fontDoc = firestore
        .collection(source.serverPath)
        .document(projectID)
        .collection('fonts')
        .document(fontID);

    return fontDoc.get().then((value) {
      final Map<String, dynamic> data = value.map;
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
    final DocumentReference apiDoc = firestore
        .collection(source.serverPath)
        .document(projectID)
        .collection('apis')
        .document(apiId);

    return apiDoc.get().then((value) {
      final Map<String, dynamic> data = value.map;
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
    final DocumentReference variablesDoc = firestore
        .collection(source.serverPath)
        .document(projectID)
        .collection('variables')
        .document(layoutID);

    return variablesDoc.get().then((value) {
      final Map<String, dynamic> data = value.map;
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
    final DocumentReference conditionsDoc = firestore
        .collection(source.serverPath)
        .document(projectID)
        .collection('conditions')
        .document(layoutID);

    return conditionsDoc.get().then((value) {
      final Map<String, dynamic> data = value.map;
      final SDKLayoutConditions layoutConditions = SDKLayoutConditions.fromJson(
        {...data, 'id': value.id},
      );
      return layoutConditions;
    });
  }
}

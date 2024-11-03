import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../codelessly_sdk.dart';
import '../logging/error_logger.dart';

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
      tracker.trackRead('${source.serverPath}/streamPublishModel');

      final Map<String, dynamic>? data = event.data();
      if (data == null || data.isEmpty) {
        ErrorLogger.instance.captureException(
          'No data found',
          message:
              'Failed to stream publish model for [$projectID] with source [${source.name}]',
          type: 'publish_model_stream_failed',
          layoutID: projectID,
        );
        return null;
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
      if (!value.exists) {
        ErrorLogger.instance.captureException(
          'Layout not found',
          message: 'Layout [$layoutID] does not exist',
          type: 'layout_not_found',
          layoutID: layoutID,
        );
        return null;
      }
      tracker.trackRead('${source.serverPath}/downloadLayoutModel');

      final Map<String, dynamic> data = value.data() ?? {};

      // Layout does not exist or there's a network error.
      if (data.isEmpty) {
        ErrorLogger.instance.captureException(
          'No data found',
          message: 'Failed to download layout [$layoutID], no data found',
          type: 'layout_download_failed',
          layoutID: layoutID,
        );
        return null;
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
      tracker.trackRead('${source.serverPath}/downloadFontModel');

      final Map<String, dynamic> data = value.data() ?? {};

      // Font does not exist or there's a network error.
      if (data.isEmpty) {
        ErrorLogger.instance.captureException(
          'No data found',
          message: 'Failed to download font [$fontID]',
          type: 'font_download_failed',
        );
        return null;
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
      tracker.trackRead('${source.serverPath}/downloadApi');

      final Map<String, dynamic> data = value.data() ?? {};

      // Api does not exist or there's a network error.
      if (data.isEmpty) {
        ErrorLogger.instance.captureException(
          'No data found',
          message: 'Failed to download api [$apiId]',
          type: 'api_download_failed',
        );
        return null;
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
      tracker.trackRead('${source.serverPath}/downloadLayoutVariables');

      final Map<String, dynamic> data = value.data() ?? {};

      // Variables do not exist or there's a network error.
      if (data.isEmpty) {
        ErrorLogger.instance.captureException(
          'No data found',
          message: 'Failed to download variables for layout/canvas [$layoutID]',
          type: 'variables_download_failed',
          layoutID: layoutID,
        );
        return null;
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
      tracker.trackRead('${source.serverPath}/downloadLayoutConditions');

      final Map<String, dynamic> data = value.data() ?? {};

      // Conditions do not exist or there's a network error.
      if (data.isEmpty) {
        ErrorLogger.instance.captureException(
          'No data found',
          message:
              'Failed to download conditions for canvas/layout [$layoutID]',
          type: 'conditions_download_failed',
          layoutID: layoutID,
        );
        return null;
      }

      final SDKLayoutConditions layoutConditions = SDKLayoutConditions.fromJson(
        {...data, 'id': value.id},
      );
      return layoutConditions;
    });
  }
}

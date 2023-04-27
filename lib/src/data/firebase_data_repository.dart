import 'dart:async';

import '../../codelessly_sdk.dart';
import '../../firedart.dart';
import '../auth/auth_manager.dart';
import '../cache/cache_manager.dart';
import '../error/error_handler.dart';
import 'network_data_repository.dart';

/// Handles the data flow of [SDKPublishModel] from the server.
class FirebaseDataRepository extends NetworkDataRepository {
  /// The firestore instance to fetch the published model from.
  final Firestore firestore;

  /// Creates a new [FirebaseDataRepository] instance with the given
  /// [firestore] instance.
  FirebaseDataRepository({required this.firestore});

  /// Returns the path collection to be used.
  String publishPath(bool isPreview) =>
      isPreview ? 'publish_preview' : 'publish';

  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required bool isPreview,
  }) {
    final String publishPath = this.publishPath(isPreview);
    final DocumentReference publishModelDoc =
        firestore.collection(publishPath).document(projectID);

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
    required bool isPreview,
  }) async {
    final String publishPath = this.publishPath(isPreview);

    final DocumentReference layoutDoc = firestore
        .collection(publishPath)
        .document(projectID)
        .collection('layouts')
        .document(layoutID);

    if (!(await layoutDoc.exists)) {
      return null;
    }

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
    required bool isPreview,
  }) {
    final String publishPath = this.publishPath(isPreview);

    final DocumentReference fontDoc = firestore
        .collection(publishPath)
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
}

import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';

abstract class NetworkDataRepository {
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required bool isPreview,
  });

  /// Fetches the relevant [SDKPublishLayout] from the server based on the
  /// configurations of the implementation.
  Future<SDKPublishLayout?> downloadLayoutModel({
    required String projectID,
    required String layoutID,
    required bool isPreview,
  });

  Future<SDKPublishFont?> downloadFontModel({
    required String projectID,
    required String fontID,
    required bool isPreview,
  });

  Set<Future<SDKPublishFont?>> downloadFontModels({
    required String projectID,
    required Set<String> fontIDs,
    required bool isPreview,
  }) =>
      {
        for (final fontID in fontIDs)
          downloadFontModel(
            projectID: projectID,
            fontID: fontID,
            isPreview: isPreview,
          )
      };

  Set<Future<SDKPublishLayout?>> downloadLayoutModels({
    required String projectID,
    required Set<String> layoutIDs,
    required bool isPreview,
  }) =>
      {
        for (final layoutID in layoutIDs)
          downloadLayoutModel(
            projectID: projectID,
            layoutID: layoutID,
            isPreview: isPreview,
          )
      };

  Future<Uint8List?> downloadFontBytes({required String url}) async {
    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      return Uint8List.view(response.bodyBytes.buffer);
    } catch (e) {
      print('Error downloading font bytes: $e');
      return null;
    }
  }
}

import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';

/// An abstract class that represents the operations that a [DataManager] will
/// need to utilize to offer a complete usage experience of a [Codelessly]
/// layout.
abstract class NetworkDataRepository {
  const NetworkDataRepository();

  /// Streams a given [projectID]'s associated [SDKPublishModel] from the
  /// network with preferably live updates.
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required PublishSource source,
  });

  /// Fetches the relevant [SDKPublishLayout] from the server based on the
  /// configurations of the implementation.
  Future<SDKPublishLayout?> downloadLayoutModel({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  });

  /// Fetches the relevant [SDKPublishLayout] from the server based on the
  /// configurations of the implementation.
  Future<HttpApiData?> downloadApi({
    required String projectID,
    required String apiId,
    required PublishSource source,
  });

  /// Fetches the relevant [SDKPublishLayout] from the server based on the
  /// configurations of the implementation.
  Future<SDKLayoutVariables?> downloadLayoutVariables({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  });

  /// Fetches the relevant [SDKPublishLayout] from the server based on the
  /// configurations of the implementation.
  Future<SDKLayoutConditions?> downloadLayoutConditions({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  });

  /// Fetches the relevant [SDKPublishFont] from the server based on the
  /// configurations of the implementation.
  Future<SDKPublishFont?> downloadFontModel({
    required String projectID,
    required String fontID,
    required PublishSource source,
  });

  /// Fetches the relevant [SDKPublishFont]s from the server based on the
  /// configurations of the implementation.
  Set<Future<SDKPublishFont?>> downloadFontModels({
    required String projectID,
    required Set<String> fontIDs,
    required PublishSource source,
  }) =>
      {
        for (final fontID in fontIDs)
          downloadFontModel(
            projectID: projectID,
            fontID: fontID,
            source: source,
          )
      };

  /// Fetches the relevant [SDKPublishLayout]s from the server based on the
  /// configurations of the implementation.
  Set<Future<SDKPublishLayout?>> downloadLayoutModels({
    required String projectID,
    required Set<String> layoutIDs,
    required PublishSource source,
  }) =>
      {
        for (final layoutID in layoutIDs)
          downloadLayoutModel(
            projectID: projectID,
            layoutID: layoutID,
            source: source,
          )
      };

  /// Downloads the bytes of a font from the server given a [url].
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

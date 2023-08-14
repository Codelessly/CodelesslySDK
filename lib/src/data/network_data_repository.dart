import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';

/// An abstract class that represents the operations that a [DataManager] will
/// need to utilize to offer a complete usage experience of a [Codelessly]
/// layout.
abstract class NetworkDataRepository {
  final String cloudFunctionsBaseURL;

  NetworkDataRepository({required this.cloudFunctionsBaseURL}) {
    log('[NetworkDataRepo] created with cloudFunctionsBaseURL: $cloudFunctionsBaseURL');
  }

  /// Calls a cloud function that searches for the project associated with the
  /// given unique slug and returns a completely populated [SDKPublishModel]
  /// instance.
  Future<SDKPublishModel?> downloadCompletePublishBundle({
    required String slug,
    required PublishSource source,
  }) async {
    log('[NetworkDataRepo] Downloading publish bundle with slug: $slug and source: $source');
    final http.Response result = await http.post(
      Uri.parse('$cloudFunctionsBaseURL/getPublishBundleBySlugRequest'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode({'slug': slug, 'source': source.serverPath}),
      encoding: utf8,
    );

    if (result.statusCode != 200) {
      log('[NetworkDataRepo] Error downloading publish bundle.');
      log('[NetworkDataRepo] Status code: ${result.statusCode}');
      log('[NetworkDataRepo] Message: ${result.body}');
      print('Error downloading publish bundle from slug [$slug]');
      return null;
    }

    final Map<String, dynamic> modelDoc = jsonDecode(result.body);
    final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc);

    log('[NetworkDataRepo] Finished downloading publish bundle with slug: $slug and source: $source.');
    return model;
  }

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
      log('Error downloading font bytes: $e');
      return null;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';

const String _label = 'Network Data Repository';

/// An abstract class that represents the operations that a [DataManager] will
/// need to utilize to offer a complete usage experience of a [Codelessly]
/// layout.
abstract class NetworkDataRepository {
  /// The [CodelesslyConfig] instance that is used to configure the SDK.
  final CodelesslyConfig config;

  /// Creates a new instance of [NetworkDataRepository].
  NetworkDataRepository({required this.config});

  /// Calls a cloud function that searches for the project associated with the
  /// given unique slug and returns a completely populated [SDKPublishModel]
  /// instance.
  Future<SDKPublishModel?> downloadCompletePublishBundle({
    required String slug,
    required PublishSource source,
  }) async {
    logger.log(_label,
        'Downloading publish bundle with slug: $slug and source: $source');
    try {
      final String url =
          'https://firebasestorage.googleapis.com/v0/b/${config.firebaseOptions.projectId}.appspot.com/o/${Uri.encodeComponent('${source.serverPath}/$slug.json')}?alt=media';

      logger.log(_label, 'Publish bundle URL: $url');
      final http.Response result = await http.get(Uri.parse(url));

      if (result.statusCode != 200) {
        logger.log(_label, 'Error downloading publish bundle.');
        logger.log(_label, 'Status code: ${result.statusCode}');
        logger.log(_label, 'Message: ${result.body}');
        throw CodelesslyException(
          ErrorType.networkException,
          message: 'Error downloading publish bundle from slug [$slug]',
        );
      }

      final Map<String, dynamic> modelDoc =
          jsonDecode(utf8.decode(result.bodyBytes));

      final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc);

      logger.log(_label,
          'Finished downloading publish bundle with slug: $slug and source: $source.');
      return model;
    } catch (e, str) {
      logger.error(_label, 'Error downloading publish bundle',
          error: e, stackTrace: str);
      print(e);
      print(str);
      return null;
    }
  }

  /// Calls a cloud function that searches for the project associated with the
  /// given unique slug and returns a completely populated [SDKPublishModel]
  /// instance.
  // Future<SDKPublishModel?> downloadCompletePublishBundle({
  //   required String slug,
  //   required PublishSource source,
  // }) async {
  //   logger.log(_label, 'Downloading publish bundle with slug: $slug and source: $source');
  //   final http.Response result = await http.post(
  //     Uri.parse(
  //         '${config.firebaseCloudFunctionsBaseURL}/getPublishBundleBySlugRequest'),
  //     headers: <String, String>{'Content-Type': 'application/json'},
  //     body: jsonEncode({'slug': slug, 'source': source.serverPath}),
  //     encoding: utf8,
  //   );
  //
  //   if (result.statusCode != 200) {
  //     logger.log(_label, 'Error downloading publish bundle.');
  //     logger.log(_label, 'Status code: ${result.statusCode}');
  //     logger.log(_label, 'Message: ${result.body}');
  //     CodelesslyErrorHandler.instance.captureException(CodelesslyException(
  //       'Error downloading publish bundle from slug [$slug]',
  //       stacktrace: StackTrace.current,
  //     ));
  //     return null;
  //   }
  //
  //   final Map<String, dynamic> modelDoc = jsonDecode(result.body);
  //   final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc);
  //
  //   logger.log(_label, 'Finished downloading publish bundle with slug: $slug and source: $source.');
  //   return model;
  // }

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
    } catch (e, str) {
      logger.error(
        _label,
        'Error downloading font bytes',
        error: e,
        stackTrace: str,
      );
      return null;
    }
  }
}

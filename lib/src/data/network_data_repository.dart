import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../codelessly_sdk.dart';
import '../logging/debug_logger.dart';
import '../logging/error_logger.dart';

/// An abstract class that represents the operations that a [DataManager] will
/// need to utilize to offer a complete usage experience of a [Codelessly]
/// layout.
abstract class NetworkDataRepository {
  static const String name = 'NetworkDataRepository';

  /// The [CodelesslyConfig] instance that is used to configure the SDK.
  final CodelesslyConfig config;

  /// The [StatTracker] instance to track the statistics of the data repository.
  final StatTracker tracker;

  /// Creates a new instance of [NetworkDataRepository].
  NetworkDataRepository({
    required this.config,
    required this.tracker,
  });

  /// Calls a cloud function that searches for the project associated with the
  /// given unique slug and returns a completely populated [SDKPublishModel]
  /// instance.
  Future<SDKPublishModel?> downloadCompletePublishBundle({
    required String slug,
    required PublishSource source,
  }) async {
    DebugLogger.instance.printFunction(
      'downloadCompletePublishBundle(slug: $slug, source: $source)',
      name: name,
    );

    try {
      final String url =
          'https://firebasestorage.googleapis.com/v0/b/${config.firebaseOptions.projectId}.appspot.com/o/${Uri.encodeComponent('${source.serverPath}/$slug.json')}?alt=media';

      DebugLogger.instance.printInfo('Publish bundle URL: $url', name: name);
      final http.Response result = await http.get(Uri.parse(url));

      if (result.statusCode != 200) {
        DebugLogger.instance
            .printInfo('Error downloading publish bundle.', name: name);
        DebugLogger.instance
            .printInfo('Status code: ${result.statusCode}', name: name);
        DebugLogger.instance.printInfo('Message: ${result.body}', name: name);

        ErrorLogger.instance.captureException(
          'Failed to download publish bundle',
          message: 'Error downloading publish bundle from slug [$slug]',
          type: 'bundle_download_failed',
          stackTrace: StackTrace.current,
        );
        return null;
      }

      tracker.trackBundleDownload();

      final Map<String, dynamic> modelDoc =
          jsonDecode(utf8.decode(result.bodyBytes));

      final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc);

      DebugLogger.instance.printInfo(
          'Finished downloading publish bundle with slug: $slug and source: $source.',
          name: name);
      return model;
    } catch (e, str) {
      DebugLogger.instance.log(
        'Error downloading publish bundle.\nError: $e',
        category: DebugCategory.error,
        name: name,
        level: Level.WARNING,
      );

      ErrorLogger.instance.captureException(
        e,
        message: 'Failed to download publish bundle',
        type: 'bundle_download_failed',
        stackTrace: str,
      );
      return null;
    }
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
    DebugLogger.instance
        .printFunction('downloadFontBytes(url: $url)', name: name);
    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      tracker.trackFontDownload();

      return Uint8List.view(response.bodyBytes.buffer);
    } catch (e) {
      DebugLogger.instance.log(
        'Error downloading font bytes.\nError: $e',
        category: DebugCategory.error,
        name: name,
        level: Level.WARNING,
      );
      return null;
    }
  }
}

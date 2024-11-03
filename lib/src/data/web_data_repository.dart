import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';
import '../logging/error_logger.dart';

/// A [NetworkDataRepository] implementation that utilizes the Firebase Cloud
/// Functions to retrieve the relevant data.
@Deprecated('Use [FirebaseDataRepository] instead.')
class WebDataRepository extends NetworkDataRepository {
  final http.Client client;

  /// Creates a [WebDataRepository] instance.
  WebDataRepository({
    required super.config,
    required this.client,
  });

  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required PublishSource source,
  }) async* {
    try {
      final http.Response result = await client.post(
        Uri.parse(
            '${config.firebaseCloudFunctionsBaseURL}/api/getPublishModelRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'source': source.serverPath,
        }),
      );

      if (result.statusCode != 200) {
        ErrorLogger.instance.captureException(
          'Failed to download publish model',
          message:
              'Error downloading publish model. Status: ${result.statusCode}',
          type: 'publish_model_download_failed',
        );
        return;
      }

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc);

      yield model;
    } catch (e, str) {
      ErrorLogger.instance.captureException(
        e,
        message: 'Failed to stream publish model',
        type: 'publish_model_stream_failed',
        stackTrace: str,
      );
      rethrow;
    }
  }

  @override
  Future<SDKPublishLayout?> downloadLayoutModel({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) async {
    try {
      final http.Response result = await client.post(
        Uri.parse(
            '${config.firebaseCloudFunctionsBaseURL}/api/getLayoutModelRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'layoutID': layoutID,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        ErrorLogger.instance.captureException(
          'Failed to download layout model',
          message:
              'Error downloading layout model [${source.serverPath}]. Status: ${result.statusCode}',
          type: 'layout_download_failed',
          layoutID: layoutID,
        );
        return null;
      }

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKPublishLayout layout = SDKPublishLayout.fromJson(modelDoc);

      return layout;
    } catch (e, str) {
      ErrorLogger.instance.captureException(
        e,
        message: 'Failed to download layout model',
        type: 'layout_download_failed',
        layoutID: layoutID,
        stackTrace: str,
      );
      return null;
    }
  }

  @override
  Future<SDKPublishFont?> downloadFontModel({
    required String projectID,
    required String fontID,
    required PublishSource source,
  }) async {
    try {
      final http.Response result = await client.post(
        Uri.parse(
            '${config.firebaseCloudFunctionsBaseURL}/api/getFontModelRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'fontID': fontID,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        ErrorLogger.instance.captureException(
          'Failed to download font model',
          message: 'Error downloading font model. Status: ${result.statusCode}',
          type: 'font_download_failed',
        );
        return null;
      }

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKPublishFont font = SDKPublishFont.fromJson(modelDoc);

      return font;
    } catch (e, str) {
      ErrorLogger.instance.captureException(
        e,
        message: 'Failed to download font model',
        type: 'font_download_failed',
        stackTrace: str,
      );
      return null;
    }
  }

  @override
  Future<HttpApiData?> downloadApi({
    required String projectID,
    required String apiId,
    required PublishSource source,
  }) async {
    try {
      final http.Response result = await client.post(
        Uri.parse(
            '${config.firebaseCloudFunctionsBaseURL}/api/getPublishedApiRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'apiId': apiId,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        ErrorLogger.instance.captureException(
          'Failed to download API',
          message: 'Error downloading API. Status: ${result.statusCode}',
          type: 'api_download_failed',
        );
        return null;
      }

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final HttpApiData api = HttpApiData.fromJson(modelDoc);

      return api;
    } catch (e, str) {
      ErrorLogger.instance.captureException(
        e,
        message: 'Failed to download API',
        type: 'api_download_failed',
        stackTrace: str,
      );
      return null;
    }
  }

  @override
  Future<SDKLayoutVariables?> downloadLayoutVariables({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) async {
    try {
      final http.Response result = await client.post(
        Uri.parse(
            '${config.firebaseCloudFunctionsBaseURL}/api/getPublishedLayoutVariablesRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'layoutID': layoutID,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        ErrorLogger.instance.captureException(
          'Failed to download variables',
          message: 'Error downloading variables. Status: ${result.statusCode}',
          type: 'variables_download_failed',
          layoutID: layoutID,
        );
        return null;
      }

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKLayoutVariables variables =
          SDKLayoutVariables.fromJson({...modelDoc, 'id': layoutID});

      return variables;
    } catch (e, str) {
      ErrorLogger.instance.captureException(
        e,
        message: 'Failed to download variables',
        type: 'variables_download_failed',
        layoutID: layoutID,
        stackTrace: str,
      );
      return null;
    }
  }

  @override
  Future<SDKLayoutConditions?> downloadLayoutConditions({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) async {
    try {
      final http.Response result = await client.post(
        Uri.parse(
            '${config.firebaseCloudFunctionsBaseURL}/api/getPublishedLayoutConditionsRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'layoutID': layoutID,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        ErrorLogger.instance.captureException(
          'Failed to download conditions',
          message: 'Error downloading conditions. Status: ${result.statusCode}',
          type: 'conditions_download_failed',
          layoutID: layoutID,
        );
        return null;
      }

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKLayoutConditions conditions =
          SDKLayoutConditions.fromJson({...modelDoc, 'id': layoutID});

      return conditions;
    } catch (e, str) {
      ErrorLogger.instance.captureException(
        e,
        message: 'Failed to download conditions',
        type: 'conditions_download_failed',
        layoutID: layoutID,
        stackTrace: str,
      );
      return null;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';

/// A [NetworkDataRepository] implementation that utilizes the Firebase Cloud
/// Functions to retrieve the relevant data.
@Deprecated('Use [FirebaseDataRepository] instead.')
class WebDataRepository extends NetworkDataRepository {
  final http.Client client;

  /// Creates a [WebDataRepository] instance.
  WebDataRepository({
    required super.config,
    required super.tracker,
    required this.client,
  });

  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required PublishSource source,
  }) async* {
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
      log('[WebDataRepo] Error downloading publish model.');
      log('[WebDataRepo] Status code: ${result.statusCode}');
      log('[WebDataRepo] Message: ${result.body}');
      throw CodelesslyException(
        'Error downloading publish model.',
        stacktrace: StackTrace.current,
      );
    }

    final Map<String, dynamic> modelDoc = jsonDecode(result.body);
    final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc);

    yield model;
  }

  @override
  Future<SDKPublishLayout?> downloadLayoutModel({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) async {
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
      log('[WebDataRepo] Error downloading layout model. [${source.serverPath}]');
      log('[WebDataRepo] Status code: ${result.statusCode}');
      log('[WebDataRepo] Message: ${result.body}');
      throw CodelesslyException(
        'Error downloading layout model [$layoutID]',
        layoutID: layoutID,
        stacktrace: StackTrace.current,
      );
    }

    final Map<String, dynamic> modelDoc = jsonDecode(result.body);
    final SDKPublishLayout layout = SDKPublishLayout.fromJson(modelDoc);

    return layout;
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
        log('[WebDataRepo] Error downloading font model.');
        log('[WebDataRepo] Status code: ${result.statusCode}');
        log('[WebDataRepo] Message: ${result.body}');
        throw CodelesslyException(
          'Error downloading font model.',
          stacktrace: StackTrace.current,
        );
      }
      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKPublishFont font = SDKPublishFont.fromJson(modelDoc);

      return font;
    } catch (e) {
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
        log('[WebDataRepo] Error downloading api.');
        log('[WebDataRepo] Status code: ${result.statusCode}');
        log('[WebDataRepo] Message: ${result.body}');
        throw CodelesslyException(
          'Error downloading api.',
          stacktrace: StackTrace.current,
        );
      }
      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final HttpApiData api = HttpApiData.fromJson(modelDoc);

      return api;
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
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
        log('[WebDataRepo] Error downloading variables.');
        log('[WebDataRepo] Status code: ${result.statusCode}');
        log('[WebDataRepo] Message: ${result.body}');
        throw CodelesslyException(
          'Error downloading variables.',
          stacktrace: StackTrace.current,
        );
      }
      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKLayoutVariables variables =
          SDKLayoutVariables.fromJson({...modelDoc, 'id': layoutID});

      return variables;
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
      return null;
    }
  }

  @override
  Future<SDKLayoutConditions?> downloadLayoutConditions({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) async {
    log('[WebDataRepo] Downloading conditions for $layoutID');
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
        log('[WebDataRepo] Error downloading conditions.');
        log('[WebDataRepo] Status code: ${result.statusCode}');
        log('[WebDataRepo] Message: ${result.body}');
        throw CodelesslyException(
          'Error downloading conditions.',
          stacktrace: StackTrace.current,
        );
      }
      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKLayoutConditions conditions =
          SDKLayoutConditions.fromJson({...modelDoc, 'id': layoutID});

      log('[WebDataRepo] Layout Conditions [${conditions.id}]: ${conditions.conditions.length}');

      return conditions;
    } catch (e, stacktrace) {
      log('[WebDataRepo] Error downloading conditions for $layoutID');
      print(e);
      print(stacktrace);
      return null;
    }
  }
}

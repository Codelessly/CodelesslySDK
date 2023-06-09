import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';

import '../../codelessly_sdk.dart';
import '../logging/error_handler.dart';

/// A [NetworkDataRepository] implementation that utilizes the Firebase Cloud
/// Functions to retrieve the relevant data.
///
/// Since Firedart is not compatible with Flutter Web, this implementation
/// utilizes the http package instead.
class WebDataRepository extends NetworkDataRepository {
  final String cloudFunctionsBaseURL;

  /// Creates a [WebDataRepository] instance.
  WebDataRepository({required this.cloudFunctionsBaseURL}) {
    log('WebDataRepository created with cloudFunctionsBaseURL: $cloudFunctionsBaseURL');
  }

  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required PublishSource source,
  }) async* {
    final Response result = await post(
      Uri.parse('$cloudFunctionsBaseURL/getPublishModelRequest'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode({
        'projectID': projectID,
        'source': source.serverPath,
      }),
    );

    if (result.statusCode != 200) {
      print('Error downloading publish model from web data manager.');
      print('Status code: ${result.statusCode}');
      print('Message: ${result.body}');
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
    final Response result = await post(
      Uri.parse('$cloudFunctionsBaseURL/getLayoutModelRequest'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode({
        'projectID': projectID,
        'layoutID': layoutID,
        'source': source.serverPath,
      }),
      encoding: utf8,
    );

    if (result.statusCode != 200) {
      print(
          'Error downloading layout model from web data manager. [${source.serverPath}]');
      print('Status code: ${result.statusCode}');
      print('Message: ${result.body}');
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
      final Response result = await post(
        Uri.parse('$cloudFunctionsBaseURL/getFontModelRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'fontID': fontID,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        print('Error downloading font model from web data manager.');
        print('Status code: ${result.statusCode}');
        print('Message: ${result.body}');
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
      final Response result = await post(
        Uri.parse('$cloudFunctionsBaseURL/getPublishedApiRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'apiId': apiId,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        print('Error downloading api from web data manager.');
        print('Status code: ${result.statusCode}');
        print('Message: ${result.body}');
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
      final Response result = await post(
        Uri.parse('$cloudFunctionsBaseURL/getPublishedLayoutVariablesRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'layoutID': layoutID,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        print('Error downloading variables from web data manager.');
        print('Status code: ${result.statusCode}');
        print('Message: ${result.body}');
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
    try {
      final Response result = await post(
        Uri.parse('$cloudFunctionsBaseURL/getPublishedLayoutConditionsRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'layoutID': layoutID,
          'source': source.serverPath,
        }),
        encoding: utf8,
      );

      if (result.statusCode != 200) {
        print('Error downloading conditions from web data manager.');
        print('Status code: ${result.statusCode}');
        print('Message: ${result.body}');
        throw CodelesslyException(
          'Error downloading conditions.',
          stacktrace: StackTrace.current,
        );
      }
      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKLayoutConditions conditions =
          SDKLayoutConditions.fromJson({...modelDoc, 'id': layoutID});

      return conditions;
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
      return null;
    }
  }
}

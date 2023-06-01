import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

import '../../codelessly_sdk.dart';
import '../logging/error_handler.dart';

/// A [NetworkDataRepository] implementation that utilizes the Firebase Cloud
/// Functions to retrieve the relevant data.
///
/// Since Firedart is not compatible with Flutter Web, this implementation
/// utilizes the http package instead.
class WebDataRepository extends NetworkDataRepository {
  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required bool isPreview,
  }) async* {
    final Response result = await post(
      Uri.parse('$firebaseCloudFunctionsBaseURL/getPublishModelRequest'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode({
        'projectID': projectID,
        'isPreview': isPreview,
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
    required bool isPreview,
  }) async {
    final Response result = await post(
      Uri.parse('$firebaseCloudFunctionsBaseURL/getLayoutModelRequest'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode({
        'projectID': projectID,
        'layoutID': layoutID,
        'isPreview': isPreview,
      }),
      encoding: utf8,
    );

    if (result.statusCode != 200) {
      print(
          'Error downloading layout model from web data manager. [${isPreview ? 'preview' : 'publish'}]');
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
    required bool isPreview,
  }) async {
    try {
      final Response result = await post(
        Uri.parse('$firebaseCloudFunctionsBaseURL/getFontModelRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'fontID': fontID,
          'isPreview': isPreview,
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
    required bool isPreview,
  }) async {
    try {
      final Response result = await post(
        Uri.parse('$firebaseCloudFunctionsBaseURL/getPublishedApiRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'apiId': apiId,
          'isPreview': isPreview,
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
}

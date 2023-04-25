import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

import '../../codelessly_sdk.dart';
import 'network_data_repository.dart';

/// Handles the data flow of [SDKPublishModel] from the server.
class WebDataRepository extends NetworkDataRepository {
  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required bool isPreview,
  }) async* {
    try {
      final Response result = await post(
        Uri.parse('$firebaseCloudFunctionsBaseURL/getPublishModelRequest'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectID': projectID,
          'isPreview': isPreview,
        }),
      );

      print(
          'streamPublishModel response:\n${result.body}\n${result.statusCode}\n${result.request}\n${result.headers}');

      if (result.statusCode != 200) {
        yield null;
        return;
      }

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKPublishModel model = SDKPublishModel.fromJson(modelDoc);

      yield model;
    } catch (e) {
      print('streamPublishModel error: $e');
      yield null;
    }
  }

  @override
  Future<SDKPublishLayout?> downloadLayoutModel({
    required String projectID,
    required String layoutID,
    required bool isPreview,
  }) async {
    try {
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

      if (result.statusCode != 200) return null;

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKPublishLayout layout = SDKPublishLayout.fromJson(modelDoc);

      return layout;
    } catch (e) {
      return null;
    }
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

      if (result.statusCode != 200) return null;

      final Map<String, dynamic> modelDoc = jsonDecode(result.body);
      final SDKPublishFont font = SDKPublishFont.fromJson(modelDoc);

      return font;
    } catch (e) {
      return null;
    }
  }
}

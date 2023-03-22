import 'dart:async';

import 'package:universal_html/html.dart';

import 'abstract_access.dart';

final WebAccess _webAccess = WebAccess._private();

AbstractPlatformAccess getPlatformAccess() => _webAccess;

class WebAccess extends AbstractPlatformAccess {
  WebAccess._private();

  @override
  String getEnvironmentVariable(String environmentVariable) =>
      throw UnsupportedError(
          'Environment variables do not exist on the platform you are using.');

  /// Untested
  @override
  Future<String> getStringFromFile(String filePath) async {
    var response = await HttpRequest.getString('filePath');
    return response;
  }

  /// Need someone more knowledgeable with dart:html
  @override
  StreamConsumer<List<int>> openWrite(String filePath) =>
      throw UnsupportedError(
          'File objects do not exist on the platform you are using.');

  /// Need someone more knowledgeable with dart:html
  @override
  Stream openRead(String filePath) => throw UnsupportedError(
      'File objects do not exist on the platform you are using.');
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';

Future<bool> saveText(String name, String text, String mimeType) async {
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(Uint8List.fromList(utf8.encode(text)), name: name, mimeType: mimeType).saveTo(location.path);
  return true;
}

// Exporting generated text is separate from cloud-file uploads.
import 'platform/file_export_native.dart'
    if (dart.library.js_interop) 'platform/file_export_web.dart' as platform;

abstract interface class FileExporter {
  Future<bool> saveText({required String fileName, required String text, String mimeType = 'text/plain'});
}

/// A suggested name never chooses a directory or contains control characters.
String exportFileName(String name) {
  final safe = name.replaceAll(RegExp(r'[\\/\x00-\x1f]'), '_').trim();
  return safe.isEmpty || safe == '.' || safe == '..' ? 'export.txt' : safe;
}

class PlatformFileExporter implements FileExporter {
  const PlatformFileExporter();
  @override
  Future<bool> saveText({required String fileName, required String text, String mimeType = 'text/plain'}) =>
      platform.saveText(exportFileName(fileName), text, mimeType);
}

/// In-memory sink for tests and apps that provide their own export destination.
class RecordingFileExporter implements FileExporter {
  final List<({String fileName, String text, String mimeType})> files = [];
  bool cancelled = false;
  @override
  Future<bool> saveText({required String fileName, required String text, String mimeType = 'text/plain'}) async {
    if (cancelled) return false;
    files.add((fileName: exportFileName(fileName), text: text, mimeType: mimeType));
    return true;
  }
}

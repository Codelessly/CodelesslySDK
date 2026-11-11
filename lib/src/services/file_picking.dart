// Choosing files on the device for a cloudFiles upload (a profile photo).
import 'package:file_selector/file_selector.dart' as selector;

import '../runtime/actions/ui.dart' show PickedFile;

/// Lets the person choose files: what a cloudFiles upload without a
/// `source` sends. The app shell's own picker (`NavigatorActionUi.files`)
/// wins when it gives one.
abstract interface class FilePicker {
  /// The chosen files; none when the person cancels.
  Future<List<PickedFile>> pick({bool images = true, bool multiple = true});
}

/// The platform's file dialog (the browser's file chooser on the web).
class PlatformFilePicker implements FilePicker {
  const PlatformFilePicker();

  static const _images = selector.XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'],
    mimeTypes: ['image/*'],
  );

  @override
  Future<List<PickedFile>> pick({bool images = true, bool multiple = true}) async {
    final groups = images ? const [_images] : const <selector.XTypeGroup>[];
    final files = multiple
        ? await selector.openFiles(acceptedTypeGroups: groups)
        : [?await selector.openFile(acceptedTypeGroups: groups)];
    return [
      for (final f in files) PickedFile(name: f.name, bytes: await f.readAsBytes(), contentType: f.mimeType ?? _typeOf(f.name)),
    ];
  }

  static String? _typeOf(String name) => switch (name.split('.').last.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'pdf' => 'application/pdf',
        _ => null,
      };
}

/// Always "chooses" [files]: for tests and previews (a 7 MB photo, a PDF).
class FixedFilePicker implements FilePicker {
  const FixedFilePicker(this.files);

  final List<PickedFile> files;

  @override
  Future<List<PickedFile>> pick({bool images = true, bool multiple = true}) async =>
      multiple ? files : files.take(1).toList();
}

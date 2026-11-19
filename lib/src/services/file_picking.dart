// Choosing files on the device: for a pickFile action (a draft's
// attachment) and a cloudFiles upload (a profile photo).
import 'package:file_selector/file_selector.dart' as selector;

import '../runtime/actions/ui.dart' show PickedFile;

/// Lets the person choose files: what a pickFile action gives the page and
/// a cloudFiles upload without a `source` sends. The app shell's own picker
/// (`NavigatorActionUi.files`) wins when it gives one.
abstract interface class FilePicker {
  /// The chosen files; none when the person cancels.
  Future<List<PickedFile>> pick({bool images = true, bool multiple = true});
}

/// A [FilePicker] that can offer the kinds of file a pickFile action
/// accepts. One that is not is asked for images or for any file, and what
/// it gives is checked against the kinds afterwards.
abstract interface class TypedFilePicker implements FilePicker {
  /// The chosen files among the kinds [accept] names, as HTML's `accept`
  /// does: MIME types (`image/*`, `application/pdf`) and extensions
  /// (`.csv`). Empty: any file. None when the person cancels.
  Future<List<PickedFile>> pickTypes(List<String> accept, {bool multiple = false});
}

/// The MIME type of a file by its name's extension; null when unknown.
String? mimeTypeOfFileName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return _typeOfExtension[name.substring(dot + 1).toLowerCase()];
}

const _typeOfExtension = <String, String>{
  'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp', //
  'heic': 'image/heic', 'svg': 'image/svg+xml', 'bmp': 'image/bmp',
  'pdf': 'application/pdf', 'json': 'application/json', 'zip': 'application/zip',
  'txt': 'text/plain', 'csv': 'text/csv', 'md': 'text/markdown', 'html': 'text/html', 'xml': 'text/xml',
  'mp3': 'audio/mpeg', 'wav': 'audio/wav', 'm4a': 'audio/mp4', 'ogg': 'audio/ogg',
  'mp4': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm',
};

/// The kinds a pickFile action's `accept` names: its comma-separated parts,
/// trimmed, in lower case.
List<String> acceptedKinds(String accept) => [
      for (final part in accept.split(','))
        if (part.trim().isNotEmpty) part.trim().toLowerCase(),
    ];

/// Whether a file called [name], of MIME type [type] (by its name when
/// null or empty), is one of the kinds [accept] names. Any file is when
/// [accept] is empty.
bool fileAccepted(List<String> accept, String name, String? type) {
  if (accept.isEmpty) return true;
  final mime = (type == null || type.isEmpty ? mimeTypeOfFileName(name) : type)?.toLowerCase() ?? '';
  final lower = name.toLowerCase();
  for (final kind in accept) {
    if (kind == '*' || kind == '*/*') return true;
    if (kind.startsWith('.')) {
      if (lower.endsWith(kind)) return true;
    } else if (kind.endsWith('/*')) {
      if (mime.startsWith(kind.substring(0, kind.length - 1))) return true;
    } else if (mime == kind) {
      return true;
    }
  }
  return false;
}

/// The platform's file dialog (the browser's file chooser on the web).
class PlatformFilePicker implements TypedFilePicker {
  const PlatformFilePicker();

  static const _images = selector.XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'],
    mimeTypes: ['image/*'],
  );

  @override
  Future<List<PickedFile>> pick({bool images = true, bool multiple = true}) =>
      _open(images ? const [_images] : const <selector.XTypeGroup>[], multiple);

  @override
  Future<List<PickedFile>> pickTypes(List<String> accept, {bool multiple = false}) =>
      _open([?typeGroupOf(accept)], multiple);

  /// The dialog's filter for [accept]: its extensions and MIME types, each
  /// MIME type also as the extensions it is known by (a desktop's dialog
  /// filters by extension). Null (any file) when [accept] is empty or names
  /// a type with no known extension: what is picked is checked afterwards.
  static selector.XTypeGroup? typeGroupOf(List<String> accept) {
    if (accept.isEmpty) return null;
    final extensions = <String>{}, mimeTypes = <String>[];
    for (final kind in accept) {
      if (kind.startsWith('.')) {
        extensions.add(kind.substring(1));
        continue;
      }
      if (kind == '*' || kind == '*/*') return null;
      mimeTypes.add(kind);
      final known = [
        for (final e in _typeOfExtension.entries)
          if (kind.endsWith('/*') ? e.value.startsWith(kind.substring(0, kind.length - 1)) : e.value == kind) e.key,
      ];
      if (known.isEmpty) return null;
      extensions.addAll(known);
    }
    return selector.XTypeGroup(label: 'Files', extensions: extensions.toList(), mimeTypes: mimeTypes);
  }

  Future<List<PickedFile>> _open(List<selector.XTypeGroup> groups, bool multiple) async {
    final files = multiple
        ? await selector.openFiles(acceptedTypeGroups: groups)
        : [?await selector.openFile(acceptedTypeGroups: groups)];
    return [
      for (final f in files)
        PickedFile(name: f.name, bytes: await f.readAsBytes(), contentType: _known(f.mimeType) ?? mimeTypeOfFileName(f.name)),
    ];
  }

  static String? _known(String? type) => type == null || type.isEmpty ? null : type;
}

/// Always "chooses" [files]: for tests and previews (a 7 MB photo, a PDF).
class FixedFilePicker implements FilePicker {
  const FixedFilePicker(this.files);

  final List<PickedFile> files;

  @override
  Future<List<PickedFile>> pick({bool images = true, bool multiple = true}) async =>
      multiple ? files : files.take(1).toList();
}

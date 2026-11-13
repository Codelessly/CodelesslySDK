// Files an action takes: chosen by the person, or given as `data:` URLs.
// Shared by the features that upload or import files.
import '../../services/file_picking.dart' show FilePicker;
import 'action_error.dart' show CodedFailure;
import 'runner.dart';
import 'ui.dart' show NavigatorActionUi, PickedFile;

/// Lets the person choose files: the app shell's picker when it gives one
/// (`NavigatorActionUi.files`, or another [ActionUi]), else the services'
/// [FilePicker] (the platform's file dialog). Without either, none.
Future<List<PickedFile>> pickFiles(ActionRun run, {required bool images, required bool multiple}) {
  final ui = run.host.ui;
  final picker = run.service<FilePicker>();
  if (ui is NavigatorActionUi && ui.files == null && picker != null) {
    return picker.pick(images: images, multiple: multiple);
  }
  return ui.pickFiles(images: images, multiple: multiple);
}

/// The files a cloudFiles action's `source` gives: a `data:` URL, a map
/// `{"data": "data:...", "name"}`, or a list of them. [name] names them
/// (numbered when several); else a map's `name`, else `file-<time>.<ext>`.
List<PickedFile> sourceFiles(Object? value, {String name = ''}) {
  final items = value is List ? value : [value];
  final out = <PickedFile>[];
  for (final (i, item) in items.indexed) {
    final data = item is Map ? item['data'] : item;
    if (data is! String || !data.trim().startsWith('data:')) {
      throw const CodedFailure('invalid-source', 'The file to upload is not a data: URL');
    }
    final UriData uri;
    try {
      uri = UriData.parse(data.trim());
    } on FormatException {
      throw const CodedFailure('invalid-source', 'The file to upload is not a valid data: URL');
    }
    final type = uri.mimeType;
    final ext = switch (type) {
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'application/pdf' => 'pdf',
      'application/json' => 'json',
      'text/plain' => 'txt',
      _ => 'bin',
    };
    final given = name.isNotEmpty
        ? (items.length > 1 ? _numbered(name, i + 1) : name)
        : (item is Map && item['name'] is String && (item['name'] as String).trim().isNotEmpty
            ? (item['name'] as String).trim()
            : 'file-${DateTime.now().millisecondsSinceEpoch}${items.length > 1 ? '-${i + 1}' : ''}.$ext');
    out.add(PickedFile(name: given, bytes: uri.contentAsBytes(), contentType: type));
  }
  return out;
}

String _numbered(String name, int n) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '$name-$n' : '${name.substring(0, dot)}-$n${name.substring(dot)}';
}

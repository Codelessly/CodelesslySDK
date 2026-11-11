// Cloud files on Firebase Storage.
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../storage.dart';

/// [CloudFileStorage] on Firebase Storage, under [root] (the project's
/// folder, `data/{projectId}`, as for its cloud data). A path can't leave
/// [root]; full URLs (`https://`, `gs://`) address files directly.
class FirebaseFileStorage implements CloudFileStorage {
  FirebaseFileStorage(this.storage, {required this.root});

  final FirebaseStorage storage;
  final String root;

  bool _isUrl(String path) => path.startsWith('https://') || path.startsWith('gs://');

  Reference _ref(String path) =>
      _isUrl(path) ? storage.refFromURL(path) : storage.ref([root, ...CloudFilePaths.segments(path)].join('/'));

  @override
  Future<CloudFile> upload(String path, Uint8List bytes, {String? contentType, void Function(double sent)? onProgress}) async {
    final ref = _ref(path);
    final type = contentType ?? CloudFilePaths.contentTypeFor(ref.name.split('.').last);
    final task = ref.putData(bytes, SettableMetadata(contentType: type));
    final progress = onProgress == null
        ? null
        : task.snapshotEvents.listen((s) {
            if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
          }, onError: (_) {});
    try {
      await task;
    } finally {
      await progress?.cancel();
    }
    onProgress?.call(1);
    return CloudFile(path: ref.fullPath, url: await ref.getDownloadURL(), name: ref.name, size: bytes.length, contentType: type);
  }

  @override
  Future<void> delete(String pathOrUrl) => _ref(pathOrUrl).delete();

  @override
  Future<List<CloudFile>> list(String folder) async {
    final result = await _ref(folder).listAll();
    return [
      for (final item in result.items)
        CloudFile(path: item.fullPath, url: await item.getDownloadURL(), name: item.name),
    ];
  }

  @override
  Future<String> downloadUrl(String path) => _ref(path).getDownloadURL();
}

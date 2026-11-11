import '../media_export.dart';

MediaExportEngine createMediaExportEngine() => const _Unavailable();

class _Unavailable implements MediaExportEngine {
  const _Unavailable();
  @override
  bool get available => false;
  @override
  Future<Map<String, Object?>> export(MediaExportRequest request, {required void Function(double) onProgress}) async =>
      throw UnsupportedError('Video export needs an encoder supplied by the host on this platform');
  @override
  void cancel() {}
}

// Browser-only integration fixture: compile from v2/example with
// flutter build web --target ../test/browser/media_export_app.dart --no-web-resources-cdn
import 'dart:convert';
import 'dart:js_interop';
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';

@JS('cutroomRunExport')
external set runExport(JSFunction function);
@JS('cutroomCancelExport')
external set cancelExport(JSFunction function);
final service = MediaExportService();
JSPromise<JSString> export(JSString request) => service
    .export(MediaExportRequest.fromJson((jsonDecode(request.toDart) as Map).cast<String, Object?>()))
    .then(
      (value) => jsonEncode(value).toJS,
      onError: (Object error, StackTrace stack) =>
          jsonEncode({'error': '$error', 'cancelled': error is MediaExportCancelled}).toJS,
    )
    .toJS;
void main() {
  runExport = export.toJS;
  cancelExport = service.cancel.toJS;
  runApp(const Directionality(textDirection: TextDirection.ltr, child: Text('Media export integration fixture')));
}

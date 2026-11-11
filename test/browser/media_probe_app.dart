// Browser fixture for selected-byte preflight. Compile with a Flutter host.
import 'dart:convert';
import 'dart:js_interop';
import 'package:codelessly_sdk/src/services/media_probe.dart';
import 'package:flutter/widgets.dart';

@JS('cutroomProbePicked')
external set pickedProbe(JSFunction function);
JSPromise<JSString> probe(JSString name, JSString base64, JSString contentType) => probePickedVideo(
  name.toDart,
  base64Decode(base64.toDart),
  contentType: contentType.toDart,
).then((value) => jsonEncode(value).toJS, onError: (Object e, StackTrace s) => jsonEncode({'error': '$e'}).toJS).toJS;
void main() {
  pickedProbe = probe.toJS;
  runApp(const Directionality(textDirection: TextDirection.ltr, child: Text('Video preflight fixture')));
}

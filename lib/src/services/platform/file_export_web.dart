import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> saveText(String name, String text, String mimeType) async {
  final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()..href = url..download = name;
  web.document.body?.append(anchor);
  try {
    anchor.click();
  } finally {
    anchor.remove();
    // The browser needs one turn to read the URL after the click.
    Future<void>.delayed(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  }
  return true;
}

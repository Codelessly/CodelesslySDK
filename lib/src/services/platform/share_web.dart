import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// The browser's share panel (`navigator.share`): true when it took the
/// share, false when the person closed it, null where the browser has none
/// or refuses (no user gesture, a page not served securely).
Future<bool?> share({required String text, required String url, required String title}) async {
  final navigator = web.window.navigator;
  if (!(navigator as JSObject).has('share')) return null;
  final data = web.ShareData();
  if (title.isNotEmpty) data.title = title;
  if (text.isNotEmpty) data.text = text;
  if (url.isNotEmpty) data.url = url;
  try {
    await navigator.share(data).toDart;
    return true;
  } catch (error) {
    // AbortError: the person closed the panel. Anything else: it could not open.
    return '$error'.contains('AbortError') ? false : null;
  }
}

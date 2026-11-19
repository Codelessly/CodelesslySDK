// Where the screen on show is: the location its route was opened with, and
// its address (`screen.url`).
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';

/// Gives what is under it the location of the page it was opened from: a
/// dialog or a sheet is at its page's location (its own route has none).
class PageLocationScope extends InheritedWidget {
  const PageLocationScope({super.key, required this.location, required super.child});

  final String location;

  @override
  bool updateShouldNotify(PageLocationScope oldWidget) => oldWidget.location != location;
}

/// The location of the page [context] is on: what its route is named when
/// that is a path (`/trip/coast?day=2`, as the app's routes are named and
/// as a link opens them), else that of the page a modal was opened from;
/// empty when there is none.
String pageLocationOf(BuildContext context) {
  final name = ModalRoute.of(context)?.settings.name;
  if (name != null && name.startsWith('/')) return name;
  return context.dependOnInheritedWidgetOfExactType<PageLocationScope>()?.location ?? '';
}

/// In a test, the address a browser would show; null: the platform's.
@visibleForTesting
String? debugBrowserUrl;

/// `screen.url`, the address of the page [context] is on: in a browser the
/// address it shows; elsewhere the page's location ([pageLocationOf]), which
/// a link into the app opens, or empty.
String pageUrlOf(BuildContext context) {
  final location = pageLocationOf(context);
  if (debugBrowserUrl case final String url) return url;
  return kIsWeb ? Uri.base.toString() : location;
}

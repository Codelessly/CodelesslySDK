// Opening links (link actions, paywall legal links).
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Opens URLs.
abstract interface class LinkOpener {
  /// Opens [url]; false when it is malformed or can't be opened.
  Future<bool> open(String url);
}

/// Opens URLs with the platform (url_launcher): the browser, mail, phone...
class PlatformLinkOpener implements LinkOpener {
  const PlatformLinkOpener();

  @override
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || url.trim().isEmpty) return false;
    try {
      return await launcher.launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}

/// Records URLs instead of opening them (tests, previews).
class RecordingLinkOpener implements LinkOpener {
  final List<String> opened = [];

  @override
  Future<bool> open(String url) async {
    if (Uri.tryParse(url.trim()) == null || url.trim().isEmpty) return false;
    opened.add(url.trim());
    return true;
  }
}

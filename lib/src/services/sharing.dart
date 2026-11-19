// Sharing a text and a link with the device's share panel (a share action).
import 'platform/share_native.dart' if (dart.library.js_interop) 'platform/share_web.dart' as platform;

/// What became of a share.
enum ShareOutcome {
  /// The share panel took it.
  shared,

  /// The person closed the panel without sharing.
  dismissed,

  /// There is no share panel here: the action copies to the clipboard.
  unavailable,
}

/// Opens the device's share panel. An app with a native share sheet of its
/// own (a plugin) gives one in `Services(sharer: ...)`.
abstract interface class Sharer {
  /// Shares [text] and [url] (either may be empty, not both) under [title].
  Future<ShareOutcome> share({String text = '', String url = '', String title = ''});
}

/// The platform's share panel: the browser's (`navigator.share`) on the
/// web. On the other platforms the SDK has none of its own
/// ([ShareOutcome.unavailable]).
class PlatformSharer implements Sharer {
  const PlatformSharer();

  @override
  Future<ShareOutcome> share({String text = '', String url = '', String title = ''}) async =>
      switch (await platform.share(text: text, url: url, title: title)) {
        true => ShareOutcome.shared,
        false => ShareOutcome.dismissed,
        null => ShareOutcome.unavailable,
      };
}

/// Records what is shared instead of opening a panel (tests, previews),
/// answering [outcome].
class RecordingSharer implements Sharer {
  RecordingSharer({this.outcome = ShareOutcome.shared});

  ShareOutcome outcome;
  final List<({String text, String url, String title})> shared = [];

  @override
  Future<ShareOutcome> share({String text = '', String url = '', String title = ''}) async {
    if (outcome != ShareOutcome.unavailable) shared.add((text: text, url: url, title: title));
    return outcome;
  }
}

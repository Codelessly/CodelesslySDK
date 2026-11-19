// The words of the runtime's own chrome that a screen reader says (none is
// drawn): English, unless the host app gives its own
// (`CodelesslyConfig.labels`).

/// What a screen reader calls the parts of the runtime's own chrome: the
/// barrier behind a dialog, a toast's close button, pull to refresh, a chat
/// list's jump-to-latest button, the players' buttons and the seek bar. English by default; a host app in
/// another language gives its own with `CodelesslyConfig(labels: ...)`.
class CodelesslyLabels {
  const CodelesslyLabels({
    this.dismiss = 'Dismiss',
    this.close = 'Close',
    this.refresh = 'Refresh',
    this.jumpToLatest = 'Jump to latest',
    this.playVideo = 'Play video',
    this.pauseVideo = 'Pause video',
    this.playAudio = 'Play audio',
    this.pauseAudio = 'Pause audio',
    this.seek = 'Position',
  });

  /// The barrier behind a dialog or a sheet (a tap on it closes it), and a
  /// toast's close button.
  final String dismiss;

  /// The barrier behind a screen opened with a route transition.
  final String close;

  /// The pull-to-refresh indicator.
  final String refresh;

  /// A chat list's button that goes back to its newest item.
  final String jumpToLatest;

  /// The players' play button, by what a press does.
  final String playVideo, pauseVideo, playAudio, pauseAudio;

  /// The audio player's seek bar.
  final String seek;

  @override
  bool operator ==(Object other) =>
      other is CodelesslyLabels &&
      other.dismiss == dismiss &&
      other.close == close &&
      other.refresh == refresh &&
      other.jumpToLatest == jumpToLatest &&
      other.playVideo == playVideo &&
      other.pauseVideo == pauseVideo &&
      other.playAudio == playAudio &&
      other.pauseAudio == pauseAudio &&
      other.seek == seek;

  @override
  int get hashCode =>
      Object.hash(dismiss, close, refresh, jumpToLatest, playVideo, pauseVideo, playAudio, pauseAudio, seek);
}

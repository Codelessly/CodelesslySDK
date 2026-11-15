/// Utility for formatting timestamps in a human-readable relative format
class TimeFormatter {
  /// Format a DateTime as a relative time string
  ///
  /// Examples:
  /// - Less than 1 minute ago: "Just now" (or "now" if short)
  /// - Less than 1 hour ago: "5m ago" (or "5m" if short)
  /// - Less than 24 hours ago: "3h ago" (or "3h" if short)
  /// - Less than 7 days ago: "2d ago" (or "2d" if short)
  /// - 7+ days ago: "1/29" (month/day)
  ///
  /// Parameters:
  /// - [time]: The DateTime to format
  /// - [short]: If true, omits " ago" suffix for a more compact format
  static String formatRelative(DateTime time, {bool short = false}) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return short ? 'now' : 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m${short ? '' : ' ago'}';
    if (diff.inHours < 24) return '${diff.inHours}h${short ? '' : ' ago'}';
    if (diff.inDays < 7) return '${diff.inDays}d${short ? '' : ' ago'}';
    return '${time.month}/${time.day}';
  }
}

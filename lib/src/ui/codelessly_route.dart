/// A screen of a Codelessly app and the parameters it was opened with, as a
/// link: `{canvasId}?key=value`. Hosts put it in the browser's address
/// (see [Codelessly.route]) and hand it back on a reload (see
/// [Codelessly.pendingRoute]), so a reload opens the same screen with the
/// same parameters.
class CodelesslyRoute {
  /// The screen (canvas) id.
  final String canvasId;

  /// The parameters the screen was opened with (`${route.key}`).
  final Map<String, String> params;

  const CodelesslyRoute(this.canvasId, [this.params = const {}]);

  /// The route of a screen opened with [arguments], the navigation action's
  /// parameters. Values that aren't text, numbers or yes/no are left out:
  /// they can't be written in a link.
  factory CodelesslyRoute.of(String canvasId, Object? arguments) =>
      CodelesslyRoute(canvasId, {
        if (arguments is Map)
          for (final MapEntry entry in arguments.entries)
            if (entry.value is String ||
                entry.value is num ||
                entry.value is bool)
              '${entry.key}': '${entry.value}',
      });

  /// Reads a link written by [toPath]; null when it names no screen.
  static CodelesslyRoute? tryParse(String path) {
    final Uri uri = Uri.parse(path.startsWith('/') ? path : '/$path');
    final List<String> segments = [
      for (final String segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty) return null;
    return CodelesslyRoute(segments.last, uri.queryParameters);
  }

  /// The link: `{canvasId}` and its parameters as a query.
  String toPath() => Uri(
    path: canvasId,
    queryParameters: params.isEmpty ? null : params,
  ).toString();

  @override
  bool operator ==(Object other) =>
      other is CodelesslyRoute &&
      other.canvasId == canvasId &&
      other.params.length == params.length &&
      params.entries.every((entry) => other.params[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
    canvasId,
    Object.hashAllUnordered(params.entries.map((e) => '${e.key}=${e.value}')),
  );

  @override
  String toString() => toPath();
}

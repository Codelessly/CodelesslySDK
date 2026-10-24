/// A screen of a Codelessly app and the parameters it was opened with, as a
/// link: `{canvasId}?key=value`, or the screen's own URL path when it has one
/// (`guide/bat-star` for a screen at `guide/:id`, see
/// [Codelessly.pathOf]). Hosts put it in the browser's address (see
/// [Codelessly.route]) and hand it back on a reload or a shared link (see
/// [Codelessly.pendingRoute]), so it opens the same screen with the same
/// parameters.
class CodelesslyRoute {
  /// The screen (canvas) id. For a link read from a URL path, its last
  /// segment, which [path] may resolve to another screen.
  final String canvasId;

  /// The parameters the screen was opened with (`${route.key}`).
  final Map<String, String> params;

  /// The whole path of a link read by [tryParse], such as `guide/bat-star`,
  /// matched against the screens' URL paths when it opens.
  final String? path;

  const CodelesslyRoute(this.canvasId, [this.params = const {}, this.path]);

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
    return CodelesslyRoute(
      segments.last,
      uri.queryParameters,
      segments.join('/'),
    );
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

import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';

import '../model/sdk_publish_model.dart';

/// The canvas a location opens and the route params it passes to it.
class CanvasLocationMatch {
  /// The layout that holds [canvasId].
  final String layoutId;

  /// The canvas whose path matched.
  final String canvasId;

  /// The path params, such as `id` for `guide/:id`, over the query params.
  final Map<String, dynamic> params;

  /// Creates a [CanvasLocationMatch].
  const CanvasLocationMatch({
    required this.layoutId,
    required this.canvasId,
    required this.params,
  });
}

/// Maps locations (URL paths relative to a published app's root) to canvases
/// by their [CanvasProperties.path], and back.
abstract final class CanvasLocation {
  /// The segments of a path or path pattern, without empty ones.
  static List<String> segmentsOf(String path) => path
      .split('/')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();

  /// The canvas node of [canvasId] in [layout], if loaded.
  static CanvasNode? canvasOf(SDKPublishLayout layout, String canvasId) {
    final BaseNode? node = layout.canvases[canvasId]?[canvasId];
    return node is CanvasNode ? node : null;
  }

  /// The params [pattern] takes from [segments], or null when it does not
  /// match them.
  static Map<String, String>? matchPattern(
    List<String> pattern,
    List<String> segments,
  ) {
    if (pattern.length != segments.length) return null;
    final Map<String, String> params = {};
    for (int i = 0; i < pattern.length; i++) {
      if (pattern[i].startsWith(':') && pattern[i].length > 1) {
        params[pattern[i].substring(1)] = segments[i];
      } else if (pattern[i] != segments[i]) {
        return null;
      }
    }
    return params;
  }

  /// The ids of the canvases of layout [layoutId]: those of the loaded
  /// layout, else those [SDKPublishUpdates.layoutCanvases] lists for it.
  static List<String> canvasIdsOf(SDKPublishModel model, String layoutId) =>
      model.layouts[layoutId]?.canvasIds.toList() ??
      model.updates.layoutCanvases[layoutId]?.toList() ??
      <String>[];

  /// The ids of the layouts of [model] that can be shown: loaded ones and
  /// those only listed in [SDKPublishUpdates.layoutCanvases], without
  /// disabled ones.
  static Iterable<String> layoutIdsOf(SDKPublishModel model) => {
    ...model.layouts.keys,
    ...model.updates.layoutCanvases.keys,
  }.where((layoutId) => !model.disabledLayouts.contains(layoutId));

  /// The path pattern of canvas [canvasId], such as `guide/:id`: the loaded
  /// canvas's, else the one [SDKPublishUpdates.canvasPaths] holds. Null when
  /// it has none.
  static String? pathOf(SDKPublishModel model, String canvasId) {
    String? path;
    for (final SDKPublishLayout layout in model.layouts.values) {
      if (!layout.canvasIds.contains(canvasId)) continue;
      path = canvasOf(layout, canvasId)?.properties.path;
      break;
    }
    path ??= model.updates.canvasPaths[canvasId];
    if (path == null || segmentsOf(path).isEmpty) return null;
    return segmentsOf(path).join('/');
  }

  /// The path pattern of layout [layoutId]: that of its first canvas (one
  /// per breakpoint) that has one. Null when none has.
  static String? layoutPathOf(SDKPublishModel model, String layoutId) {
    for (final String canvasId in canvasIdsOf(model, layoutId)) {
      final String? path = pathOf(model, canvasId);
      if (path != null) return path;
    }
    return null;
  }

  /// The canvas of [model] whose path matches [location], such as
  /// `guide/bat-star?x=1` for a canvas at `guide/:id`. Its params are the path
  /// params (`id: bat-star`) over the query params (`x: 1`). When several
  /// canvases match, the one with the most literal segments wins, so
  /// `guide/new` beats `guide/:id`. Null when no canvas matches.
  static CanvasLocationMatch? match(SDKPublishModel model, String location) {
    final Uri uri = Uri.parse(location.trim());
    final List<String> segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return null;

    CanvasLocationMatch? best;
    int bestLiterals = -1;
    for (final String layoutId in layoutIdsOf(model)) {
      for (final String canvasId in canvasIdsOf(model, layoutId)) {
        final String? path = pathOf(model, canvasId);
        if (path == null) continue;
        final List<String> pattern = segmentsOf(path);
        final Map<String, String>? params = matchPattern(pattern, segments);
        if (params == null) continue;
        final int literals = pattern.length - params.length;
        if (literals <= bestLiterals) continue;
        bestLiterals = literals;
        best = CanvasLocationMatch(
          layoutId: layoutId,
          canvasId: canvasId,
          params: {...uri.queryParameters, ...params},
        );
      }
    }
    return best;
  }

  /// The location of the screen [destinationId] (a canvas or layout id) opened
  /// with [params]: its path with `:name` segments filled from [params], and
  /// the other params as the query. The entry screen without a path is at the
  /// root (an empty path). Null when the screen has no path or [params] lack
  /// one of its path params.
  static String? locationOf(
    SDKPublishModel model,
    String destinationId,
    Map<String, dynamic> params,
  ) {
    final String? layoutId = model.resolveLayoutId(destinationId);
    if (layoutId == null) return null;

    // The destination canvas's path, else that of a canvas for another
    // breakpoint of its layout.
    final String? path =
        pathOf(model, destinationId) ?? layoutPathOf(model, layoutId);
    if (path == null && model.entryLayoutId != layoutId) return null;
    return fill(path ?? '', params);
  }

  /// [pattern] with its `:name` segments filled from [params] and the other
  /// params as the query, such as `guide/bat-star?x=1`. Null when [params]
  /// lack one of its path params.
  static String? fill(String pattern, Map<String, dynamic> params) {
    final Map<String, dynamic> query = {...params};
    final List<String> segments = [];
    for (final String segment in segmentsOf(pattern)) {
      if (segment.startsWith(':') && segment.length > 1) {
        final String value = _stringOf(query.remove(segment.substring(1)));
        if (value.isEmpty) return null;
        segments.add(value);
      } else {
        segments.add(segment);
      }
    }
    query.removeWhere((key, value) => value == null);

    return Uri(
      pathSegments: segments,
      queryParameters: query.isEmpty
          ? null
          : query.map((key, value) => MapEntry(key, _stringOf(value))),
    ).toString();
  }

  /// [value] as it is written in a link: text as is, lists and maps as JSON.
  static String stringOf(Object? value) => _stringOf(value);

  static String _stringOf(Object? value) => switch (value) {
    null => '',
    String() => value,
    Map() || List() => jsonEncode(value),
    _ => '$value',
  };
}

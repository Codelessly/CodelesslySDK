// Screens as locations: a canvas's URL path (`guide/:id`) and the params a
// screen is opened with, and the routes CodelesslyWidget pushes for
// navigation actions.
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart' show ActionDef, Json, NavigateAction, PublishModel;
import 'package:flutter/foundation.dart';

/// A screen of a Codelessly app and the params it was opened with.
@immutable
class CodelesslyRoute {
  const CodelesslyRoute(this.layoutId, this.canvasId, [this.params = const {}]);

  final String layoutId;

  /// The canvas shown (the one for the current breakpoint).
  final String canvasId;

  /// The params it was opened with (`route.<name>` in the layout).
  final Map<String, Object?> params;

  @override
  bool operator ==(Object other) =>
      other is CodelesslyRoute &&
      other.layoutId == layoutId &&
      other.canvasId == canvasId &&
      mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(layoutId, canvasId, Object.hashAllUnordered(params.entries.map((e) => '${e.key}=${e.value}')));

  @override
  String toString() => 'CodelesslyRoute($layoutId/$canvasId $params)';
}

/// The screen a location opens and the params it passes to it.
@immutable
class CanvasLocationMatch {
  const CanvasLocationMatch({required this.layoutId, required this.canvasId, required this.params});

  final String layoutId;
  final String canvasId;

  /// The path params (`id` for `guide/:id`) over the query params.
  final Map<String, String> params;
}

/// Maps locations (URL paths relative to an app's root) to screens by their
/// canvases' paths ([PublishCanvas.path]), and back.
abstract final class CanvasLocation {
  /// The segments of a path or path pattern, without empty ones.
  static List<String> segmentsOf(String path) =>
      path.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  /// Whether [segment] of a path pattern is a catch-all: `*name` (or a bare
  /// `*`, named `path`) as the last segment takes the rest of the location.
  static bool isCatchAll(String segment) => segment.startsWith('*');

  /// The param name of catch-all [segment].
  static String catchAllName(String segment) => segment.length > 1 ? segment.substring(1) : 'path';

  /// The params [pattern] takes from [segments], or null when it doesn't
  /// match them.
  static Map<String, String>? matchPattern(List<String> pattern, List<String> segments) {
    final catchAll = pattern.isNotEmpty && isCatchAll(pattern.last);
    if (catchAll ? segments.length < pattern.length : pattern.length != segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      if (catchAll && i == pattern.length - 1) {
        params[catchAllName(pattern[i])] = segments.sublist(i).join('/');
      } else if (pattern[i].startsWith(':') && pattern[i].length > 1) {
        params[pattern[i].substring(1)] = segments[i];
      } else if (pattern[i] != segments[i]) {
        return null;
      }
    }
    return params;
  }

  /// The path pattern of canvas [canvasId], normalized; null when it has
  /// none.
  static String? pathOf(PublishModel model, String canvasId) {
    final path = model.canvas(canvasId)?.path;
    if (path == null || segmentsOf(path).isEmpty) return null;
    return segmentsOf(path).join('/');
  }

  /// The path pattern of layout [layoutId]: that of its first canvas (one
  /// per breakpoint) that has one.
  static String? layoutPathOf(PublishModel model, String layoutId) {
    for (final c in model.layouts[layoutId]?.canvases ?? const []) {
      final p = pathOf(model, c.id);
      if (p != null) return p;
    }
    return null;
  }

  /// The screen of [model] whose path matches [location] (`guide/bat-star?x=1`
  /// for a canvas at `guide/:id`), with the path params over the query
  /// params. The match with the most literal segments wins (`guide/new`
  /// beats `guide/:id`), and a catch-all loses to any other. Null when none
  /// matches.
  static CanvasLocationMatch? match(PublishModel model, String location) {
    final uri = Uri.parse(location.trim());
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    CanvasLocationMatch? best;
    var bestRank = -1;
    for (final layout in model.layouts.values) {
      if (model.disabledLayouts.contains(layout.id)) continue;
      for (final canvas in layout.canvases) {
        final path = pathOf(model, canvas.id);
        if (path == null) continue;
        final pattern = segmentsOf(path);
        final catchAll = pattern.isNotEmpty && isCatchAll(pattern.last);
        final params = matchPattern(pattern, segments);
        if (params == null) continue;
        final rank = (catchAll ? 0 : 1000) + pattern.length - params.length;
        if (rank <= bestRank) continue;
        bestRank = rank;
        best = CanvasLocationMatch(
          layoutId: layout.id,
          canvasId: canvas.id,
          params: {...uri.queryParameters, ...params},
        );
      }
    }
    return best;
  }

  /// The location of screen [destinationId] (a canvas or layout id) opened
  /// with [params]: its path with `:name` segments filled from [params] and
  /// the other params as the query. The entry screen without a path is at
  /// the root (an empty path). Null when the screen has no path or [params]
  /// lack one of its path params.
  static String? locationOf(PublishModel model, String destinationId, Map<String, Object?> params) {
    final layoutId = model.resolveLayoutId(destinationId);
    if (layoutId == null) return null;
    final path = pathOf(model, destinationId) ?? layoutPathOf(model, layoutId);
    if (path == null && model.entryLayoutId != layoutId) return null;
    return fill(path ?? '', params);
  }

  /// [pattern] with its `:name` segments filled from [params] and the other
  /// params as the query. Null when [params] lack one of its path params.
  static String? fill(String pattern, Map<String, Object?> params) {
    final query = {...params};
    final segments = <String>[];
    for (final segment in segmentsOf(pattern)) {
      if (isCatchAll(segment)) {
        final value = stringOf(query.remove(catchAllName(segment)));
        if (value.isEmpty) return null;
        segments.addAll(segmentsOf(value));
      } else if (segment.startsWith(':') && segment.length > 1) {
        final value = stringOf(query.remove(segment.substring(1)));
        if (value.isEmpty) return null;
        segments.add(value);
      } else {
        segments.add(segment);
      }
    }
    query.removeWhere((_, v) => v == null);
    return Uri(
      pathSegments: segments,
      queryParameters: query.isEmpty ? null : query.map((k, v) => MapEntry(k, stringOf(v))),
    ).toString();
  }

  /// [value] as written in a link: text as is, lists and maps as JSON.
  static String stringOf(Object? value) => switch (value) {
        null => '',
        final String s => s,
        Map() || List() => jsonEncode(value),
        _ => '$value',
      };
}

/// What a navigation action (`{"type": "navigate", ...}`) asks for.
@immutable
class NavigationRequest {
  const NavigationRequest({
    this.type = NavigationType.push,
    this.destinationId = '',
    this.params = const {},
    this.baseDestinationId,
    this.baseParams = const {},
  });

  /// [action] with its params (evaluated) [params] and [baseParams].
  factory NavigationRequest.fromAction(NavigateAction action, {Json? params, Json? baseParams}) => NavigationRequest(
        type: NavigationType.values[action.mode.index],
        destinationId: action.to,
        params: params ?? action.params,
        baseDestinationId: action.base.isEmpty ? null : action.base,
        baseParams: baseParams ?? action.baseParams,
      );

  /// Reads a navigation action's JSON.
  factory NavigationRequest.fromJson(Map<String, Object?> action) => switch (ActionDef.fromJson(action)) {
        final NavigateAction a => NavigationRequest.fromAction(a),
        _ => const NavigationRequest(),
      };

  final NavigationType type;

  /// The screen to open: a canvas or layout id.
  final String destinationId;
  final Map<String, Object?> params;

  /// For [NavigationType.reset]: the screen left beneath the destination.
  final String? baseDestinationId;
  final Map<String, Object?> baseParams;
}

/// How a navigation action moves between screens.
enum NavigationType {
  /// Opens the screen above the current one.
  push,

  /// Goes back (with a destination: goes there when there's nothing to go
  /// back to).
  pop,

  /// Replaces the current screen.
  replace,

  /// Clears the history and opens the screen (above its base screen, if set).
  reset,
}

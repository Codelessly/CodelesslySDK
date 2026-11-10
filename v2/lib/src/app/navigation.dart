// Screens as locations: a canvas's URL path (`guide/:id`) and the params a
// screen is opened with, and the routes CodelesslyWidget pushes for
// navigation actions.
import 'dart:convert';

import 'package:codelessly_api_v2/codelessly_api.dart'
    show ActionDef, Json, NavigateAction, PageTransition, PublishModel, RouteTransition;
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

  /// The URL path of a screen named [name] that has no path of its own: its
  /// name's words in lowercase joined by `-` (`Log entry` is `log-entry`),
  /// so a published screen's address reads as its name, not its id (the
  /// editor publishes it). Null when the name has no letters or digits.
  static String? defaultPathOf(String? name) {
    final slug = (name ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? null : slug;
  }

  /// [path], or `path-2`, `path-3`... the first that [taken] lacks.
  static String uniquePath(String path, Set<String> taken) {
    var candidate = path;
    for (var n = 2; taken.contains(candidate); n++) {
      candidate = '$path-$n';
    }
    return candidate;
  }

  /// Whether [segment] of a path pattern is a catch-all: `*name` (or a bare
  /// `*`, named `path`) as the last segment takes the rest of the location.
  static bool isCatchAll(String segment) => segment.startsWith('*');

  /// Whether [segment] of a path pattern is an optional param: `:name?`,
  /// which a location may leave out from the end (`sheet/:id?` is both
  /// `sheet` and `sheet/doom`).
  static bool isOptional(String segment) => segment.length > 2 && segment.startsWith(':') && segment.endsWith('?');

  /// The param name of [segment]: `id` for `:id` and `:id?`.
  static String paramName(String segment) =>
      isOptional(segment) ? segment.substring(1, segment.length - 1) : segment.substring(1);

  /// The patterns [pattern] stands for, one per number of its trailing
  /// optional params given, longest first (`sheet/:id?` is `sheet/:id` and
  /// `sheet`).
  static List<String> expandOptional(String pattern) {
    final segments = segmentsOf(pattern);
    var required = segments.length;
    while (required > 0 && isOptional(segments[required - 1])) {
      required--;
    }
    return [
      for (var n = segments.length; n >= required; n--)
        [for (final s in segments.take(n)) isOptional(s) ? ':${paramName(s)}' : s].join('/'),
    ];
  }

  /// The param name of catch-all [segment].
  static String catchAllName(String segment) => segment.length > 1 ? segment.substring(1) : 'path';

  /// The params [pattern] takes from [segments], or null when it doesn't
  /// match them. Trailing optional params (`:id?`) may be left out.
  static Map<String, String>? matchPattern(List<String> pattern, List<String> segments) {
    final catchAll = pattern.isNotEmpty && isCatchAll(pattern.last);
    var required = pattern.length;
    while (!catchAll && required > 0 && isOptional(pattern[required - 1])) {
      required--;
    }
    if (catchAll ? segments.length < pattern.length : segments.length < required || segments.length > pattern.length) {
      return null;
    }
    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      if (!catchAll && i >= segments.length) break; // optional, left out
      if (catchAll && i == pattern.length - 1) {
        params[catchAllName(pattern[i])] = segments.sublist(i).join('/');
      } else if (pattern[i].startsWith(':') && pattern[i].length > 1) {
        params[paramName(pattern[i])] = segments[i];
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
      } else if (isOptional(segment)) {
        // Left out when not given, and so is everything after it.
        final value = stringOf(query.remove(paramName(segment)));
        if (value.isEmpty) continue;
        segments.add(value);
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

  /// [location] at its screen's URL path when it names the screen by id: a
  /// link to `{canvasId}?entryId=l2` (or a layout id) of a screen at
  /// `log/:entryId` is `log/l2`, and the entry screen's id is the root
  /// (empty), so the address shows the path. Other locations, and a screen
  /// without a path or a link lacking one of its params, as they are.
  static String named(PublishModel model, String location) {
    final Uri uri;
    try {
      uri = Uri.parse(location.trim());
    } on FormatException {
      return location;
    }
    final segments = segmentsOf(uri.path);
    if (segments.length != 1) return location;
    final id = segments.single;
    if (model.resolveLayoutId(id) == null) return location;
    final path = locationOf(model, id, uri.queryParameters);
    if (path == null) return location;
    // A screen whose path is its id.
    return Uri.parse(path).path == uri.path || Uri.parse(path).path == id ? location : path;
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
    this.routeTransition,
    this.transition = PageTransition.platform,
    this.transitionMs,
    this.reverseTransitionMs,
  });

  /// [action] with its params (evaluated) [params] and [baseParams].
  factory NavigationRequest.fromAction(NavigateAction action, {Json? params, Json? baseParams}) => NavigationRequest(
        type: NavigationType.values[action.mode.index],
        destinationId: action.to,
        params: params ?? action.params,
        baseDestinationId: action.base.isEmpty ? null : action.base,
        baseParams: baseParams ?? action.baseParams,
        routeTransition: action.routeTransition,
        transition: action.transition,
        transitionMs: action.transitionMs,
        reverseTransitionMs: action.reverseTransitionMs,
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

  /// The custom transition the destination opens with (it replaces
  /// [transition]); null: [transition].
  final RouteTransition? routeTransition;

  /// The page transition the destination opens with ([PageTransition.platform]
  /// plays none on the web), over [transitionMs] (and back over
  /// [reverseTransitionMs]); null: the transition's own duration.
  final PageTransition transition;
  final int? transitionMs, reverseTransitionMs;
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

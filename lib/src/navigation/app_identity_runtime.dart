import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../model/sdk_publish_model.dart';
import '../ui/canvas_location.dart';
import 'codelessly_router.dart';

/// The title and description of one screen, from the app's [AppIdentity].
@immutable
class ScreenIdentity {
  /// The document / task-switcher title.
  final String title;

  /// The meta description, when there is one.
  final String? description;

  /// The layout shown, when known.
  final String? layoutId;

  const ScreenIdentity({
    required this.title,
    this.description,
    this.layoutId,
  });

  @override
  bool operator ==(Object other) =>
      other is ScreenIdentity &&
      other.title == title &&
      other.description == description &&
      other.layoutId == layoutId;

  @override
  int get hashCode => Object.hash(title, description, layoutId);

  @override
  String toString() => 'ScreenIdentity($title, $description, $layoutId)';
}

/// Reads a published app's [AppIdentity] (see [SDKPublishModel.appIdentity])
/// for host apps: screen titles, descriptions and colors.
abstract final class CodelesslyAppIdentity {
  /// The identity of [model], or null when it has none.
  static AppIdentity? of(SDKPublishModel? model) => model?.appIdentity;

  /// `#RRGGBB` / `#RRGGBBAA` as a [Color], or null.
  static Color? parseColor(String? hex) {
    final String? normalized = normalizeHexColor(hex);
    if (normalized == null) return null;
    final String digits = normalized.substring(1);
    final int rgb = int.parse(digits.substring(0, 6), radix: 16);
    final int a = digits.length == 8
        ? int.parse(digits.substring(6), radix: 16)
        : 0xFF;
    return Color((a << 24) | rgb);
  }

  /// The layout shown at [location] (like `/guide/bat-star`): the screen
  /// whose URL path matches, else the screen whose id is the first segment,
  /// else, for `/`, the entry screen.
  static String? layoutIdAt(SDKPublishModel model, String location) {
    final String path = Uri.parse(location).path;
    final List<String> segments = CanvasLocation.segmentsOf(path);
    if (segments.isEmpty) return model.resolveLayoutId(model.entryLayoutId);
    final CanvasLocationMatch? match = CanvasLocation.match(model, location);
    if (match != null) return match.layoutId;
    return model.resolveLayoutId(segments.first);
  }

  /// The [PageIdentity] for [layoutId]: an override keyed by the layout id,
  /// one of its canvas ids, or its page id.
  static PageIdentity? pageOf(
    SDKPublishModel model,
    AppIdentity identity,
    String layoutId,
  ) {
    final SDKPublishLayout? layout = model.layouts[layoutId];
    for (final String key in [
      layoutId,
      ...?layout?.canvasIds,
      ?layout?.pageId,
    ]) {
      final PageIdentity? page = identity.pages[key];
      if (page != null) return page;
    }
    return null;
  }

  /// The name of [layoutId]'s first screen (its canvas's name).
  static String? screenNameOf(SDKPublishModel model, String layoutId) {
    final SDKPublishLayout? layout = model.layouts[layoutId];
    if (layout == null) return null;
    for (final MapEntry<String, Map<String, BaseNode>> canvas
        in layout.canvases.entries) {
      final BaseNode? node = canvas.value[canvas.key];
      if (node != null && node.name.trim().isNotEmpty) return node.name.trim();
    }
    return null;
  }

  /// The title and description of the screen [layoutId] (null: the home
  /// page), from [model]'s identity. Without one, [fallbackName] alone.
  ///
  /// The entry screen is titled with the app name only, unless it has an
  /// override.
  static ScreenIdentity resolve(
    SDKPublishModel model, {
    String? layoutId,
    String fallbackName = '',
  }) {
    final AppIdentity identity = model.appIdentity ?? const AppIdentity();
    final String appName = identity.appName(fallbackName);
    if (layoutId == null) {
      return ScreenIdentity(
        title: renderTitle(identity.titleTemplate, appName: appName),
        description: identity.description,
      );
    }
    final PageIdentity? page = pageOf(model, identity, layoutId);
    final bool isEntry =
        layoutId == model.resolveLayoutId(model.entryLayoutId);
    final String? pageTitle =
        page?.title ??
        (isEntry ? null : page?.name ?? screenNameOf(model, layoutId));
    return ScreenIdentity(
      title: renderTitle(
        identity.titleTemplate,
        appName: appName,
        pageTitle: pageTitle,
      ),
      description: page?.description ?? identity.description,
      layoutId: layoutId,
    );
  }

  /// Sets the browser tab title (document.title on web) and the task
  /// switcher label and color on Android.
  static Future<void> applyTitle(String title, {Color? color}) =>
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(
          label: title,
          primaryColor: color?.toARGB32(),
        ),
      );

  /// The status bar style [identity] asks for, or null for "auto".
  static SystemUiOverlayStyle? overlayStyleOf(AppIdentity identity) =>
      switch (identity.mobile.statusBarStyle) {
        StatusBarStyle.light => SystemUiOverlayStyle.light,
        StatusBarStyle.dark => SystemUiOverlayStyle.dark,
        StatusBarStyle.auto => null,
      };
}

/// Keeps the title (and, through [onChanged], anything else such as the
/// meta description) in step with the screen a [CodelesslyRouter] shows.
///
/// ```dart
/// final updater = CodelesslyAppIdentityUpdater(router)..attach();
/// ```
class CodelesslyAppIdentityUpdater {
  /// The router whose top screen titles the app.
  final CodelesslyRouter router;

  /// The name used when the app's identity has none.
  final String fallbackName;

  /// Called with each new screen identity, after the title is applied.
  final void Function(ScreenIdentity identity)? onChanged;

  /// Whether to set the title through [CodelesslyAppIdentity.applyTitle].
  final bool applyTitle;

  ScreenIdentity? _last;

  /// The identity last applied.
  ScreenIdentity? get current => _last;

  /// Creates an updater. Call [attach] to start.
  CodelesslyAppIdentityUpdater(
    this.router, {
    this.fallbackName = '',
    this.onChanged,
    this.applyTitle = true,
  });

  /// Starts following the router.
  void attach() {
    router.delegate.addListener(update);
    update();
  }

  /// Stops following the router.
  void detach() => router.delegate.removeListener(update);

  /// Applies the identity of the screen on top, when it changed.
  void update() {
    final SDKPublishModel? model = router.delegate.publishModel;
    if (model == null) return;
    final String location = router.delegate.historyEntry.stack.isEmpty
        ? '/'
        : router.delegate.historyEntry.stack.last;
    final String? layoutId = CodelesslyAppIdentity.layoutIdAt(model, location);
    final ScreenIdentity next = CodelesslyAppIdentity.resolve(
      model,
      layoutId: layoutId,
      fallbackName: fallbackName,
    );
    if (next == _last) return;
    _last = next;
    if (applyTitle) {
      CodelesslyAppIdentity.applyTitle(
        next.title,
        color: CodelesslyAppIdentity.parseColor(
          model.appIdentity?.themeColor,
        ),
      );
    }
    onChanged?.call(next);
  }
}

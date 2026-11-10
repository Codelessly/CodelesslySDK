// A published app's identity at runtime: each screen's title and
// description from the publish model's `appIdentity`, and the title
// applied to the browser tab and the task switcher as screens change.
// SDK 8.x's CodelessyAppIdentity and CodelesslyAppIdentityUpdater.
import 'package:codelessly_api/codelessly_api.dart' show AppIdentity, PageIdentity, PublishModel, renderTitle;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'codelessly.dart';
import 'navigation.dart';

/// The title and description of one screen.
@immutable
class ScreenIdentity {
  const ScreenIdentity({required this.title, this.description, this.layoutId});

  /// The document and task switcher title.
  final String title;

  /// The meta description, when there is one.
  final String? description;
  final String? layoutId;

  @override
  bool operator ==(Object other) =>
      other is ScreenIdentity && other.title == title && other.description == description && other.layoutId == layoutId;

  @override
  int get hashCode => Object.hash(title, description, layoutId);

  @override
  String toString() => 'ScreenIdentity($title, $description, $layoutId)';
}

/// Reads a published app's [AppIdentity] for app shells.
abstract final class CodelesslyAppIdentity {
  /// A CSS hex color (`#RRGGBB`, `#RRGGBBAA`) as a [Color], or null.
  static Color? parseColor(String? hex) {
    if (hex == null) return null;
    final digits = hex.trim().replaceFirst('#', '');
    if (digits.length != 6 && digits.length != 8) return null;
    final rgb = int.tryParse(digits.substring(0, 6), radix: 16);
    final a = digits.length == 8 ? int.tryParse(digits.substring(6), radix: 16) : 0xFF;
    if (rgb == null || a == null) return null;
    return Color((a << 24) | rgb);
  }

  /// The layout shown at [location] (`/guide/bat-star`): a screen without a
  /// URL path is at `/<its id>`, which wins over a catch-all (`*path`)
  /// screen; else the screen whose path matches; else the screen whose id
  /// is the first segment; the entry screen at `/`.
  static String? layoutIdAt(PublishModel model, String location) {
    final path = Uri.parse(location).path;
    final segments = CanvasLocation.segmentsOf(path);
    if (segments.isEmpty) return model.resolveLayoutId(model.entryLayoutId ?? '');
    if (segments.length == 1) {
      final byId = model.resolveLayoutId(segments.first);
      if (byId != null) return byId;
    }
    final match = CanvasLocation.match(model, location);
    if (match != null) return match.layoutId;
    return model.resolveLayoutId(segments.first);
  }

  /// The override for layout [layoutId]: by the layout id, one of its
  /// canvas ids, or its page id.
  static PageIdentity? pageOf(PublishModel model, AppIdentity identity, String layoutId) {
    final info = model.layouts[layoutId];
    return identity.pageOf([layoutId, ...?info?.canvases.map((c) => c.id), if (info != null && info.pageId.isNotEmpty) info.pageId]);
  }

  /// The name of layout [layoutId]'s first named screen.
  static String? screenNameOf(PublishModel model, String layoutId) {
    for (final c in model.layouts[layoutId]?.canvases ?? const []) {
      if (c.name.trim().isNotEmpty) return c.name.trim();
    }
    return null;
  }

  /// The title and description of screen [layoutId] (null: the home page)
  /// from [model]'s identity; without one, [fallbackName] alone. The entry
  /// screen is titled with the app name only, unless it has an override.
  static ScreenIdentity resolve(PublishModel model, {String? layoutId, String fallbackName = ''}) {
    final identity = model.appIdentity ?? AppIdentity.none;
    final appName = identity.appName(fallbackName);
    if (layoutId == null) {
      return ScreenIdentity(title: renderTitle(identity.titleTemplate, appName: appName), description: identity.description);
    }
    final page = pageOf(model, identity, layoutId);
    final isEntry = layoutId == model.resolveLayoutId(model.entryLayoutId);
    final pageTitle = page?.title ?? (isEntry ? null : page?.name ?? screenNameOf(model, layoutId));
    return ScreenIdentity(
      title: renderTitle(identity.titleTemplate, appName: appName, pageTitle: pageTitle),
      description: page?.description ?? identity.description,
      layoutId: layoutId,
    );
  }

  /// Sets the browser tab title (on the web) and the task switcher label
  /// and color (Android).
  static Future<void> applyTitle(String title, {Color? color}) => SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(label: title, primaryColor: color?.toARGB32()),
      );
}

/// Keeps the app's title (and, through [onChanged], anything else such as
/// the meta description) in step with the screen [codelessly] shows.
///
/// ```dart
/// final updater = CodelesslyAppIdentityUpdater(Codelessly.instance)..attach();
/// ```
class CodelesslyAppIdentityUpdater {
  CodelesslyAppIdentityUpdater(this.codelessly, {this.fallbackName = '', this.onChanged, this.applyTitle = true});

  final Codelessly codelessly;

  /// The name used when the identity has none.
  final String fallbackName;

  /// Called with each new screen identity, after the title is applied.
  final void Function(ScreenIdentity identity)? onChanged;

  /// Whether to set the title ([CodelesslyAppIdentity.applyTitle]).
  final bool applyTitle;

  ScreenIdentity? _last;

  /// The identity last applied.
  ScreenIdentity? get current => _last;

  void attach() {
    codelessly.route.addListener(update);
    update();
  }

  void detach() => codelessly.route.removeListener(update);

  /// Applies the identity of the screen shown, when it changed.
  void update() {
    final model = codelessly.publishModel;
    if (model == null) return;
    final CodelesslyRoute? route = codelessly.route.value;
    final next = CodelesslyAppIdentity.resolve(model, layoutId: route?.layoutId, fallbackName: fallbackName);
    if (next == _last) return;
    _last = next;
    if (applyTitle) {
      CodelesslyAppIdentity.applyTitle(next.title, color: CodelesslyAppIdentity.parseColor(model.appIdentity?.themeColor));
    }
    onChanged?.call(next);
  }
}

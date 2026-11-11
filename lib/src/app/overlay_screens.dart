// Overlay screens: layouts with an overlay canvas (`CanvasProps.overlay`),
// drawn above every screen of the app, outside navigation (a podcast app's
// mini player and tab bar staying while the screens under them change).
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'backdrop_screens.dart';
import 'codelessly.dart';
import 'codelessly_widget.dart';

/// Marks the widgets of an overlay screen.
///
/// An overlay screen isn't the screen the app is on, so it leaves the app's
/// navigation state alone: it doesn't report itself as the current route
/// ([Codelessly.route]) and doesn't add overlay screens of its own.
class OverlayScreenScope extends InheritedWidget {
  const OverlayScreenScope({super.key, required this.layoutId, required super.child});

  /// The overlay screen's layout.
  final String layoutId;

  /// Whether [context] is inside an overlay screen.
  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<OverlayScreenScope>() != null;

  @override
  bool updateShouldNotify(OverlayScreenScope oldWidget) => false;
}

/// Shows a project's overlay screens ([PublishModel.overlays]) above the
/// screens of the navigator a [CodelesslyWidget] is in.
///
/// Each overlay screen is an entry in the navigator's [Overlay]. Entries
/// that aren't routes' stay above every route the navigator pushes,
/// replaces or resets, so an overlay screen persists across navigation,
/// keeping its state while screens change under it. One entry is kept per
/// overlay screen, project and navigator: the first [CodelesslyWidget] that
/// shows a screen there adds them, and they follow republishes (an overlay
/// screen turned off leaves).
///
/// An overlay screen's empty parts (no fill, no reactions) let taps through
/// to the screen below; give its canvas no background. Its navigation
/// actions navigate the navigator it is above.
abstract final class CodelesslyOverlayHost {
  static final Expando<Map<Codelessly, _OverlayHost>> _hosts = Expando('codelessly overlay screens');

  /// Adds [codelessly]'s overlay screens above the screens of the navigator
  /// around [context], once. [currentLayoutId] is the layout [context]
  /// shows: an overlay screen isn't drawn over itself. [template] passes
  /// its data and handlers to the overlay screens.
  ///
  /// Call it after a frame (it changes the navigator's overlay).
  static void ensure(
    BuildContext context, {
    required Codelessly codelessly,
    String? currentLayoutId,
    CodelesslyWidget? template,
  }) {
    if (!context.mounted || OverlayScreenScope.of(context) || BackdropScreenScope.of(context)) return;
    final overlay = Navigator.maybeOf(context)?.overlay;
    if (overlay == null) return;
    final hosts = _hosts[overlay] ??= {};
    final host = hosts[codelessly] ??= _OverlayHost(overlay, codelessly, template, () => hosts.remove(codelessly));
    host.sync(skip: currentLayoutId);
  }

  /// The overlay screens shown above [navigator] for [codelessly], by
  /// layout id.
  @visibleForTesting
  static Iterable<String> shownIn(NavigatorState navigator, Codelessly codelessly) {
    final overlay = navigator.overlay;
    return overlay == null ? const [] : _hosts[overlay]?[codelessly]?.entries.keys ?? const [];
  }
}

class _OverlayHost {
  _OverlayHost(this.overlay, this.codelessly, this.template, this.onDispose) {
    codelessly.addListener(_changed);
  }

  final OverlayState overlay;
  final Codelessly codelessly;
  final CodelesslyWidget? template;
  final VoidCallback onDispose;
  final Map<String, OverlayEntry> entries = {};

  void _changed() {
    // Republished: overlay screens may come or go. The overlay changes
    // outside a build.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => sync());
    } else {
      sync();
    }
  }

  void sync({String? skip}) {
    if (!overlay.mounted) return _dispose();
    final model = codelessly.publishModel;
    if (model == null) return;
    final wanted = model.overlays;
    for (final id in [...entries.keys]) {
      if (wanted.contains(id)) continue;
      entries.remove(id)!
        ..remove()
        ..dispose();
    }
    for (final id in wanted) {
      if (id == skip || entries.containsKey(id)) continue;
      final entry = OverlayEntry(builder: (_) => _build(id));
      entries[id] = entry;
      // Later overlay screens over earlier ones.
      overlay.insert(entry);
    }
  }

  Widget _build(String layoutId) => OverlayScreenScope(
        layoutId: layoutId,
        child: CodelesslyWidget(
          codelessly: codelessly,
          layoutId: layoutId,
          data: template?.data ?? const {},
          onNavigate: template?.onNavigate,
          paywallAppVersion: template?.paywallAppVersion ?? '',
          onActionError: template?.onActionError,
          // Nothing over the screens while it loads, or if it fails.
          loadingBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (_, _) => const SizedBox.shrink(),
        ),
      );

  void _dispose() {
    codelessly.removeListener(_changed);
    for (final entry in entries.values) {
      if (entry.mounted) entry.remove();
    }
    entries.clear();
    onDispose();
  }
}

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// Marks the widgets of an overlay screen: a canvas with
/// [CanvasProperties.overlay], drawn above every other screen of the app.
///
/// An overlay screen isn't the screen the app is on, so it leaves the
/// app's navigation state alone: it doesn't report itself to navigation or
/// breakpoint listeners and doesn't take the current route's params.
class OverlayScreenScope extends InheritedWidget {
  /// Creates an [OverlayScreenScope].
  const OverlayScreenScope({super.key, required super.child});

  /// Whether [context] is inside an overlay screen.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OverlayScreenScope>() != null;

  @override
  bool updateShouldNotify(OverlayScreenScope oldWidget) => false;
}

/// Shows a project's overlay screen above the screens of the navigator a
/// [CodelesslyWidget] is in.
///
/// The overlay is an entry in the navigator's [Overlay]. Entries that aren't
/// routes stay above every route the navigator pushes or replaces, so the
/// overlay screen persists across navigation, keeping its state (an
/// expanded player stays expanded, its animations run on) while screens
/// change under it. One entry is kept per navigator overlay; the first
/// [CodelesslyWidget] that builds there adds it.
abstract final class CodelesslyOverlayHost {
  static final Expando<_HostedOverlay> _hosted = Expando('overlay screen');

  /// The id of [model]'s overlay screen, if it has one.
  static String? overlayCanvasId(SDKPublishModel model) {
    for (final SDKPublishLayout layout in model.layouts.values) {
      for (final MapEntry<String, Map<String, BaseNode>> canvas
          in layout.canvases.entries) {
        final BaseNode? node = canvas.value[canvas.key];
        if (node is CanvasNode && node.properties.overlay) return canvas.key;
      }
    }
    return null;
  }

  /// Adds [model]'s overlay screen above the screens of the navigator around
  /// [context], unless it is already there or is the layout being shown
  /// ([currentLayoutId]): an overlay isn't drawn on top of itself.
  static void ensure(
    BuildContext context, {
    required SDKPublishModel model,
    required CodelesslyWidgetController controller,
    required String? currentLayoutId,
  }) {
    final String? canvasId = overlayCanvasId(model);
    final OverlayState? overlay = Navigator.maybeOf(context)?.overlay;
    if (overlay == null) return;
    final _HostedOverlay? hosted = _hosted[overlay];
    if (canvasId == null) {
      // The overlay was turned off and republished.
      if (hosted != null) {
        hosted.entry.remove();
        _hosted[overlay] = null;
      }
      return;
    }
    final String? layoutId = model.resolveLayoutId(canvasId);
    if (layoutId == null || layoutId == currentLayoutId) return;
    if (hosted != null && hosted.layoutId == layoutId) return;
    hosted?.entry.remove();
    final CodelesslyWidgetController overlayController = controller.copyWith(
      layoutID: layoutId,
    );
    final OverlayEntry entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: OverlayScreenScope(
          // Its empty parts let taps through to the screen below.
          child: TapThroughScope(
            child: CodelesslyWidget(
              controller: overlayController,
              overlay: true,
              // Nothing over the screen while it loads or if it fails.
              loadingBuilder: (_) => const SizedBox.shrink(),
              errorBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    _hosted[overlay] = _HostedOverlay(layoutId, entry);
    overlay.insert(entry);
  }
}

class _HostedOverlay {
  _HostedOverlay(this.layoutId, this.entry);

  final String layoutId;
  final OverlayEntry entry;
}

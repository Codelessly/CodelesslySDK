// Where a transition or an anchored modal starts from: the last tap and the
// box of the node whose reaction ran. Kept by the runtime as reactions fire;
// read by whatever shows the screen.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

/// Where a reveal grows from: the last tap, and the box of the node that
/// navigated (global).
@immutable
class RevealAnchor {
  const RevealAnchor({this.tap, this.node});

  final Offset? tap;
  final Rect? node;

  /// The last pointer down anywhere (tracked once a transition is built).
  static Offset? lastTap;

  /// The box (global) of the node whose trigger fired last: what a modal
  /// anchored to its trigger sits by.
  static Rect? lastTrigger;

  /// The box (global) of the node a modal anchored to a named node sits by
  /// (`ModalAnchor.node`), found by the action that opens it.
  static Rect? named;
  static bool _tracking = false;

  static void track() {
    if (_tracking) return;
    _tracking = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent) lastTap = event.position;
    });
  }

  /// The last tap, and [node]'s box when it's laid out.
  factory RevealAnchor.of(RenderBox? node) => RevealAnchor(
        tap: lastTap,
        node: node != null && node.attached && node.hasSize ? node.localToGlobal(Offset.zero) & node.size : null,
      );

  @override
  bool operator ==(Object other) => other is RevealAnchor && other.tap == tap && other.node == node;

  @override
  int get hashCode => Object.hash(tap, node);
}

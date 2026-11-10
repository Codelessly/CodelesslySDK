import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import '../functions/functions_repository.dart';

/// Runs [reactions] ([TriggerType.scrollEnd]) when the node's own scrollable
/// comes within [threshold] of its end, or its content doesn't fill it, as
/// infinite scroll needs: the actions load the next page.
///
/// It runs once per content length: after the content grows (the page came
/// in) reaching the end runs them again; scrolling about near the same end
/// doesn't. Scrollables nested inside the node are ignored.
class ScrollEndDetector extends StatefulWidget {
  /// The reactions to run.
  final List<Reaction> reactions;

  /// How close to the end counts, in logical pixels.
  final double threshold;

  /// The node's widget, which contains its scrollable.
  final Widget child;

  /// Creates a [ScrollEndDetector].
  const ScrollEndDetector({
    super.key,
    required this.reactions,
    required this.child,
    this.threshold = 240,
  });

  @override
  State<ScrollEndDetector> createState() => _ScrollEndDetectorState();
}

class _ScrollEndDetectorState extends State<ScrollEndDetector> {
  double? _firedAt;

  void _check(ScrollMetrics metrics) {
    if (!metrics.hasContentDimensions) return;
    if (metrics.extentAfter > widget.threshold) return;
    if (_firedAt == metrics.maxScrollExtent) return;
    _firedAt = metrics.maxScrollExtent;
    // Not during the layout that reported the metrics.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FunctionsRepository.triggerAction(
        context,
        TriggerType.scrollEnd,
        reactions: widget.reactions,
      );
    });
  }

  @override
  Widget build(BuildContext context) => NotificationListener<Notification>(
    onNotification: (notification) {
      if (notification is ScrollNotification && notification.depth == 0) {
        _check(notification.metrics);
      } else if (notification is ScrollMetricsNotification &&
          notification.depth == 0) {
        _check(notification.metrics);
      }
      return false;
    },
    child: widget.child,
  );
}

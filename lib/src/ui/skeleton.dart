import 'package:flutter/widgets.dart';

/// Tells the nodes below it that they are shown as a loading skeleton, so
/// a cloud list that is still loading builds a few sample items to shimmer
/// instead of nothing.
class SkeletonScope extends InheritedWidget {
  /// Whether the skeleton is shown.
  final bool enabled;

  const SkeletonScope({super.key, required this.enabled, required super.child});

  /// Whether the nodes at [context] are shown as a skeleton.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkeletonScope>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(SkeletonScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// How many sample items a loading cloud list shows in a skeleton.
const int kSkeletonItemCount = 3;

/// Paints [child] as a loading skeleton while [enabled]: every painted
/// pixel turns a neutral grey with a light band sweeping across it. When
/// not [enabled], [child] paints as it is; the widget tree stays the same
/// either way, so switching keeps the state below (a loading list keeps
/// its query).
class Skeleton extends StatefulWidget {
  /// Whether the skeleton is shown.
  final bool enabled;

  /// The grey the content turns.
  final Color baseColor;

  /// The colour of the sweeping band.
  final Color highlightColor;

  /// What is painted.
  final Widget child;

  const Skeleton({
    super.key,
    required this.enabled,
    this.baseColor = const Color(0xFFE3E5E8),
    this.highlightColor = const Color(0xFFF4F5F7),
    required this.child,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Skeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.enabled && !controller.isAnimating) {
      controller.repeat();
    } else if (!widget.enabled && controller.isAnimating) {
      controller.stop();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;
    return SkeletonScope(
      enabled: enabled,
      child: AnimatedBuilder(
        animation: controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          // BlendMode.dst keeps the content as it is.
          blendMode: enabled ? BlendMode.srcATop : BlendMode.dst,
          shaderCallback: (bounds) => LinearGradient(
            colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            stops: const [0.3, 0.5, 0.7],
            begin: Alignment(-2 + 3 * controller.value, -0.3),
            end: Alignment(-1 + 3 * controller.value, 0.3),
          ).createShader(bounds),
          child: child,
        ),
      ),
    );
  }
}

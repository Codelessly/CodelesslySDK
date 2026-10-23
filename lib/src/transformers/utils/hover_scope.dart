import 'package:flutter/widgets.dart';

/// Tells the nodes inside a tappable node whether a mouse is over it; they
/// read it as the `hovered` variable, for hover borders and colors.
class HoverProvider extends InheritedWidget {
  /// Whether the pointer is over the node.
  final bool hovered;

  /// Creates a [HoverProvider].
  const HoverProvider({super.key, required this.hovered, required super.child});

  /// Whether the nearest [HoverScope] above [context] is hovered, if any.
  static bool? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HoverProvider>()?.hovered;

  @override
  bool updateShouldNotify(HoverProvider oldWidget) =>
      hovered != oldWidget.hovered;
}

/// Tracks whether a mouse is over [child] and shares it through a
/// [HoverProvider].
class HoverScope extends StatefulWidget {
  /// The widget hovered.
  final Widget child;

  /// Creates a [HoverScope].
  const HoverScope({super.key, required this.child});

  @override
  State<HoverScope> createState() => _HoverScopeState();
}

class _HoverScopeState extends State<HoverScope> {
  bool _hovered = false;

  void _set(bool hovered) {
    if (hovered != _hovered) setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: HoverProvider(hovered: _hovered, child: widget.child),
    );
  }
}

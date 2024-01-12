import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class DraggableScrollConfiguration extends StatelessWidget {
  final Widget child;

  const DraggableScrollConfiguration({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const DraggableScrollBehavior(),
      child: child,
    );
  }
}

/// Used for views that can be scrolled by all devices.
class DraggableScrollBehavior extends MaterialScrollBehavior {
  const DraggableScrollBehavior();

  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

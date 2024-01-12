import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

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

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';

/// Renders one GenUI surface, e.g. inside a chat bubble.
class GenUiSurfaceView extends StatelessWidget {
  const GenUiSurfaceView({super.key, required this.surface});

  final SurfaceModel<ComponentImplementation> surface;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: A2uiSurface(key: ObjectKey(surface), surface: surface),
  );
}

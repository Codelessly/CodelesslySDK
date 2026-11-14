// What a layout shown by the runtime's presenter (Codelessly.present, an
// automation's openModal) knows about where it shows: how its close modal
// action closes it (a banner, a full-screen presentation), and that it is
// not the app's current screen.
import 'package:codelessly_api/core.dart' show ModalPresentation;
import 'package:flutter/widgets.dart';

/// Marks a presented layout: [close] (when given) is what its close modal
/// action does, with the action's result.
class CodelesslyPresentation extends InheritedWidget {
  const CodelesslyPresentation({super.key, required this.presentation, this.close, required super.child});

  /// How it shows.
  final ModalPresentation presentation;

  /// Closes it with a result; null: it closes as its route does (a dialog,
  /// a sheet).
  final void Function(Object? result)? close;

  /// The presentation [context] is in, without depending on it.
  static CodelesslyPresentation? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CodelesslyPresentation>();

  @override
  bool updateShouldNotify(CodelesslyPresentation oldWidget) =>
      presentation != oldWidget.presentation || close != oldWidget.close;
}

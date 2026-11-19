// Backdrop screens: layouts with a backdrop canvas (`CanvasProps.backdrop`),
// drawn once beneath every screen of the app, outside navigation (a sky, an
// animated starfield staying perfectly still while route transitions move
// the screens over it).
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'codelessly.dart';
import 'codelessly_widget.dart';

/// Marks the widgets of a backdrop screen.
///
/// A backdrop screen isn't the screen the app is on, so it leaves the app's
/// navigation state alone: it doesn't report itself as the current route
/// ([Codelessly.route]) and doesn't add overlay screens.
class BackdropScreenScope extends InheritedWidget {
  const BackdropScreenScope({super.key, required this.layoutId, required super.child});

  /// The backdrop screen's layout.
  final String layoutId;

  /// Whether [context] is inside a backdrop screen.
  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<BackdropScreenScope>() != null;

  @override
  bool updateShouldNotify(BackdropScreenScope oldWidget) => false;
}

/// Draws a project's backdrop screens ([PublishModel.backdrops]) once,
/// beneath [child], the app's [Navigator]. Use it as `MaterialApp.builder`
/// (a [CodelesslyPresenterHost] there draws them too):
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => CodelesslyBackdropHost(codelessly: codelessly, child: child!),
///   onGenerateRoute: CodelesslyWidget.onGenerateRoute(codelessly),
/// );
/// ```
///
/// The backdrop is outside navigation: route transitions move only the
/// screens, while the backdrop stays the same widget (its state and
/// animations go on). It can't be an entry of the navigator's [Overlay]: an
/// opaque route stops the overlay painting what is beneath it.
///
/// Screens show it through where they paint nothing: give their canvases
/// no background fill. While backdrops are shown, the app's screen routes
/// ([CodelesslyPageRoute]) play their page transition without the scrim or
/// surface color the platform's transition paints behind the screens
/// ([seeThroughPageTransitions]).
///
/// It follows republishes (a backdrop turned off leaves; one turned on
/// comes in) without rebuilding [child]. A project with no backdrop screens
/// draws [child] alone.
class CodelesslyBackdropHost extends StatefulWidget {
  const CodelesslyBackdropHost({
    super.key,
    required this.codelessly,
    this.data = const {},
    this.onActionError,
    required this.child,
  });

  /// The project.
  final Codelessly codelessly;

  /// `data.<key>` in the backdrop screens.
  final Map<String, Object?> data;

  /// Gets the failed action chains of the backdrop screens.
  final void Function(Object error, StackTrace stack, String? action)? onActionError;

  /// The app's navigator (`MaterialApp.builder`'s child).
  final Widget child;

  /// Whether [context] is beneath a [CodelesslyBackdropHost] drawing
  /// backdrop screens: the screens above should let them show through.
  static bool showsBackdrop(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BackdropShown>()?.shown ?? false;

  @override
  State<CodelesslyBackdropHost> createState() => _CodelesslyBackdropHostState();
}

class _CodelesslyBackdropHostState extends State<CodelesslyBackdropHost> {
  @override
  void initState() {
    super.initState();
    _listen(widget.codelessly);
  }

  @override
  void didUpdateWidget(CodelesslyBackdropHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.codelessly, widget.codelessly)) {
      oldWidget.codelessly.removeListener(_changed);
      _listen(widget.codelessly);
    }
  }

  void _listen(Codelessly codelessly) {
    codelessly.addListener(_changed);
    // The backdrops are listed in the publish model: load it, if the
    // screens haven't yet. A failure is theirs to show.
    if (codelessly.publishModel == null) unawaited(codelessly.initialize().catchError((Object _) {}));
  }

  /// Loaded or republished: backdrops may come or go.
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.codelessly.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final codelessly = widget.codelessly;
    final ids = codelessly.publishModel?.backdrops ?? const <String>[];
    // One Stack whatever the backdrops: the navigator keeps its element (and
    // its routes) when they come or go. It is laid out as without them; the
    // backdrops fill it.
    return _BackdropShown(
      shown: ids.isNotEmpty,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Earlier backdrops beneath later ones.
          for (final id in ids)
            Positioned.fill(
              key: ValueKey(('backdrop', codelessly, id)),
              child: BackdropScreenScope(
                layoutId: id,
                child: CodelesslyWidget(
                  codelessly: codelessly,
                  layoutId: id,
                  data: widget.data,
                  onActionError: widget.onActionError,
                  // Nothing beneath the screens while it loads, or if it fails.
                  loadingBuilder: (_) => const SizedBox.shrink(),
                  errorBuilder: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          KeyedSubtree(key: const ValueKey('screens'), child: widget.child),
        ],
      ),
    );
  }
}

class _BackdropShown extends InheritedWidget {
  const _BackdropShown({required this.shown, required super.child});

  final bool shown;

  @override
  bool updateShouldNotify(_BackdropShown oldWidget) => shown != oldWidget.shown;
}

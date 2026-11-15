// A generated screen in a box, as the storyboard shows it: a story (one
// screen for one person, which only lists what it says), a step of a flow
// (a screen put in a given state), or the running app (the kernel's current
// screen, which navigates). The box is the phone: the screen is laid out
// 390 wide and scaled to the frame it is given.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart' show CodelesslyView, UiSession;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

import '../skip_app.dart';
import 'skip_controls.dart';

/// The app and its controls, for everything under the storyboard.
class SkipScope extends InheritedWidget {
  const SkipScope({super.key, required this.app, required this.controls, required super.child});

  final SkipApp app;
  final SkipControls controls;

  static SkipScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SkipScope>()!;

  @override
  bool updateShouldNotify(SkipScope old) => app != old.app || controls != old.controls;
}

/// Shows [child] in the nearest overlay (the navigator the template's phone
/// frame puts around a page) instead of in place, at the same size. A page
/// is drawn where it was, but its render objects are no longer under the
/// page's own box.
///
/// It is here for one reason. A second after an item is chosen, and after
/// the window is resized, the template's viewer looks for annotated widgets:
/// it walks every render object under the page at every point of a 10 px
/// grid, whether or not there is an annotation. For a generated screen that
/// freezes a browser tab for over half a minute, and for the flow it does
/// not end. With the page's content in the overlay, the walk finds one box.
/// The template's Inspect mode then cannot pick a widget inside a screen.
class Detached extends StatefulWidget {
  const Detached({super.key, required this.child});

  final Widget child;

  @override
  State<Detached> createState() => _DetachedState();
}

class _DetachedState extends State<Detached> {
  final _portal = OverlayPortalController()..show();

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (context) => Positioned.fill(child: widget.child),
    child: const SizedBox.expand(),
  );
}

/// The width the screens were generated for.
const double kPhoneWidth = 390;

String _named(String s) => s[0].toUpperCase() + s.substring(1);

/// One generated screen, in its own session.
class SkipScreen extends StatefulWidget {
  const SkipScreen({
    super.key,
    required this.screen,
    this.person,
    this.state = const {},
    this.over,
    this.interactive = true,
  });

  final String screen;

  /// Whose screen; null follows the person chosen in the panel.
  final String? person;

  /// The screen's own state when it is shown (a session that is running).
  final Map<String, Object?> state;

  /// Values shown in place of the store's, worked out from it (Home after a
  /// session that has not happened).
  final Map<String, Object?> Function(Map<String, Object?> data)? over;

  /// Whether it takes taps. A story does, and lists what the screen says; a
  /// step of a flow is a picture.
  final bool interactive;

  @override
  State<SkipScreen> createState() => _SkipScreenState();
}

class _SkipScreenState extends State<SkipScreen> {
  SkipApp? _app;
  UiSession? _session;
  StreamSubscription<Object?>? _events;
  String _made = '';

  String get _who => widget.person ?? _app!.person;
  String get _key => '${_app!.ready}/${widget.screen}/$_who/${_app!.tokens}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = SkipScope.of(context).app;
    if (app == _app) return;
    _app?.removeListener(_changed);
    _drop();
    _app = app..addListener(_changed);
    _make();
  }

  @override
  void didUpdateWidget(SkipScreen old) {
    super.didUpdateWidget(old);
    if (old.screen != widget.screen || old.person != widget.person) _make();
  }

  void _drop() {
    _events?.cancel();
    _events = null;
    _app?.close(_session);
    _session = null;
  }

  void _make() {
    final app = _app!;
    _drop();
    _made = _key;
    if (!app.ready) return;
    final who = _who;
    final session = app.show(widget.screen, who: who, state: {...widget.state, ...?widget.over?.call(app.data)});
    if (session != null && widget.interactive) {
      _events = session.events.listen((e) => app.note(e, from: widget.screen, who: who));
    }
    _session = session;
  }

  void _changed() {
    if (!mounted) return;
    if (_made != _key) {
      setState(_make);
    } else if (_session != null && widget.over != null) {
      // The store reached the session already; the values shown in its
      // place follow.
      _app!.put(_session!, widget.over!(_app!.data));
    }
  }

  @override
  void dispose() {
    _app?.removeListener(_changed);
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PhoneScreen(app: _app!, session: _session, screen: widget.screen, person: _who, interactive: widget.interactive);
}

/// The running app: the kernel's current screen. Its events navigate and a
/// finished session changes the store.
class RunScreen extends StatelessWidget {
  const RunScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = SkipScope.of(context).app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => PhoneScreen(app: app, session: app.session, screen: app.screen, person: app.person),
    );
  }
}

/// A session drawn as a phone screen, or the state that stands in for it.
class PhoneScreen extends StatelessWidget {
  const PhoneScreen({
    super.key,
    required this.app,
    required this.session,
    required this.screen,
    required this.person,
    this.interactive = true,
  });

  final SkipApp app;
  final UiSession? session;
  final String screen;
  final String person;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final b = SoftSaaSTheme.brightnessOf(context);
    final session = this.session;
    if (session == null) {
      return ColoredBox(
        color: SoftSaaSTokens.primaryBackground(b),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: _standIn(b)),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.hasBoundedWidth ? box.maxWidth : kPhoneWidth;
        final height = box.hasBoundedHeight ? box.maxHeight : 844.0;
        final scale = width / kPhoneWidth;
        return SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: kPhoneWidth,
              height: height / scale,
              child: IgnorePointer(
                ignoring: !interactive,
                // A new session is a new screen: its state starts over.
                child: CodelesslyView(key: ObjectKey(session), session: session),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _standIn(Brightness b) {
    if (app.failure != null) {
      return PaneMessage(
        icon: LucideIcons.triangle_alert,
        title: 'The app could not be read',
        description:
            'Run ./tool_bundle.sh to copy the design system, the token sets and the screens into assets/. ${app.failure}',
        actionLabel: 'Try again',
        onAction: app.start,
      );
    }
    if (!app.ready) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SoftSaaSLoadingSpinner(),
          const SizedBox(height: 12),
          Text(
            'Reading the design system and the generated screens',
            textAlign: TextAlign.center,
            style: SoftSaaSTypography.bodySecondary(b),
          ),
        ],
      );
    }
    return PaneMessage(
      icon: LucideIcons.file_question_mark,
      title: 'No ${_named(screen)} screen for the $person',
      description:
          'It was not generated. Run ../tool/generate.py --design-system skip --blocks-only --persona $person --only $screen, then ./tool_bundle.sh.',
    );
  }
}

/// A pane's empty, missing or failed state: centered, borderless, a 36 px
/// icon tile (the Editor's `StudioPanelMessage`).
class PaneMessage extends StatelessWidget {
  const PaneMessage({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SoftSaaSEmptyState(
    icon: icon,
    title: title,
    description: description,
    actionLabel: actionLabel,
    onActionPressed: onAction,
    background: SoftSaaSEmptyBackground.transparent,
    border: SoftSaaSEmptyBorder.none,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    iconSize: 16,
    iconTileSize: 36,
  );
}

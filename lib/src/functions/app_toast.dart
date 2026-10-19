import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// Shows [ShowToastAction] messages: a pill near the bottom of the screen
/// that fades in, stays for the action's duration and fades out. A new toast
/// replaces the one on screen.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  /// Shows [action]'s message. Returns false when there is no overlay to
  /// show it in.
  static bool show(BuildContext context, ShowToastAction action) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;

    // Read variables now: the action that follows may navigate away.
    final String message = PropertyValueDelegate.substituteVariables(
      action.message,
      scopedValues: ScopedValues.of(context),
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );

    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastView(
        action: action,
        message: message,
        onDone: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    return true;
  }

  /// Removes the toast on screen, if any.
  static void hide() {
    final OverlayEntry? entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.action,
    required this.message,
    required this.onDone,
  });

  final ShowToastAction action;
  final String message;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  static const Duration _fade = Duration(milliseconds: 220);

  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _timer = Timer(Duration(milliseconds: widget.action.duration), () {
      if (!mounted) return;
      setState(() => _visible = false);
      _timer = Timer(_fade, widget.onDone);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShowToastAction action = widget.action;
    final Color textColor = action.textColor.toFlutterColor();
    final Widget? icon = action.icon == null
        ? null
        : retrieveIconWidget(action.icon!, 18);
    return Positioned(
      left: 16,
      right: 16,
      bottom: action.bottomOffset,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label: widget.message,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: _fade,
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: action.backgroundColor.toFlutterColor(),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[icon, const SizedBox(width: 8)],
                      Flexible(
                        child: Text(
                          widget.message,
                          style: DefaultTextStyle.of(context).style.copyWith(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

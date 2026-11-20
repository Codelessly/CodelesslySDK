// Finding the buttons of the runtime's own chrome (a toast, the confirm
// dialog, a list's Undo bar, a player's controls): they are the SDK's
// buttons, which draw their own label, so `find.text` does not see them.
import 'package:codelessly_sdk/src/render/controls/buttons.dart';
import 'package:codelessly_sdk/src/render/node_view.dart' show ControlButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The chrome's button labeled [label].
Finder shellButton(String label) =>
    find.byWidgetPredicate((w) => w is ControlButton && w.spec.label == label, description: 'the button "$label"');

/// The render object of the one button at or under [at] (a key the chrome
/// gives its button, or [shellButton]).
RenderButton shellButtonBox(WidgetTester tester, Finder at) =>
    tester.renderObject<RenderButton>(find.descendant(of: at, matching: find.byType(ControlButton), matchRoot: true));

/// The button at or under [at], as a finder (its semantics, its box).
Finder shellButtonIn(Finder at) => find.descendant(of: at, matching: find.byType(ControlButton), matchRoot: true);

// The renderer's root without an app: a document of controls laid out,
// painted, hit-tested and focused under the widget adapter alone (NodeView,
// no MaterialApp, WidgetsApp, Theme, Overlay or Navigator above it).
// direct_attach_test.dart attaches it to the view with no widget at all.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/focus.dart';
import 'package:codelessly_sdk/src/render/controls/root.dart';
import 'package:flutter/rendering.dart' show RenderConstrainedBox, BoxConstraints;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

final _doc = columnDoc({
  'save': hugging('filledButton', {'label': 'Save'}),
  'cancel': hugging('outlinedButton', {'label': 'Cancel'}),
});

void main() {
  test('a control\'s key result: handled stops there, ignored lets the scope press, passThrough goes back to the host unpressed',
      () {
    final scope = ControlFocusScope();
    var pressed = 0;
    var result = ControlKeyResult.ignored;
    final node = ControlFocusNode(RenderConstrainedBox(additionalConstraints: const BoxConstraints()),
        onActivate: () => pressed++, onKeyResult: (_) => result)
      ..join(scope);
    expect(node.requestFocus(), isTrue);
    const space = KeyDownEvent(physicalKey: PhysicalKeyboardKey.space, logicalKey: LogicalKeyboardKey.space, timeStamp: Duration.zero);
    const enter = KeyDownEvent(physicalKey: PhysicalKeyboardKey.enter, logicalKey: LogicalKeyboardKey.enter, timeStamp: Duration.zero);
    expect(scope.handleKeyEvent(space), isTrue);
    expect(pressed, 1, reason: 'ignored: the scope presses');
    result = ControlKeyResult.passThrough;
    expect(scope.handleKeyEvent(space), isFalse, reason: 'unhandled: the host (the platform\'s text input) gets it');
    expect(scope.handleKeyEvent(enter), isFalse);
    expect(pressed, 1, reason: 'nothing pressed');
    result = ControlKeyResult.handled;
    expect(scope.handleKeyEvent(enter), isTrue);
    expect(pressed, 1);
    // The bool onKey still works: false is ignored.
    node
      ..onKeyResult = null
      ..onKey = (_) => false;
    expect(scope.handleKeyEvent(enter), isTrue);
    expect(pressed, 2);
    node.leave();
  });

  testWidgets('a document lays out, paints, hit-tests and takes the keyboard under the adapter alone, with no app above it',
      (tester) async {
    final (tree, recorded) = runningTree(_doc);
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));

    // Nothing above the adapter but what every Flutter view has.
    for (final type in [WidgetsApp, Directionality, Overlay, Navigator, DefaultTextStyle]) {
      expect(find.byType(type), findsNothing, reason: '$type above the document');
    }
    final ancestors = <String>[];
    tester.element(find.byType(NodeView)).visitAncestorElements((e) {
      ancestors.add(e.widget.runtimeType.toString());
      return true;
    });
    expect(ancestors.where((a) => !const {'View', 'RawView', '_RawViewInternal', '_PipelineOwnerScope', '_ViewScope', 'RootWidget', '_MediaQueryFromView', 'MediaQuery', '_FocusInheritedScope', 'FocusScope', 'Focus', 'FocusTraversalGroup', 'Semantics'}.contains(a)
        && !a.startsWith('_')), isEmpty, reason: 'ancestors: $ancestors');

    // Laid out: the filled button hugs at SSUI's 28.
    expect(rectOf(tree, 'save').height, 28);
    // Hit-tested: a tap is the node's click.
    await tester.tapAt(centerOf(tree, 'save'));
    await tester.pump();
    expect(recorded.fired, ['save click']);

    // Focused: Tab reaches the first button, then the second; Enter and Space press.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final root = tester.renderObject<RenderControlRoot>(find.byType(NodeView));
    expect(root.focus.focused?.owner, isA<RenderBox>());
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(recorded.fired.last, 'save click');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(recorded.fired.last, 'cancel click');
  });
}

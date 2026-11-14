// A root attached straight to the view with no widget ever mounted: what a
// whole app with no widget does instead of runApp (its own isolate: the
// view must have no render view yet).
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/root.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

final _doc = columnDoc({
  'save': hugging('filledButton', {'label': 'Save'}),
  'cancel': hugging('outlinedButton', {'label': 'Cancel'}),
});

Future<Color> _pixel(WidgetTester tester, OffsetLayer layer, Size size, Offset at) async {
  final image = await tester.runAsync(() => layer.toImage(Offset.zero & size));
  final data = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final i = (at.dy.floor() * image!.width + at.dx.floor()) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  testWidgets('a root attached straight to the view, with no widget at all, lays out, paints, hit-tests and takes the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (tree, recorded) = runningTree(_doc);
    final root = RenderNodeView(tree, 'col');
    // The test binding's own render view of the implicit view (a whole app
    // gets one made by attachRoot).
    final attachment = attachRoot(root, view: tester.view, existing: tester.binding.renderViews.first);
    await tester.pump();
    // The view's child is the root itself: no element made or holds it.
    expect(attachment.renderView.child, same(root));
    expect(find.byType(NodeView), findsNothing);
    expect(root.attached, isTrue);
    expect(rectOf(tree, 'save').height, 28);

    // Painted: the filled button is SSUI's primary blue.
    final layer = attachment.renderView.debugLayer! as OffsetLayer;
    final pixel = await _pixel(tester, layer, const Size(400, 300), rectOf(tree, 'save').topLeft + const Offset(4, 14));
    expect(pixel, const Color(0xFF2563EB));

    await tester.tapAt(centreOf(tree, 'cancel'));
    await tester.pump();
    expect(recorded.fired, ['cancel click']);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(recorded.fired.last, 'save click');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'android');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(recorded.fired.last, 'save click', reason: 'Shift-Tab goes back to the first button');
    // Off the view before the test's own widget tree is torn down.
    attachment.detach();
    root.dispose();
    tree.dispose();
  });
}

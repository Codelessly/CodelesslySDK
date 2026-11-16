import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/kit.dart' show RenderControl;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';
import 'support.dart';

PublishBundle _bundle() {
  final layout = PublishLayout.fromJson({
    'schema': 3,
    'id': 'home',
    'roots': ['home'],
    'nodes': {
      'home': {'type': 'canvas', 'layout': {'width': 390, 'height': 844}, 'slots': {'body': 'body'}},
      'body': {'type': 'column', 'children': ['preview', 'status'], 'layout': {'width': 390, 'height': 200}},
      'preview': {
        'type': 'filledButton',
        'props': {'label': 'Preview project'},
        'layout': {'width': 180, 'height': 48},
        'bind': {'visible': r'${= !device.hover}'},
        'actions': [
          {'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'previewed', 'value': true}]},
        ],
      },
      'status': {'type': 'text', 'props': {'text': r'${device.pointer}'}, 'layout': {'width': 120, 'height': 24}},
    },
    'variables': {'home': [{'name': 'previewed', 'type': 'boolean', 'value': false}]},
  });
  return PublishBundle(
    model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
    layouts: {'home': layout},
  );
}

void main() {
  testWidgets('a touch preview is visible, works by touch and keyboard, and disappears when a mouse connects', (tester) async {
    ignoreOverflows();
    setScreen(tester, const Size(390, 844));
    final app = Codelessly(loader: MemoryPublishLoader(_bundle()), fonts: const NoFontFetcher());
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    addTearDown(app.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
    await settle(tester);
    expect(controller.read('device.hover'), isFalse);
    expect(controller.read('device.pointer'), 'coarse');
    expect(controller.tree!.boxOf('preview')!.attached, isTrue);
    RenderControl? control;
    void findControl(RenderObject object) {
      if (object is RenderControl) control = object;
      object.visitChildren(findControl);
    }
    findControl(controller.tree!.boxOf('preview')!);
    expect(control!.tapTarget.width, greaterThanOrEqualTo(44));
    expect(control!.tapTarget.height, greaterThanOrEqualTo(44));

    final keys = Keyboard(tester);
    await tester.tapAt(controller.tree!.boxOf('preview')!.localToGlobal(const Offset(60, 24)));
    await settle(tester);
    expect(controller.read('previewed'), isTrue);
    expect(keys.ringShown, isFalse, reason: 'a pointer alone does not draw a keyboard focus ring');
    controller.setVariable('previewed', false);
    await tester.pump();
    await keys.tab();
    expect(keys.focusedId, 'preview');
    expect(keys.ringShown, isTrue);
    expect(keys.semantics!.isButton, isTrue);
    expect(keys.semantics!.label, 'Preview project');
    expect(keys.semantics!.isFocused, isTrue);
    await keys.enter();
    expect(controller.read('previewed'), isTrue);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.moveTo(const Offset(1, 1));
    await settle(tester);
    expect(controller.read('device.hover'), isTrue);
    expect(controller.read('device.pointer'), 'fine');
    expect(controller.node('preview')!.visible, isFalse);
    await mouse.removePointer();
    await settle(tester);
    expect(controller.read('device.hover'), isFalse);
  });

  testWidgets('the preview remains named and operable in a dark right-to-left page', (tester) async {
    ignoreOverflows();
    setScreen(tester, const Size(390, 844));
    final app = Codelessly(loader: MemoryPublishLoader(_bundle()), fonts: const NoFontFetcher());
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    addTearDown(app.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Directionality(textDirection: TextDirection.rtl,
          child: CodelesslyWidget(codelessly: app, controller: controller, sizing: CanvasSizing.design)),
    ));
    await settle(tester);
    expect(controller.read('device.hover'), isFalse);
    final keys = Keyboard(tester);
    await keys.tab();
    expect(keys.focusedId, 'preview');
    expect(keys.semantics!.label, 'Preview project');
    await keys.space();
    expect(controller.read('previewed'), isTrue);
  });
}

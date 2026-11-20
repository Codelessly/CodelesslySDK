import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

// What the device covers of a screen, read under `screen`: the safe area
// (`screen.insets`), the soft keyboard (`screen.keyboard`) and the text scale
// (`screen.textScale`). The host supplies them as Flutter does, from the
// platform's view metrics or a MediaQuery of its own; they follow as they
// change.

Codelessly _app({double maxTextScaleFactor = 1}) {
  final home = PublishLayout.fromJson({
    'schema': 3,
    'id': 'home',
    'roots': ['h'],
    'nodes': {
      'h': {'type': 'canvas', 'slots': {'body': 'label'}, 'layout': {'width': 390, 'height': 844}},
      'label': {'type': 'text', 'props': {'text': r'${screen.keyboard}'}},
    },
  });
  return Codelessly.fromBundle(
    PublishBundle(
      model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(home)}),
      layouts: {'home': home},
    ),
    config: CodelesslyConfig(maxTextScaleFactor: maxTextScaleFactor),
    fonts: const NoFontFetcher(),
  );
}

Future<CodelesslyWidgetController> _show(WidgetTester tester, Codelessly app, {MediaQueryData Function(MediaQueryData)? media}) async {
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  addTearDown(app.dispose);
  final layout = CodelesslyWidget(codelessly: app, controller: controller);
  await tester.pumpWidget(MaterialApp(
      home: media == null ? layout : Builder(builder: (context) => MediaQuery(data: media(MediaQuery.of(context)), child: layout))));
  await settle(tester);
  return controller;
}

void main() {
  test('the values, in formulas', () {
    const e = Expressions();
    final s = ValuesScope({'screen': deviceEdgeValues(top: 47, bottom: 34, keyboard: 0, textScale: 1.3)});
    expect(e.evaluate(r'${screen.insets.top}', s), 47);
    expect(e.evaluate(r'${= screen.keyboard + screen.insets.bottom}', s), 34);
    expect(e.evaluate(r'${= screen.textScale > 1.2}', s), isTrue);
    final open = ValuesScope({'screen': deviceEdgeValues(top: 47, keyboard: 336)});
    expect(e.evaluate(r'${= screen.keyboard + screen.insets.bottom}', open), 336, reason: 'the home indicator is under the keyboard');
    expect(e.evaluate(r'${= screen.keyboard > 0}', open), isTrue);
  });

  testWidgets('from the platform: none until the device has them', (tester) async {
    setScreen(tester, const Size(390, 844));
    final c = await _show(tester, _app());
    expect(c.read('screen.insets'), {'top': 0.0, 'right': 0.0, 'bottom': 0.0, 'left': 0.0});
    expect(c.read('screen.keyboard'), 0.0);
    expect(c.read('screen.textScale'), 1.0);

    // A phone's safe area, then its keyboard opening over the home indicator.
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    await tester.pump();
    expect(c.read('screen.insets.top'), 47.0);
    expect(c.read('screen.insets.bottom'), 34.0);

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    tester.view.padding = const FakeViewPadding(top: 47);
    await tester.pump();
    expect(c.read('screen.keyboard'), 336.0);
    expect(c.read('screen.insets.bottom'), 0.0);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    expect(c.read('screen.keyboard'), 0.0, reason: 'closed again');
  });

  testWidgets("from the host's own MediaQuery", (tester) async {
    setScreen(tester, const Size(390, 844));
    final c = await _show(tester, _app(),
        media: (mq) => mq.copyWith(padding: const EdgeInsets.only(top: 20), viewInsets: const EdgeInsets.only(bottom: 250)));
    expect(c.read('screen.insets.top'), 20.0);
    expect(c.read('screen.keyboard'), 250.0);
  });

  testWidgets('the text scale the text is drawn at: the platform\'s, up to the config\'s largest', (tester) async {
    setScreen(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final locked = await _show(tester, _app());
    expect(locked.read('screen.textScale'), 1.0, reason: 'layouts ignore the text size setting by default');
    await tester.pumpWidget(const SizedBox());

    final followed = await _show(tester, _app(maxTextScaleFactor: 2));
    expect(followed.read('screen.textScale'), 1.5);
  });

  testWidgets('a SafeArea the host puts around the layout consumes the insets', (tester) async {
    setScreen(tester, const Size(390, 844));
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    final app = _app();
    addTearDown(app.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: SafeArea(child: CodelesslyWidget(codelessly: app, controller: controller))));
    await settle(tester);
    expect(controller.read('screen.insets.top'), 0.0);
    expect(controller.read('screen.insets.bottom'), 0.0);
  });
}

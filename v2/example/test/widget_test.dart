import 'package:codelessly_example/hello_bundle.dart';
import 'package:codelessly_example/main.dart';
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      // Test fonts are wider than the designs': overflows aren't failures.
      if (!'${d.exception}'.contains('overflowed by')) original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void phone(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
  }

  testWidgets('whole app: shows the entry screen of the bundled project', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: WholeAppExample()));
    // Loading the asset is real I/O.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await frames(tester);
    expect(find.byType(NodeView), findsOneWidget);
    expect(find.byType(CodelesslyErrorScreen), findsNothing);
  });

  testWidgets('embedded: data, params, a variable, a function and the controller', (tester) async {
    phone(tester);
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Embedded widget'));
    await frames(tester);
    expect(find.byType(NodeView), findsOneWidget);

    final state = tester.state<State<CodelesslyWidget>>(find.byType(CodelesslyWidget));
    final controller = state.widget.controller!;
    expect(controller.layout!.id, helloLayoutId);
    expect(controller.read('data.name'), 'Flutter');
    expect(controller.read('route.source'), 'the example');
    expect(controller.read('count'), 0);
    expect(controller.node('title')!.prop(TextProps.text), 'Hello, Flutter!');

    // The app's data changes: the layout follows.
    await tester.enterText(find.byType(TextFormField), 'Ada');
    await frames(tester);
    expect(controller.node('title')!.prop(TextProps.text), 'Hello, Ada!');

    // A tap on the layout's button: the variable changes and the app's
    // function is called with it.
    await controller.trigger('button', 'click');
    await frames(tester);
    expect(controller.read('count'), 1);
    expect(controller.node('counter')!.prop(TextProps.text), 'Taps: 1 (opened from the example)');
    expect(find.text('The layout called onTap with 1'), findsOneWidget);

    // A real tap does the same.
    final box = controller.tree!.boxOf('button')!;
    await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
    await frames(tester);
    expect(controller.read('count'), 2);

    // The app resets the count from outside.
    await tester.tap(find.text('Reset the layout\'s count'));
    await frames(tester);
    expect(controller.read('count'), 0);
  });
}

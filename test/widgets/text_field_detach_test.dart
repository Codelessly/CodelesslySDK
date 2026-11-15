// A focused text field whose screen is torn down while a LayoutBuilder lays
// out (the editor's preview closing, a route replaced under a responsive
// layout): the field lets its focus go quietly, without marking itself for
// layout in the middle of someone else's layout, and the next screen runs.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fields.dart';
import '../support/screen.dart';

Map<String, Json> fieldScreen() => {
      'col': {
        'type': 'column',
        'children': ['field'],
        'layout': {'width': 300, 'height': {'hug': 60}},
      },
      'field': {
        'type': 'textField',
        'layout': {'width': {'fill': 300}, 'height': {'hug': 48}},
        'bind': {'props.initialValue': r'${query}'},
      },
    };

void main() {
  testWidgets('a focused text field torn down during a LayoutBuilder layout leaves no error behind', (tester) async {
    final s = await show(tester, fieldScreen(), variables: [v('query', '')]);
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    Widget app(NodeTree tree) => MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: shown,
              builder: (_, on, _) => LayoutBuilder(
                builder: (_, _) => on ? NodeView(tree: tree, rootId: 'col', interactive: true) : const SizedBox(),
              ),
            ),
          ),
        );
    await tester.pumpWidget(app(s.tree));
    await typeInto(tester, 'شكرا');
    expect(textField(tester).focusNode.hasFocus, isTrue);

    // Closed while focused: the view goes in the LayoutBuilder's layout.
    shown.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);

    // And a screen shown after it runs and takes typing.
    final next = await show(tester, fieldScreen(), variables: [v('query', '')]);
    expect(tester.takeException(), isNull);
    await typeInto(tester, 'hello');
    expect(next['query'], 'hello');
  });
}

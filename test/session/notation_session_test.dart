// A session takes a UI written in the compact notation as it arrives
// (UiSession.applyNotation): each line paints when it completes, the
// controls are the design system's with nothing styled, and they work.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/buttons.dart' show RenderButton;
import 'package:codelessly_sdk/src/render/controls/slider.dart' show RenderSlider;
import 'package:codelessly_sdk/src/render/controls/text_field.dart' show RenderTextField;
import 'package:codelessly_sdk/src/render/controls/toggles.dart' show RenderToggle;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _card = '''
Column gap:12 pad:16
  Slider =volume
  Input "Email" =email
  Toggle "Notifications" =notify
  Button "Save" -> emit save
''';

List<T> _all<T extends RenderObject>(WidgetTester tester) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o);
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return out;
}

void main() {
  testWidgets('four controls written as four lines arrive one by one and render as the default controls', (tester) async {
    final session = UiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, height: 500, child: CodelesslyView(session: session))),
    ));
    final nodesAfterEachChunk = <int>[];
    // Ten characters at a time.
    Stream<String> chunks() async* {
      for (var i = 0; i < _card.length; i += 10) {
        yield _card.substring(i, i + 10 > _card.length ? _card.length : i + 10);
        nodesAfterEachChunk.add(session.document.nodes.length);
      }
    }

    final result = await session.applyNotation(chunks());
    await tester.pumpAndSettle();
    expect(session.notationIssues, isEmpty);
    expect(result.errors, isEmpty, reason: '${result.errors}');
    expect(nodesAfterEachChunk.toSet().length, greaterThan(3), reason: 'nodes arrive as lines complete: $nodesAfterEachChunk');
    expect(session.document.nodes.keys, ['screen', 'column1', 'slider1', 'textField1', 'switch1', 'filledButton1']);
    expect(_all<RenderSlider>(tester), hasLength(1));
    expect(_all<RenderTextField>(tester), hasLength(1));
    expect(_all<RenderToggle>(tester).single.label, 'Notifications');
    final button = _all<RenderButton>(tester).single;
    expect(button.size.height, 28, reason: 'the default button, hugging');
    // The toggle is bound both ways to the variable its line declared.
    final toggle = _all<RenderToggle>(tester).single;
    await tester.tapAt(toggle.localToGlobal(toggle.size.center(Offset.zero)));
    await tester.pumpAndSettle();
    expect(toggle.value, true);
  });
}

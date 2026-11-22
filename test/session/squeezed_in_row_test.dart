// What a row leaves no room for is reported on its own line: a text of
// several words given a word's width, a field given a few pixels. A text
// that has room, and a short label, are not.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Json _doc(List<String> rowKids, Map<String, Json> nodes, {double width = 300}) => {
      'schema': 3,
      'roots': ['page'],
      'nodes': {
        'page': {
          'type': 'canvas',
          'layout': {'width': width, 'height': {'hug': 0}},
          'slots': {'body': 'row'},
        },
        'row': {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'spacing': 8, 'crossAxisAlignment': 'start'},
          'children': rowKids,
        },
        ...nodes,
      },
    };

Future<List<api.EditDiagnostic>> _shown(WidgetTester tester, Json document, {double width = 300}) async {
  final session = UiSession(document: api.LayoutDocument.fromJson(document));
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: 900, child: CodelesslyView(session: session))),
  ));
  await tester.pumpAndSettle();
  tester.takeException();
  return [for (final d in session.shownDiagnostics()) if (d.code == 'content_overflows') d];
}

const Json _picture = {
  'type': 'column',
  'layout': {'width': 240, 'height': 80},
};

Json _text(String text) => {
      'type': 'text',
      'layout': {'width': {'fill': 0}, 'height': {'hug': 0}, 'flex': 1},
      'props': {'text': text, 'style': {'fontSize': 10}},
    };

void main() {
  testWidgets('a text of several words left a word\'s width beside a fixed picture is reported on its line', (tester) async {
    final found = await _shown(tester, _doc(['pic', 'words'], {'pic': _picture, 'words': _text('The last salt marsh of the sound is farmed by the tide')}));
    expect(found.map((d) => d.nodeId), contains('words'));
    final message = found.firstWhere((d) => d.nodeId == 'words').message;
    expect(message, contains('about a word to a line'));
    expect(message, contains('wrap'));
  });

  testWidgets('a text with room, and a short label in a narrow place, are not', (tester) async {
    expect(await _shown(tester, _doc(['pic', 'words'], {'pic': {..._picture, 'layout': {'width': 100, 'height': 80}}, 'words': _text('The last salt marsh of the sound')})), isEmpty);
    expect(await _shown(tester, _doc(['pic', 'words'], {'pic': _picture, 'words': _text('Qty')})), isEmpty);
  });

  testWidgets('a field left a few pixels beside fixed fields is reported', (tester) async {
    final found = await _shown(
      tester,
      _doc(['name', 'a', 'b'], {
        'name': {
          'type': 'textField',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}, 'flex': 1},
        },
        'a': {'type': 'column', 'layout': {'width': 140, 'height': 32}},
        'b': {'type': 'column', 'layout': {'width': 130, 'height': 32}},
      }),
    );
    expect(found.map((d) => d.nodeId), contains('name'));
    expect(found.firstWhere((d) => d.nodeId == 'name').message, contains('too narrow'));
  });
}

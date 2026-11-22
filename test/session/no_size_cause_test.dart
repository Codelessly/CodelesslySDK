// A `no_size` note says why where the layout shows it: a node given no
// width because what is beside it in its row keeps a width that takes the
// row's (said once, not again on everything in it), and a node with no
// height because all that is in it is a list that shows no rows.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<api.EditDiagnostic>> _noSize(WidgetTester tester, Json document, {double width = 350}) async {
  final session = UiSession(document: api.LayoutDocument.fromJson(document));
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: 900, child: CodelesslyView(session: session))),
  ));
  await tester.pumpAndSettle();
  tester.takeException();
  return [for (final d in session.layoutDiagnostics()) if (d.code == 'no_size') d];
}

Json _page(Json nodes, String body, {double width = 350}) => {
      'schema': 3,
      'roots': ['page'],
      'nodes': {
        'page': {
          'type': 'canvas',
          'layout': {'width': width, 'height': {'hug': 0}},
          'slots': {'body': body},
        },
        ...nodes,
      },
    };

Json _text(String text) => {
      'type': 'text',
      'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
      'props': {'text': text, 'style': {'fontSize': 10, 'color': '#FF111827'}},
    };

void main() {
  testWidgets('a column that grows beside one of a fixed width as wide as the row: said once, with the row and the width', (tester) async {
    final found = await _noSize(
      tester,
      _page({
        'row': {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'spacing': 32, 'crossAxisAlignment': 'start'},
          'children': ['main', 'side'],
        },
        'main': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}, 'flex': 1},
          'children': ['about', 'inner'],
        },
        'about': _text('About this home'),
        'inner': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'children': ['plans'],
        },
        'plans': _text('Floor plans'),
        'side': {
          'type': 'column',
          'layout': {'width': 340, 'height': 120},
          'decoration': {
            'fills': [
              {'color': '#FF14284B'},
            ],
          },
        },
      }, 'row'),
    );
    expect(found.map((d) => d.nodeId), ['main']);
    expect(found.single.message, allOf(contains('"side" beside it keeps its width of 340'), contains('"row" is 350 wide'), contains('wrap')));
  });

  testWidgets('a card whose only content is a list with no rows: the note names the list, not a missing size', (tester) async {
    final found = await _noSize(
      tester,
      _page({
        'card': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
          'children': ['list'],
        },
        'list': {
          'type': 'listView',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'scrollable': false},
          'bind': {'data': r'${= filter(listings,x=>x.id==7)}'},
          'children': ['item'],
        },
        'item': _text(r'${item.title}'),
      }, 'card'),
    );
    expect(found.map((d) => d.nodeId), ['card']);
    expect(found.single.message, allOf(contains('a list ("list"'), contains('shows no rows'), isNot(contains('Give it a width and a height'))));
  });
}

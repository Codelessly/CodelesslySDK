import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' show show, v;

Map<String, Map<String, Object?>> _card(String type, {Object height = const {'fill': 100}, List<String> extra = const []}) => {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': 400},
        'children': ['card'],
      },
      'card': {
        'type': type,
        'props': {'crossAxisAlignment': 'stretch'},
        'layout': type == 'row'
            ? {'width': {'fill': 100}, 'height': {'hug': 40}}
            : {'width': {'hug': 40}, 'height': {'fill': 100}},
        'children': ['bar', 'body'],
      },
      'bar': {
        'type': 'box',
        'layout': type == 'row' ? {'width': 5, 'height': height} : {'width': height, 'height': 5},
      },
      'body': {
        'type': 'column',
        'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'padding': [12, 11, 12, 11]},
        'children': ['title', ...extra],
      },
      'title': {'type': 'text', 'props': {'text': 'Close'}, 'layout': {'width': 100, 'height': 20}},
      'note': {
        'type': 'text',
        'props': {'text': 'Couldn’t fill', 'maxLines': 3},
        'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'margin': [0, 8, 0, 0]},
        'bind': {'visible': r'${= missing != null}'},
      },
    };

void main() {
  testWidgets('a bar filling a hugging row stretches to its siblings, not its design size', (tester) async {
    final screen = await show(tester, _card('row', extra: ['note']), variables: [v('missing', null)]);
    expect(screen.tree.boxOf('note')!.collapsed, isTrue);
    expect(screen.tree.boxOf('card')!.size.height, 42);
    expect(screen.tree.boxOf('bar')!.size.height, 42);
  });

  testWidgets('a bar filling a hugging column stretches to its siblings', (tester) async {
    final screen = await show(tester, _card('column'));
    expect(screen.tree.boxOf('card')!.size.width, 124);
    expect(screen.tree.boxOf('bar')!.size.width, 124);
  });

  testWidgets('a fixed bar still sets the thickness of a hugging stretch row', (tester) async {
    final screen = await show(tester, _card('row', height: 100));
    expect(screen.tree.boxOf('card')!.size.height, 100);
  });
}

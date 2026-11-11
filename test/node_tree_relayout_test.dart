import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart' as support;

void main() {
  testWidgets(
    'repeated bound changes keep reused layer chains dirty through their owner',
    (tester) async {
      final screen = await support.show(
        tester,
        {
          'col': {
            'type': 'stack',
            'children': ['pages', 'overlay'],
            'layout': {'width': 300, 'height': 400},
          },
          'pages': {
            'type': 'pageView',
            'children': ['page'],
            'layout': {'width': 300, 'height': 400},
            'bind': {
              'data': r'${books[book]}',
              'props.initialPage': r'${pageIndex}',
            },
            'props': {
              'animationDuration': 40,
              'scrollDirection': 'horizontal',
              'pageMotion': {'rotateY': -9, 'opacity': .75},
            },
          },
          'page': {
            'type': 'column',
            'children': ['title', 'words'],
            'layout': {
              'width': {'fill': 300},
              'height': {'fill': 400},
            },
            'decoration': {
              'fills': [
                {'color': '#faf5e9'},
              ],
            },
            'motion': {'translateY': -2, 'duration': 2400, 'loop': 'reverse'},
            'hero': {'tag': 'cover'},
          },
          'title': {
            'type': 'text',
            'layout': {'width': 280, 'height': 40},
            'props': {'text': r'${item.title}'},
            'bind': {'opacity': r'${= book == 0 ? 1 : 0.7}'},
          },
          'words': {
            'type': 'listView',
            'children': ['word'],
            'layout': {
              'width': 280,
              'height': {'hug': 0},
            },
            'props': {
              'wrap': true,
              'scrollDirection': 'horizontal',
              'scrollable': false,
            },
            'bind': {'data': r'${item.words}'},
          },
          'word': {
            'type': 'text',
            'layout': {
              'width': {'hug': 0},
              'height': {'hug': 0},
              'padding': [2, 2, 2, 2],
            },
            'props': {'text': r'${item}'},
            'decoration': {
              'fills': [
                {'color': '#00000000'},
              ],
            },
            'bind': {
              'decoration.fills[0].color':
                  r'${= index == pageIndex ? "#ead48a" : "#00000000"}',
              'layout.width': r'${= book == 0 ? 40 : 65}',
            },
          },
          'overlay': {
            'type': 'column',
            'children': ['notice'],
            'layout': {'width': 300, 'height': 400},
            'bind': {'visible': r'${showOverlay}'},
          },
          'notice': {
            'type': 'text',
            'layout': {'width': 280, 'height': 30},
            'props': {'text': 'Every little chapter'},
          },
        },
        root: 'col',
        variables: [
          support.v('books', [
            List.generate(
              12,
              (i) => {
                'title': 'Chapter $i',
                'words': ['A', 'little', 'light', 'stays', 'with', 'you'],
              },
            ),
            List.generate(
              4,
              (i) => {
                'title': 'Rain $i',
                'words': ['Pip', 'heard', 'the', 'rain', 'on', 'the', 'roof'],
              },
            ),
          ], VariableType.list),
          support.v('book', 0, VariableType.integer),
          support.v('pageIndex', 0, VariableType.integer),
          support.v('showOverlay', false, VariableType.boolean),
        ],
      );
      for (var step = 0; step < 20; step++) {
        screen.scope.set('book', step % 2);
        screen.scope.set('pageIndex', step % 2 == 0 ? 11 : 0);
        screen.scope.set('showOverlay', step % 3 == 0);
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
      }
    },
  );
}

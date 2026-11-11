// A transcript: a scrolling column of typed lines (grow) and an end marker
// that follows. When a written scene replaces lines still typing, the
// scroll's extent covers every line and it rests at the end.
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

void main() {
  for (final lateFont in [false, true]) {
  testWidgets('a written scene replacing typing lines: the scroll ends at the last line${lateFont ? ', a font loading late' : ''}', (tester) async {
    final family = lateFont ? 'LateTranscript' : null;
    Map<String, Object?> line(String t, String k, bool fresh, int offset) => {'t': t, 'k': k, 'fresh': fresh, 'offset': offset};
    const long = 'one two three four five six seven eight nine ten eleven twelve thirteen fourteen';
    final s = await support.show(
      tester,
      {
        'col': {
          'type': 'column',
          'layout': {'width': 200, 'height': 300},
          'props': {'scrollable': true},
          'children': ['list', 'end'],
        },
        'list': {
          'type': 'listView',
          'children': ['item'],
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {'scrollable': false},
          'bind': {'data': r'${lines}'},
        },
        'item': {
          'type': 'column',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'children': ['gap', 'v'],
        },
        'gap': {
          'type': 'box',
          'layout': {'width': {'fill': 1}, 'height': 8},
        },
        'v': {
          'type': 'variance',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {
            'current': 'text',
            'variants': [
              {'id': 'text', 'children': ['vcol']},
              {'id': 'cmd', 'children': ['ccol']},
            ],
          },
          'bind': {'props.current': r'${item.k}'},
        },
        'vcol': {'type': 'column', 'layout': {'width': {'fill': 1}, 'height': {'hug': 0}}, 'children': ['t']},
        'ccol': {'type': 'column', 'layout': {'width': {'fill': 1}, 'height': {'hug': 0}}, 'children': ['c']},
        't': {
          'type': 'text',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {'text': '', 'style': {'fontSize': 14, 'fontFamily': ?family}},
          'typewriter': {'charsPerSecond': 100, 'grow': true},
          'bind': {
            'props.text': r'${item.t}',
            'typewriter.enabled': r'${item.fresh}',
            'typewriter.delayMs': r'${= item.offset * 10}',
            'typewriter.skip': r'${= skip == 1}',
          },
        },
        'c': {
          'type': 'text',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {'text': '', 'style': {'fontSize': 14}},
          'bind': {'props.text': r'${item.t}'},
        },
        'end': {
          'type': 'box',
          'layout': {'width': {'fill': 1}, 'height': 10},
          'reveal': {'alignment': 1, 'duration': 0, 'follow': true},
        },
      },
      root: 'col',
      variables: [
        support.v('lines', [line(long, 'text', true, 0), line(long, 'text', true, 81)], VariableType.list),
        support.v('skip', 0, VariableType.integer),
      ],
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 40));
    // The scene: many lines, written (old, or the last batch skipped).
    setVariableIn(s.scope, 'lines', [
      for (var i = 0; i < 12; i++) ...[line('cmd $i', 'cmd', false, 0), line(long, 'text', i == 11, 0)],
    ]);
    setVariableIn(s.scope, 'skip', 1);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    if (lateFont) {
      final bytes = File('../references/tally_v2/assets/fonts/Newsreader-400.ttf').readAsBytesSync();
      await tester.runAsync(() async {
        final loader = FontLoader('LateTranscript')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
        await loader.load();
      });
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    RenderDesignScroll? viewport;
    void find(RenderObject r) {
      if (r is RenderDesignScroll) viewport ??= r;
      r.visitChildren(find);
    }

    find(s.tree.boxOf('col')!);
    final list = s.tree.boxOf('list')!;
    // Every line's real height: the list's content, laid out in full.
    var bottom = 0.0;
    void lowest(RenderObject r) {
      if (r is RenderParagraph && r.hasSize) {
        final y = r.localToGlobal(Offset(0, r.size.height), ancestor: list).dy;
        if (y > bottom) bottom = y;
      }
      r.visitChildren(lowest);
    }

    lowest(list);
    expect(list.size.height, closeTo(bottom, 1), reason: 'the list is as tall as its lines');
    expect(viewport!.pixels, viewport!.maxScrollExtent);
    final end = s.tree.boxOf('end')!;
    final endBottom = end.localToGlobal(Offset(0, end.size.height), ancestor: viewport).dy;
    expect(endBottom, closeTo(300, 1), reason: 'the end marker at the bottom of the view');
  });
  }
}

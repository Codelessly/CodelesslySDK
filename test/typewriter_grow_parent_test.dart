// A growing typewriter that stops typing (disabled, skipped) gives its
// parent the whole text's size again.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

void main() {
  testWidgets('a hugging column follows a growing typewriter turned off mid-wait', (tester) async {
    final s = await support.show(
      tester,
      {
        'col': {
          'type': 'column',
          'layout': {'width': 200, 'height': {'hug': 0}},
          'children': ['t', 'after'],
        },
        't': {
          'type': 'text',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {'text': 'one two three four five six seven eight nine ten', 'style': {'fontSize': 14}},
          'typewriter': {'charsPerSecond': 100, 'delayMs': 5000, 'grow': true},
          'bind': {'typewriter.enabled': r'${fresh}'},
        },
        'after': {'type': 'box', 'layout': {'width': 200, 'height': 10}},
      },
      variables: [support.v('fresh', true, VariableType.boolean)],
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    double h(String id) => s.tree.boxOf(id)!.size.height;
    expect(h('t'), 0, reason: 'waiting to type');
    setVariableIn(s.scope, 'fresh', false);
    await tester.pump();
    await tester.pump();
    expect(h('t'), greaterThan(40));
    expect(h('col'), h('t') + 10);
  });

  testWidgets('list items typed with grow show in full once the data says they are old', (tester) async {
    Map<String, Object?> line(String t, bool fresh, int offset) => {'t': t, 'fresh': fresh, 'offset': offset};
    const long = 'one two three four five six seven eight nine ten eleven twelve';
    final s = await support.show(
      tester,
      {
        'list': {
          'type': 'listView',
          'children': ['t'],
          'layout': {'width': 200, 'height': {'hug': 0}},
          'props': {'scrollable': false},
          'bind': {'data': r'${lines}'},
        },
        't': {
          'type': 'text',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {'text': '', 'style': {'fontSize': 14}},
          'typewriter': {'charsPerSecond': 100, 'grow': true},
          'bind': {
            'props.text': r'${item.t}',
            'typewriter.enabled': r'${item.fresh}',
            'typewriter.delayMs': r'${= item.offset * 10}',
          },
        },
      },
      root: 'list',
      variables: [
        support.v('lines', [line(long, true, 0), line(long, true, 63)], VariableType.list),
      ],
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 50));
    final typing = s.tree.boxOf('list')!.size.height;
    setVariableIn(s.scope, 'lines', [line(long, false, 0), line(long, false, 63), line('new', true, 0)]);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final done = s.tree.boxOf('list')!.size.height;
    expect(done, greaterThan(typing + 80), reason: 'both old lines in full (\$typing → \$done)');
  });

  testWidgets('a growing line inside a variance in a list gets its size back when it stops typing', (tester) async {
    Map<String, Object?> line(String t, bool fresh, int offset) => {'t': t, 'k': 'text', 'fresh': fresh, 'offset': offset};
    const long = 'one two three four five six seven eight nine ten eleven twelve';
    final s = await support.show(
      tester,
      {
        'list': {
          'type': 'listView',
          'children': ['v'],
          'layout': {'width': 200, 'height': {'hug': 0}},
          'props': {'scrollable': false},
          'bind': {'data': r'${lines}'},
        },
        'v': {
          'type': 'variance',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {
            'current': 'text',
            'variants': [
              {'id': 'text', 'children': ['vcol']},
              {'id': 'other', 'children': []},
            ],
          },
          'bind': {'props.current': r'${item.k}'},
        },
        'vcol': {
          'type': 'column',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}, 'padding': [0, 8, 0, 0]},
          'children': ['t'],
        },
        't': {
          'type': 'text',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {'text': '', 'style': {'fontSize': 14}},
          'typewriter': {'charsPerSecond': 100, 'grow': true},
          'bind': {
            'props.text': r'${item.t}',
            'typewriter.enabled': r'${item.fresh}',
            'typewriter.delayMs': r'${= item.offset * 10}',
          },
        },
      },
      root: 'list',
      variables: [
        support.v('lines', [line(long, true, 0), line(long, true, 63)], VariableType.list),
      ],
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 50));
    final typing = s.tree.boxOf('list')!.size.height;
    setVariableIn(s.scope, 'lines', [line(long, false, 0), line(long, false, 63), line('new', true, 0)]);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final done = s.tree.boxOf('list')!.size.height;
    expect(done, greaterThan(typing + 80), reason: 'both old lines in full (\$typing → \$done)');
  });

  testWidgets('a growing line in a padded card in a variance in a list, skipped, shows in full', (tester) async {
    Map<String, Object?> line(String t, String k, bool fresh, int offset) => {'t': t, 'k': k, 'fresh': fresh, 'offset': offset};
    const long = 'one two three four five six seven eight nine ten eleven twelve';
    final s = await support.show(
      tester,
      {
        'list': {
          'type': 'listView',
          'children': ['v'],
          'layout': {'width': 200, 'height': {'hug': 0}},
          'props': {'scrollable': false},
          'bind': {'data': r'${lines}'},
        },
        'v': {
          'type': 'variance',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {
            'current': 'text',
            'variants': [
              {'id': 'text', 'children': ['vcol']},
              {'id': 'read', 'children': ['rcol']},
            ],
          },
          'bind': {'props.current': r'${item.k}'},
        },
        'vcol': {
          'type': 'column',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}, 'padding': [0, 8, 0, 0]},
          'children': ['t'],
        },
        't': {
          'type': 'text',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {'text': '', 'style': {'fontSize': 14}},
          'typewriter': {'charsPerSecond': 100, 'grow': true},
          'bind': {
            'props.text': r'${item.t}',
            'typewriter.enabled': r'${item.fresh}',
            'typewriter.delayMs': r'${= item.offset * 10}',
            'typewriter.skip': r'${= skip == 1}',
          },
        },
        'rcol': {
          'type': 'column',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}, 'padding': [0, 22, 0, 0]},
          'children': ['card'],
        },
        'card': {
          'type': 'column',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}, 'padding': [18, 14, 18, 16]},
          'decoration': {'fills': [{'color': '#FFEEEEEE'}]},
          'children': ['r'],
        },
        'r': {
          'type': 'text',
          'layout': {'width': {'fill': 1}, 'height': {'hug': 0}},
          'props': {'text': '', 'style': {'fontSize': 14}},
          'typewriter': {'charsPerSecond': 100, 'grow': true},
          'bind': {
            'props.text': r'${item.t}',
            'typewriter.enabled': r'${item.fresh}',
            'typewriter.delayMs': r'${= item.offset * 10}',
            'typewriter.skip': r'${= skip == 1}',
          },
        },
      },
      root: 'list',
      variables: [
        support.v('lines', [line('intro words', 'text', true, 0)], VariableType.list),
        support.v('skip', 0, VariableType.integer),
      ],
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 30));
    // A scene arrives fully written: the last batch fresh but skipped.
    setVariableIn(s.scope, 'lines', [line(long, 'text', false, 0), line(long, 'text', true, 0), line(long, 'read', true, 63)]);
    setVariableIn(s.scope, 'skip', 1);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    final h = s.tree.boxOf('list')!.size.height;
    expect(h, greaterThan(3 * 80), reason: 'three full lines, one in its card (got \$h)');
  });
}

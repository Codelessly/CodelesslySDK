// A grid whose rows shrink-wrap is CSS grid's auto rows: each row as long
// as its longest item, every item stretched to it (`align-items:
// stretch`). Checked against the rects CSS specifies for
// `grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
// grid-auto-rows: auto; gap: 12px` over cards whose content differs, at
// three widths, with items whose subtree a viewport hides from intrinsic
// measurement (a bound list) and items that can be measured.
import 'package:codelessly_sdk/codelessly_sdk.dart' show VariableType;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  // Card i holds lines[i] feature rows of 30 px, inside 10 px padding.
  const lines = [2, 5, 3, 1];
  double content(int i) => lines[i] * 30.0 + 20;

  /// The CSS rects: (top, height) of each card, at [cols] columns.
  List<(double, double)> css(int cols) {
    final out = <(double, double)>[];
    var top = 0.0;
    for (var start = 0; start < lines.length; start += cols) {
      final row = [for (var i = start; i < start + cols && i < lines.length; i++) i];
      final h = row.map(content).reduce((a, b) => a > b ? a : b);
      for (final _ in row) {
        out.add((top, h));
      }
      top += h + 12;
    }
    return out;
  }

  Map<String, Map<String, Object?>> grid(double width, {required String fit, required bool boundList}) => {
        'col': {'type': 'column', 'children': ['grid'], 'layout': {'width': width, 'height': {'hug': 600}}},
        'grid': {
          'type': 'gridView',
          'children': ['card'],
          'layout': {'width': {'fill': 300}, 'height': {'hug': 400}},
          'props': {'shrinkWrapRows': true, 'minCrossAxisExtent': 280, 'physics': 'never', 'crossAxisSpacing': 12, 'mainAxisSpacing': 12},
          'bind': {'data': r'${= [2, 5, 3, 1]}'},
        },
        'card': {
          'type': 'column',
          'children': boundList ? ['feats'] : ['f0', 'f1', 'f2', 'f3', 'f4'],
          'layout': {'width': {'fill': 280}, 'height': {fit: 900}, 'padding': 10},
          'decoration': {'fills': [{'color': '#FF202125'}]},
        },
        // A list bound to data: a viewport, which intrinsic measurement can't see into.
        'feats': {
          'type': 'listView',
          'children': ['feat'],
          'layout': {'width': {'fill': 260}, 'height': {'hug': 60}},
          'bind': {'data': r'${= slice([0, 1, 2, 3, 4], 0, item)}'},
        },
        'feat': {'type': 'box', 'layout': {'width': {'fill': 260}, 'height': 30}},
        // Without a list: as many 30 px rows shown as the card's number.
        for (var k = 0; k < 5; k++)
          'f$k': {'type': 'box', 'layout': {'width': {'fill': 260}, 'height': 30}, 'bind': {'visible': '\${= item > $k}'}},
      };

  for (final boundList in [true, false]) {
    for (final fit in ['hug', 'fill']) {
      testWidgets('cards that $fit their height${boundList ? ' around a bound list' : ''} stretch to their row at 3, 2 and 1 columns', (tester) async {
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final (width, cols) in [(900.0, 3), (600.0, 2), (390.0, 1)]) {
          final s = await show(tester, grid(width, fit: fit, boundList: boundList));
          await tester.pumpAndSettle();
          final cards = s.tree.boxesOf('card').toList();
          expect(cards, hasLength(4));
          final grid0 = s.tree.boxOf('grid')!.localToGlobal(Offset.zero).dy;
          final want = css(cols);
          for (var i = 0; i < 4; i++) {
            final b = cards[i];
            final top = b.localToGlobal(Offset.zero).dy - grid0;
            expect((top, b.size.height), want[i], reason: 'card $i at $width wide ($cols columns)');
          }
          expect(s.tree.boxOf('grid')!.size.height, want.last.$1 + want.last.$2, reason: 'the grid hugs its rows');
        }
      });
    }
  }

  testWidgets('rows that shrink-wrap their cards win over a fixed item extent', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final g = grid(900, fit: 'hug', boundList: true);
    (g['grid']!['props'] as Map)['mainAxisExtent'] = 37.0;
    final s = await show(tester, g);
    await tester.pumpAndSettle();
    expect(s.tree.boxesOf('card').map((b) => b.size.height).toList(), [170.0, 170.0, 170.0, 50.0]);
  });

  testWidgets('a card whose content grows later measures its row again', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final g = grid(900, fit: 'hug', boundList: true);
    g['grid']!['bind'] = {'data': r'${counts}'};
    final s = await show(tester, g, variables: [v('counts', [2, 5, 3, 1], VariableType.list)]);
    await tester.pumpAndSettle();
    expect(s.tree.boxesOf('card').map((b) => b.size.height).toList(), [170.0, 170.0, 170.0, 50.0]);
    s.scope.set('counts', [2, 5, 3, 4]);
    await tester.pumpAndSettle();
    expect(s.tree.boxesOf('card').map((b) => b.size.height).toList(), [170.0, 170.0, 170.0, 140.0]);
    s.scope.set('counts', [2, 2, 3, 4]);
    await tester.pumpAndSettle();
    expect(s.tree.boxesOf('card').map((b) => b.size.height).toList(), [110.0, 110.0, 110.0, 140.0], reason: 'and shrinks again');
  });

  for (final cross in ['stretch', 'start']) {
    testWidgets('a childless box that hugs and keeps an aspect ratio in a card ($cross) is drawn at the ratio its row made room for',
        (tester) async {
      // The row measures the card's content (its intrinsic height: the box
      // at the card's width over its ratio, and a caption); the box then
      // takes that height, as Flutter's AspectRatio takes the width it may
      // have. It took none, and drew nothing in the room left for it.
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await show(tester, {
        'col': {'type': 'column', 'children': ['grid'], 'layout': {'width': 600, 'height': {'hug': 600}}},
        'grid': {
          'type': 'gridView',
          'children': ['card'],
          'layout': {'width': {'fill': 600}, 'height': {'hug': 400}},
          'props': {'shrinkWrapRows': true, 'crossAxisCount': 2, 'physics': 'never', 'crossAxisSpacing': 20},
          'bind': {'data': r'${= [1, 2, 3]}'},
        },
        'card': {
          'type': 'column',
          'children': ['photo'],
          'layout': {'width': {'fill': 290}, 'height': {'hug': 10}},
          'props': {'crossAxisAlignment': cross},
        },
        'photo': {
          'type': 'box',
          'layout': {'width': {'hug': 100}, 'height': {'hug': 50}, 'aspectRatio': 2},
          'decoration': {'fills': [{'color': '#FF0057FF'}]},
        },
      });
      await tester.pumpAndSettle();
      expect(s.tree.boxesOf('photo').map((b) => b.size).toList(), List.filled(3, const Size(290, 145)));
      expect(s.tree.boxesOf('card').map((b) => b.size.height).toList(), List.filled(3, 145.0));
    });
  }
}

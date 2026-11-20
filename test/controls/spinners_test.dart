// Spinners as render objects (render/controls/spinner.dart, recipes in
// widgets/indicators.dart): circularProgressIndicator is SSUI's arc and
// activityIndicator a ticked wheel, each turning on its own ticker, with no
// Material or Cupertino widget anywhere in the SDK.
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/spinner.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show Align, Alignment, SizedBox, TickerMode;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

RenderSpinner _spinner(RenderTree tree, String id) {
  RenderSpinner? found;
  void visit(RenderObject o) {
    if (o is RenderSpinner) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

void main() {
  testWidgets('with no props and no layout: SSUI\'s 16 px spinner in the primary color, a 20 px wheel in secondary text',
      (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'spin': {'type': 'circularProgressIndicator'},
      'wheel': {'type': 'activityIndicator'},
      'ring': {'type': 'circularProgressIndicator', 'props': {'value': .25, 'backgroundColor': '#FFE5E7EB'}},
    }));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    expect(rectOf(tree, 'spin').size, const Size(16, 16));
    expect(rectOf(tree, 'wheel').size, const Size(20, 20));
    final spin = _spinner(tree, 'spin'), wheel = _spinner(tree, 'wheel'), ring = _spinner(tree, 'ring');
    expect(spin.color, const Color(0xFF2563EB));
    expect(spin.value, isNull);
    expect(wheel.style, SpinnerStyle.ticks);
    expect(wheel.color, const Color(0xFF4B5563));
    expect(ring.value, .25);
    expect(ring.track, const Color(0xFFE5E7EB));
    expect(ring.spinning, isFalse);
    // Indeterminate: a turn every 900 ms on the ticker.
    expect(spin.spinning, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    final a = spin.turns;
    await tester.pump(const Duration(milliseconds: 225));
    expect(spin.turns - a, closeTo(.25, .02));
    await tester.pumpWidget(const SizedBox());
    expect(spin.spinning, isFalse, reason: 'it stops when it leaves the tree');
  });

  testWidgets('a ring filled to a value with no background shows its track; a spinner none', (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'spin': {'type': 'circularProgressIndicator'},
      'ring': {'type': 'circularProgressIndicator', 'props': {'value': .4}},
    }, theme: null));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    expect(_spinner(tree, 'ring').track, const Color(0xFFE5E7EB), reason: 'the track of the default theme');
    expect(_spinner(tree, 'spin').track, isNull);
    // A theme's track.
    final (themed, _) = runningTree(
      columnDoc({
        'ring': {'type': 'circularProgressIndicator', 'props': {'value': .4}},
      }),
      theme: ThemeTokens.fromJson({
        'colors': {'track': '#FFDDE3EA'},
      }),
    );
    addTearDown(themed.dispose);
    await tester.pumpWidget(NodeView(tree: themed, rootId: 'col', interactive: true));
    expect(_spinner(themed, 'ring').track, const Color(0xFFDDE3EA));
  });

  testWidgets('an activity indicator with animating false holds still', (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'wheel': {'type': 'activityIndicator', 'props': {'animating': false, 'radius': 8}},
    }));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    expect(rectOf(tree, 'wheel').size, const Size(16, 16));
    expect(_spinner(tree, 'wheel').spinning, isFalse);
  });

  testWidgets('with the host\'s tickers off (a design canvas) a spinner holds still, in its own layer', (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'spin': {'type': 'circularProgressIndicator'},
    }));
    addTearDown(tree.dispose);
    await tester.pumpWidget(TickerMode(enabled: false, child: NodeView(tree: tree, rootId: 'col')));
    final spin = _spinner(tree, 'spin');
    expect(spin.isRepaintBoundary, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 225));
    expect(spin.turns, 0);
    expect(spin.debugNeedsPaint, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a spinner with a written size keeps it where it is placed: 20 × 20 centred in a stack, not the stack\'s size',
      (tester) async {
    final (tree, _) = runningTree({
      'schema': 3,
      'roots': ['stack'],
      'nodes': {
        'stack': {
          'type': 'stack',
          'layout': {'width': 390, 'height': 500},
          'children': ['spin'],
        },
        'spin': {
          'type': 'circularProgressIndicator',
          'layout': {
            'width': 20,
            'height': 20,
            'x': {'align': 0},
            'y': {'align': 0},
          },
        },
      },
    });
    addTearDown(tree.dispose);
    await tester.pumpWidget(Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'stack', interactive: true)));
    expect(rectOf(tree, 'spin'), const Rect.fromLTWH(185, 240, 20, 20));
    expect(_spinner(tree, 'spin').size, const Size(20, 20));
    await tester.pumpWidget(const SizedBox());
  });

  test('no file in the SDK imports Cupertino', () {
    final cupertino = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && f.readAsStringSync().contains("package:flutter/cupertino.dart")) f.path,
    ];
    expect(cupertino, isEmpty);
  });
}

// A row lines its children up on their control boxes (render/layout/
// control_line.dart): a field's label hangs above the line and its helper
// or error below it, and what sits beside the field lines up with its box.
import 'dart:math' as math;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/field_frame.dart';
import 'package:codelessly_sdk/src/render/layout/control_line.dart';
import 'package:codelessly_sdk/src/render/layout/fit_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';

/// The box of the field drawn by node [id] (the frame's box, its label and
/// lines below left out), in global coordinates.
Rect fieldBoxOf(WidgetTester tester, String id) {
  RenderFieldFrame? frame;
  void find(RenderObject o) {
    if (o is RenderFieldFrame) frame ??= o;
    if (frame == null) o.visitChildren(find);
  }

  find(boxOf(tester, id));
  expect(frame, isNotNull, reason: 'no field under "$id"');
  return frame!.boxRect.shift(frame!.localToGlobal(Offset.zero));
}

/// A field in the matrix: its notation lines (indented under the row) and
/// where its control box is.
typedef Case = ({String name, List<String> lines, Rect Function(WidgetTester) control, String? designSystem});

Rect _node(WidgetTester t, String id) => rectOf(t, id);

final List<Case> fields = [
  (name: 'a labelled field', lines: ['Input#f "Label" @v grow'], control: (t) => fieldBoxOf(t, 'f'), designSystem: null),
  (name: 'a field with a hint only', lines: ['Input#f hint="Type here" @v grow'], control: (t) => fieldBoxOf(t, 'f'), designSystem: null),
  (
    name: 'a field with a helper',
    lines: ['Input#f "Label" helper="Shown under the field" @v grow'],
    control: (t) => fieldBoxOf(t, 'f'),
    designSystem: null,
  ),
  (name: 'a field showing an error', lines: ['Input#f "Label" error="Required" @v grow'], control: (t) => fieldBoxOf(t, 'f'), designSystem: null),
  (
    name: 'a dropdown with a label (a column of the label and the dropdown)',
    lines: ['Column#f gap=6 grow', '  Text "Size"', '  Select#fs "Choose" items=["S","M","L"] @v'],
    control: (t) => fieldBoxOf(t, 'fs'),
    designSystem: null,
  ),
  (name: 'a multi-line field', lines: ['Input#f "Notes" lines=3 @v grow'], control: (t) => fieldBoxOf(t, 'f'), designSystem: null),
  (
    name: "Cards' InputField",
    lines: ['InputField#f label="Email" placeholder="you@example.com" @v'],
    control: (t) => _node(t, 'f/box'),
    designSystem: 'design_systems/cards',
  ),
  (
    name: "SSUI's Field around a TextInput",
    lines: ['Field#f label="Email" help="We never share it."', '  TextInput#fi placeholder="you@example.com"'],
    control: (t) => _node(t, 'fi'),
    designSystem: 'design_systems/ssui',
  ),
];

final List<Case> partners = [
  (name: 'a filled button', lines: ['Button#p "Add"'], control: (t) => _node(t, 'p'), designSystem: null),
  (name: 'an outlined button', lines: ['Button.outline#p "Add"'], control: (t) => _node(t, 'p'), designSystem: null),
  (name: 'an icon button', lines: ['IconButton#p "add"'], control: (t) => _node(t, 'p'), designSystem: null),
  (name: 'a text', lines: ['Text#p "Total"'], control: (t) => _node(t, 'p'), designSystem: null),
  (name: 'a checkbox', lines: ['Checkbox#p @c'], control: (t) => _node(t, 'p'), designSystem: null),
  (name: 'a switch', lines: ['Switch#p @s'], control: (t) => _node(t, 'p'), designSystem: null),
  (name: 'another labelled field', lines: ['Input#p "Other" @w grow'], control: (t) => fieldBoxOf(t, 'p'), designSystem: null),
  (
    name: 'a nested row of a labelled field and a button',
    lines: ['Row#p gap=4', '  Input#p1 "Nested" @w', '  Button#p2 "Go"'],
    control: (t) => fieldBoxOf(t, 'p1'),
    designSystem: null,
  ),
];

const aligns = ['', 'middle', 'top', 'bottom', 'stretch'];

// The variables the lines bind (v, w: a field's text; c, s: a checkbox, a switch).
String _page(Case field, Case partner, String align, bool wrap) => [
      'state v=""',
      'state w=""',
      'state c=false',
      'state s=false',
      'Card gap=10',
      '  Row#row gap=8${align.isEmpty ? '' : ' $align'}${wrap ? ' wrap' : ''}',
      for (final l in field.lines) '    $l',
      for (final l in partner.lines) '    $l',
    ].join('\n');

bool _overlaps(Rect a, Rect b) => a.top < b.bottom && b.top < a.bottom;

// --- documents written as JSON ------------------------------------------------------

Future<NodeTree> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, {String root = 'row'}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'schema': 3, 'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 600, child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))))));
  return tree;
}

Rect _r(NodeTree tree, String id) => tree.boxOf(id)!.rectIn(tree.boxOf('row')!)!;

Map<String, Object?> _row(List<String> children, {String? cross, Object height = const {'hug': 0}, bool wrap = false}) => {
      'type': 'row',
      'children': children,
      'layout': {'width': 560, 'height': height},
      'props': {'spacing': 8, 'crossAxisAlignment': ?cross, if (wrap) 'wrap': true},
    };

Map<String, Object?> _field({String? label, String? helper, String? error, String? hint, Object width = 200}) => {
      'type': 'textField',
      'layout': {'width': width, 'height': {'hug': 0}},
      'props': {
        'decoration': {'labelText': ?label, 'helperText': ?helper, 'errorText': ?error, 'hintText': ?hint},
      },
    };

Map<String, Object?> _box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
      'decoration': {'fills': [{'color': '#FF2196F3'}]},
    };

Map<String, Object?> _text(String text) => {'type': 'text', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}}, 'props': {'text': text}};

RenderCodelesslyFlex _flexOf(NodeTree tree, String id) {
  RenderCodelesslyFlex? found;
  void find(RenderObject o) {
    if (o is RenderCodelesslyFlex) found ??= o;
    if (found == null) o.visitChildren(find);
  }

  find(tree.boxOf(id)!);
  return found!;
}

Rect _fieldBox(NodeTree tree, String id) {
  RenderFieldFrame? frame;
  void find(RenderObject o) {
    if (o is RenderFieldFrame) frame ??= o;
    if (frame == null) o.visitChildren(find);
  }

  find(tree.boxOf(id)!);
  final row = tree.boxOf('row')!;
  return MatrixUtils.transformRect(frame!.getTransformTo(row), frame!.boxRect);
}

/// Every node's rect in [nodes] laid out with the control line on and off.
Future<(Map<String, Rect>, Map<String, Rect>)> _onAndOff(WidgetTester tester, Map<String, Map<String, Object?>> nodes) async {
  Future<Map<String, Rect>> rects() async {
    final tree = await _show(tester, nodes);
    final out = {for (final id in nodes.keys) id: ?tree.boxOf(id)?.rectIn(tree.boxOf('row')!)};
    await tester.pumpWidget(const SizedBox());
    return out;
  }

  final on = await rects();
  ControlLine.enabled = false;
  try {
    return (on, await rects());
  } finally {
    ControlLine.enabled = true;
  }
}

void main() {
  group('the control line, in numbers', () {
    testWidgets('a button beside a labelled field is level with its box, and the row is as tall as the field', (tester) async {
      final tree = await _show(tester, {'row': _row(['f', 'b']), 'f': _field(label: 'Name', hint: 'Ada'), 'b': _box(60, 28)});
      final f = _r(tree, 'f'), box = _fieldBox(tree, 'f'), b = _r(tree, 'b');
      expect(box.top, greaterThan(f.top + 10), reason: 'the label is over the box');
      expect(b.top, box.top);
      expect(b.bottom, box.bottom);
      expect(_r(tree, 'row').height, f.height);
    });

    testWidgets('a helper under the field hangs below the line: the row grows by it, the button stays on the box', (tester) async {
      final tree = await _show(tester, {'row': _row(['f', 'b']), 'f': _field(label: 'Name', helper: 'As on your passport'), 'b': _box(60, 40)});
      final f = _r(tree, 'f'), box = _fieldBox(tree, 'f'), b = _r(tree, 'b');
      expect(b.center.dy, closeTo(box.center.dy, 1e-9));
      final row = _r(tree, 'row');
      expect(row.top, 0);
      // The button is taller than the box: the label still hangs above it,
      // and the row reaches the helper's foot.
      expect(row.bottom, f.bottom);
      expect(math.min(f.top, b.top), 0);
    });

    testWidgets("a row's intrinsic height and dry layout are what its layout comes to", (tester) async {
      for (final cross in ['start', 'center', 'end', 'stretch']) {
        final tree = await _show(tester, {
          'row': _row(['f', 'g', 'b'], cross: cross),
          'f': _field(label: 'Name'),
          'g': _field(helper: 'Under it', error: 'Wrong', width: 160),
          'b': _box(60, 36),
        });
        final flex = _flexOf(tree, 'row');
        final laidOut = flex.size;
        expect(flex.getMaxIntrinsicHeight(laidOut.width), closeTo(laidOut.height, 1e-9), reason: cross);
        // The least it can be squeezed to: the box's own minimum is 0.
        expect(flex.getMinIntrinsicHeight(laidOut.width), lessThanOrEqualTo(laidOut.height), reason: cross);
        expect(flex.getMinIntrinsicHeight(laidOut.width), greaterThanOrEqualTo(_r(tree, 'f').height), reason: cross);
        // (A flex stretching across no bound has no dry height, as in
        // Flutter: a hugging row that stretches is measured by RenderHugCross.)
        if (cross != 'stretch') {
          expect(flex.getDryLayout(BoxConstraints(maxWidth: laidOut.width)).height, closeTo(laidOut.height, 1e-9), reason: cross);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a nested row passes its own line on: Row[Row[Input, Button], Button] lines up', (tester) async {
      final tree = await _show(tester, {
        'row': _row(['inner', 'b']),
        'inner': {'type': 'row', 'children': ['f', 'ib'], 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}}, 'props': {'spacing': 4}},
        'f': _field(label: 'Name'),
        'ib': _box(40, 28),
        'b': _box(60, 40),
      });
      final box = _fieldBox(tree, 'f');
      expect(_r(tree, 'ib').center.dy, closeTo(box.center.dy, 1e-9));
      expect(_r(tree, 'b').center.dy, closeTo(box.center.dy, 1e-9));
    });

    testWidgets('a row of a fixed height centers what its children take together', (tester) async {
      final tree = await _show(tester, {'row': _row(['f', 'b'], height: 120), 'f': _field(label: 'Name'), 'b': _box(60, 28)});
      final f = _r(tree, 'f'), b = _r(tree, 'b');
      expect(f.top, closeTo((120 - f.height) / 2, 1e-9));
      expect(b.top, _fieldBox(tree, 'f').top);
    });

    testWidgets('a tap on the button beside a labelled field reaches the button', (tester) async {
      final tree = await _show(tester, {'row': _row(['f', 'b']), 'f': _field(label: 'Name'), 'b': _box(60, 28)});
      final button = tree.boxOf('b')!;
      final at = button.localToGlobal(button.size.center(Offset.zero));
      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(result, at, tester.view.viewId);
      expect(result.path.map((e) => e.target), contains(button));
    });

    testWidgets('stretched in a row that hugs, a button is as tall as the field box, not as the field and its label', (tester) async {
      final tree = await _show(tester, {
        'row': _row(['f', 'b'], cross: 'stretch'),
        'f': _field(label: 'Name'),
        'b': {'type': 'box', 'layout': {'width': 60, 'height': {'fill': 0}}},
      });
      final box = _fieldBox(tree, 'f'), b = _r(tree, 'b');
      expect(b.top, box.top);
      expect(b.height, box.height);
      expect(_r(tree, 'row').height, _r(tree, 'f').height);
    });

    testWidgets("a column of a label text and a field is lined up as a labelled field (a design system's field)", (tester) async {
      final tree = await _show(tester, {
        'row': _row(['col', 'b']),
        'col': {'type': 'column', 'children': ['label', 'f', 'help'], 'layout': {'width': 200, 'height': {'hug': 0}}, 'props': {'spacing': 6}},
        'label': _text('Email'),
        'f': _field(hint: 'you@example.com'),
        'help': _text('We never share it.'),
        'b': _box(60, 28),
      });
      expect(_r(tree, 'b').center.dy, closeTo(_fieldBox(tree, 'f').center.dy, 1e-9));
    });
  });

  group('rows the control line leaves as they were', () {
    testWidgets('fields with no label and no line under them, beside other children', (tester) async {
      for (final cross in ['start', 'center', 'end', 'stretch', 'baseline']) {
        final (on, off) = await _onAndOff(tester, {
          'row': _row(['f', 'b', 't'], cross: cross),
          'f': _field(hint: 'Search'),
          'b': _box(60, 40),
          't': _text('Total'),
        });
        expect(on, off, reason: cross);
      }
    });

    testWidgets('a card (a column that draws a box) around a labelled field is one box', (tester) async {
      final (on, off) = await _onAndOff(tester, {
        'row': _row(['card', 'b']),
        'card': {
          'type': 'column',
          'children': ['label', 'f'],
          'layout': {'width': 240, 'height': {'hug': 0}, 'padding': [12, 12, 12, 12]},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}], 'strokes': [{'color': '#FFE5E7EB'}], 'strokeWidth': 1},
          'props': {'spacing': 6},
        },
        'label': _text('Profile'),
        'f': _field(label: 'Name', width: 200),
        'b': _box(60, 28),
      });
      expect(on['b'], off['b']);
      expect(on['card'], off['card']);
    });

    testWidgets('a column of a heading, a paragraph and a field is not a labelled field', (tester) async {
      final (on, off) = await _onAndOff(tester, {
        'row': _row(['col', 'img']),
        'col': {'type': 'column', 'children': ['h', 'p', 'f'], 'layout': {'width': 240, 'height': {'hug': 0}}, 'props': {'spacing': 6}},
        'h': _text('Stay in touch'),
        'p': _text('One email a month.'),
        'f': _field(hint: 'you@example.com', width: 200),
        'img': _box(80, 80),
      });
      expect(on, off);
    });

    testWidgets('a column, a stack and a wrapping row of boxes only', (tester) async {
      final (on, off) = await _onAndOff(tester, {
        'row': _row(['a', 'b', 'c'], wrap: true),
        'a': _box(300, 20),
        'b': _box(300, 30),
        'c': _box(100, 10),
      });
      expect(on, off);
    });
  });

  group('a row lines up a field and what is beside it on the field box (notation, Cards and SSUI)', () {
    for (final field in fields) {
      for (final partner in partners) {
        testWidgets('${field.name} and ${partner.name}', (tester) async {
          var wrappedOnOneRun = 0;
          for (final wrap in [false, true]) {
            for (final align in aligns) {
              final page = _page(field, partner, align, wrap);
              await showCards(tester, page, designSystem: field.designSystem ?? 'design_systems/cards', size: const Size(420, 500));
              expect(tester.takeException(), isNull, reason: page);
              final f = field.control(tester), p = partner.control(tester);
              final row = rectOf(tester, 'row');
              final say = '$page\nfield box $f, partner box $p, row $row';
              // The row holds what it lays out, and no more.
              final shown = [rectOf(tester, 'f'), rectOf(tester, 'p')];
              final top = shown.map((r) => r.top).reduce((a, b) => a < b ? a : b);
              final bottom = shown.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
              expect(row.top, lessThanOrEqualTo(top + 0.01), reason: say);
              expect(row.bottom, greaterThanOrEqualTo(bottom - 0.01), reason: say);
              // (A field held to a height draws an error that had no
              // helper's room below its box, out of its node: stretched,
              // the row keeps the room for it.)
              final errorHangs = align == 'stretch' && field.name.contains('error');
              if (!wrap && !errorHangs) expect(row.height, closeTo(bottom - top, 0.01), reason: say);
              // A wrapping row lines up each run on its own: one that put
              // the partner on the next run has nothing to line up across.
              if (wrap && !_overlaps(rectOf(tester, 'f'), rectOf(tester, 'p'))) continue;
              if (wrap) wrappedOnOneRun++;
              switch (align) {
                case '' || 'middle':
                  expect(p.center.dy, closeTo(f.center.dy, 0.5), reason: say);
                case 'top':
                  expect(p.top, closeTo(f.top, 0.5), reason: say);
                case 'bottom':
                  expect(p.bottom, closeTo(f.bottom, 0.5), reason: say);
                case 'stretch' when partner.name.startsWith('a nested row'):
                  // The nested row is stretched to the field's box and
                  // centers its own children on it (its own alignment).
                  expect(p.center.dy, closeTo(f.center.dy, 0.5), reason: say);
                case 'stretch':
                  expect(p.top, closeTo(f.top, 0.5), reason: say);
                  expect(p.height, closeTo(f.height, 0.5), reason: say);
              }
              // The nested row's own button sits on its field's box.
              if (partner.name.startsWith('a nested row') && align != 'stretch') {
                expect(rectOf(tester, 'p2').center.dy, closeTo(fieldBoxOf(tester, 'p1').center.dy, 0.5), reason: say);
              }
            }
          }
          // Wrapping, the two shared a run (and were lined up) at every
          // alignment, but where a wide field and the nested row don't fit
          // one run of the 384 px row.
          if (!partner.name.startsWith('a nested row')) expect(wrappedOnOneRun, aligns.length);
        });
      }
    }
  });
}

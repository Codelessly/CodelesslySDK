// A screen shown over everything as a banner (`openModal presentation=banner`,
// app/ui/banner.dart; codelessly_api docs/design/26-shown-over-and-in-sequence.md):
// the toast as a behaviour. It slides in over every route (a dialog's barrier
// included) without a barrier of its own, stays for closeAfterMs (the clock
// held while it is pressed), goes when swiped away or closed, and banners
// show one at a time in the order they were opened. The chain that opened it
// reads what closed it.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/app/ui/banner.dart' show CodelesslyBanner, bannersWaiting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' show v;
import 'support.dart';

Json _press(String text, List<Json> actions) => {
      'type': 'text',
      'layout': {'width': {'hug': 80}, 'height': {'hug': 20}},
      'props': {'text': text, 'style': {'color': '#FF111111', 'fontSize': 14}},
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': actions},
      ],
    };

Json _banner(String to, {int closeAfterMs = 0, Json extra = const {}}) => {
      'type': 'openModal',
      'to': to,
      'presentation': 'banner',
      if (closeAfterMs > 0) 'closeAfterMs': closeAfterMs,
      ...extra,
    };

/// A toast's screen: a full-width transparent canvas with a pill holding
/// [text] and an Undo that closes it with "undo".
PublishLayout _toast(String id, String text) => PublishLayout.fromJson({
      'schema': 3,
      'id': '$id-layout',
      'roots': [id],
      'nodes': {
        id: {
          'type': 'canvas',
          'name': id,
          'slots': {'body': '$id-pill'},
          'layout': {'width': 400, 'height': {'hug': 0}},
        },
        '$id-pill': {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}, 'padding': 12},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
          'props': {'spacing': 8},
          'children': ['$id-text', '$id-undo'],
        },
        '$id-text': {
          'type': 'text',
          'layout': {'width': {'hug': 80}, 'height': {'hug': 20}},
          'props': {'text': text, 'style': {'color': '#FF111111', 'fontSize': 14}},
        },
        '$id-undo': _press('Undo', [
          {'type': 'closeModal', 'result': 'undo'},
        ]),
      },
    });

PublishLayout _dialog() => PublishLayout.fromJson({
      'schema': 3,
      'id': 'dialog-layout',
      'roots': ['dialog'],
      'nodes': {
        'dialog': {
          'type': 'canvas',
          'name': 'dialog',
          'slots': {'body': 'dialog-body'},
          'layout': {'width': 300, 'height': 160},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        },
        'dialog-body': {
          'type': 'column',
          'layout': {'width': {'fill': 300}, 'height': {'fill': 160}, 'padding': 16},
          'children': ['dialog-save'],
        },
        'dialog-save': _press('Save from dialog', [_banner('saved', closeAfterMs: 1000)]),
      },
    });

PublishBundle _bundle() {
  final home = PublishLayout.fromJson({
    'schema': 3,
    'id': 'home-layout',
    'roots': ['home'],
    'variables': {
      'home': [v('answer', '').toJson()],
    },
    'nodes': {
      'home': {
        'type': 'canvas',
        'name': 'home',
        'slots': {'body': 'col'},
        'layout': {'width': 400, 'height': 800},
        'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
      },
      'col': {
        'type': 'column',
        'layout': {'width': {'fill': 400}, 'height': {'fill': 800}, 'padding': {'left': 24, 'top': 300, 'right': 24, 'bottom': 24}},
        'props': {'spacing': 16},
        'children': ['save', 'stay', 'twice', 'openDialog', 'bottom', 'grow'],
      },
      // What closed it is the chain's result: "undo", or empty when it
      // went by itself or was swiped away.
      'save': _press('Save', [
        _banner('saved', closeAfterMs: 1000),
        {'type': 'setVariable', 'variable': 'answer', 'value': r'closed:${result}'},
      ]),
      'stay': _press('Stay', [
        _banner('saved'),
        {'type': 'setVariable', 'variable': 'answer', 'value': r'closed:${result}'},
      ]),
      'twice': _press('Twice', [
        {..._banner('first', closeAfterMs: 500), 'nonBlocking': true},
        {..._banner('second', closeAfterMs: 500), 'nonBlocking': true},
      ]),
      'openDialog': _press('Dialog', [
        {'type': 'openModal', 'to': 'dialog', 'presentation': 'dialog'},
      ]),
      'grow': _press('Grow', [
        {'type': 'openModal', 'to': 'first', 'presentation': 'popover', 'anchor': 'trigger', 'enterScale': 0.5},
      ]),
      'bottom': _press('Bottom', [
        _banner('saved', closeAfterMs: 1000, extra: {'alignment': [0, 1]}),
      ]),
    },
  });
  final layouts = [home, _toast('saved', 'Saved to your journal'), _toast('first', 'First'), _toast('second', 'Second'), _dialog()];
  return PublishBundle(
    model: PublishModel(
      projectId: 'p',
      entryLayoutId: 'home-layout',
      layouts: {for (final l in layouts) l.id: PublishLayoutInfo.of(l)},
    ),
    layouts: {for (final l in layouts) l.id: l},
  );
}

Future<CodelesslyWidgetController> _show(WidgetTester tester) async {
  setScreen(tester, const Size(400, 800));
  final app = Codelessly.fromBundle(_bundle());
  addTearDown(app.dispose);
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
  await settle(tester);
  return controller;
}

/// Where the paragraph showing [text] is on screen, or null.
Rect? _textRect(WidgetTester tester, String text) {
  Rect? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderParagraph && o.text.toPlainText() == text && o.attached && o.hasSize) {
      found = Rect.fromPoints(o.localToGlobal(Offset.zero), o.localToGlobal(o.size.bottomRight(Offset.zero)));
      return;
    }
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return found;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tapAt(_textRect(tester, text)!.center);
  await tester.pump();
}

OverlayState _rootOverlay(WidgetTester tester) => tester.state<OverlayState>(find.byType(Overlay).first);

void main() {
  testWidgets('slides in along the top: frames at its start, middle and end', (tester) async {
    final controller = await _show(tester);
    await _tapText(tester, 'Stay');
    await tester.pump();
    final start = _textRect(tester, 'Saved to your journal')!;
    await tester.pump(const Duration(milliseconds: 140));
    final middle = _textRect(tester, 'Saved to your journal')!;
    await tester.pump(const Duration(milliseconds: 200));
    final end = _textRect(tester, 'Saved to your journal')!;
    // From above the screen's top edge to its place at the top.
    expect(start.top, lessThan(middle.top));
    expect(middle.top, lessThan(end.top));
    expect(end.top, closeTo(12, 1));
    // No barrier: the page behind still takes taps (the dialog opens).
    await _tapText(tester, 'Dialog');
    await settle(tester);
    expect(_textRect(tester, 'Save from dialog'), isNotNull);
    expect(controller.tree, isNotNull);
  });

  testWidgets('shows over a dialog and its barrier, and its Undo closes it with a result', (tester) async {
    final controller = await _show(tester);
    await _tapText(tester, 'Dialog');
    await settle(tester);
    await _tapText(tester, 'Save from dialog');
    await tester.pump(const Duration(milliseconds: 400));
    // Above the dialog's barrier: a tap on its Undo reaches it.
    await tester.pump();
    final undo = _textRect(tester, 'Undo')!;
    final hit = HitTestResult();
    tester.binding.hitTestInView(hit, undo.center, tester.view.viewId);
    final paragraph = hit.path.map((e) => e.target).whereType<RenderParagraph>().firstOrNull;
    expect(paragraph?.text.toPlainText(), 'Undo');
    // The page's own chain: Save shows it and reads what closed it.
    await tester.tapAt(undo.center);
    await settle(tester);
    expect(_textRect(tester, 'Saved to your journal'), isNull);
    // The dialog is still open under it.
    expect(_textRect(tester, 'Save from dialog'), isNotNull);
    expect(controller.tree, isNotNull);
  });

  testWidgets('closes itself after closeAfterMs; the clock holds while it is pressed', (tester) async {
    final controller = await _show(tester);
    await _tapText(tester, 'Save');
    // In (280 ms), then 1000 ms on screen.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_textRect(tester, 'Saved to your journal'), isNotNull);
    // Pressed (read, or about to be swiped): the clock holds.
    await tester.pump();
    final gesture = await tester.startGesture(_textRect(tester, 'Saved to your journal')!.center);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_textRect(tester, 'Saved to your journal'), isNotNull);
    expect(tester.state<State<CodelesslyBanner>>(find.byType(CodelesslyBanner)), isNotNull);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_textRect(tester, 'Saved to your journal'), isNotNull);
    // The rest of its time (400 ms), then out (200 ms).
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_textRect(tester, 'Saved to your journal'), isNull);
    expect(controller.read('answer'), isNot('closed:undo'));
    expect('${controller.read('answer')}', startsWith('closed:'));
  });

  testWidgets('a swipe up dismisses it: the chain reads no result', (tester) async {
    final controller = await _show(tester);
    await _tapText(tester, 'Stay');
    await tester.pump(const Duration(milliseconds: 400));
    final at = _textRect(tester, 'Saved to your journal')!;
    // It follows the finger, then flies off.
    await tester.pump();
    final gesture = await tester.startGesture(at.center);
    await gesture.moveBy(const Offset(0, -10));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(_textRect(tester, 'Saved to your journal')!.top, lessThan(at.top - 20));
    await gesture.moveBy(const Offset(0, -60));
    await gesture.up();
    await settle(tester);
    expect(_textRect(tester, 'Saved to your journal'), isNull);
    expect(controller.read('answer'), isNot('closed:undo'));
    expect('${controller.read('answer')}', startsWith('closed:'));
  });

  testWidgets('banners show one at a time, in the order they were opened', (tester) async {
    await _show(tester);
    await _tapText(tester, 'Twice');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_textRect(tester, 'First'), isNotNull);
    expect(_textRect(tester, 'Second'), isNull);
    expect(bannersWaiting(_rootOverlay(tester)), 1);
    // The first's 280 + 500 + 200 ms, then the second comes.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_textRect(tester, 'First'), isNull);
    expect(_textRect(tester, 'Second'), isNotNull);
    expect(bannersWaiting(_rootOverlay(tester)), 0);
    await settle(tester);
    await settle(tester);
    expect(_textRect(tester, 'Second'), isNull);
  });

  testWidgets('alignment [0,1] shows it along the bottom edge', (tester) async {
    await _show(tester);
    await _tapText(tester, 'Bottom');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_textRect(tester, 'Saved to your journal')!.bottom, greaterThan(740));
    await settle(tester);
    await settle(tester);
  });

  testWidgets('an anchored popover with enterScale grows out of the node that opened it', (tester) async {
    await _show(tester);
    final grow = _textRect(tester, 'Grow')!;
    await _tapText(tester, 'Grow');
    await tester.pump(const Duration(milliseconds: 16));
    final start = _textRect(tester, 'First')!;
    await tester.pump(const Duration(milliseconds: 400));
    final end = _textRect(tester, 'First')!;
    // Smaller at its start, and nearer the button than where it ends.
    expect(start.width, lessThan(end.width * 0.8));
    expect((start.center - grow.center).distance, lessThan((end.center - grow.center).distance));
  });
}

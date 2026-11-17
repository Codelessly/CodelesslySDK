// The keyboard in a modal overlay (ModalFocus, app/ui/presentation_route.dart): every dialog,
// sheet, side sheet, popover, full-screen cover and the built-in confirm
// takes the focus as it opens, keeps Tab inside, closes on Escape unless
// the document blocks it, gives the focus back to what opened it, and is
// named for assistive technology. Nested overlays unwind.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/focus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fields.dart';
import '../support/keyboard.dart';
import '../support/screen.dart' show v;
import 'support.dart';

Json _press(String text, List<Json> actions, {Json extra = const {}}) => {
      'type': 'text',
      'layout': {'width': {'hug': 80}, 'height': {'hug': 20}},
      'props': {'text': text, 'style': {'color': '#FF111111', 'fontSize': 14}},
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': actions},
      ],
      ...extra,
    };

Json _label(String text) => {
      'type': 'text',
      'layout': {'width': {'hug': 80}, 'height': {'hug': 20}},
      'props': {'text': text, 'style': {'color': '#FF111111', 'fontSize': 16}},
    };

/// An overlay's screen: a title and two press targets, `<id>-a` (closes it)
/// and `<id>-b`.
PublishLayout _overlay(String id, String title, {Json canvasProps = const {}, Json canvasBind = const {}, List<Json> canvasActions = const [], Json? first, Json? second, List<Variable> variables = const []}) =>
    PublishLayout.fromJson({
      'schema': 2,
      'id': '$id-layout',
      'roots': [id],
      'variables': {
        id: [for (final v in variables) v.toJson()],
      },
      'nodes': {
        id: {
          'type': 'canvas',
          'name': id,
          'slots': {'body': '$id-body'},
          'layout': {'width': 320, 'height': 200},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
          if (canvasProps.isNotEmpty) 'props': canvasProps,
          if (canvasBind.isNotEmpty) 'bind': canvasBind,
          if (canvasActions.isNotEmpty) 'actions': canvasActions,
        },
        '$id-body': {
          'type': 'column',
          'layout': {'width': {'fill': 320}, 'height': {'fill': 200}, 'padding': 16},
          'props': {'spacing': 12},
          'children': ['$id-title', '$id-a', '$id-b'],
        },
        '$id-title': _label(title),
        '$id-a': first ?? _press('Close', [{'type': 'closeModal'}]),
        '$id-b': second ?? _press('Other', [{'type': 'showToast', 'message': 'Other'}]),
      },
    });

/// A sheet whose content scrolls: a title and forty lines, as the notation's
/// `Sheet stops=[...]` expands (a column as tall as the sheet, scrolling).
PublishLayout _scrollingSheet() => PublishLayout.fromJson({
      'schema': 2,
      'id': 'tall-layout',
      'roots': ['tall'],
      'nodes': {
        'tall': {
          'type': 'canvas',
          'name': 'tall',
          'slots': {'body': 'tall-body'},
          'layout': {'width': 560, 'height': {'fill': 0}},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        },
        'tall-body': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'padding': 16},
          'props': {'spacing': 12, 'scrollable': true},
          'children': ['tall-title', for (var i = 0; i < 40; i++) 'tall-line$i'],
        },
        'tall-title': _label('Queue'),
        for (var i = 0; i < 40; i++) 'tall-line$i': _label('Line $i'),
      },
    });

Json _open(String to, String presentation, {Json extra = const {}}) =>
    {'type': 'openModal', 'to': to, 'presentation': presentation, ...extra};

PublishBundle _bundle() {
  final home = PublishLayout.fromJson({
    'schema': 2,
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
        'layout': {'width': 1200, 'height': 800},
        'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
      },
      'col': {
        'type': 'column',
        'layout': {'width': {'fill': 1200}, 'height': {'fill': 800}, 'padding': 24},
        'props': {'spacing': 16},
        'children': [
          'openDialog', 'openSheet', 'openSide', 'openPopover', 'openFull', 'openLocked', 'openGuard', 'openMenu', //
          'openConfirm', 'search', 'openLiveGuard', 'openSnapSheet', 'openTallSheet',
        ],
      },
      'openDialog': _press('Dialog', [_open('dialog', 'dialog')]),
      'openSheet': _press('Sheet', [_open('sheet', 'bottomSheet')]),
      'openSide': _press('Side', [_open('side', 'sideSheet')]),
      'openPopover': _press('Popover', [_open('popover', 'popover', extra: {'anchor': 'trigger'})]),
      'openFull': _press('Full', [_open('full', 'fullScreen')]),
      'openLocked': _press('Locked', [_open('locked', 'dialog', extra: {'barrierDismissible': false})]),
      'openGuard': _press('Guard', [_open('guard', 'dialog')]),
      'openLiveGuard': _press('Live guard', [_open('liveGuard', 'dialog')]),
      'openSnapSheet': _press('Snap sheet', [_open('snap', 'bottomSheet', extra: {'maxHeightFactor': 0.9, 'snapHeights': [0.5, 0.9]})]),
      'openTallSheet': _press('Tall sheet', [_open('tall', 'bottomSheet', extra: {'maxHeightFactor': 0.9, 'snapHeights': [0.5, 0.9], 'showDragHandle': true})]),
      'openMenu': _press('More', [_open('menu', 'popover', extra: {'anchor': 'trigger'})]),
      'openConfirm': _press('Delete', [
        {'type': 'confirm', 'title': 'Delete it?', 'message': 'This cannot be undone.'},
        {'type': 'setVariable', 'variable': 'answer', 'value': 'yes'},
      ]),
      // Suggestions that open while typing: the field keeps the focus.
      'search': {
        'type': 'textField',
        'layout': {'width': 240, 'height': 48},
        'actions': [
          {'trigger': {'type': 'changed'}, 'actions': [_open('popover', 'popover', extra: {'anchor': 'trigger'})]},
        ],
      },
    },
  });
  final layouts = [
    home,
    _overlay('dialog', 'Join the waitlist'),
    _overlay('sheet', 'Filters'),
    _overlay('side', 'Your cart'),
    _overlay('popover', 'What is this?'),
    _overlay('full', 'Onboarding'),
    _overlay('locked', 'Terms', canvasProps: {'semanticLabel': 'Accept the terms'}),
    _overlay('liveGuard', 'Draft', canvasBind: {'props.blockBack': r'${= name != ""}'}, variables: [v('name', '')],
      first: _press('Type', [{'type': 'setVariable', 'variable': 'name', 'value': 'Jo'}]),
      second: _press('Discard', [{'type': 'setVariable', 'variable': 'name', 'value': ''}, {'type': 'closeModal'}])),
    _overlay('snap', 'Booking details'),
    _scrollingSheet(),
    _overlay(
      'guard',
      'Unsaved changes',
      canvasProps: {'blockBack': true},
      variables: [v('asked', 0, VariableType.integer)],
      canvasActions: [
        {
          'trigger': {'type': 'backPressed'},
          'actions': [{'type': 'setVariable', 'variable': 'asked', 'op': 'add', 'value': '1'}],
        },
      ],
      first: _press('Asked', [{'type': 'closeModal'}], extra: {
        'bind': {'props.text': r'Asked ${asked}'},
      }),
    ),
    // A menu whose first item opens the dialog.
    _overlay('menu', 'Share', first: _press('Invite', [_open('dialog', 'dialog')])),
  ];
  return PublishBundle(
    model: PublishModel(
      projectId: 'p',
      entryLayoutId: 'home-layout',
      layouts: {for (final l in layouts) l.id: PublishLayoutInfo.of(l)},
    ),
    layouts: {for (final l in layouts) l.id: l},
  );
}

Future<CodelesslyWidgetController> _show(WidgetTester tester,
    {Size size = const Size(1200, 800), ThemeData? theme, TextDirection direction = TextDirection.ltr}) async {
  setScreen(tester, size);
  final app = Codelessly.fromBundle(_bundle());
  addTearDown(app.dispose);
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    builder: (context, child) => Directionality(textDirection: direction, child: child!),
    home: CodelesslyWidget(codelessly: app, controller: controller),
  ));
  await settle(tester);
  return controller;
}

/// Tabs until [id] has the focus.
Future<void> _tabTo(Keyboard keys, String id) async {
  for (var i = 0; i < 20 && keys.focusedId != id; i++) {
    await keys.tab();
  }
  expect(keys.focusedId, id);
}

String _texts(WidgetTester tester) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return out.toString();
}

/// Where the text [text] shows.
Offset _textCenter(WidgetTester tester, String text) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText() == text) found = o;
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return found!.localToGlobal(found!.size.center(Offset.zero));
}

/// Taps the text [text] where it shows (in an overlay's screen).
Future<void> _tapText(WidgetTester tester, String text) async {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText() == text) found = o;
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  await tester.tapAt(found!.localToGlobal(found!.size.center(Offset.zero)));
  await settle(tester);
}

void main() {
  for (final (opener, id, title) in const [
    ('openDialog', 'dialog', 'Join the waitlist'),
    ('openSheet', 'sheet', 'Filters'),
    ('openSide', 'side', 'Your cart'),
    ('openPopover', 'popover', 'Popover'),
    ('openFull', 'full', 'Onboarding'),
  ]) {
    testWidgets('$id: Enter opens it with the focus inside, Tab stays inside, Escape closes it and the focus returns', (tester) async {
      final handle = tester.ensureSemantics();
      await _show(tester);
      final keys = Keyboard(tester);
      await _tabTo(keys, opener);
      await keys.enter();
      await settle(tester);
      // On its first focusable, with the ring: the keyboard opened it.
      expect(keys.topOverlay, isNotNull);
      expect(keys.focusedId, '$id-a');
      expect(keys.ringShown, isTrue);
      expect(keys.inOverlay, isTrue);
      expect(keys.semantics!.isButton, isTrue);
      expect(keys.semantics!.isFocused, isTrue);
      expect(keys.semantics!.label, 'Close');
      // Named for assistive technology: its first text; a popover, by what
      // opened it.
      expect(keys.routeName, title);
      // Tab and Shift+Tab never leave it.
      final seen = <String?>{};
      for (var i = 0; i < 5; i++) {
        await keys.tab();
        seen.add(keys.focusedId);
      }
      for (var i = 0; i < 3; i++) {
        await keys.shiftTab();
        seen.add(keys.focusedId);
      }
      expect(seen, {'$id-a', '$id-b'});
      await keys.escape();
      await settle(tester);
      expect(keys.topOverlay, isNull);
      expect(_texts(tester), isNot(contains('Other')));
      expect(keys.focusedId, opener);
      expect(keys.ringShown, isTrue);
      handle.dispose();
    });
  }

  testWidgets('a pointer opens an overlay with no ring and nothing focused; the keys still stay in it', (tester) async {
    final controller = await _show(tester);
    final keys = Keyboard(tester);
    await tapNode(tester, controller, 'openDialog');
    expect(keys.topOverlay, isNotNull);
    expect(keys.focused, isNull, reason: 'the overlay itself holds the focus: no ring, no on-screen keyboard');
    // The first Tab goes to its first focusable, not to the page under it.
    await keys.tab();
    expect(keys.focusedId, 'dialog-a');
    expect(keys.ringShown, isTrue);
    await keys.tab();
    await keys.tab();
    expect(keys.focusedId, 'dialog-a');
    await keys.enter();
    await settle(tester);
    // Closed from the keyboard: the opener has the focus again.
    expect(keys.topOverlay, isNull);
    expect(keys.focusedId, 'openDialog');
  });

  testWidgets('opened and closed by a pointer, nothing is focused, and the next Tab starts at the opener', (tester) async {
    final controller = await _show(tester);
    final keys = Keyboard(tester);
    await tapNode(tester, controller, 'openSheet');
    expect(keys.topOverlay, isNotNull);
    await _tapText(tester, 'Close');
    expect(keys.topOverlay, isNull);
    expect(keys.focused, isNull);
    expect(keys.ringShown, isFalse);
    await keys.tab();
    expect(keys.focusedId, 'openSheet');
    expect(keys.ringShown, isTrue);
  });

  testWidgets('Escape closes an overlay a pointer opened, with nothing in it focused, and the opener gets the focus', (tester) async {
    final controller = await _show(tester);
    final keys = Keyboard(tester);
    await tapNode(tester, controller, 'openSide');
    expect(keys.topOverlay, isNotNull);
    expect(keys.focused, isNull);
    await keys.escape();
    await settle(tester);
    expect(keys.topOverlay, isNull);
    expect(keys.focusedId, 'openSide');
    expect(keys.ringShown, isTrue);
  });

  testWidgets('barrierDismissible: false keeps Escape from closing it; its canvas names it', (tester) async {
    final handle = tester.ensureSemantics();
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabTo(keys, 'openLocked');
    await keys.enter();
    await settle(tester);
    expect(keys.focusedId, 'locked-a');
    expect(keys.routeName, 'Accept the terms');
    await keys.escape();
    await settle(tester);
    expect(keys.topOverlay, isNotNull);
    expect(keys.focusedId, 'locked-a');
    // Its own action closes it, and the focus returns.
    await keys.enter();
    await settle(tester);
    expect(keys.topOverlay, isNull);
    expect(keys.focusedId, 'openLocked');
    handle.dispose();
  });

  testWidgets('a canvas that blocks back stays open on Escape and runs its backPressed reactions', (tester) async {
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabTo(keys, 'openGuard');
    await keys.enter();
    await settle(tester);
    expect(_texts(tester), contains('Asked 0'));
    await keys.escape();
    await settle(tester);
    expect(keys.topOverlay, isNotNull);
    expect(_texts(tester), contains('Asked 1'));
    expect(keys.focusedId, 'guard-a');
  });

  testWidgets('a live guard blocks outside press and Escape only after input changes', (tester) async {
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabTo(keys, 'openLiveGuard');
    await keys.enter();
    await settle(tester);
    await keys.enter();
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(keys.topOverlay, isNotNull);
    await keys.escape();
    await settle(tester);
    expect(keys.topOverlay, isNotNull);
    await keys.tab();
    await keys.enter();
    await settle(tester);
    expect(keys.topOverlay, isNull);
    await keys.enter();
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(keys.topOverlay, isNull);
  });

  testWidgets('sheet handle drags between half and full stops and exposes adjustable semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabTo(keys, 'openSnapSheet');
    await keys.enter();
    await settle(tester);
    final drag = find.byKey(const ValueKey('Codelessly sheet drag handle'));
    expect(drag, findsOneWidget);
    final halfTop = tester.getTopLeft(drag).dy;
    expect(halfTop, greaterThan(300));
    expect(tester.getSemantics(find.bySemanticsLabel('Sheet height')).value, '50% of screen');
    await tester.drag(drag, const Offset(0, -340));
    await settle(tester);
    expect(tester.getTopLeft(drag).dy, lessThan(halfTop - 200));
    expect(find.bySemanticsLabel('Sheet height'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Sheet height')).value, '90% of screen');
    await tester.drag(drag, const Offset(0, 340));
    await settle(tester);
    expect(tester.getTopLeft(drag).dy, closeTo(halfTop, 2));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    expect(tester.getTopLeft(drag).dy, lessThan(halfTop - 200));
    handle.dispose();
  });

  testWidgets('a drag on a sheet\'s scrolling content moves it to its top stop before the content scrolls', (tester) async {
    final controller = await _show(tester);
    await tapNode(tester, controller, 'openTallSheet');
    final handle = find.byKey(const ValueKey('Codelessly sheet drag handle'));
    final halfTop = tester.getTopLeft(handle).dy;
    // The handle is drawn 8 px below the sheet's top: half of 800 is 400.
    expect(halfTop, closeTo(408, 2));
    // Up from the title: the sheet grows to 90%, the content stays at its start.
    await tester.dragFrom(_textCenter(tester, 'Queue'), const Offset(0, -300));
    await settle(tester);
    expect(tester.getTopLeft(handle).dy, closeTo(88, 2));
    expect(_textCenter(tester, 'Queue').dy - tester.getTopLeft(handle).dy, lessThan(60));
    // At the top stop the content scrolls.
    final line = _textCenter(tester, 'Line 10').dy;
    await tester.dragFrom(_textCenter(tester, 'Line 10'), const Offset(0, -200));
    await settle(tester);
    expect(tester.getTopLeft(handle).dy, closeTo(88, 2));
    expect(_textCenter(tester, 'Line 10').dy, lessThan(line - 150));
    // Down: the content scrolls back to its start, then the sheet shrinks.
    await tester.dragFrom(_textCenter(tester, 'Line 10'), const Offset(0, 600));
    await settle(tester);
    expect(tester.getTopLeft(handle).dy, closeTo(408, 2));
    // A tap on the handle steps to the next stop.
    await tester.tap(find.byKey(const ValueKey('Codelessly sheet drag area')));
    await settle(tester);
    expect(tester.getTopLeft(handle).dy, closeTo(88, 2));
  });

  testWidgets('nested overlays unwind: a menu item opens a dialog, Escape goes back to the item, then to the button', (tester) async {
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabTo(keys, 'openMenu');
    await keys.enter();
    await settle(tester);
    expect(keys.focusedId, 'menu-a');
    final menu = keys.topOverlay;
    await keys.enter();
    await settle(tester);
    expect(keys.focusedId, 'dialog-a');
    expect(keys.topOverlay, isNot(same(menu)));
    // The menu under the dialog takes no key.
    await keys.tab();
    await keys.tab();
    expect(keys.focusedId, 'dialog-a');
    await keys.escape();
    await settle(tester);
    expect(keys.topOverlay, same(menu));
    expect(keys.focusedId, 'menu-a');
    expect(keys.ringShown, isTrue);
    await keys.escape();
    await settle(tester);
    expect(keys.topOverlay, isNull);
    expect(keys.focusedId, 'openMenu');
  });

  testWidgets('when the opener is gone the focus goes to what opened its overlay', (tester) async {
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabTo(keys, 'openMenu');
    await keys.enter();
    await settle(tester);
    final menu = keys.topOverlay!;
    await keys.enter();
    await settle(tester);
    expect(keys.focusedId, 'dialog-a');
    // The menu under the dialog closes first (its route is removed).
    final menuScreen = find.byType(NodeView).evaluate().elementAt(1);
    Navigator.of(menuScreen).removeRoute(ModalRoute.of(menuScreen)!);
    await settle(tester);
    expect(menu.isOpen, isFalse);
    expect(keys.focusedId, 'dialog-a');
    await keys.escape();
    await settle(tester);
    expect(keys.topOverlay, isNull);
    expect(keys.focusedId, 'openMenu');
  });

  testWidgets('the built-in confirm is named by its title, closes on Escape, and the focus returns', (tester) async {
    final handle = tester.ensureSemantics();
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabTo(keys, 'openConfirm');
    await keys.enter();
    await settle(tester);
    expect(find.text('Delete it?'), findsOneWidget);
    expect(keys.topOverlay, isNotNull);
    expect(keys.routeName, 'Delete it?');
    final cancel = find.byKey(const ValueKey('codelessly-confirm-cancel'));
    expect(cancel, findsOneWidget);
    final cancelLabel = find.descendant(of: cancel, matching: find.text('Cancel')).first;
    expect(Focus.of(tester.element(cancelLabel)).hasFocus, isTrue, reason: 'Cancel is the safe initial choice');
    // The page under it takes no key.
    await keys.tab();
    expect(keys.focused, isNull);
    await keys.escape();
    await settle(tester);
    expect(find.text('Delete it?'), findsNothing);
    expect(keys.topOverlay, isNull);
    expect(keys.focusedId, 'openConfirm');
    handle.dispose();
  });

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('confirm at phone width in dark theme with $direction keeps safe focus and button semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await _show(tester, size: const Size(390, 844), theme: ThemeData.dark(), direction: direction);
      final keys = Keyboard(tester);
      await _tabTo(keys, 'openConfirm');
      await keys.space();
      await settle(tester);
      expect(keys.routeName, 'Delete it?');
      final cancel = find.byKey(const ValueKey('codelessly-confirm-cancel'));
      final cancelLabel = find.descendant(of: cancel, matching: find.text('Cancel')).first;
      expect(Focus.of(tester.element(cancelLabel)).hasFocus, isTrue);
      expect(tester.getSemantics(cancel).hasFlag(SemanticsFlag.isButton), isTrue);
      expect(tester.takeException(), isNull);
      await keys.enter();
      await settle(tester);
      expect(keys.topOverlay, isNull);
      expect(keys.focusedId, 'openConfirm');
      handle.dispose();
    });
  }

  testWidgets('confirm pointer choices expose buttons and close on Cancel or OK', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = await _show(tester);
    final keys = Keyboard(tester);
    await tapNode(tester, controller, 'openConfirm');
    final cancel = find.byKey(const ValueKey('codelessly-confirm-cancel'));
    final ok = find.byKey(const ValueKey('codelessly-confirm-ok'));
    expect(tester.getSemantics(cancel).hasFlag(SemanticsFlag.isButton), isTrue);
    expect(tester.getSemantics(ok).hasFlag(SemanticsFlag.isButton), isTrue);
    await tester.tap(cancel);
    await settle(tester);
    expect(keys.topOverlay, isNull);
    await tapNode(tester, controller, 'openConfirm');
    await tester.tap(ok);
    await settle(tester);
    expect(keys.topOverlay, isNull);
    handle.dispose();
  });

  testWidgets('a popover that opens while a field is typed in leaves the focus in the field', (tester) async {
    await _show(tester);
    final keys = Keyboard(tester);
    final field = textField(tester);
    await tapField(tester, field);
    await typeInto(tester, 'ha', field: field);
    await settle(tester);
    expect(_texts(tester), contains('What is this?'));
    expect(field.focusNode.hasFocus, isTrue);
    expect(keys.topOverlay, isNull);
    expect(ControlFocusScope.focusedScope!.layer, isNull);
  });
}

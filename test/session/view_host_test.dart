// CodelesslyViewHost: the box a view is in is its whole world. A view in a
// 390 × 844 box of a 1440 × 900 app opens a dialog, a sheet, a drawer and a
// toast: under a host each is shown in the host's own navigator and overlay,
// whose bounds are the box (the dialog centred in it, the sheet in its lower
// half, nothing drawn outside it), and a press outside the box reaches what
// is there; with no host they are shown by the app's, over the whole window,
// as before.
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Catalog;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const String _ui = '''
Column gap=8 pad=16
  Button#d "Dialog" onTap={open dlg}
  Button#s "Sheet" onTap={open sh}
  Button#w "Drawer" onTap={open dr}
  Button#t "Toast" onTap={toast "Saved it"}
Dialog#dlg "New ticket"
  Text "In the dialog"
Sheet#sh
  Text "In the sheet"
Drawer#dr
  Text "In the drawer"
''';

const Rect _box = Rect.fromLTWH(100, 20, 390, 844);

UiSession _session() {
  final result = parseNotation(_ui, options: const NotationOptions(width: 390));
  expect(result.issues, isEmpty, reason: '${result.issues}');
  return UiSession(document: LayoutDocument.fromJson(result.document));
}

/// The rect of the text [text], wherever it is painted.
Rect? _textRect(WidgetTester tester, String text) {
  Rect? found;
  void visit(RenderObject o) {
    if (found == null && o is RenderParagraph && o.text.toPlainText() == text && o.attached && o.hasSize) {
      found = o.localToGlobal(Offset.zero) & o.size;
    }
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return found;
}

Offset _center(WidgetTester tester, String id) {
  Offset? at;
  void visit(RenderObject o) {
    if (at == null && o is NodeBox && o.id == id && o.hasSize) at = o.localToGlobal(o.size.center(Offset.zero));
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return at!;
}

int _outsidePresses = 0;

Future<void> _show(WidgetTester tester, UiSession session, {required bool host}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _outsidePresses = 0;
  final Widget view = CodelesslyView(session: session);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Stack(children: [
        // The app around the box: something to press beside it.
        Positioned(
          left: 700,
          top: 300,
          child: GestureDetector(
            key: const ValueKey('outside'),
            onTap: () => _outsidePresses++,
            child: const SizedBox(width: 200, height: 100, child: ColoredBox(color: Color(0xFFEEEEEE))),
          ),
        ),
        Positioned.fromRect(
          rect: _box,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: SizedBox.expand(key: const ValueKey('box'), child: host ? CodelesslyViewHost(child: view) : view),
          ),
        ),
      ]),
    ),
  ));
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _press(WidgetTester tester, String id) async {
  await tester.tapAt(_center(tester, id));
  await _settle(tester);
}

bool _inBox(Rect rect) => _box.contains(rect.topLeft) && _box.contains(rect.bottomRight - const Offset(0.01, 0.01));

void main() {
  testWidgets('under a host, what a view opens is in the host\'s box', (tester) async {
    final session = _session();
    await _show(tester, session, host: true);
    final BuildContext inside = tester.element(find.byType(CodelesslyView));
    final NavigatorState navigator = CodelesslyViewHost.navigatorOf(inside)!;
    final RenderBox overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    expect(overlay.localToGlobal(Offset.zero) & overlay.size, _box, reason: 'the host\'s overlay is the box');
    final NavigatorState app = Navigator.of(tester.element(find.byType(Scaffold)));
    expect(navigator, isNot(same(app)));
    expect(maybeViewNavigatorOf(inside, rootNavigator: true), same(navigator), reason: 'the root asked for under a host is the host\'s');

    // With nothing open, a press outside the box is the app's.
    await tester.tap(find.byKey(const ValueKey('outside')));
    expect(_outsidePresses, 1);

    // A dialog: a route of the host's navigator, centred in the box.
    await _press(tester, 'd');
    expect(navigator.canPop(), isTrue);
    expect(app.canPop(), isFalse, reason: 'the app\'s navigator has no route of the view\'s');
    final Rect dialog = _textRect(tester, 'In the dialog')!;
    expect(_inBox(dialog), isTrue, reason: '$dialog');
    expect(dialog.center.dx, closeTo(_box.center.dx, 150), reason: 'in the box, not at the window\'s centre (720)');
    // The barrier dims the box alone: a press outside it is the app's, and
    // does not close the dialog.
    await tester.tap(find.byKey(const ValueKey('outside')), warnIfMissed: false);
    await _settle(tester);
    expect(_outsidePresses, 2);
    expect(navigator.canPop(), isTrue);
    // A press on the barrier, inside the box, closes it.
    await tester.tapAt(_box.topLeft + const Offset(10, 830));
    await _settle(tester);
    expect(navigator.canPop(), isFalse);
    expect(_textRect(tester, 'In the dialog'), isNull);

    // A sheet: inside the box, in its lower half.
    await _press(tester, 's');
    expect(navigator.canPop(), isTrue);
    final Rect sheet = _textRect(tester, 'In the sheet')!;
    expect(_inBox(sheet), isTrue, reason: '$sheet');
    expect(sheet.top, greaterThan(_box.center.dy));
    navigator.pop();
    await _settle(tester);

    // A drawer: inside the box.
    await _press(tester, 'w');
    expect(navigator.canPop(), isTrue);
    final Rect drawer = _textRect(tester, 'In the drawer')!;
    expect(_inBox(drawer), isTrue, reason: '$drawer');
    navigator.pop();
    await _settle(tester);

    // A toast: in the host's overlay, inside the box.
    await _press(tester, 't');
    final Rect toast = _textRect(tester, 'Saved it')!;
    expect(_inBox(toast), isTrue, reason: '$toast');
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('with no host, they are shown by the app, as before', (tester) async {
    final session = _session();
    await _show(tester, session, host: false);
    final BuildContext inside = tester.element(find.byType(CodelesslyView));
    expect(CodelesslyViewHost.navigatorOf(inside), isNull);
    final NavigatorState app = Navigator.of(inside);
    expect(viewNavigatorOf(inside), same(app));
    await _press(tester, 'd');
    expect(app.canPop(), isTrue);
    final Rect dialog = _textRect(tester, 'In the dialog')!;
    // In the window's middle (720), which is outside the box (100 to 490).
    expect(dialog.center.dx, closeTo(720, 200));
    // The barrier covers the window: a press outside the box closes the dialog.
    await tester.tap(find.byKey(const ValueKey('outside')), warnIfMissed: false);
    await _settle(tester);
    expect(_outsidePresses, 0);
    expect(app.canPop(), isFalse);
  });
}

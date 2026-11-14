// The playground reads what is typed and shows it: a sample renders, an
// edit redraws, a line that cannot be read is listed with the rest still
// shown, another design system redraws the same text, the document can be
// read, and the page lays out on a narrow window.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playground/main.dart';

const Key _canvas = ValueKey<String>('playground-canvas');

/// Every text painted under [root], render objects included: the SDK draws
/// text without a Text widget.
String _painted(WidgetTester tester, Finder root) {
  final StringBuffer out = StringBuffer();
  void visit(RenderObject object) {
    if (object is RenderParagraph) out.writeln(object.text.toPlainText());
    if (object is RenderEditable) out.writeln(object.text?.toPlainText() ?? '');
    object.visitChildren(visit);
  }

  visit(tester.renderObject(root));
  return out.toString();
}

/// The center of the text [text] painted under [root].
Offset _centerOf(WidgetTester tester, Finder root, String text) {
  Offset? center;
  void visit(RenderObject object) {
    if (center != null) return;
    if (object is RenderParagraph && object.text.toPlainText() == text) {
      center = object.localToGlobal(object.size.center(Offset.zero));
      return;
    }
    object.visitChildren(visit);
  }

  visit(tester.renderObject(root));
  return center!;
}

Future<String> _file(String key) => File(key).readAsString();

/// Pumps the app at [size] and waits for the design systems (read from
/// files) and the first reading.
Future<NotationPlaygroundState> _open(WidgetTester tester, Size size, {Map<String, String> parameters = const <String, String>{}}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(PlaygroundApp(loadAsset: _file, parameters: parameters));
    for (int i = 0; i < 200 && find.byKey(_canvas).evaluate().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
  await tester.pump();
  expect(tester.takeException(), isNull);
  return tester.state<NotationPlaygroundState>(find.byType(NotationPlayground));
}

/// Taps the row of [sample] in the samples tree and lets its file load.
Future<void> _pickSample(WidgetTester tester, String sample) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(ValueKey<String>('tree-row-$sample')));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
}

void main() {
  test('every sample reads without a problem in every design system, but Mistakes', () {
    for (final PlaygroundDesignSystem system in playgroundDesignSystems) {
      final api.DesignSystem designSystem = api.DesignSystem.fromJson(
        (jsonDecode(File(system.asset).readAsStringSync()) as Map<Object?, Object?>).cast<String, Object?>(),
      );
      for (final PlaygroundSample sample in playgroundSamples) {
        final PlaygroundReading reading = PlaygroundReading.read(File(sample.asset).readAsStringSync(), designSystem);
        expect(reading.nodes, greaterThan(0), reason: '${sample.id} in ${system.id}');
        expect(
          reading.issues.map((Object issue) => '$issue'),
          sample.id == 'mistakes' ? isNotEmpty : isEmpty,
          reason: '${sample.id} in ${system.id}',
        );
        reading.session.dispose();
      }
    }
  });

  testWidgets('a sample renders, an edit redraws, a problem is listed, the design system switches, the document shows', (
    WidgetTester tester,
  ) async {
    final NotationPlaygroundState playground = await _open(tester, const Size(1440, 900));

    // The first sample, with nothing to report.
    expect(_painted(tester, find.byKey(_canvas)), contains('Start here'));
    expect(find.byKey(const ValueKey<String>('playground-no-problems')), findsOneWidget);
    expect(find.text('No problems'), findsWidgets);
    expect(find.textContaining('characters written'), findsOneWidget);
    expect(find.textContaining('as a document'), findsOneWidget);
    expect(find.text('10 nodes'), findsOneWidget);

    // An edit redraws once typing has stopped.
    final TextEditingController text = playground.text;
    text.text = text.text.replaceFirst('"Start here"', '"Edited title"');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painted(tester, find.byKey(_canvas)), isNot(contains('Edited title')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_painted(tester, find.byKey(_canvas)), contains('Edited title'));
    expect(find.text('Start here · edited'), findsOneWidget);

    // A line that cannot be read is listed with its place; the rest shows.
    final int lines = '\n'.allMatches(text.text.trimRight()).length + 1;
    text.text = '${text.text.trimRight()}\n  Button.nope "Odd"\n';
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('playground-problem-0')), findsOneWidget);
    expect(find.text('Ln ${lines + 1}, Col 10'), findsOneWidget);
    expect(find.text('1 problem'), findsOneWidget);
    expect(_painted(tester, find.byKey(const ValueKey<String>('playground-drawer'))), contains('No Button.nope.'));
    expect(_painted(tester, find.byKey(_canvas)), contains('Edited title'));

    // Selecting the problem puts the cursor on its line.
    await tester.tap(find.byKey(const ValueKey<String>('playground-problem-0')));
    await tester.pump();
    await tester.pump();
    final int lineStart = text.text.indexOf('  Button.nope');
    expect(text.selection.start, lineStart + 9);
    expect(text.selection.end, text.text.indexOf('\n', lineStart));

    // Another design system, the same text.
    await tester.tap(find.text('Paper'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Paper · 420 px'), findsOneWidget);
    expect(_painted(tester, find.byKey(_canvas)), contains('Edited title'));
    expect(playground.reading!.session.designSystem!.manifest.id, 'paper');

    // The document the notation expands to.
    await tester.tap(find.byKey(const ValueKey<String>('playground-tab-document')));
    await tester.pump();
    expect(_painted(tester, find.byKey(const ValueKey<String>('playground-drawer'))), contains('"schema": 3'));
    expect(tester.takeException(), isNull);

    // Another width.
    await tester.tap(find.text('720'));
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey<String>('playground-frame'))).width, 720 + 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sample opens from the list, and what the UI emits is listed until cleared', (WidgetTester tester) async {
    final NotationPlaygroundState playground = await _open(tester, const Size(1440, 900));

    await _pickSample(tester, 'state_and_actions');
    expect(tester.takeException(), isNull);
    expect(playground.text.text, startsWith('state seats=1'));
    expect(_painted(tester, find.byKey(_canvas)), contains('State and actions'));

    await tester.tap(find.byKey(const ValueKey<String>('playground-tab-events')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('playground-no-events')), findsOneWidget);

    // The SDK paints a button's label itself: Checkout is at the end of the
    // row that starts with the caption.
    final Rect frame = tester.getRect(find.byKey(const ValueKey<String>('playground-frame')));
    final double row = _centerOf(tester, find.byKey(_canvas), 'Seats: 1, billed monthly').dy;
    await tester.tapAt(Offset(frame.right - 16 - 24, row));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey<String>('playground-no-events')), findsNothing);
    final String events = _painted(tester, find.byKey(const ValueKey<String>('playground-drawer')));
    expect(events, contains('EMIT'));
    expect(events, contains('checkout'));
    expect(events, contains('TOAST'));
    // Newest first: the toast came after the emit.
    expect(events.indexOf('TOAST'), lessThan(events.indexOf('EMIT')));

    await tester.tap(find.byKey(const ValueKey<String>('playground-events-clear')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('playground-no-events')), findsOneWidget);
    // The host's toast leaves.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow window stacks the panes and opens the samples over the page', (WidgetTester tester) async {
    await _open(tester, const Size(700, 900), parameters: const <String, String>{'sample': 'mistakes', 'system': 'harbor'});
    expect(tester.takeException(), isNull);

    // The parameters chose the sample and the look.
    expect(find.text('Harbor · 420 px'), findsOneWidget);
    expect(find.text('5 problems'), findsOneWidget);
    expect(_painted(tester, find.byKey(_canvas)), contains('Lines the parser cannot read'));

    // Editor over preview over the drawer.
    final double editor = tester.getTopLeft(find.text('Notation')).dy;
    final double preview = tester.getTopLeft(find.text('Preview')).dy;
    final double drawer = tester.getTopLeft(find.byKey(const ValueKey<String>('playground-drawer'))).dy;
    expect(editor, lessThan(preview));
    expect(preview, lessThan(drawer));

    // The samples are a pane over the page.
    expect(find.byKey(const ValueKey<String>('playground-samples')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('playground-samples-open')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('playground-samples')), findsOneWidget);
    await _pickSample(tester, 'start_here');
    expect(find.byKey(const ValueKey<String>('playground-samples')), findsNothing);
    expect(_painted(tester, find.byKey(_canvas)), contains('Start here'));
    expect(tester.takeException(), isNull);

    // Narrower still, and dark.
    tester.view.physicalSize = const Size(380, 700);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('playground-theme')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}

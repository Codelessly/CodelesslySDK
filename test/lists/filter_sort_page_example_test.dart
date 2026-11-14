// The reference's "Filter, sort and page a list" example (codelessly_api
// tool/reference/examples/pages/table_filter.json, copied to
// test/fixtures/reference): computed variables chained (shown filters and
// sorts the records with lambdas, paged is one page of it), a search, a
// status dropdown, sortable headers and a pager. It works as the reference
// says: every record shows at first, the search and the filter narrow it
// and reset the page, a header sorts and flips, the pager moves.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/kit.dart' show LabelledControl;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fields.dart';

Future<UiSession> _show(WidgetTester tester) async {
  final json = jsonDecode(File('test/fixtures/reference/table_filter.json').readAsStringSync());
  final session = UiSession(document: LayoutDocument.fromJson(json));
  addTearDown(session.dispose);
  tester.view.physicalSize = const Size(390, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  await tester.pumpAndSettle();
  return session;
}

/// The texts on screen, top to bottom.
List<String> _texts(WidgetTester tester) {
  final out = <(double, String)>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.attached && o.hasSize) out.add((o.localToGlobal(Offset.zero).dy, o.text.toPlainText()));
    // A button draws its own label (no RenderParagraph).
    if (o is LabelledControl && o.attached && o.hasSize) {
      for (final l in o.labels) {
        out.add((o.localToGlobal(Offset.zero).dy, l.text));
      }
    }
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final t in out) t.$2];
}

/// The invoice numbers the list shows, top to bottom.
List<String> _rows(WidgetTester tester) => [for (final t in _texts(tester)) if (t.startsWith('INV-')) t.split(' ').first];

/// Whether [text] is on screen.
bool _shows(WidgetTester tester, String text) => _texts(tester).contains(text);

/// Taps the text [text] shows.
Future<void> _tap(WidgetTester tester, String text) async {
  RenderBox? hit;
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.attached && o.text.toPlainText() == text) hit = o;
    if (o is LabelledControl && o.attached && o.labels.any((l) => l.text == text)) hit = o;
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  expect(hit, isNotNull, reason: 'no text "$text" in ${_texts(tester)}');
  await tester.tapAt(hit!.localToGlobal(hit!.size.center(Offset.zero)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every record shows at first: an empty search and "All" match everything, three to a page', (tester) async {
    await _show(tester);
    expect(_rows(tester), ['INV-1', 'INV-2', 'INV-3']);
    expect(_shows(tester, '1–3 of 5'), isTrue, reason: '${_texts(tester)}');
  });

  testWidgets('the pager moves through the filtered list and stops at its last page', (tester) async {
    await _show(tester);
    await _tap(tester, 'Next');
    expect(_rows(tester), ['INV-4', 'INV-5']);
    expect(_shows(tester, '4–5 of 5'), isTrue, reason: '${_texts(tester)}');
    await _tap(tester, 'Next');
    expect(_shows(tester, '4–5 of 5'), isTrue, reason: '${_texts(tester)}');
  });

  testWidgets('the search narrows the list by customer and sends the pager back to the first page', (tester) async {
    await _show(tester);
    await _tap(tester, 'Next');
    await typeInto(tester, 'o');
    await tester.pumpAndSettle();
    // Globex, Hooli, Wonka.
    expect(_rows(tester), ['INV-2', 'INV-4', 'INV-5']);
    expect(_shows(tester, '1–3 of 3'), isTrue, reason: '${_texts(tester)}');
    await typeInto(tester, 'zz');
    await tester.pumpAndSettle();
    expect(_rows(tester), isEmpty);
    expect(_shows(tester, 'No invoices match'), isTrue, reason: '${_texts(tester)}');
  });

  testWidgets('the status filter keeps the matching records', (tester) async {
    await _show(tester);
    await _tap(tester, 'All');
    await tester.tap(find.text('Overdue').last);
    await tester.pumpAndSettle();
    expect(_rows(tester), ['INV-2', 'INV-4']);
    expect(_shows(tester, '1–2 of 2'), isTrue, reason: '${_texts(tester)}');
  });

  testWidgets('a header sorts by its column, and a second tap reverses it', (tester) async {
    await _show(tester);
    await _tap(tester, 'Amount');
    expect(_rows(tester), ['INV-3', 'INV-5', 'INV-4'], reason: '430, 520, 675');
    expect(_shows(tester, 'Amount ↑'), isTrue, reason: '${_texts(tester)}');
    await _tap(tester, 'Amount ↑');
    expect(_rows(tester), ['INV-1', 'INV-2', 'INV-4'], reason: '1200, 850, 675');
    expect(_shows(tester, 'Amount ↓'), isTrue, reason: '${_texts(tester)}');
  });
}

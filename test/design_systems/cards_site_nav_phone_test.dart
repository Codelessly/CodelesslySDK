// Cards' SiteNav on a phone: a brand of two words beside the menu button
// and a call to action. The brand kept its width, so the three were wider
// than a phone and the button was cut at the window's edge (10 px, on every
// page of a site). The brand's name gives way: it is cut with an ellipsis.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<UiSession> _show(WidgetTester tester, String notation, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final ds = await tester.runAsync(() => api.DesignSystem.load((ref) async {
        final file = File('design_systems/cards/$ref');
        return file.existsSync() ? file.readAsStringSync() : null;
      }));
  final session = UiSession(designSystem: ds);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(notation));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pumpAndSettle();
  return session;
}

Rect? _rectOf(WidgetTester tester, String id) {
  Rect? found;
  void visit(RenderObject o) {
    if (found == null && o is NodeBox && o.id == id && o.hasSize && !o.size.isEmpty) found = o.localToGlobal(Offset.zero) & o.size;
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return found;
}

const _nav = 'Page\n  SiteNav brand="Northlight 2027" icon="auto_awesome" links=["Home","Schedule","Speakers"] cta="Get tickets"\n  Section\n    Text "Welcome"\n';

void main() {
  testWidgets('on a phone the call to action is whole, inside the window, and the brand gives way', (tester) async {
    await _show(tester, _nav, const Size(390, 844));
    expect(tester.takeException(), isNull);
    final cta = _rectOf(tester, 'cta')!;
    expect(cta.right, closeTo(390 - 20, 0.01));
    expect(_rectOf(tester, 'menuButton')!.right, lessThan(cta.left));
    expect(_rectOf(tester, 'brandName')!.right, lessThan(_rectOf(tester, 'menuButton')!.left));
  });

  testWidgets('on a desktop the brand is as wide as its name', (tester) async {
    await _show(tester, _nav, const Size(1440, 900));
    expect(tester.takeException(), isNull);
    // (The test's font: fifteen letters, with the heading's letter spacing.)
    expect(_rectOf(tester, 'brandName')!.width, 267);
  });
}

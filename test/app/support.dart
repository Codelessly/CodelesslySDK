import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The publish fixtures (bundles of real projects).
PublishBundle fixture(String name) => decodeBundle(File('test/fixtures/publish/$name.json.gz').readAsBytesSync());

/// Content overflows are reported by the layout objects (test fonts are
/// wider than the designs'): not failures here.
void ignoreOverflows() {
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!'${d.exception}'.contains('overflowed by')) original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
}

void setScreen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// The id of the canvas of [layout] named [name].
String canvasNamed(PublishLayout layout, String name) =>
    layout.canvasIds.firstWhere((c) => layout.document[c]!.name == name);

/// The id of the first node named [name] in canvas [canvasId] of [layout].
String nodeNamed(PublishLayout layout, String canvasId, String name) =>
    layout.document.subtree(canvasId).firstWhere((n) => n.name == name).id;

/// The layout of [bundle] holding a canvas named [canvasName].
PublishLayout layoutWithCanvas(PublishBundle bundle, String canvasName) =>
    bundle.layouts.values.firstWhere((l) => l.canvasIds.any((c) => l.document[c]!.name == canvasName));

/// Taps the center of node [id]'s box in [controller]'s screen.
Future<void> tapNode(WidgetTester tester, CodelesslyWidgetController controller, String id) async {
  final box = controller.tree!.boxOf(id)!;
  final content = box.contentBox ?? box;
  await tester.tapAt(content.localToGlobal(content.size.center(Offset.zero)));
  await settle(tester);
}

/// Pumps a second of frames: screens with looping animations (spinners,
/// pulses) never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// An empty datePicker (bound to a variable that holds no date) shows no date
// (restaurant, brief 3: it showed today's while the variable stayed empty,
// so the available slots that read the variable never appeared). Control
// behavior: it shows its hint (render/controls/pickers.dart).
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

void main() {
  testWidgets('a datePicker whose bound value is empty shows no date until one is picked', (tester) async {
    final out = Directory.systemTemp.createTempSync('date_picker_empty');
    addTearDown(() => out.deleteSync(recursive: true));
    final report = await runRender(tester, RenderArgs(inputs: ['test/tool/fixtures/datepicker'], out: out.path, sizes: const [Size(390, 200)]));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final p = (await tester.runAsync(() => decodePng(File(report.images.single).readAsBytesSync())))!;
    // The field's text area (left of its calendar icon): no date drawn.
    var ink = 0;
    for (var y = 30; y < 60; y++) {
      for (var x = 32; x < 300; x++) {
        if (p.rgba[(y * p.width + x) * 4] < 128) ink++;
      }
    }
    expect(ink, lessThan(10), reason: 'an empty picker drew a date (today\'s) that its variable does not hold');
  });
}

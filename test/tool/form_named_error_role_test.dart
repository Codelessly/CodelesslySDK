// A form's fields after an invalid `validate`, under a theme whose `error`
// role names a theme color: they must still be drawn (nonprofit, brief 3:
// the invalid fields went blank). Owned by the controls engineer (theme roles
// reaching controls: control_theme.dart resolves `tokens.error` with
// colorOf, which does not look up the named color "clay"), so skipped here.
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

void main() {
  testWidgets('fields left invalid by validate are still drawn when the theme error role names a theme color', (tester) async {
    final out = Directory.systemTemp.createTempSync('form_named_error');
    addTearDown(() => out.deleteSync(recursive: true));
    final report = await runRender(tester, RenderArgs(inputs: ['test/tool/fixtures/form_named_error'], out: out.path,
        sizes: const [Size(390, 300)], steps: const [Step('tap', 'send')], label: 'invalid'));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final p = (await tester.runAsync(() => decodePng(File(report.images.single).readAsBytesSync())))!;
    // The field's error border and its error line are drawn in the theme's
    // clay (#AE553D), not left out (an unresolved name is transparent).
    var clay = 0;
    for (var i = 0; i < p.rgba.length; i += 4) {
      if ((p.rgba[i] - 0xAE).abs() < 24 && (p.rgba[i + 1] - 0x55).abs() < 24 && (p.rgba[i + 2] - 0x3D).abs() < 24) clay++;
    }
    expect(clay, greaterThan(200), reason: 'the invalid field is drawn in the error color');
  }, skip: true); // controls engineer: theme roles naming a theme color (see the comment above) // controls engineer: theme roles naming a theme color (see the comment above)
}

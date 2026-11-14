// soft_saas_ui's own toggles, slider and segmented control, rendered in
// Roboto, light and dark: the reference for the SDK's render-object
// controls (test/controls/ssui_toggles_reference_test.dart rebuilds this
// page from zero-prop core nodes).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

final _key = GlobalKey();

Future<void> _fonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(File('$dir/$f').readAsBytesSync().buffer.asByteData()));
  }
  await roboto.load();
  final lucide = FontLoader('packages/flutter_lucide/lucide')
    ..addFont(Future.value(File('${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/flutter_lucide-1.63.0/lib/fonts/lucide.ttf').readAsBytesSync().buffer.asByteData()));
  await lucide.load();
}

Widget _page(Brightness b) {
  Widget row(List<Widget> c) => Row(mainAxisSize: MainAxisSize.min, spacing: 12, crossAxisAlignment: CrossAxisAlignment.center, children: c);
  const days = [
    SegmentedControlOption(value: 'd', label: 'Day'),
    SegmentedControlOption(value: 'w', label: 'Week'),
    SegmentedControlOption(value: 'm', label: 'Month'),
  ];
  return Container(
    width: 600,
    height: 240,
    color: SoftSaaSTokens.secondaryBackground(b),
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
      row([
        SoftSaaSCheckbox(value: true, onChanged: (_) {}),
        SoftSaaSCheckbox(value: false, onChanged: (_) {}),
        SoftSaaSCheckbox(value: true, indeterminate: true, onChanged: (_) {}),
        SoftSaaSRadio<String>(value: 'a', groupValue: 'a', onChanged: (_) {}),
        SoftSaaSRadio<String>(value: 'b', groupValue: 'a', onChanged: (_) {}),
        SoftSaaSSwitch(value: true, onChanged: (_) {}),
        SoftSaaSSwitch(value: false, onChanged: (_) {}),
        const SoftSaaSCheckbox(value: true),
        SoftSaaSSwitch(value: true, onChanged: (_) {}, disabled: true),
      ]),
      row([
        SizedBox(width: 240, child: SoftSaaSSlider(value: 50, onChanged: (_) {}, showValue: false)),
        SizedBox(width: 160, child: SoftSaaSSlider(value: 80, onChanged: (_) {}, showValue: false)),
      ]),
      row([
        SoftSaaSSegmentedControl<String>(options: days, value: 'w', onChanged: (_) {}),
        SoftSaaSSegmentedControl<String>(options: days, value: 'd', onChanged: (_) {}, size: SegmentedControlSize.xs),
        SoftSaaSSegmentedControl<String>(options: days, value: 'm', onChanged: (_) {}, size: SegmentedControlSize.small),
      ]),
    ]),
  );
}

void main() {
  setUpAll(_fonts);
  for (final b in Brightness.values) {
    testWidgets('soft_saas_ui toggles: ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(600, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final base = b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark();
      final theme = base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Roboto'));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Roboto'),
            child: Material(child: RepaintBoundary(key: _key, child: Align(alignment: Alignment.topLeft, child: _page(b))))),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      File('${Platform.environment['OUT'] ?? '.'}/ssui-toggles-${b.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

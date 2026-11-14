// soft_saas_ui's own date and time pickers (closed) and its calendar,
// Roboto, light and dark: the reference for the SDK's render-object pickers.
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
    ..addFont(Future.value(File('/root/.pub-cache/hosted/pub.dev/flutter_lucide-1.63.0/lib/fonts/lucide.ttf').readAsBytesSync().buffer.asByteData()));
  await lucide.load();
}

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Widget _page(Brightness b) => Container(
      width: 640,
      height: 400,
      color: SoftSaaSTokens.secondaryBackground(b),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 180, child: SoftSaaSDatePicker(value: DateTime(2026, 3, 4), formatDate: _iso, onChanged: (_) {})),
          const SizedBox(width: 12),
          SizedBox(width: 180, child: SoftSaaSTimePicker(value: const TimeOfDay(hour: 9, minute: 30), use24HourFormat: true, onChanged: (_) {})),
          const SizedBox(width: 12),
          SizedBox(width: 180, child: SoftSaaSDatePicker(onChanged: (_) {})),
        ]),
        const SizedBox(height: 12),
        SoftSaaSCalendar(value: DateTime(2026, 3, 4), autofocus: false, onChanged: (_) {}),
      ]),
    );

void main() {
  setUpAll(_fonts);
  for (final b in Brightness.values) {
    testWidgets('soft_saas_ui pickers: ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(640, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final base = b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Roboto')),
        home: DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Roboto'),
            child: Material(child: RepaintBoundary(key: _key, child: Align(alignment: Alignment.topLeft, child: _page(b))))),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      File('${Platform.environment['OUT'] ?? '.'}/ssui-pickers-${b.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

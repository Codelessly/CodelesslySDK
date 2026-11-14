// soft_saas_ui's own SoftSaaSDropdown (Select), rendered in Roboto, light and
// dark: closed with a value, closed empty, and open. The reference for the
// SDK's render-object dropdown.
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

const _options = [SelectOption(value: 'Weekly', label: 'Weekly'), SelectOption(value: 'Monthly', label: 'Monthly'), SelectOption(value: 'Yearly', label: 'Yearly')];

void main() {
  setUpAll(_fonts);
  for (final b in Brightness.values) {
    testWidgets('soft_saas_ui select: ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(480, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final base = b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark();
      final theme = base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Roboto'));
      await tester.pumpWidget(RepaintBoundary(
        key: _key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Roboto'),
            child: Material(
              color: SoftSaaSTokens.secondaryBackground(b),
              child: Stack(children: [
                Positioned(left: 24, top: 24, width: 200, child: SoftSaaSDropdown(options: _options, value: 'Monthly', onChanged: (_) {})),
                Positioned(left: 248, top: 24, width: 200, child: SoftSaaSDropdown(options: _options, placeholder: 'Select…', onChanged: (_) {})),
                Positioned(left: 24, top: 76, width: 200, child: SoftSaaSDropdown(key: const ValueKey('open'), options: _options, value: 'Monthly', onChanged: (_) {})),
              ]),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      // The pointer leaves (no row hovered).
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      File('${Platform.environment['OUT']}/ssui-select-${b.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

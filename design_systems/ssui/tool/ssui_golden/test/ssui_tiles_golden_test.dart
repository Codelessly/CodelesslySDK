// soft_saas_ui's own Accordion (the flat style), rendered in Roboto, light and dark: the reference for the SDK's
// `accordion` (test/controls/tile_reference_test.dart). OUT=<dir> sets where the PNGs go.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

final _key = GlobalKey();
const _roboto = TextStyle(fontFamily: 'Roboto');

Future<void> _fonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(File('$dir/$f').readAsBytesSync().buffer.asByteData()));
  }
  await roboto.load();
  // The chevron's font (flutter_lucide), from the package's own folder.
  final lucide = FontLoader('packages/flutter_lucide/lucide');
  final pkg = File('.dart_tool/package_config.json').readAsStringSync();
  final root = RegExp(r'"rootUri":\s*"file://([^"]*flutter_lucide[^"]*)"').firstMatch(pkg)![1]!;
  lucide.addFont(Future.value(File('$root/lib/fonts/lucide.ttf').readAsBytesSync().buffer.asByteData()));
  await lucide.load();
}

Widget _page(Brightness b) => Container(
      color: SoftSaaSTokens.secondaryBackground(b),
      padding: const EdgeInsets.all(24),
      width: 600,
      height: 400,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 360,
        child: SoftSaaSAccordion(
          defaultOpen: const [0],
          // The content's text style sets no family (the platform's in an app): Roboto here, as the titles.
          items: const [
            AccordionItem(title: 'What is included?', content: Text('Every feature, for every seat on the team.', style: _roboto)),
            AccordionItem(title: 'Can I cancel at any time?', content: Text('Yes.', style: _roboto)),
            AccordionItem(title: 'Do you offer refunds?', content: Text('Within 30 days.', style: _roboto)),
          ],
        ),
      ),
    );

void main() {
  setUpAll(_fonts);
  for (final b in Brightness.values) {
    testWidgets('soft_saas_ui accordion: ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final base = b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark();
      final theme = base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Roboto'));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Roboto'),
            child: Material(child: RepaintBoundary(key: _key, child: Align(alignment: Alignment.topLeft, child: _page(b))))),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      final out = Platform.environment['OUT'] ?? '.';
      File('$out/ssui-accordion-${b.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

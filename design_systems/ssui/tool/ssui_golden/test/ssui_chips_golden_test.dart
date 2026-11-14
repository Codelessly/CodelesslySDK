// soft_saas_ui's own chips and badges, rendered in Roboto, light and dark: the reference for
// test/controls/chips_test.dart's pixel match (design_systems/ssui/examples/renders/ssui-reference/chips-*.png).
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
  final icons = FontLoader('MaterialIcons')..addFont(Future.value(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync().buffer.asByteData()));
  await icons.load();
}

Widget _page(Brightness b) {
  Widget row(List<Widget> c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: c));
  return Container(
    color: SoftSaaSTokens.secondaryBackground(b),
    padding: const EdgeInsets.all(24),
    width: 600,
    height: 160,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row([
        const SoftSaaSChip(label: 'Design'),
        const SoftSaaSChip(label: 'Engineering'),
        const SoftSaaSChip(label: 'Tagged', icon: Icon(Icons.sell)),
      ]),
      row([
        const SoftSaaSBadge(label: 'Draft'),
        const SoftSaaSBadge(label: 'Archived'),
      ]),
    ]),
  );
}

void main() {
  setUpAll(_fonts);
  for (final b in Brightness.values) {
    testWidgets('soft_saas_ui chips: ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(600, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = (b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark()).copyWith(
          textTheme: (b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark()).textTheme.apply(fontFamily: 'Roboto'));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Roboto'),
            child: Material(
                // The host Material's body style adds 0.25 letter spacing to SSUI's Text; SSUI's data has none.
                child: DefaultTextStyle.merge(
                    style: const TextStyle(letterSpacing: 0),
                    child: RepaintBoundary(key: _key, child: Align(alignment: Alignment.topLeft, child: _page(b)))))),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      File('${Platform.environment['OUT'] ?? '.'}/chips-${b.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

// soft_saas_ui's SoftSaaSTabBar (its bottom navigation), Roboto, light and dark: the reference for
// navigationBar and bottomNavigationBar (examples/renders/m3/navigation-ssui-*.png; written here as
// nav-ssui-<mode>.png).
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

void main() {
  setUpAll(_fonts);
  for (final b in Brightness.values) {
    testWidgets('SoftSaaSTabBar: ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(360, 120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = (b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark()).copyWith(
          textTheme: (b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark()).textTheme.apply(fontFamily: 'Roboto'));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Roboto'),
            child: Material(color: const Color(0x00000000), child: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: _key, child: SizedBox(width: 360,
              child: SoftSaaSTabBar(items: const [
                TabBarItem(label: 'Home', icon: Icons.home),
                TabBarItem(label: 'Search', icon: Icons.search),
                TabBarItem(label: 'Profile', icon: Icons.person),
              ], selectedIndex: 0, onTap: (_) {})))))),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      File('nav-ssui-${b.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
      // ignore: avoid_print
      print('size ${boundary.size}');
    });
  }
}

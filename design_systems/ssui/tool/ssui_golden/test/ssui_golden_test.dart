// soft_saas_ui's own widgets, rendered in Roboto, light and dark: the reference for the data version.
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
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final v in [SoftSaaSButtonVariant.primary, SoftSaaSButtonVariant.secondary, SoftSaaSButtonVariant.outline, SoftSaaSButtonVariant.ghost, SoftSaaSButtonVariant.destructive])
        row([
          for (final s in SoftSaaSButtonSize.values)
            SoftSaaSButton(onPressed: () {}, variant: v, size: s, child: Text('${v.name[0].toUpperCase()}${v.name.substring(1)} ${s.name}')),
        ]),
      row([
        SoftSaaSButton(onPressed: () {}, icon: Icons.add, child: const Text('New file')),
        SoftSaaSButton(onPressed: null, child: const Text('Disabled')),
        SoftSaaSButton(onPressed: null, variant: SoftSaaSButtonVariant.outline, child: const Text('Disabled')),
      ]),
      row([
        const SizedBox(width: 220, child: SoftSaaSTextInput(hintText: 'Full name')),
        SizedBox(width: 220, child: SoftSaaSTextInput(controller: TextEditingController(text: 'ada@example.com'))),
        SizedBox(width: 220, child: SoftSaaSTextInput(controller: TextEditingController(text: 'ada@example.com'), errorText: 'Enter an email.')),
      ]),
      row([
        SoftSaaSCheckbox(value: true, onChanged: (_) {}, label: 'I agree'),
        SoftSaaSCheckbox(value: false, onChanged: (_) {}, label: 'Send me news'),
        SoftSaaSSwitch(value: true, onChanged: (_) {}, label: 'Notifications'),
        SoftSaaSSwitch(value: false, onChanged: (_) {}, label: 'Dark mode'),
      ]),
      row([
        SoftSaaSSegmentedControl<String>(options: const [
          SegmentedControlOption(value: 'd', label: 'Day'),
          SegmentedControlOption(value: 'w', label: 'Week'),
          SegmentedControlOption(value: 'm', label: 'Month'),
        ], value: 'w', onChanged: (_) {}),
        for (final v in SoftSaaSBadgeVariant.values.take(6)) SoftSaaSBadge(label: v.name, variant: v),
      ]),
      SizedBox(width: 340, child: SoftSaaSPanel(title: 'Billing', subtitle: 'Your plan and invoices', expandBody: false,
          child: const Padding(padding: EdgeInsets.all(12), child: Text('Team plan, 12 seats, renews on 1 December.')))),
    ]),
  );
}

void main() {
  setUpAll(_fonts);
  for (final b in Brightness.values) {
    testWidgets('soft_saas_ui widgets: ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(1200, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = (b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark()).copyWith(
          textTheme: (b == Brightness.light ? SoftSaaSTheme.light() : SoftSaaSTheme.dark()).textTheme.apply(fontFamily: 'Roboto'));
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
      File(Platform.environment['OUT'] ?? 'ssui-${b.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

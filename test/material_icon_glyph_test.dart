import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog icons request styled SVGs by name, not Google codepoint', () {
    const icon = MaterialIcon(
      codepoint: 0xe037, // Flutter's font assigns a different glyph here.
      name: 'play_arrow',
      style: MaterialIconStyle.rounded,
      version: 16,
    );
    expect(
      icon.toSvgUrl(),
      'https://fonts.gstatic.com/s/i/materialiconsround/play_arrow/v16/24px.svg',
    );
  });

  testWidgets('renderer requests a vector without mounting a font icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            // Inspect the returned widget without mounting it: widget tests block
            // HTTP requests, and the SVG loader would otherwise fetch the CDN.
            final box = const SvgIcon(
              icon: MaterialIcon(
                codepoint: 0xe037,
                name: 'play_arrow',
                style: MaterialIconStyle.rounded,
                version: 16,
              ),
              color: Colors.red,
              size: 32,
            ).build(context) as SizedBox;
            final picture = box.child! as SvgPicture;
            expect(box.width, 32);
            expect(box.height, 32);
            expect(
              (picture.bytesLoader as SvgNetworkLoader).url,
              'https://fonts.gstatic.com/s/i/materialiconsround/play_arrow/v16/24px.svg',
            );
            expect(
              picture.colorFilter,
              const ColorFilter.mode(Colors.red, BlendMode.srcIn),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  test('the SDK never builds a non-constant IconData', () {
    final RegExp call = RegExp(r'(?<!const )(?<![\w.])IconData\(');
    final List<String> offenders = [
      for (final File file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          for (final (int i, String line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//') && call.hasMatch(line))
              '${file.path}:${i + 1}',
    ];
    expect(offenders, isEmpty);
  });

  test('the SDK does not ship a full Material Icons font map', () {
    expect(
      File('lib/src/utils/material_icons_by_name.dart').existsSync(),
      isFalse,
    );
    final renderer = File(
      'lib/src/transformers/widget_node_transformer_manager.dart',
    ).readAsStringSync();
    expect(renderer, contains('SvgPicture.network('));
    expect(renderer, isNot(contains('materialIconsByName[')));
  });
}

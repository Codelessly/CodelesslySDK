// A site's own files at run time: the fonts site.json declares (published
// with their path relative to the site) and the images its documents name by
// a relative path are read through the loader that loaded the site, as a
// Flutter app reads its assets.
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/app/site_files.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

final _woff = File('test/tool/fixtures/look/fonts/dm-sans-latin-400-normal.woff').readAsBytesSync();
final _png = File('test/tool/fixtures/look/images/photo.png').readAsBytesSync();

PublishBundle _bundle() {
  final layout = PublishLayout.fromJson({
    'schema': 3,
    'id': 'home',
    'roots': ['home'],
    'fonts': ['Plain Sans/400/false'],
    'nodes': {
      'home': {'type': 'canvas', 'slots': {'body': 'body'}, 'layout': {'width': 390, 'height': 844}},
      'body': {
        'type': 'column',
        'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
        'children': ['photo', 'gone', 'label'],
      },
      'photo': {
        'type': 'box',
        'layout': {'width': 320, 'height': 200},
        'decoration': {'fills': [{'type': 'image', 'image': {'url': 'images/photo.png', 'fit': 'cover'}}]},
      },
      'gone': {
        'type': 'box',
        'layout': {'width': 32, 'height': 32},
        'decoration': {'fills': [{'type': 'image', 'image': {'url': './images/gone.png'}}]},
      },
      'label': {
        'type': 'text',
        'props': {'text': 'Plain', 'style': {'fontFamily': 'Plain Sans', 'fontSize': 16, 'color': '#FF000000'}},
        'layout': {'width': 200, 'height': 24},
      },
    },
  });
  return PublishBundle(
    model: PublishModel(
      projectId: 'files',
      entryLayoutId: 'home',
      layouts: {'home': PublishLayoutInfo.of(layout)},
      fonts: {
        for (final f in PublishFont.ofFamilies([
          const FontFamily(family: 'Plain Sans', fonts: [FontAsset(asset: 'fonts/plain.woff')]),
        ]))
          f.id: f,
      },
    ),
    layouts: {'home': layout},
  );
}

class _Errors implements AnalyticsService {
  final List<String> types = [];
  @override
  void logError(Object error, {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) =>
      types.add('$type: $error');
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}
  @override
  void logScreen(String name, {String? layoutId}) {}
}

void main() {
  test('a WOFF file is unwrapped to the TrueType file the engine registers; WOFF2 is refused with the reason', () {
    final sfnt = sfntOf(_woff)!;
    expect(ByteData.sublistView(sfnt).getUint32(0), anyOf(0x00010000, 0x4F54544F));
    expect(sfnt.length, greaterThan(_woff.length), reason: 'its tables inflated');
    String? why;
    expect(sfntOf(Uint8List.fromList([0x77, 0x4F, 0x46, 0x32, ...List.filled(60, 0)]), why: (r) => why = r), isNull);
    expect(why, contains('WOFF2'));
  });

  test('a site image is a relative path to an image file, not a URL, an expression or another string', () {
    expect(siteImagesIn({
      'a': 'images/a.jpg',
      'b': ['https://x.com/b.png', r'images/${id}.png', 'data:image/png;base64,AA', 'Read more', './c.svg'],
    }), {'images/a.jpg', './c.svg'});
  });

  testWidgets('a declared font and a local image are read from the site\'s files; a missing file is logged by name',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    final errors = _Errors();
    final reads = <String>[];
    final loader = MemoryPublishLoader(_bundle(), assets: {'images/photo.png': _png}, readAsset: (path) async {
      reads.add(path);
      return path == 'fonts/plain.woff' ? _woff : null;
    });
    final app = Codelessly(
      loader: loader,
      fonts: const NoFontFetcher(),
      config: CodelesslyConfig(services: Services(analytics: errors)),
    );
    addTearDown(app.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.runAsync(() => app.loadLayout('home'));
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
    await settle(tester);

    expect(reads, contains('fonts/plain.woff'));
    expect(app.fonts.loaded, contains('Plain Sans/400/false'));
    final photo = controller.tree!.boxOf('photo')!.node!.decoration.fills.single.image!.url!;
    expect(photo, startsWith('data:image/png;base64,'));
    expect(controller.tree!.boxOf('gone')!.node!.decoration.fills.single.image!.url, './images/gone.png');
    expect(errors.types.where((t) => t.startsWith('site_file_missing')), [contains('images/gone.png')]);
  });

  test('a site served over HTTP names its files beside the bundle', () {
    final loader = HttpPublishLoader(projectId: 'my-site', baseUrl: 'https://cdn.example.com', bundle: true);
    expect('${loader.assetUrl('./images/hero.jpg')}', 'https://cdn.example.com/publish/my-site/files/images/hero.jpg');
  });
}

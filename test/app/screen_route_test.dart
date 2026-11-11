// A link opens a screen with the screens beneath it (ScreenRoute.under),
// and a translucent screen's route lets the one beneath show.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

PublishModel museum() {
  PublishLayoutInfo screen(String id, String? path, [api.ScreenRoute route = api.ScreenRoute.none]) =>
      PublishLayoutInfo(id: id, canvases: [PublishCanvas(id: id, name: id, path: path, route: route)]);
  return PublishModel(
    projectId: 'museum',
    entryLayoutId: 'wall',
    layouts: {
      'wall': screen('wall', 'layer/:layer'),
      'specimen': screen('specimen', 'specimen/:id', const api.ScreenRoute(under: '/')),
      'photo': screen('photo', 'specimen/:id/photo', const api.ScreenRoute(under: 'specimen/:id', translucent: true)),
      'glossary': screen('glossary', 'glossary', const api.ScreenRoute(under: '/')),
      'loop': screen('loop', 'loop', const api.ScreenRoute(under: 'loop')),
      'lost': screen('lost', '*path'),
    },
  );
}

void main() {
  test('the screens beneath a link, outermost first', () {
    final m = museum();
    expect(CanvasLocation.beneath(m, '/specimen/trilobite/photo?zoom=2'), ['/', '/specimen/trilobite']);
    expect(CanvasLocation.beneath(m, '/specimen/trilobite'), ['/']);
    expect(CanvasLocation.beneath(m, 'glossary?q=fossil'), ['/']);
    expect(CanvasLocation.beneath(m, '/layer/kaibab'), isEmpty);
    expect(CanvasLocation.beneath(m, '/nowhere'), isEmpty);
    expect(CanvasLocation.beneath(m, '/loop'), isEmpty);
  });

  test('a translucent screen', () {
    final m = museum();
    expect(CanvasLocation.isTranslucent(m, '/specimen/a/photo'), isTrue);
    expect(CanvasLocation.isTranslucent(m, '/specimen/a'), isFalse);
  });

  test('initial routes: the stack beneath, the translucent route not opaque', () async {
    final app = Codelessly(
      config: const CodelesslyConfig(projectId: 'museum'),
      loader: MemoryPublishLoader(PublishBundle(model: museum(), layouts: const {})),
      fonts: const NoFontFetcher(),
    );
    addTearDown(app.dispose);
    await app.initialize();
    final routes = CodelesslyWidget.onGenerateInitialRoutes(app)('/specimen/a/photo');
    expect([for (final r in routes) r.settings.name], ['/', '/specimen/a', '/specimen/a/photo']);
    expect([for (final r in routes) (r as PageRoute).opaque], [true, true, false]);
  });
}

// A family no file provides falls back by its class (round 11: Georgia,
// Roboto Slab and a script drew as the sans): tool/render/src/fonts.dart.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/fonts.dart';

void main() {
  test('a family\'s class, from its name', () {
    expect(
      {for (final f in ['Georgia', 'Playfair Display', 'Roboto Slab', 'Dancing Script', 'IBM Plex Mono', 'Inter', 'PT Sans', 'Noto Serif', 'Alegreya Sans']) f: fontClassOf(f).name},
      {
        'Georgia': 'serif',
        'Playfair Display': 'serif',
        'Roboto Slab': 'slab',
        'Dancing Script': 'script',
        'IBM Plex Mono': 'mono',
        'Inter': 'sans',
        'PT Sans': 'sans',
        'Noto Serif': 'serif',
        'Alegreya Sans': 'sans',
      },
    );
  });

  test('a serif no file provides takes the first serif the system has; a slab with none takes a serif; a sans none', () {
    const anton = 'test/tool/fixtures/latefont/fonts/Anton-Regular.ttf';
    final fetcher = DirectoryFontFetcher(const [], classFiles: {
      FontClass.serif: ['missing/georgia.ttf', anton],
      FontClass.slab: const [],
      FontClass.script: const [],
    });
    expect(fetcher.classFace('Georgia', 700, false)?.family, 'Anton');
    expect(fetcher.classFace('Roboto Slab', 400, false)?.family, 'Anton');
    expect(fetcher.classFace('Inter', 400, false), isNull);
  });
}

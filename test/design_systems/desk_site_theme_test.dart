// Desk under a site's theme, and on a website's page: every surface Desk
// draws itself is made from the site's surface and ink, every use of its
// accent follows the site's primary, a dark surface draws Desk's dark side,
// and a text under a `Page` takes Desk's page scale while an `App` keeps
// the app's.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'design_systems/desk';

Future<DesignSystem> _load() => DesignSystem.load((ref) async => File('$_dir/$ref').existsSync() ? File('$_dir/$ref').readAsStringSync() : null);

double _luma(Color c) => (0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue) / 255;

/// The names of the colours Desk draws a surface or a line in.
const _surfaces = ['window', 'card', 'pageFill', 'primaryBackground', 'raisedBackground', 'chrome', 'sidebar', 'band', 'well', 'subtleFill', 'neutralFill', 'track', 'hover', 'keycap'];
const _inks = ['primaryText', 'secondaryText', 'tertiaryText', 'ink', 'ink2', 'ink3'];

void main() {
  late DesignSystem desk;
  setUpAll(() async => desk = await _load());

  test('a cream surface and a brown ink: no surface of Desk stays white, no ink stays zinc, and each ink reads on each surface', () {
    final t = desk.themeUnder(ThemeTokens.fromJson({'surface': '#FFFAF4E6', 'onSurface': '#FF2A2620'}));
    for (final name in _surfaces) {
      final c = t.color(name)!;
      expect(c.toJson(), isNot('#FFFFFFFF'), reason: name);
      expect(c.red, greaterThanOrEqualTo(c.blue), reason: '$name is warm: ${c.toJson()}');
      expect(_luma(c), greaterThan(0.78), reason: '$name stays a light surface: ${c.toJson()}');
    }
    for (final ink in _inks) {
      for (final surface in ['window', 'card', 'band', 'well']) {
        expect(ThemeTokens.contrastOf(t.color(ink)!, t.color(surface)!), greaterThan(3.9), reason: '$ink on $surface');
      }
    }
    expect(t.color('line')!.red, greaterThan(t.color('line')!.blue));
  });

  test('a near-black surface as the light theme: Desk\'s dark side on that ground, every ink read on every surface', () {
    for (final site in [
      {'primary': '#FF3DFFB0', 'surface': '#FF0A0B0E', 'onSurface': '#FFE6E8EC'},
      {'primary': '#FFC6F432', 'surface': '#FF0B0B0B', 'onSurface': '#FFFFFFFF'},
      {'surface': '#FF101418'},
    ]) {
      final t = desk.themeUnder(ThemeTokens.fromJson(site));
      for (final name in _surfaces) {
        expect(_luma(t.color(name)!), lessThan(0.25), reason: '$name under $site: ${t.color(name)!.toJson()}');
      }
      for (final ink in _inks) {
        for (final surface in ['window', 'card', 'band', 'sidebar', 'raisedBackground']) {
          expect(ThemeTokens.contrastOf(t.color(ink)!, t.color(surface)!), greaterThan(4.4), reason: '$ink on $surface under $site');
        }
      }
      // What is drawn on the accent reads on it.
      expect(ThemeTokens.contrastOf(t.color('onAccent')!, t.color('accent')!), greaterThan(3), reason: '$site');
      expect(ThemeTokens.contrastOf(t.color('onPrimary')!, t.color('primary')!), greaterThan(3), reason: '$site');
      // Status tints are the dark ones.
      expect(_luma(t.color('successTint')!), lessThan(0.25));
    }
  });

  test('a site primary: no colour of Desk stays its indigo, light or dark', () {
    final t = desk.themeUnder(ThemeTokens.fromJson({'primary': '#FF0D9488'}));
    bool indigo(Color c) {
      final r = c.red / 255, g = c.green / 255, b = c.blue / 255;
      final max = [r, g, b].reduce((a, b) => a > b ? a : b), min = [r, g, b].reduce((a, b) => a < b ? a : b);
      if (max - min < 0.08) return false;
      final h = max == r ? ((g - b) / (max - min)) % 6 : (max == g ? (b - r) / (max - min) + 2 : (r - g) / (max - min) + 4);
      final hue = (h * 60 + 360) % 360;
      return hue >= 228 && hue <= 256;
    }

    const accent = ['accent', 'accentHover', 'accentText', 'accentTint', 'accentTintBorder', 'focusBorder', 'focusRing', 'activeTint', 'primaryTint', 'primaryTintBorder', 'selection', 'selectedRow', 'iconTile', 'chart1'];
    for (final dark in [false, true]) {
      final side = t.forBrightness(dark: dark);
      for (final name in accent) {
        expect(indigo(side.color(name)!), isFalse, reason: '${dark ? 'dark ' : ''}$name: ${side.color(name)!.toJson()}');
      }
      expect(indigo(side.color('primary')!), isFalse);
    }
  });

  test('no component of Desk writes a colour of its own: each is a name of the theme', () {
    final hex = RegExp(r'#[0-9A-Fa-f]{8}\b');
    for (final f in Directory('$_dir/components/src/components').listSync().whereType<File>().where((f) => f.path.endsWith('.txt'))) {
      final found = {
        for (final m in hex.allMatches(f.readAsStringSync()))
          // (Nothing at all is a value, not a colour of the system.)
          if (m[0] != '#00000000') m[0]!,
      };
      expect(found, isEmpty, reason: f.path);
    }
  });

  group('the page scale', () {
    NotationResult read(String text) {
      final catalog = desk.catalogOver(standardCatalog);
      final r = Catalog.run(catalog, () => parseNotation(text, catalog: catalog, options: NotationOptions.fromDesignSystem(desk, width: 1440, named: true)));
      expect(r.issues, isEmpty, reason: text);
      return r;
    }

    Object? styleOf(NotationResult r, String text) =>
        ((((r.document['nodes'] as Map).values.cast<Map>().firstWhere((n) => n['type'] == 'text' && (n['props'] as Map)['text'] == text))['props'] as Map)['style'] as Map)['from'];

    test('under a Page: the headline 60, the second heading 36, the lead 19, the body 16', () {
      final r = read('Page\n  Section\n    Text.heading1 "Head"\n    Text.heading2 "Two"\n    Text.lead "Lead"\n    Text "Body"\n    Text.muted "Muted"\n');
      expect([for (final t in ['Head', 'Two', 'Lead', 'Body', 'Muted']) styleOf(r, t)], ['heading1Page', 'heading2Page', 'leadPage', 'bodyPage', 'mutedPage']);
      final theme = desk.tokens;
      expect(theme.textStyle('heading1Page')!.fontSize, inInclusiveRange(56, 72));
      expect(theme.textStyle('heading2Page')!.fontSize, 36);
      expect(theme.textStyle('leadPage')!.fontSize, inInclusiveRange(18, 20));
      expect(theme.textStyle('bodyPage')!.fontSize, inInclusiveRange(15, 16));
    });

    test('in an App: the app\'s scale, exactly', () {
      final r = read('App\n  Main\n    Text.heading1 "Head"\n    Text.heading2 "Two"\n    Text.lead "Lead"\n    Text "Body"\n');
      expect([for (final t in ['Head', 'Two', 'Lead']) styleOf(r, t)], ['heading1', 'heading2', 'lead']);
      final theme = desk.tokens;
      expect(theme.textStyle('heading1')!.fontSize, 30);
      expect(theme.textStyle('body')!.fontSize, 13);
      expect(theme.sizes['control'], 34);
    });

    test('every page style is a style of the app\'s scale too', () {
      for (final name in desk.tokens.textStyles.keys.where((k) => k.endsWith('Page'))) {
        expect(desk.tokens.textStyles, contains(name.substring(0, name.length - 4)), reason: name);
      }
    });
  });

  test('a Banner, a Status and a Stat have one word for each tone: tone="error" is said with danger; a Brand with no icon has its letter in a rail', () {
    final catalog = desk.catalogOver(standardCatalog);
    final r = Catalog.run(
        catalog,
        () => parseNotation('Column\n  Banner "Sold out" tone="danger"\n  Status "Failed" tone="danger" pill\n  Stat "Errors" "3" tone="danger"\n  Brand "Cutline" rail=true\n',
            catalog: catalog, options: NotationOptions.fromDesignSystem(desk, width: 1440, named: true)));
    expect(r.issues, isEmpty);
    final said = Catalog.run(
        catalog,
        () => parseNotation('Column\n  Banner "Sold out" tone="error"\n  Status "Failed" tone="error" pill\n  Stat "Errors" "3" tone="error"\n',
            catalog: catalog, options: NotationOptions.fromDesignSystem(desk, width: 1440, named: true)));
    expect([for (final i in said.issues) i.message], [
      'A Banner\'s tone is one of info, success, warning, danger, neutral: tone=danger.',
      'A Status\'s tone is one of neutral, success, warning, danger, info, accent: tone=danger.',
      'A Stat\'s tone is one of neutral, success, warning, danger, info: tone=danger.',
    ]);
    final brand = desk.components.definitions['Brand']!;
    expect(brand.toJson().toString(), contains('markLetter'));
  });
}

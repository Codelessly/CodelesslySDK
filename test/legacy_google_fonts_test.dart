import 'dart:typed_data';

import 'package:codelessly_sdk/src/utils/legacy_google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(LegacyGoogleFonts.reset);

  test('families google_fonts dropped are listed with their files', () {
    expect(LegacyGoogleFonts.has('Big Shoulders Stencil Display'), isTrue);
    expect(LegacyGoogleFonts.has('IBM Plex Sans Condensed'), isTrue);
    expect(LegacyGoogleFonts.has('Roboto Condensed'), isTrue);
    expect(LegacyGoogleFonts.has('Roboto'), isFalse);
    for (final files in legacyGoogleFontFiles.values) {
      for (final url in files.values) {
        expect(url, startsWith('https://fonts.gstatic.com/'));
        expect(url, endsWith('.ttf'));
      }
    }
  });

  test('picks the nearest weight in the same style', () {
    expect(
      LegacyGoogleFonts.variantFor('IBM Plex Sans Condensed', 600, false),
      '600',
    );
    expect(
      LegacyGoogleFonts.variantFor('IBM Plex Sans Condensed', 650, true),
      '600italic',
    );
    expect(
      LegacyGoogleFonts.variantFor('Big Shoulders Stencil Display', 850, false),
      '800',
    );
    expect(LegacyGoogleFonts.variantFor('Saira Stencil One', 700, true), '400');
    expect(LegacyGoogleFonts.variantFor('Nope', 400, false), isNull);
  });

  test('loads each file once under the family name', () async {
    final fetched = <String>[];
    final registered = <String>[];
    LegacyGoogleFonts.fetch = (url) async {
      fetched.add(url);
      return Uint8List(4);
    };
    LegacyGoogleFonts.register = (family, bytes) async =>
        registered.add(family);
    await Future.wait([
      LegacyGoogleFonts.ensure('Big Shoulders Text', weight: 700),
      LegacyGoogleFonts.ensure('Big Shoulders Text', weight: 700),
      LegacyGoogleFonts.ensure('Big Shoulders Text', weight: 500),
    ]);
    expect(fetched, hasLength(2));
    expect(registered, ['Big Shoulders Text', 'Big Shoulders Text']);
  });

  test('a failed download leaves the fallback font', () async {
    LegacyGoogleFonts.fetch = (url) async => throw Exception('offline');
    await LegacyGoogleFonts.ensure('Roboto Condensed');
  });
}

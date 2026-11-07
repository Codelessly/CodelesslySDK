// Runtime of the v1 features ported to v2 by the widgets area.
import 'dart:ui' as ui;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/src/render/convert.dart';
import 'package:codelessly_sdk_v2/src/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text and values', () {
    test('font features: last per tag wins, tnum for tabular figures', () {
      final s = textStyle(const api.TextStyle(fontFeatures: ['lnum', 'liga', 'liga=0'], tabularFigures: true));
      expect(s.fontFeatures, const [ui.FontFeature('lnum'), ui.FontFeature('liga', 0), ui.FontFeature.tabularFigures()]);
      expect(textStyle(const api.TextStyle(tabularFigures: true)).fontFeatures, const [ui.FontFeature.tabularFigures()]);
      expect(textStyle(api.TextStyle.empty).fontFeatures, isNull);
    });

    test('leading distribution: proportional unless even', () {
      expect(textStyle(api.TextStyle.empty).leadingDistribution, TextLeadingDistribution.proportional);
      expect(textStyle(const api.TextStyle(leadingDistribution: api.TextLeadingDistribution.even)).leadingDistribution,
          TextLeadingDistribution.even);
    });

    test('input decoration: padding with the border, icon padding, always-visible affixes', () {
      final d = api.InputDecoration.fromJson({
        'paddingIncludesBorder': true,
        'enabledBorder': {'borderSide': {'width': 2}},
        'focusedBorder': {'type': 'underline', 'borderSide': {'width': 3}},
        'suffixText': 'kWh',
        'affixesAlwaysVisible': true,
        'prefixIcon': {'icon': {'source': 'material', 'name': 'home', 'codepoint': 59530}},
        'prefixIconPadding': [12, 0, 8, 0],
      });
      final rest = inputDecoration(d, const api.EdgeInsets.all(10));
      expect(rest.contentPadding, const EdgeInsets.all(12));
      final focused = inputDecoration(d, const api.EdgeInsets.all(10), focused: true);
      expect(focused.contentPadding, const EdgeInsets.fromLTRB(10, 10, 10, 13));
      expect(rest.suffix, isNull);
      expect(rest.suffixIcon, isA<Padding>());
      expect(rest.suffixIconConstraints, const BoxConstraints());
      expect(rest.prefixIcon, isA<Padding>());
      expect(rest.prefixIconConstraints, const BoxConstraints());
    });
  });
}

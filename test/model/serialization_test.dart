// Copyright (c) 2022, Codelessly.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE.md file.

/// Tests for JSON serialization behavior, specifically:
/// - Round-trip serialization (toJson -> fromJson)
/// - Empty string handling
/// - Default value handling
/// - Null value exclusion
library;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FontVariantModel serialization', () {
    test('round-trip preserves all values', () {
      const original = FontVariantModel(
        name: 'Bold',
        weight: FontWeightNumeric.w700,
        style: 'Italic',
        fontURL: 'https://example.com/font.ttf',
        previewURL: 'https://example.com/preview.png',
      );

      final json = original.toJson();
      final restored = FontVariantModel.fromJson(json);

      expect(restored.name, equals(original.name));
      expect(restored.weight, equals(original.weight));
      expect(restored.style, equals(original.style));
      expect(restored.fontURL, equals(original.fontURL));
      expect(restored.previewURL, equals(original.previewURL));
    });

    test('round-trip with default values preserves defaults', () {
      const original = FontVariantModel();

      final json = original.toJson();
      final restored = FontVariantModel.fromJson(json);

      expect(restored.name, equals('regular'));
      expect(restored.weight, equals(FontWeightNumeric.w400));
      expect(restored.style, equals('Normal'));
      expect(restored.fontURL, equals(''));
      expect(restored.previewURL, equals(''));
    });

    test('fromJson handles missing fields by using defaults', () {
      final json = <String, dynamic>{};
      final model = FontVariantModel.fromJson(json);

      expect(model.name, equals('regular'));
      expect(model.weight, equals(FontWeightNumeric.w400));
      expect(model.style, equals('Normal'));
      expect(model.fontURL, equals(''));
      expect(model.previewURL, equals(''));
    });

    group('optimized default value exclusion', () {
      test('default values are excluded from JSON (optimized serialization)', () {
        const model = FontVariantModel();
        final json = model.toJson();

        // Optimized behavior: default values are excluded to save storage
        expect(json.containsKey('name'), isFalse,
            reason: 'default name should be excluded');
        expect(json.containsKey('weight'), isFalse,
            reason: 'default weight should be excluded');
        expect(json.containsKey('style'), isFalse,
            reason: 'default style should be excluded');
        expect(json.containsKey('fontURL'), isFalse,
            reason: 'empty fontURL should be excluded');
        expect(json.containsKey('previewURL'), isFalse,
            reason: 'empty previewURL should be excluded');

        // Empty JSON for defaults saves maximum storage
        expect(json.isEmpty, isTrue,
            reason: 'default FontVariantModel should serialize to empty JSON');
      });

      test('non-default values ARE serialized', () {
        const model = FontVariantModel(
          name: 'Bold',
          weight: FontWeightNumeric.w700,
          style: 'Italic',
          fontURL: 'https://fonts.example.com/bold.ttf',
          previewURL: 'https://preview.example.com/bold.png',
        );

        final json = model.toJson();

        // Non-default values should be present
        expect(json['name'], equals('Bold'));
        expect(json['weight'], equals('w700'));
        expect(json['style'], equals('Italic'));
        expect(json['fontURL'], equals('https://fonts.example.com/bold.ttf'));
        expect(json['previewURL'], equals('https://preview.example.com/bold.png'));
      });

      test('partial defaults - only non-default values are serialized', () {
        const model = FontVariantModel(
          name: 'Bold',  // non-default
          weight: FontWeightNumeric.w400,  // default - should be excluded
          style: 'Italic',  // non-default
          fontURL: '',  // default - should be excluded
          previewURL: 'https://preview.example.com/bold.png',  // non-default
        );

        final json = model.toJson();

        // Non-default values present
        expect(json.containsKey('name'), isTrue);
        expect(json.containsKey('style'), isTrue);
        expect(json.containsKey('previewURL'), isTrue);

        // Default values excluded
        expect(json.containsKey('weight'), isFalse);
        expect(json.containsKey('fontURL'), isFalse);
      });

      test('demonstrates storage savings', () {
        const modelWithDefaults = FontVariantModel();
        const modelWithValues = FontVariantModel(
          name: 'Bold',
          weight: FontWeightNumeric.w700,
          style: 'Italic',
          fontURL: 'https://fonts.example.com/bold.ttf',
          previewURL: 'https://preview.example.com/bold.png',
        );

        final jsonDefaults = modelWithDefaults.toJson();
        final jsonValues = modelWithValues.toJson();

        // Default model serializes to empty JSON
        expect(jsonDefaults.isEmpty, isTrue);

        // Non-default model has all fields
        expect(jsonValues.length, equals(5));

        // Print for documentation purposes
        // ignore: avoid_print
        print('JSON with defaults (optimized): $jsonDefaults');
        // ignore: avoid_print
        print('JSON with values: $jsonValues');
        // ignore: avoid_print
        print('Storage saved: ${jsonValues.toString().length} characters for default models');
      });
    });
  });

  group('CustomComponent serialization', () {
    test('round-trip preserves all values', () {
      final original = CustomComponent(
        id: 'test-id',
        name: 'Test Component',
        data: ComponentData(
          width: 100,
          height: 200,
          nodes: {'root': <String, dynamic>{}},
          parentId: 'root',
          originalParentId: 'root',
        ),
        projectId: 'project-1',
        pageId: 'page-1',
        previewUrl: 'https://example.com/preview.png',
        blurhash: 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
        version: 1,
      );

      final json = original.toJson();
      final restored = CustomComponent.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.projectId, equals(original.projectId));
      expect(restored.pageId, equals(original.pageId));
      expect(restored.previewUrl, equals(original.previewUrl));
      expect(restored.blurhash, equals(original.blurhash));
    });

    test('documents current behavior: empty strings ARE serialized', () {
      final model = CustomComponent(
        id: 'test-id',
        name: '', // empty string
        data: ComponentData(
          width: 100,
          height: 200,
          nodes: {'root': <String, dynamic>{}},
          parentId: 'root',
          originalParentId: 'root',
        ),
        projectId: 'project-1',
        pageId: 'page-1',
        blurhash: '', // empty string
        version: 1,
      );

      final json = model.toJson();

      // Document current behavior: empty strings are serialized
      expect(json.containsKey('name'), isTrue,
          reason: 'name is serialized even when empty string');
      expect(json.containsKey('blurhash'), isTrue,
          reason: 'blurhash is serialized even when empty string');

      expect(json['name'], equals(''));
      expect(json['blurhash'], equals(''));
    });

    test('null previewUrl is correctly excluded (include_if_null: false)', () {
      final model = CustomComponent(
        id: 'test-id',
        name: 'Test',
        data: ComponentData(
          width: 100,
          height: 200,
          nodes: {'root': <String, dynamic>{}},
          parentId: 'root',
          originalParentId: 'root',
        ),
        projectId: 'project-1',
        pageId: 'page-1',
        previewUrl: null, // null value
        version: 1,
      );

      final json = model.toJson();

      // This should pass because include_if_null: false is configured
      expect(json.containsKey('previewUrl'), isFalse,
          reason: 'null previewUrl should be excluded due to include_if_null: false');
    });
  });

  group('DateTimeConverter', () {
    test('serializes DateTime to milliseconds', () {
      final dateTime = DateTime.utc(2024, 1, 15, 12, 30, 45);
      const converter = DateTimeConverter();

      final millis = converter.toJson(dateTime);

      expect(millis, equals(dateTime.millisecondsSinceEpoch));
    });

    test('deserializes milliseconds to DateTime', () {
      final original = DateTime.utc(2024, 1, 15, 12, 30, 45);
      const converter = DateTimeConverter();

      final millis = converter.toJson(original);
      final restored = converter.fromJson(millis);

      // Note: restored is local time, original is UTC
      expect(restored!.toUtc(), equals(original));
    });

    test('fromJson handles null by returning current time', () {
      const converter = DateTimeConverter();
      final before = DateTime.now();
      final result = converter.fromJson(null);
      final after = DateTime.now();

      expect(result.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}

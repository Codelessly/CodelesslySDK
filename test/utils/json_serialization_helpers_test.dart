// Copyright (c) 2022, Codelessly.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE.md file.

import 'package:codelessly_sdk/src/utils/json_serialization_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emptyStringToNull', () {
    test('returns null for empty string', () {
      expect(emptyStringToNull(''), isNull);
    });

    test('returns value for non-empty string', () {
      expect(emptyStringToNull('hello'), equals('hello'));
    });

    test('returns value for whitespace-only string', () {
      // Note: emptyStringToNull does NOT trim, use blankStringToNull for that
      expect(emptyStringToNull('   '), equals('   '));
    });
  });

  group('blankStringToNull', () {
    test('returns null for empty string', () {
      expect(blankStringToNull(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(blankStringToNull('   '), isNull);
      expect(blankStringToNull('\t\n'), isNull);
    });

    test('returns value for non-blank string', () {
      expect(blankStringToNull('hello'), equals('hello'));
      expect(blankStringToNull('  hello  '), equals('  hello  '));
    });
  });

  group('trueToNull', () {
    test('returns null for true', () {
      expect(trueToNull(true), isNull);
    });

    test('returns false for false', () {
      expect(trueToNull(false), isFalse);
    });
  });

  group('falseToNull', () {
    test('returns null for false', () {
      expect(falseToNull(false), isNull);
    });

    test('returns true for true', () {
      expect(falseToNull(true), isTrue);
    });
  });

  group('zeroIntToNull', () {
    test('returns null for zero', () {
      expect(zeroIntToNull(0), isNull);
    });

    test('returns value for non-zero', () {
      expect(zeroIntToNull(42), equals(42));
      expect(zeroIntToNull(-1), equals(-1));
    });
  });

  group('zeroDoubleToNull', () {
    test('returns null for zero', () {
      expect(zeroDoubleToNull(0.0), isNull);
    });

    test('returns value for non-zero', () {
      expect(zeroDoubleToNull(3.14), equals(3.14));
      expect(zeroDoubleToNull(-0.5), equals(-0.5));
    });
  });

  group('oneToNull', () {
    test('returns null for 1.0', () {
      expect(oneToNull(1.0), isNull);
    });

    test('returns value for other values', () {
      expect(oneToNull(0.5), equals(0.5));
      expect(oneToNull(2.0), equals(2.0));
    });
  });

  group('emptyListToNull', () {
    test('returns null for empty list', () {
      expect(emptyListToNull<int>([]), isNull);
    });

    test('returns value for non-empty list', () {
      expect(emptyListToNull([1, 2, 3]), equals([1, 2, 3]));
    });
  });

  group('emptyMapToNull', () {
    test('returns null for empty map', () {
      expect(emptyMapToNull<String, int>({}), isNull);
    });

    test('returns value for non-empty map', () {
      expect(emptyMapToNull({'a': 1}), equals({'a': 1}));
    });
  });

  group('emptySetToNull', () {
    test('returns null for empty set', () {
      expect(emptySetToNull<int>({}), isNull);
    });

    test('returns value for non-empty set', () {
      expect(emptySetToNull({1, 2, 3}), equals({1, 2, 3}));
    });
  });

  group('defaultToNull', () {
    test('returns null when value equals default', () {
      final regularToNull = defaultToNull('regular');
      expect(regularToNull('regular'), isNull);
    });

    test('returns value when not equal to default', () {
      final regularToNull = defaultToNull('regular');
      expect(regularToNull('bold'), equals('bold'));
    });

    test('works with different types', () {
      final w400ToNull = defaultToNull(400);
      expect(w400ToNull(400), isNull);
      expect(w400ToNull(700), equals(700));
    });
  });

  group('defaultsToNull', () {
    test('returns null when value is in defaults list', () {
      final fn = defaultsToNull(['', 'N/A', 'none']);
      expect(fn(''), isNull);
      expect(fn('N/A'), isNull);
      expect(fn('none'), isNull);
    });

    test('returns value when not in defaults list', () {
      final fn = defaultsToNull(['', 'N/A', 'none']);
      expect(fn('active'), equals('active'));
    });
  });
}

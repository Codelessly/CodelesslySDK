// Ported from SDK 8.x's cloud_data_test: written values follow the schema.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

const posts = CollectionSchema('posts', fields: [
  SchemaField('text', required: true),
  SchemaField('likes', type: SchemaFieldType.number, defaultValue: '0'),
  SchemaField('pinned', type: SchemaFieldType.boolean),
  SchemaField('createdAt', type: SchemaFieldType.date, defaultValue: 'now'),
  SchemaField('tags', type: SchemaFieldType.list),
  SchemaField('author', type: SchemaFieldType.reference, referenceCollection: 'users'),
]);

void main() {
  group('convert', () {
    test('numbers, yes/no, references, lists and objects', () {
      expect(CloudFieldValues.convert('12.5', SchemaFieldType.number), 12.5);
      expect(CloudFieldValues.convert(' 3 ', SchemaFieldType.number), 3);
      expect(CloudFieldValues.convert('', SchemaFieldType.number), isNull);
      expect(CloudFieldValues.convert('yes', SchemaFieldType.boolean), isTrue);
      expect(CloudFieldValues.convert('false', SchemaFieldType.boolean), isFalse);
      expect(CloudFieldValues.convert(0, SchemaFieldType.boolean), isFalse);
      expect(CloudFieldValues.convert({'id': 'u1', 'name': 'Ana'}, SchemaFieldType.reference), 'u1');
      expect(CloudFieldValues.convert('a, b,c', SchemaFieldType.list), ['a', 'b', 'c']);
      expect(CloudFieldValues.convert('[1,2]', SchemaFieldType.list), [1, 2]);
      expect(CloudFieldValues.convert('{"a":1}', SchemaFieldType.object), {'a': 1});
      expect(CloudFieldValues.convert(12, SchemaFieldType.text), '12');
      expect(CloudFieldValues.convert('12', null), '12');
    });

    test('dates become UTC DateTimes', () {
      expect(CloudFieldValues.convert('2026-10-22T10:00:00Z', SchemaFieldType.date), DateTime.utc(2026, 10, 22, 10));
      expect(CloudFieldValues.convert(0, SchemaFieldType.date), DateTime.utc(1970));
      expect(CloudFieldValues.convert('now', SchemaFieldType.date, now: () => DateTime.utc(2026)), DateTime.utc(2026));
      expect(CloudFieldValues.convert('soon', SchemaFieldType.date), isNull);
    });
  });

  group('buildWrite', () {
    Object? evaluate(String value) => switch (value) {
          r'${title}' => 'Hello',
          r'${count}' => '2',
          _ => value,
        };

    test('a create converts, fills defaults and checks required fields', () {
      final data = CloudFieldValues.buildWrite(
        fields: const [
          CloudFieldWrite('text', r'${title}'),
          CloudFieldWrite('pinned', 'true'),
          CloudFieldWrite('tags', 'news, sport'),
          CloudFieldWrite('author', 'u1'),
          CloudFieldWrite('gone', '', operation: CloudFieldOperation.delete),
        ],
        schema: posts,
        evaluate: evaluate,
        create: true,
      );
      expect(data['text'], 'Hello');
      expect(data['pinned'], isTrue);
      expect(data['tags'], ['news', 'sport']);
      expect(data['likes'], 0);
      expect(data['createdAt'], isA<DateTime>());
      expect(data['author'], 'u1');
      expect(data.containsKey('gone'), isFalse);
      expect(
        () => CloudFieldValues.buildWrite(fields: const [], schema: posts, evaluate: evaluate, create: true),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'text is required.')),
      );
    });

    test('an update writes field operations and no defaults', () {
      final data = CloudFieldValues.buildWrite(
        fields: const [
          CloudFieldWrite('likes', r'${count}', operation: CloudFieldOperation.increment),
          CloudFieldWrite('tags', 'old', operation: CloudFieldOperation.arrayRemove),
          CloudFieldWrite('labels', 'x', operation: CloudFieldOperation.arrayAdd),
          CloudFieldWrite('pinned', '', operation: CloudFieldOperation.delete),
          CloudFieldWrite('editedAt', '', operation: CloudFieldOperation.serverTime),
        ],
        schema: posts,
        evaluate: evaluate,
        create: false,
      );
      expect(data, {
        'likes': const FieldOp.increment(2),
        'tags': const FieldOp.arrayRemove(['old']),
        'labels': const FieldOp.arrayUnion(['x']),
        'pinned': FieldOp.delete,
        'editedAt': FieldOp.serverTime,
      });
    });
  });

  test('JSON field operation markers', () {
    final now = DateTime.utc(2026);
    expect(
      resolveFieldOperations({
        'a': {r'$increment': '3'},
        'b': {r'$arrayUnion': 1},
        'c': {r'$now': true},
        'd': {
          'e': {r'$delete': true},
        },
        'f': {'x': 1, 'y': 2},
      }, now: () => now),
      {
        'a': const FieldOp.increment(3),
        'b': const FieldOp.arrayUnion([1]),
        'c': now.toIso8601String(),
        'd': {'e': FieldOp.delete},
        'f': {'x': 1, 'y': 2},
      },
    );
  });
}

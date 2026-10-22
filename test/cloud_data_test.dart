import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

const CollectionSchema posts = CollectionSchema(
  name: 'posts',
  fields: [
    SchemaField(name: 'text', required: true),
    SchemaField(name: 'likes', type: SchemaFieldType.number, defaultValue: '0'),
    SchemaField(name: 'pinned', type: SchemaFieldType.boolean),
    SchemaField(
      name: 'createdAt',
      type: SchemaFieldType.date,
      defaultValue: 'now',
    ),
    SchemaField(name: 'tags', type: SchemaFieldType.list),
    SchemaField(
      name: 'author',
      type: SchemaFieldType.reference,
      referenceCollection: 'users',
    ),
  ],
);

void main() {
  group('CloudFieldValues.convert', () {
    test('numbers, yes/no, references, lists and objects', () {
      expect(CloudFieldValues.convert('12.5', SchemaFieldType.number), 12.5);
      expect(CloudFieldValues.convert(' 3 ', SchemaFieldType.number), 3);
      expect(CloudFieldValues.convert('', SchemaFieldType.number), isNull);
      expect(CloudFieldValues.convert('yes', SchemaFieldType.boolean), isTrue);
      expect(
        CloudFieldValues.convert('false', SchemaFieldType.boolean),
        isFalse,
      );
      expect(CloudFieldValues.convert(0, SchemaFieldType.boolean), isFalse);
      expect(
        CloudFieldValues.convert({
          'id': 'u1',
          'name': 'Ana',
        }, SchemaFieldType.reference),
        'u1',
      );
      expect(CloudFieldValues.convert('a, b,c', SchemaFieldType.list), [
        'a',
        'b',
        'c',
      ]);
      expect(CloudFieldValues.convert('[1,2]', SchemaFieldType.list), [1, 2]);
      expect(CloudFieldValues.convert('{"a":1}', SchemaFieldType.object), {
        'a': 1,
      });
      expect(CloudFieldValues.convert(12, SchemaFieldType.text), '12');
      // No schema: kept as is.
      expect(CloudFieldValues.convert('12', null), '12');
    });

    test('dates become timestamps', () {
      final Object? parsed = CloudFieldValues.convert(
        '2026-10-22T10:00:00Z',
        SchemaFieldType.date,
      );
      expect(parsed, isA<Timestamp>());
      expect(
        (parsed as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 22, 10),
      );
      expect(
        CloudFieldValues.convert('now', SchemaFieldType.date),
        isA<Timestamp>(),
      );
      expect(CloudFieldValues.convert('soon', SchemaFieldType.date), isNull);
    });
  });

  group('CloudFieldValues.buildWrite', () {
    Object? evaluate(String value) => switch (value) {
      r'${title}' => 'Hello',
      r'${count}' => '2',
      _ => value,
    };

    test('a create converts, fills defaults and checks required fields', () {
      final Map<String, dynamic> data = CloudFieldValues.buildWrite(
        fields: const [
          CloudFieldWrite(field: 'text', value: r'${title}'),
          CloudFieldWrite(field: 'pinned', value: 'true'),
          CloudFieldWrite(field: 'tags', value: 'news, sport'),
          CloudFieldWrite(field: 'author', value: 'u1'),
        ],
        schema: posts,
        evaluate: evaluate,
        create: true,
      );
      expect(data['text'], 'Hello');
      expect(data['pinned'], isTrue);
      expect(data['tags'], ['news', 'sport']);
      expect(data['likes'], 0);
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['author'], 'u1');

      expect(
        () => CloudFieldValues.buildWrite(
          fields: const [],
          schema: posts,
          evaluate: evaluate,
          create: true,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'text is required.',
          ),
        ),
      );
    });

    test('an update writes field operations and no defaults', () {
      final Map<String, dynamic> data = CloudFieldValues.buildWrite(
        fields: const [
          CloudFieldWrite(
            field: 'likes',
            value: r'${count}',
            operation: CloudFieldOperation.increment,
          ),
          CloudFieldWrite(
            field: 'tags',
            value: 'old',
            operation: CloudFieldOperation.arrayRemove,
          ),
          CloudFieldWrite(
            field: 'pinned',
            operation: CloudFieldOperation.delete,
          ),
          CloudFieldWrite(
            field: 'editedAt',
            operation: CloudFieldOperation.serverTime,
          ),
        ],
        schema: posts,
        evaluate: evaluate,
        create: false,
      );
      expect(data.keys, ['likes', 'tags', 'pinned', 'editedAt']);
      expect(data.values, everyElement(isA<FieldValue>()));
      expect(data.containsKey('createdAt'), isFalse);
    });
  });

  test('aggregates over documents', () {
    final docs = [
      {'likes': 2},
      {'likes': 5},
      {'likes': 'many'},
      <String, dynamic>{},
    ];
    expect(
      CloudDataRunner.aggregateDocuments(docs, CloudDataOperation.count, ''),
      4,
    );
    expect(
      CloudDataRunner.aggregateDocuments(docs, CloudDataOperation.sum, 'likes'),
      7,
    );
    expect(
      CloudDataRunner.aggregateDocuments(
        docs,
        CloudDataOperation.average,
        'likes',
      ),
      3.5,
    );
    expect(
      CloudDataRunner.aggregateDocuments([], CloudDataOperation.average, 'x'),
      isNull,
    );
  });

  test('data rules read schemas and find them by collection path', () {
    final DataRules rules = DataRules.fromJson({
      'collections': {'posts': 'publicReadOwnerWrite'},
      'schemas': {
        'posts': posts.toJson()..remove('name'),
        'tasks': {
          'fields': [
            {'name': 'done', 'type': 'boolean'},
          ],
        },
      },
    });
    expect(
      rules.schemaFor('posts')!.field('likes')!.type,
      SchemaFieldType.number,
    );
    expect(rules.schemaFor('users/u1/tasks')!.field('done'), isNotNull);
    expect(rules.schemaFor('users/u1/tasks')!.name, 'tasks');
    expect(rules.schemaFor('comments'), isNull);
    expect(DataRules.fromJson(rules.toJson()).schemas.keys, ['posts', 'tasks']);
  });
}

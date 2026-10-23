// Firestore marks its references @sealed; these test fakes stand in for them.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collection path -> document id -> data.
final Map<String, Map<String, Map<String, dynamic>>> store = {};

/// The batches committed, each as its number of writes.
final List<int> commits = [];

int _autoId = 0;

class _MemQuery extends Fake implements Query<Map<String, dynamic>> {
  _MemQuery(this._collection, [this.tests = const []]);

  final _MemCollection? _collection;
  _MemCollection get collection => _collection!;
  final List<bool Function(Map<String, dynamic>)> tests;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _MemQuery(collection, [...tests, (data) => data[field] == isEqualTo]);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docs = store[collection.path] ?? {};
    return _MemSnapshot([
      for (final entry in docs.entries)
        if (tests.every((test) => test(entry.value)))
          _MemDocSnapshot(collection.doc(entry.key) as _MemDoc, entry.value),
    ]);
  }
}

class _MemCollection extends _MemQuery
    implements CollectionReference<Map<String, dynamic>> {
  _MemCollection(this.path) : super(null);

  @override
  _MemCollection get collection => this;

  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _MemDoc(this, id ?? 'auto${_autoId++}');
}

class _MemDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _MemDoc(this.parentCollection, this.id);

  final _MemCollection parentCollection;

  @override
  final String id;

  @override
  String get path => '${parentCollection.path}/$id';

  @override
  CollectionReference<Map<String, dynamic>> collection(String id) =>
      _MemCollection('$path/$id');

  @override
  bool operator ==(Object other) => other is _MemDoc && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class _MemDocSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _MemDocSnapshot(this.reference, this._data);

  @override
  final _MemDoc reference;
  final Map<String, dynamic> _data;

  @override
  String get id => reference.id;

  @override
  Map<String, dynamic> data() => _data;
}

class _MemSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _MemSnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _MemBatch extends Fake implements WriteBatch {
  final List<void Function()> _ops = [];

  @override
  void delete(DocumentReference document) {
    final doc = document as _MemDoc;
    _ops.add(() => store[doc.parentCollection.path]?.remove(doc.id));
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    final doc = document as _MemDoc;
    final Map<String, dynamic> value = Map.of(data as Map<String, dynamic>);
    _ops.add(() {
      final docs = store.putIfAbsent(doc.parentCollection.path, () => {});
      docs[doc.id] = options?.merge == true
          ? {...?docs[doc.id], ...value}
          : value;
    });
  }

  @override
  Future<void> commit() async {
    expect(_ops.length, lessThanOrEqualTo(500));
    commits.add(_ops.length);
    for (final op in _ops) {
      op();
    }
  }
}

class _MemFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _MemCollection(path);

  @override
  WriteBatch batch() => _MemBatch();
}

const String sessions = 'data/project/sessions';

void main() {
  late FirestoreCloudDatabase database;

  void seed(int count, {String Function(int i)? spot}) {
    store[sessions] = {
      for (int i = 0; i < count; i++)
        's$i': {'id': 's$i', 'spot': spot?.call(i) ?? 'Pipe'},
    };
  }

  setUp(() {
    store.clear();
    commits.clear();
    database = FirestoreCloudDatabase(
      'project',
      PublishSource.publish,
      firestore: _MemFirestore(),
    );
  });

  test('removeDocuments clears a collection in one batch', () async {
    seed(14);
    expect(await database.removeDocuments('sessions'), 14);
    expect(store[sessions], isEmpty);
    expect(commits, [14]);
  });

  test('removeDocuments splits more than 500 deletes into batches', () async {
    seed(1203);
    expect(await database.removeDocuments('sessions'), 1203);
    expect(store[sessions], isEmpty);
    expect(commits, [500, 500, 203]);
  });

  test('removeDocuments by where filter or ids', () async {
    seed(6, spot: (i) => i.isEven ? 'Pipe' : 'Malibu');
    expect(
      await database.removeDocuments(
        'sessions',
        filters: const [
          CloudWhereFilter('spot', WhereQueryOperator.equal, 'Malibu'),
        ],
      ),
      3,
    );
    expect(store[sessions]!.keys, ['s0', 's2', 's4']);

    expect(
      await database.removeDocuments('sessions', documentIds: ['s0', ' s4 ']),
      2,
    );
    expect(store[sessions]!.keys, ['s2']);
    expect(commits, [3, 2]);
  });

  test('setDocuments writes a list in one batch and can replace the '
      'collection', () async {
    seed(3);
    final int written = await database.setDocuments('sessions', [
      {'id': 's1', 'spot': 'Rincon'},
      {'id': 'n1', 'spot': 'Trestles'},
      {'spot': 'No id'},
    ], replaceCollection: true);
    expect(written, 3);
    expect(commits, [5]); // 3 sets + 2 deletes (s0, s2)
    final docs = store[sessions]!;
    expect(docs.keys, containsAll(['s1', 'n1']));
    expect(docs.length, 3);
    expect(docs['s1']!['spot'], 'Rincon');
    // A document without an id gets one, stored in its id field.
    final generated = docs.entries.firstWhere(
      (e) => e.value['spot'] == 'No id',
    );
    expect(generated.value['id'], generated.key);
  });

  test('setDocuments merges into stored documents when asked', () async {
    seed(1);
    await database.setDocuments('sessions', [
      {'id': 's0', 'rating': 4},
    ], merge: true);
    expect(store[sessions]!['s0']!['spot'], 'Pipe');
    expect(store[sessions]!['s0']!['rating'], 4);
  });

  test('the actions read ids, filters and documents from variables', () async {
    seed(5, spot: (i) => i < 2 ? 'Malibu' : 'Pipe');
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'selected': VariableData(
          id: 'selected',
          name: 'selected',
          type: VariableType.list,
          value: [
            {'id': 's3'},
            {'id': 's4'},
          ],
        ),
        'seed': VariableData(
          id: 'seed',
          name: 'seed',
          type: VariableType.list,
          value: [
            {'id': 'a', 'spot': 'Pipe'},
            {'id': 'b', 'spot': 'Rincon'},
          ],
        ),
      },
    );

    expect(
      await FunctionsRepository.removeDocumentsFromCloud(
        const RemoveDocumentsSubAction(
          path: 'sessions',
          documentIds: r'${selected}',
        ),
        scope,
        database: database,
      ),
      isTrue,
    );
    expect(store[sessions]!.keys, ['s0', 's1', 's2']);

    await FunctionsRepository.removeDocumentsFromCloud(
      const RemoveDocumentsSubAction(
        path: 'sessions',
        whereFilters: [
          WhereQueryFilter(
            field: 'spot',
            operator: WhereQueryOperator.equal,
            value: 'Malibu',
          ),
        ],
      ),
      scope,
      database: database,
    );
    expect(store[sessions]!.keys, ['s2']);

    expect(
      await FunctionsRepository.setDocumentsOnCloud(
        const SetDocumentsSubAction(
          path: 'sessions',
          documents: r'${seed}',
          replaceCollection: true,
        ),
        scope,
        database: database,
      ),
      isTrue,
    );
    expect(store[sessions]!.keys, unorderedEquals(['a', 'b']));
    expect(commits, [2, 2, 3]);
  });

  test('documentIdsOf reads lists, documents, JSON and commas', () {
    expect(FunctionsRepository.documentIdsOf(['a', 'b']), ['a', 'b']);
    expect(
      FunctionsRepository.documentIdsOf([
        {'id': 'a'},
        {'name': 'x'},
      ]),
      ['a'],
    );
    expect(FunctionsRepository.documentIdsOf('["a","b"]'), ['a', 'b']);
    expect(FunctionsRepository.documentIdsOf('a, b,,c'), ['a', 'b', 'c']);
    expect(FunctionsRepository.documentIdsOf(null), isEmpty);
  });
}

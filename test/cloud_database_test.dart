// Firestore marks its references @sealed; these test fakes stand in for them.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// One snapshot stream per collection path, so tests can see who listens.
final Map<String, StreamController<QuerySnapshot<Map<String, dynamic>>>>
snapshotStreams = {};

class _FakeCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this.path);

  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _FakeDoc('$path/$id');

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => snapshotStreams.putIfAbsent(path, StreamController.new).stream;
}

class _FakeDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _FakeDoc(this.path);

  @override
  final String path;

  @override
  CollectionReference<Map<String, dynamic>> collection(String id) =>
      _FakeCollection('$path/$id');
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _FakeCollection(path);
}

void main() {
  late FirestoreCloudDatabase database;
  late Observable<VariableData> variable;

  void stream(String path) => database.streamCollectionToVariable(
    path,
    variable,
    whereFilters: const [],
    orderByOperations: const [],
    scopedValues: ScopedValues.empty(),
    nullSubstitutionMode: NullSubstitutionMode.emptyString,
  );

  bool listening(String path) => snapshotStreams.entries
      .firstWhere((entry) => entry.key.endsWith('/$path'))
      .value
      .hasListener;

  setUp(() {
    snapshotStreams.clear();
    database = FirestoreCloudDatabase(
      'project',
      PublishSource.publish,
      firestore: _FakeFirestore(),
    );
    variable = Observable(VariableData(id: 'items', name: 'items'));
  });

  test('a new query for a variable replaces its previous listener', () {
    stream('first');
    expect(listening('first'), isTrue);

    stream('second');
    expect(listening('first'), isFalse);
    expect(listening('second'), isTrue);
  });

  test('reset cancels every listener', () {
    stream('first');
    database.reset();
    expect(listening('first'), isFalse);
  });
}

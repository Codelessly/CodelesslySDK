import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/firedart.dart';
import 'package:codelessly_sdk/src/firedart/generated/google/firestore/v1/firestore.pbgrpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

const databaseId = '(default)';
const database = 'projects/$defaultProjectId/databases/$databaseId';
const documentPath = '$database/documents/investor_tmp/investor';

// https://github.com/grpc/grpc-dart/issues/215

Future<void> getDocument() async {
  final channel = ClientChannel('firestore.googleapis.com');
  final FirestoreClient firestore = FirestoreClient(channel);

  final request = GetDocumentRequest()..name = documentPath;
  final document = await firestore.getDocument(request);
  print(document);
}

Future main() async {
  test('Get Document directly', () async {
    await getDocument();
  });

  test('Get Document using FireDart without login', () async {
    final Firestore firestore = Firestore(defaultProjectId);
    var doc = await firestore.document('investor_tmp/investor').get();
    print('doc is $doc');
  });

  test('Get public document using FireDart with login w/o auth', () async {
    var auth = FirebaseAuth(defaultApiKey, VolatileStore());
    var firestore = Firestore(defaultProjectId);

    final document = firestore.collection('publish').document('test');

    final doc = await document.get();
    print(doc.map);

    expect(doc.map, isNotEmpty);
  });

  test('Listen to document', () async {
    var tokenStore = VolatileStore();
    var auth = FirebaseAuth(defaultApiKey, tokenStore);
    var firestore = Firestore(defaultProjectId);
    await auth.signIn('codelessly@gmail.com', '123456');

    await firestore.document('investor_tmp/investor').stream.forEach((element) {
      print('STREAM DOC IS $element');
    });
  });
}

import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/firedart/generated/google/firestore/v1/firestore.pbgrpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

final databaseId = '(default)';
final database = 'projects/$defaultProjectId/databases/$databaseId';
final documentPath = '$database/documents/investor_tmp/investor';

Future<void> main() async {
  // Works fine
  // await getDocument();
  // Fails

  test('Counter value should be incremented', () async {
    // Doesn't work
    await listen();
  });
}

void getDocument() async {
  final channel = ClientChannel('firestore.googleapis.com');
  final FirestoreClient firestore = FirestoreClient(channel);

  final request = GetDocumentRequest()..name = documentPath;
  final document = await firestore.getDocument(request);
  print(document);
}

Future<void> listen() async {
  final channel = ClientChannel('firestore.googleapis.com');
  final FirestoreClient firestore = FirestoreClient(channel);

  // final streamController = StreamController<ListenRequest>();

  final documentsTarget = Target_DocumentsTarget()..documents.add(documentPath);

  final target = Target()..documents = documentsTarget;

  final request = ListenRequest()
    ..database = database
    ..addTarget = target;

  firestore
      .listen(
        Stream.fromIterable([request]),
        options:
            CallOptions(metadata: {'google-cloud-resource-prefix': database}),
      )
      .listen(print)
    ..onDone(() {
      print('onDone');
    })
    ..onError((error) {
      print('onError $error');
    })
    ..onData((data) {
      print('onData $data');
    });

  // print("waiting...");
  // await Future.delayed(Duration(seconds: 2));
  // print("done");

  // Initiate request
  // streamController.add(request);
}

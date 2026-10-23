import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _FakeCache extends Fake implements CacheManager {}

class _FakeAuthManager extends Fake implements AuthManager {}

class _FakeLocalRepository extends Fake implements LocalDataRepository {}

class _FakeNetworkRepository extends Fake implements NetworkDataRepository {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _TestDataManager extends DataManager {
  _TestDataManager(SDKPublishModel model, CodelesslyConfig config)
    : super(
        'test',
        config: config,
        cacheManager: _FakeCache(),
        authManager: _FakeAuthManager(),
        networkDataRepository: _FakeNetworkRepository(),
        localDataRepository: _FakeLocalRepository(),
        firebaseFirestore: _FakeFirestore(),
        errorLogger: ErrorLogger.instance,
        publishModel: model,
      );
}

void main() {
  testWidgets('an API call finishes its chain after the dialog that started '
      'it closes', (tester) async {
    final Completer<void> answer = Completer<void>();
    final List<String> calls = [];
    final model = SDKPublishModel(
      projectId: 'project',
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    model.apis['sun'] = HttpApiData(
      id: 'sun',
      name: 'Sun times',
      directory: '',
      url: 'https://example.com/sun',
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    final config = CodelesslyConfig(authToken: 'token');
    final codelessly = Codelessly(
      config: config,
      client: MockClient((request) async {
        await answer.future;
        return http.Response('{"sunrise": "7:25"}', 200, request: request);
      }),
      publishDataManager: _TestDataManager(model, config),
    );
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'close': (context, reference, params) => Navigator.of(context).pop(),
        'record': (context, reference, params) =>
            calls.add('${params['what']}'),
      };
    late BuildContext pageContext;
    await tester.pumpWidget(
      Provider<Codelessly>.value(
        value: codelessly,
        child: ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
          child: MaterialApp(
            home: ActionChainHost(
              child: Builder(
                builder: (context) {
                  pageContext = context;
                  return const Scaffold();
                },
              ),
            ),
          ),
        ),
      ),
    );
    // A settings dialog: picking a setting reloads data, and the dialog is
    // closed before the data arrives.
    final openerHosts = ActionChainOpener.hostsFor(pageContext);
    unawaited(
      showDialog<void>(
        context: pageContext,
        builder: (context) => ActionChainOpener(
          openerHosts: openerHosts,
          child: ActionChainHost(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.click,
                  reactions: [
                    Reaction(
                      action: ApiCallAction(
                        apiId: 'sun',
                        onSuccess: [
                          CallFunctionAction(
                            name: 'record',
                            params: {'what': 'loaded'},
                          ),
                        ],
                      ),
                      trigger: TriggerModel(type: TriggerType.click),
                    ),
                  ],
                ),
                child: const Text('Reload'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reload'));
    await tester.pump();
    Navigator.of(pageContext).pop();
    await tester.pumpAndSettle();
    expect(find.text('Reload'), findsNothing);

    await tester.runAsync(() async {
      answer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(calls, ['loaded']);
  });
}

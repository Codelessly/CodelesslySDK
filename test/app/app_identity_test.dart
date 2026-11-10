// The app identity's screen titles.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final model = PublishModel.fromJson({
    'projectId': 'p',
    'entryLayoutId': 'home',
    'layouts': {
      'home': {
        'pageId': 'p0',
        'canvases': [
          {'id': 'home-c', 'name': 'Home'},
        ],
      },
      'log': {
        'pageId': 'p1',
        'canvases': [
          {'id': 'log-c', 'name': 'Hive log'},
        ],
      },
      'about': {
        'canvases': [
          {'id': 'about-c', 'name': 'About'},
        ],
      },
    },
    'appIdentity': {
      'name': 'Hive',
      'description': 'Bees',
      'themeColor': '#FFAA0080',
      'pages': {
        'p1': {'title': 'Log', 'description': 'Every visit'},
      },
    },
  });

  test('titles and descriptions per screen', () {
    expect(CodelesslyAppIdentity.resolve(model).title, 'Hive');
    expect(CodelesslyAppIdentity.resolve(model, layoutId: 'home'), const ScreenIdentity(title: 'Hive', description: 'Bees', layoutId: 'home'));
    final log = CodelesslyAppIdentity.resolve(model, layoutId: 'log');
    expect((log.title, log.description), ('Log · Hive', 'Every visit'));
    expect(CodelesslyAppIdentity.resolve(model, layoutId: 'about').title, 'About · Hive');
    expect(CodelesslyAppIdentity.parseColor('#FFAA0080'), const Color(0x80FFAA00));
    expect(CodelesslyAppIdentity.parseColor('nope'), isNull);
    final none = PublishModel.fromJson({'projectId': 'p', 'layouts': {}});
    expect(CodelesslyAppIdentity.resolve(none, fallbackName: 'App').title, 'App');
  });

  testWidgets('the updater applies the shown screen\'s title', (tester) async {
    final labels = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setApplicationSwitcherDescription') labels.add('${(call.arguments as Map)['label']}');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final codelessly = Codelessly(
      config: const CodelesslyConfig(projectId: 'p'),
      loader: MemoryPublishLoader(PublishBundle(model: model)),
      fonts: const NoFontFetcher(),
    );
    addTearDown(codelessly.dispose);
    await codelessly.initialize();
    final updater = CodelesslyAppIdentityUpdater(codelessly)..attach();
    codelessly.route.value = const CodelesslyRoute('log', 'log-c');
    await tester.pump();
    updater.detach();
    expect(labels, ['Hive', 'Log · Hive']);
    expect(updater.current!.layoutId, 'log');
  });
}

import 'dart:convert';
import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CanvasNode canvas(String id, String name, {String? path}) => CanvasNode(
  id: id,
  name: name,
  basicBoxLocal: NodeBox(0, 0, 390, 844),
  children: const [],
  scaleMode: ScaleMode.responsive,
  properties: CanvasProperties(bodyId: '${id}body', path: path),
)..parentID = kRootNode;

SDKPublishLayout layout(String id, String pageId, CanvasNode node) =>
    SDKPublishLayout(
      id: id,
      pageId: pageId,
      projectId: 'project',
      canvases: {
        node.id: {node.id: node},
      },
      lastUpdated: DateTime(2026),
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );

SDKPublishModel model({AppIdentity? identity}) => SDKPublishModel(
  projectId: 'project',
  layouts: LookupMap((
    lookupMap: {},
    dataMap: {
      'home': layout('home', 'pageHome', canvas('cHome', 'Home')),
      'plans': layout(
        'plans',
        'pagePlans',
        canvas('cPlans', 'Plans', path: 'plans'),
      ),
      'about': layout('about', 'pageAbout', canvas('cAbout', 'About us')),
    },
  )),
  entryLayoutId: 'home',
  appIdentity: identity,
  owner: 'owner',
  teams: const {},
  users: const {},
  roles: const {},
  public: false,
);

const AppIdentity identity = AppIdentity(
  name: 'Wireless',
  description: 'Phone plans.',
  themeColor: '#112233',
  mobile: MobileIdentity(statusBarStyle: StatusBarStyle.light),
  pages: {
    'pageAbout': PageIdentity(title: 'About', description: 'Who we are.'),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SDKPublishModel.appIdentity', () {
    test('round-trips through the publish JSON', () {
      final SDKPublishModel published = model(identity: identity);
      final Map<String, dynamic> json =
          jsonDecode(jsonEncode(published.toFullJson()))
              as Map<String, dynamic>;
      expect(json['appIdentity']['name'], 'Wireless');
      final SDKPublishModel read = SDKPublishModel.fromJson(json);
      expect(read.appIdentity, identity);
    });

    test('old bundles without an identity still load', () {
      final Map<String, dynamic> json =
          jsonDecode(jsonEncode(model().toFullJson())) as Map<String, dynamic>;
      expect(json.containsKey('appIdentity'), isFalse);
      expect(SDKPublishModel.fromJson(json).appIdentity, isNull);
    });

    test('copyWith keeps and replaces the identity', () {
      final SDKPublishModel published = model(identity: identity);
      expect(published.copyWith().appIdentity, identity);
      expect(
        published
            .copyWith(appIdentity: const AppIdentity(name: 'X'))
            .appIdentity
            ?.name,
        'X',
      );
    });
  });

  group('CodelesslyAppIdentity', () {
    test('finds the layout at a location', () {
      final SDKPublishModel m = model(identity: identity);
      expect(CodelesslyAppIdentity.layoutIdAt(m, '/'), 'home');
      expect(CodelesslyAppIdentity.layoutIdAt(m, '/plans'), 'plans');
      expect(CodelesslyAppIdentity.layoutIdAt(m, '/about?x=1'), 'about');
    });

    test('titles screens from overrides, screen names, and the app name', () {
      final SDKPublishModel m = model(identity: identity);
      expect(
        CodelesslyAppIdentity.resolve(m, layoutId: 'home').title,
        'Wireless',
      );
      expect(
        CodelesslyAppIdentity.resolve(m, layoutId: 'plans').title,
        'Plans · Wireless',
      );
      final ScreenIdentity about = CodelesslyAppIdentity.resolve(
        m,
        layoutId: 'about',
      );
      expect(about.title, 'About · Wireless');
      expect(about.description, 'Who we are.');
      expect(
        CodelesslyAppIdentity.resolve(m, layoutId: 'plans').description,
        'Phone plans.',
      );
    });

    test('falls back to the host name without an identity', () {
      final SDKPublishModel m = model();
      expect(
        CodelesslyAppIdentity.resolve(
          m,
          layoutId: 'plans',
          fallbackName: 'Host',
        ).title,
        'Plans · Host',
      );
    });

    test('parses colors and status bar styles', () {
      expect(
        CodelesslyAppIdentity.parseColor('#112233'),
        const Color(0xFF112233),
      );
      expect(
        CodelesslyAppIdentity.parseColor('#11223380'),
        const Color(0x80112233),
      );
      expect(CodelesslyAppIdentity.parseColor('nope'), isNull);
      expect(
        CodelesslyAppIdentity.overlayStyleOf(identity),
        SystemUiOverlayStyle.light,
      );
      expect(
        CodelesslyAppIdentity.overlayStyleOf(const AppIdentity()),
        isNull,
      );
    });

    test('applyTitle sets the application switcher description', () async {
      final List<MethodCall> calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      await CodelesslyAppIdentity.applyTitle(
        'Plans · Wireless',
        color: const Color(0xFF112233),
      );
      final MethodCall call = calls.singleWhere(
        (c) => c.method == 'SystemChrome.setApplicationSwitcherDescription',
      );
      expect((call.arguments as Map)['label'], 'Plans · Wireless');
      expect((call.arguments as Map)['primaryColor'], 0xFF112233);
    });
  });
}

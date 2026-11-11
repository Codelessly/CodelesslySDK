// An `openPaywall` action opens its placement's screen as a navigation
// would: with the action's route transition (a cover from the bottom), and
// its screen reads the placement's legal links and whether it runs on the
// test store (`${paywall.termsUrl}`, `${paywall.test}`). A purchase closes
// it by playing the transition in reverse, not by dropping the route.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Json _box(String name, List<Json> actions) => {
      'type': 'box',
      'name': name,
      'layout': {'width': 390, 'height': 60},
      'decoration': {
        'fills': [
          {'color': '#FF2196F3'},
        ],
      },
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': actions,
        },
      ],
    };

Json _text(String name, String text) => {
      'type': 'text',
      'name': name,
      'layout': {'width': 390, 'height': 40},
      'props': {'text': text},
    };

Json _layout(String id, Map<String, Json> body) => {
      'schema': 2,
      'id': id,
      'roots': ['$id-canvas'],
      'nodes': {
        '$id-canvas': {
          'type': 'canvas',
          'name': id,
          'slots': {'body': '$id-column'},
          'layout': {'width': 390, 'height': 844},
        },
        '$id-column': {
          'type': 'column',
          'children': [...body.keys],
          'layout': {
            'width': {'fill': 390},
            'height': {'fill': 844},
          },
        },
        ...body,
      },
    };

PublishBundle _bundle(Json open) => PublishBundle.fromJson({
      'model': {
        'schema': 2,
        'projectId': 'open_paywall_demo',
        'entryLayoutId': 'home',
        'layouts': {
          'home': {
            'canvases': [
              {'id': 'home-canvas', 'name': 'home'},
            ],
          },
          'paywall': {
            'canvases': [
              {'id': 'paywall-canvas', 'name': 'paywall'},
            ],
          },
        },
        'paywall': {
          'products': [
            {
              'id': 'yearly',
              'test': {'rawPrice': 34.99, 'currency': 'USD', 'period': 'year', 'trialDays': 7, 'entitlementId': 'plus'},
            },
          ],
          'placements': [
            {'id': 'upgrade', 'layoutId': 'paywall', 'productSlots': ['yearly']},
          ],
          'termsUrl': 'https://example.com/terms',
          'privacyUrl': 'https://example.com/privacy',
          'testStore': true,
        },
      },
      'layouts': {
        'home': _layout('home', {
          'status': _text('Status', r"${entitlements.plus == true ? 'PLUS' : 'FREE'}"),
          'open': _box('Open', [open]),
        }),
        'paywall': _layout('paywall', {
          'details': _text('Details', r"${paywall.placement} ${paywall.termsUrl} ${paywall.test == true ? 'TEST' : 'REAL'}"),
          'buy': _box('Buy', [
            {'type': 'paywall', 'operation': 'purchase', 'slot': 'yearly'},
          ]),
          'close': _box('Close', [
            {'type': 'paywall', 'operation': 'closePaywall'},
          ]),
        }),
      },
    });

void main() {
  List<String> texts(WidgetTester tester) {
    final found = <String>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) found.add(o.text.toPlainText());
      o.visitChildren(visit);
    }

    for (final view in tester.binding.renderViews) {
      visit(view);
    }
    return found;
  }

  Future<void> tapNode(WidgetTester tester, String id, {bool settled = true}) async {
    final box = tester.widgetList<NodeView>(find.byType(NodeView)).map((v) => v.tree.boxOf(id)).nonNulls.last;
    final content = box.contentBox ?? box;
    await tester.tapAt(content.localToGlobal(content.size.center(Offset.zero)));
    if (settled) await settle(tester);
  }

  Future<(Services, Codelessly)> start(WidgetTester tester, Json open) async {
    setScreen(tester, const Size(390, 844));
    final services = Services(web: true, storage: MemoryLocalStorage(), analytics: const NoAnalytics());
    final codelessly = Codelessly.fromBundle(_bundle(open), config: CodelesslyConfig(services: services), fonts: const NoFontFetcher());
    addTearDown(services.dispose);
    addTearDown(codelessly.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
    await settle(tester);
    return (services, codelessly);
  }

  Iterable<Route<dynamic>> paywallRoutes(WidgetTester tester) => tester
      .widgetList<NodeView>(find.byType(NodeView, skipOffstage: false))
      .map((v) => ModalRoute.of(tester.element(find.byWidget(v, skipOffstage: false))))
      .nonNulls
      .where((r) => r.settings.name == '/paywall/upgrade');

  testWidgets('openPaywall covers with the action\'s route transition and closes in reverse', (tester) async {
    await start(tester, {
      'type': 'paywall',
      'operation': 'openPaywall',
      'placement': 'upgrade',
      'routeTransition': {'preset': 'coverVertical', 'durationMs': 520},
    });
    expect(texts(tester), contains('FREE'));

    await tapNode(tester, 'open');
    final route = paywallRoutes(tester).single;
    expect(route, isA<CodelesslyRouteTransitionRoute<Object?>>());
    expect((route as CodelesslyRouteTransitionRoute<Object?>).transition.durationMs, 520);
    expect(route.transition.preset, RouteTransitionPreset.coverVertical);
    expect(texts(tester), contains('upgrade https://example.com/terms TEST'),
        reason: 'the opened paywall reads its placement, legal links and the test store');

    // A purchase closes it in reverse: mid-way it is still on screen.
    await tapNode(tester, 'buy', settled: false);
    await tester.pump(const Duration(milliseconds: 450)); // the test store's delay
    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation!.status, AnimationStatus.reverse, reason: 'it plays the transition back');
    await settle(tester);
    expect(paywallRoutes(tester), isEmpty);
    expect(texts(tester), contains('PLUS'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('openPaywall with a page transition and durations', (tester) async {
    await start(tester, {
      'type': 'paywall',
      'operation': 'openPaywall',
      'placement': 'upgrade',
      'transition': 'slideUp',
      'transitionMs': 300,
      'reverseTransitionMs': 200,
    });
    await tapNode(tester, 'open');
    final route = paywallRoutes(tester).single as PageRoute<Object?>;
    expect(route.transitionDuration, const Duration(milliseconds: 300));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 200));
    await tapNode(tester, 'close');
    expect(paywallRoutes(tester), isEmpty);
    expect(texts(tester), contains('FREE'));
    expect(tester.takeException(), isNull);
  });
}

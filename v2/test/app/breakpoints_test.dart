// A project's own breakpoints (DESIGN.md §5.3) at runtime: screens pick
// their canvas by them, responsive variances switch variants by the
// screen's width, `${screen}` names them, and per-breakpoint toast looks
// are keyed by them.
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/src/runtime/actions/presentation_route.dart' show defaultSheetBelowWidth, resolvePresentation;
import 'package:codelessly_sdk_v2/src/runtime/actions/toast.dart' show perBreakpointValue;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Three breakpoints, none of them the defaults.
final custom = Breakpoints([
  const Breakpoint(id: 'compact', name: 'Compact', width: 360, height: 800),
  const Breakpoint(id: 'medium', name: 'Medium', minWidth: 700, width: 900, height: 1000),
  const Breakpoint(id: 'xl', name: 'Large desktop', minWidth: 1300, width: 1600, height: 1000),
]);

Map<String, Object?> _box(String name, {List<String> children = const []}) => {
      'type': 'box',
      'name': name,
      'layout': {'width': 100, 'height': 40},
      if (children.isNotEmpty) 'children': children,
    };

/// A screen of two canvases (compact, xl), the compact one holding a
/// responsive variance with a variant for compact and for medium, and a
/// text bound to `${screen.breakpoint}` in each.
PublishBundle bundleWith(Breakpoints breakpoints, {Map<String, num> minWidths = const {}}) {
  final layout = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['c', 'x'],
    'nodes': {
      'c': {'type': 'canvas', 'name': 'Home · C', 'slots': {'body': 'body'}, 'layout': {'width': 360, 'height': 800},
            'props': {'breakpoint': 'compact', 'screen': 'home'}},
      'body': {'type': 'stack', 'children': ['v'], 'layout': {'width': {'fill': 360}, 'height': {'fill': 800}}},
      'v': {
        'type': 'variance',
        'children': ['vc', 'vm'],
        'layout': {'width': 200, 'height': 100},
        'props': {
          'variants': [
            {'id': 'pc', 'name': 'Compact', 'children': ['vc'], 'breakpoint': 'compact'},
            {'id': 'pm', 'name': 'Medium', 'children': ['vm'], 'breakpoint': 'medium'},
          ],
          'current': 'pc',
          if (minWidths.isNotEmpty) 'minWidths': minWidths,
        },
      },
      'vc': _box('in compact', children: ['tc']),
      'vm': _box('in medium', children: ['tm']),
      'tc': {'type': 'text', 'name': 'tc', 'props': {'text': r'${screen.breakpoint}'}},
      'tm': {'type': 'text', 'name': 'tm', 'props': {'text': r'${screen.breakpoint}'}},
      'x': {'type': 'canvas', 'name': 'Home · XL', 'layout': {'width': 1600, 'height': 1000},
            'props': {'breakpoint': 'xl', 'screen': 'home'}},
    },
    'breakpoints': [
      {'canvas': 'c', 'breakpoint': 'compact'},
      {'canvas': 'x', 'breakpoint': 'xl'},
    ],
  });
  return PublishBundle(
    model: PublishModel(
      projectId: 'p',
      entryLayoutId: 'home',
      layouts: {'home': PublishLayoutInfo.of(layout)},
      breakpoints: breakpoints,
    ),
    layouts: {'home': layout},
  );
}

void main() {
  group('screen values', () {
    test('name the project breakpoints, by id and by name', () {
      final s = screenValues(800, 1000, breakpoints: custom);
      expect(s['breakpoint'], 'medium');
      expect(s['breakpointName'], 'Medium');
      expect(s['breakpointIndex'], 1);
      expect(s['isMedium'], isTrue);
      expect(s['isCompact'], isFalse);
      expect(s['isLargeDesktop'], isFalse);
      expect(s['isXl'], isFalse);
      expect((s['is'] as Map)['medium'], isTrue);
      expect((s['atLeast'] as Map)['compact'], isTrue);
      expect((s['atLeast'] as Map)['largeDesktop'], isFalse);
      expect(s.containsKey('isMobile'), isFalse, reason: 'no fixed mobile/tablet/desktop');
      expect((s['breakpoints'] as List).map((b) => (b as Map)['id']), ['compact', 'medium', 'xl']);
    });

    test('the defaults keep isMobile/isTablet/isDesktop, also after a rename', () {
      expect(screenValues(390, 844)['isMobile'], isTrue);
      expect(screenValues(834, 1112)['isTablet'], isTrue);
      final renamed = Breakpoints.defaults.update('mobile', (b) => b.copyWith(name: 'Phone'));
      final s = screenValues(390, 844, breakpoints: renamed);
      expect(s['isMobile'], isTrue, reason: 'by its id');
      expect(s['isPhone'], isTrue, reason: 'by its name');
      expect(s['breakpointName'], 'Phone');
    });

    test('formulas read them', () {
      const e = Expressions();
      final s = ValuesScope({'screen': screenValues(1400, 900, breakpoints: custom)});
      expect(e.evaluate(r'${screen.breakpoint}', s), 'xl');
      expect(e.evaluate(r'${= screen.isLargeDesktop ? 1 : 2}', s), 1);
      expect(e.evaluate(r'${screen.atLeast.medium}', s), isTrue);
      expect(e.evaluate(r'${screen.is.compact}', s), isFalse);
    });

    test("inside a responsive layout with its own switch points, screen is the layout's", () {
      final around = ValuesScope({'screen': screenValues(1000, 900)});
      final v = Node.fromJson({
        'type': 'variance',
        'props': {
          'variants': [
            {'id': 'a', 'name': 'A', 'children': [], 'breakpoint': 'tablet'},
          ],
          'minWidths': {'desktop': 900},
        },
      }, id: 'v')!;
      final scope = nodeValuesScopeFor(v, around);
      expect(scope, isA<ResponsiveScreenScope>());
      expect(readPath(around, 'screen.breakpoint'), 'tablet');
      expect(readPath(scope, 'screen.breakpoint'), 'desktop');
      expect(readPath(scope, 'screen.isDesktop'), isTrue);
      // Following the screen.
      var told = 0;
      watchName(scope, 'screen')!.addListener(() => told++);
      around.set('screen', screenValues(800, 900));
      expect(told, 1);
      expect(readPath(scope, 'screen.breakpoint'), 'tablet');
    });
  });

  test("an adaptive modal is a sheet below its breakpoint's min width", () {
    expect(defaultSheetBelowWidth(custom), 700, reason: 'the second breakpoint');
    expect(defaultSheetBelowWidth(Breakpoints([const Breakpoint(id: 'only')])), 0);
    final atXl = const OpenModalAction(presentation: ModalPresentation.adaptive, sheetBelow: 'xl').sheetBelowWidthIn(custom);
    expect(atXl, 1300);
    expect(resolvePresentation(ModalPresentation.adaptive, 1299, sheetBelowWidth: atXl), ModalPresentation.bottomSheet);
    expect(resolvePresentation(ModalPresentation.adaptive, 1300, sheetBelowWidth: atXl), ModalPresentation.dialog);
    expect(resolvePresentation(ModalPresentation.adaptive, 650, sheetBelowWidth: defaultSheetBelowWidth(custom)),
        ModalPresentation.bottomSheet);
    expect(resolvePresentation(ModalPresentation.adaptive, null, sheetBelowWidth: 700), ModalPresentation.dialog);
    expect(resolvePresentation(ModalPresentation.sideSheet, 100, sheetBelowWidth: 700), ModalPresentation.sideSheet);
  });

  test('a per-breakpoint toast look is keyed by id, else name', () {
    expect(perBreakpointValue({'medium': 'start'}, 800, custom), 'start');
    expect(perBreakpointValue({'Medium': 'end'}, 800, custom), 'end');
    expect(perBreakpointValue({'largeDesktop': 'end'}, 1500, custom), 'end');
    expect(perBreakpointValue({'compact': 'start'}, 800, custom), isNull);
    expect(perBreakpointValue({'tablet': 'start'}, 800, Breakpoints.defaults), 'start');
  });

  group('running', () {
    Future<CodelesslyWidgetController> pump(WidgetTester tester, PublishBundle bundle) async {
      final codelessly = Codelessly(
        config: const CodelesslyConfig(projectId: 'p'),
        loader: MemoryPublishLoader(bundle),
        fonts: const NoFontFetcher(),
      );
      final controller = CodelesslyWidgetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
      await settle(tester);
      return controller;
    }

    bool shows(CodelesslyWidgetController c, String id) => c.tree!.boxOf(id)?.attached ?? false;
    String textOf(CodelesslyWidgetController c, String id) => c.node(id)!.prop(TextProps.text);

    testWidgets('screens pick their canvas by the project breakpoints', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(1299, 900));
      var c = await pump(tester, bundleWith(custom));
      expect(c.canvasId, 'c', reason: 'xl starts at 1300 in this project');
      setScreen(tester, const Size(1300, 900));
      await settle(tester);
      expect(c.canvasId, 'x');
      // The same layout in a project whose xl starts at 1000.
      setScreen(tester, const Size(1100, 900));
      c = await pump(tester, bundleWith(custom.update('xl', (b) => b.copyWith(minWidth: 1000))));
      expect(c.canvasId, 'x');
    });

    testWidgets('a responsive variance switches variant by the screen width', (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(400, 900));
      final c = await pump(tester, bundleWith(custom));
      expect(shows(c, 'vc'), isTrue);
      expect(shows(c, 'vm'), isFalse);
      expect(textOf(c, 'tc'), 'compact');
      // Medium (700..1299) shows the medium variant: on the compact canvas,
      // which this screen shows up to xl.
      tester.view.physicalSize = const Size(800, 900);
      await settle(tester);
      expect(c.canvasId, 'c');
      expect(shows(c, 'vm'), isTrue);
      expect(shows(c, 'vc'), isFalse);
      expect(textOf(c, 'tm'), 'medium');
      // Back.
      tester.view.physicalSize = const Size(500, 900);
      await settle(tester);
      expect(shows(c, 'vc'), isTrue);
    });

    testWidgets('a breakpoint no variant names changes nothing', (tester) async {
      ignoreOverflows();
      // A breakpoint between compact and medium: the compact variant still
      // shows up to medium; screen names the new one.
      final more = custom.add(const Breakpoint(id: 'mid', name: 'Mid', minWidth: 500));
      setScreen(tester, const Size(600, 900));
      final c = await pump(tester, bundleWith(more));
      expect(shows(c, 'vc'), isTrue);
      expect(textOf(c, 'tc'), 'mid');
      tester.view.physicalSize = const Size(750, 900);
      await settle(tester);
      expect(shows(c, 'vm'), isTrue);
    });
    testWidgets("a variance's own switch points move where it switches, and screen inside it", (tester) async {
      ignoreOverflows();
      setScreen(tester, const Size(800, 900));
      final c = await pump(tester, bundleWith(custom, minWidths: const {'medium': 900}));
      expect(shows(c, 'vc'), isTrue, reason: 'medium from 900 for this variance');
      expect(textOf(c, 'tc'), 'compact', reason: 'screen inside it agrees');
      expect(c.read('screen.breakpoint'), 'medium', reason: 'the screen itself is medium');
      tester.view.physicalSize = const Size(950, 900);
      await settle(tester);
      expect(shows(c, 'vm'), isTrue);
      expect(textOf(c, 'tm'), 'medium');
    });
  });
}

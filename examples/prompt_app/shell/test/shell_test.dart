// The storyboard shows the generated screens as one app: the store's values
// reach every screen, a screen's events navigate, a finished session changes
// what the next screen shows, and the panel's rows and the app stay the same
// in both directions.
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart' show UiEvent;
import 'package:dynamic_properties_panel/dynamic_properties_panel.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skip_shell/skip/skip_screen.dart';
import 'package:skip_shell/skip/skip_storyboard.dart';
import 'package:skip_shell/skip_app.dart';
import 'package:skip_shell/storyboard/data/storyboard_data.dart';
import 'package:skip_shell/storyboard/services/annotation_service.dart';
import 'package:skip_shell/storyboard/services/pinned_service.dart';
import 'package:skip_shell/storyboard/services/status_service.dart';
import 'package:skip_shell/storyboard/widgets/phone_frame_viewer.dart';
import 'package:skip_shell/storyboard/widgets/single_flow_viewer.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

Future<String> _file(String key) => File(key).readAsString();

/// The test font draws every glyph a full em wide, so a row of a generated
/// screen that fits in the real fonts overflows here: only that is let by.
void _letOverflowBy() {
  final old = FlutterError.onError;
  FlutterError.onError = (d) => d.exceptionAsString().contains('overflowed') ? null : old?.call(d);
  addTearDown(() => FlutterError.onError = old);
}

/// One change, taken all the way: the controller tells its listeners after
/// the write, and the storyboard chooses its page after a frame.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Shows the storyboard for [app] and waits for its first page. The
/// template's services read files, which only moves on outside the test's
/// clock, so they are read first and the frames are pumped in rounds.
Future<void> _open(WidgetTester tester, SkipApp app) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() async {
    await StatusService.instance.init();
    await PinnedService.instance.init();
    await AnnotationService.instance.init();
  });
  await tester.pumpWidget(SkipStoryboardApp(app: app));
  await _settle(tester);
  await _settle(tester);
}

/// The text painted under [finder].
String _painted(WidgetTester tester, Finder finder) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(tester.renderObject(finder));
  return out.toString();
}

void main() {
  test('the store: a finished session is added, and the streak and the week follow', () async {
    final app = SkipApp(_file);
    await app.start();
    expect(app.screen, 'home');
    expect(app.data['streak'], 4);
    app.handle(const UiEvent(event: 'start_session'));
    expect(app.screen, 'session');
    app.handle(const UiEvent(event: 'finish_session', value: 25));
    expect(app.data['streak'], 5);
    expect(app.data['sessionsThisWeek'], 4);
    expect(((app.data['sessions']! as List).first as Map)['jumps'], 25);
    app.handle(const UiEvent(event: 'open_history'));
    expect(app.screen, 'history');
    expect(app.log.map((l) => l.value == null ? l.event : '${l.event} ${l.value}'), [
      'open_history',
      'finish_session 25',
      'start_session',
    ]);
    expect(app.log.every((l) => l.handled), isTrue);
    app.dispose();
  });

  test('the kernel: a restyle keeps the person, a store edit keeps the screen, a missing screen is a state', () async {
    final app = SkipApp(
      (key) => key.endsWith('session.kid.json') ? throw const FileSystemException('none') : _file(key),
    );
    await app.start();
    expect(app.ready, isTrue);
    expect(app.has('session', 'kid'), isFalse);
    expect(app.has('session', 'beginner'), isTrue);
    app.restyle('athlete');
    expect((app.person, app.tokens), ('beginner', 'athlete'));
    final shown = app.session;
    app.set('streak', 9);
    expect(app.session, same(shown), reason: 'an edit goes into the screen on show; it is not opened again');
    app.choose('kid');
    expect(app.tokens, 'pink', reason: 'a person brings their own token set');
    app.open('session');
    expect(app.session, isNull);
    app.dispose();
  });

  testWidgets('the storyboard: stories, the panel and the app, both ways', (tester) async {
    _letOverflowBy();
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final app = SkipApp(_file);
    await tester.runAsync(app.start);
    await _open(tester, app);
    expect(tester.takeException(), isNull);

    final state = tester.state<SkipStoryboardAppState>(find.byType(SkipStoryboardApp));
    final controller = state.controls.controller;
    final phone = find.byType(PhoneFrameViewer);
    Future<void> settle() async {
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }

    // It loads on a story: a generated screen in the template's phone frame,
    // with the panel showing the same person, screen and store.
    expect(state.selectedItem?.route, storyRoute('home', 'beginner'));
    expect(phone, findsOneWidget);
    expect(find.descendant(of: phone, matching: find.byType(SkipScreen)), findsOneWidget);
    expect(find.byType(DynamicPropertiesPanel), findsNWidgets(2));
    expect((controller['person'], controller['tokens'], controller['screen']), ('beginner', 'default', 'home'));
    expect(controller['streak'], 4);
    final home = _painted(tester, phone);
    expect(home, contains('Today'));
    expect(home, contains('4'));

    // Person, through the controller: the kid's own Home, under their tokens.
    controller['person'] = 'kid';
    await settle();
    expect(app.person, 'kid');
    expect(controller['tokens'], 'pink');
    expect(state.selectedItem?.route, storyRoute('home', 'kid'));
    final kid = _painted(tester, phone);
    expect(kid, isNot(home), reason: 'the kid has their own Home');

    // Token set alone: the same screen, the same text, another session.
    final before = app.session;
    controller['tokens'] = 'athlete';
    await settle();
    expect((app.person, app.tokens), ('kid', 'athlete'));
    expect(app.session, isNot(same(before)));
    expect(_painted(tester, phone), kid, reason: 'a restyle regenerates nothing');
    expect(state.selectedItem?.route, storyRoute('home', 'kid'));

    // The store, through the controller: Home shows it at once.
    expect(_painted(tester, phone), isNot(contains('27')));
    controller['streak'] = 27;
    await settle();
    expect(app.data['streak'], 27);
    expect(_painted(tester, phone), contains('27'));

    // And back: what a screen told the app reaches the controller.
    app.handle(const UiEvent(event: 'finish_session', value: 12));
    await settle();
    expect(controller['streak'], 28);
    expect(controller['sessionsThisWeek'], 4);
    expect(((controller['sessions'] as List).first as Map)['jumps'], 12);
    expect(_painted(tester, phone), contains('28'));
    expect(find.textContaining('finish_session', findRichText: true), findsOneWidget);

    // Screen, through the controller: the storyboard goes to that story.
    controller['screen'] = 'history';
    await settle();
    expect(state.selectedItem?.route, storyRoute('history', 'kid'));

    // The flow shows the real screens side by side.
    await tester.tap(find.text('A session, start to finish'));
    await settle();
    expect(find.byType(SingleFlowViewer), findsOneWidget);
    expect(find.byType(SkipScreen), findsNWidgets(5));

    // A person's group shows their three screens side by side.
    await tester.tap(find.text('ATHLETE'));
    await settle();
    expect(find.byType(SkipScreen), findsNWidgets(3));
    expect(app.person, 'athlete');

    // The running app navigates by the screens' own events.
    await tester.tap(find.text('Run the app'));
    await settle();
    expect(find.byType(RunScreen), findsOneWidget);
    app.handle(const UiEvent(event: 'open_home'));
    await settle();
    expect(controller['screen'], 'home');
    app.handle(const UiEvent(event: 'start_session'));
    await settle();
    expect(controller['screen'], 'session');
    expect(find.byType(SoftSaaSLoadingSpinner), findsNothing);

    await settle();
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('the storyboard: a screen that was not generated is a state, not an error', (tester) async {
    _letOverflowBy();
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = SkipApp(
      (key) => key.endsWith('session.kid.json') ? throw const FileSystemException('none') : _file(key),
    );
    // Before the app is read, the phone and the panel say so.
    await _open(tester, app);
    expect(find.text('Reading the design system and the generated screens'), findsOneWidget);
    await tester.runAsync(app.start);
    await _settle(tester);
    final state = tester.state<SkipStoryboardAppState>(find.byType(SkipStoryboardApp));
    // 1000 wide: the panel does not fit beside the viewer, and is a rail.
    expect(find.byKey(const ValueKey('skip-inspector-open')), findsOneWidget);
    expect(find.byType(DynamicPropertiesPanel), findsNothing);
    state.controls.controller.applyAll({'person': 'kid', 'screen': 'session'});
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(state.selectedItem?.route, storyRoute('session', 'kid'));
    expect(find.text('No Session screen for the kid'), findsOneWidget);
    await _settle(tester);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}

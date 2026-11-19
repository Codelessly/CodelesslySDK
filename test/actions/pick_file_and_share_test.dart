// pickFile: the person chooses a file on the device and the page gets its
// record (name, size, type and its content as a data: URL or as text) as
// `result`, with nothing uploaded. share: the device's share panel takes a
// text, a link and a title, or where there is none the link is copied.
// `screen.url` is the page's address.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/internals.dart';
import 'package:codelessly_sdk/src/app/navigator_ui.dart' show debugBrowserUrl;
import 'package:codelessly_sdk/src/runtime/actions/action_error.dart' show CodedFailure;
import 'package:codelessly_sdk/src/render/controls/kit.dart' show firstTextUnder;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/present_support.dart' show bundleOf, screen;
import '../support/cards.dart' show boxesOf, centerOf, settle, textOf;
import 'action_chains_test.dart' show Harness;

PickedFile _file(String name, List<int> bytes, [String? type]) => PickedFile(name: name, bytes: Uint8List.fromList(bytes), contentType: type);

final _png = _file('map.png', [137, 80, 78, 71, 13, 10, 26, 10], 'image/png');
final _notes = _file('notes.txt', utf8.encode('Low tide 06:12'));

/// A picker that says what it was asked for.
class _Asked implements TypedFilePicker {
  _Asked(this.files);
  final List<PickedFile> files;
  final asked = <Object>[];

  @override
  Future<List<PickedFile>> pick({bool images = true, bool multiple = true}) async {
    asked.add((images: images, multiple: multiple));
    return files;
  }

  @override
  Future<List<PickedFile>> pickTypes(List<String> accept, {bool multiple = false}) async {
    asked.add((accept: accept, multiple: multiple));
    return files;
  }
}

Future<UiSession> _show(WidgetTester tester, String notation, Services services, {String? routeName}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.reset);
  final session = UiSession(catalog: standardCatalog, profile: TrustProfile.none);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (_) => Scaffold(body: CodelesslyView(session: session, services: services, handlers: mediaFeature.actions)),
    ),
  ));
  final result = await session.applyNotation(Stream.value(notation), options: const NotationOptions(width: 390));
  await settle(tester);
  expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

/// Every text on screen, a line each.
String _texts(WidgetTester tester) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    if (o is NodeBox) {
      if (firstTextUnder(o) case final String t) out.writeln(t);
    }
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return '$out';
}

const _attach = '''
state files=[]
state shown=""
state said=""
Column gap=12 pad=16
  Button#attach "Attach" onTap={pickFile accept="image/*,.txt"; files=append(files, result); shown=result.data; said="picked"}
  Text#count "{length(files)}"
  Text#said "{said}"
  each f in files
    Text#name "{f.name} {f.size} {f.type}"
  Image#picture {shown} w=40 h=40
''';

void main() {
  group('picking a file', () {
    testWidgets('a tap opens the chooser and the page gets the file\'s record; an image shows its data', (tester) async {
      final picker = _Asked([_png]);
      await _show(tester, _attach, Services(filePicker: picker));
      await tester.tapAt(centerOf(tester, 'attach'));
      await settle(tester);
      expect('${picker.asked.single}', '(accept: [image/*, .txt], multiple: false)');
      expect(textOf(tester, 'count'), '1');
      expect(textOf(tester, 'name'), 'map.png 8 image/png');
      expect(textOf(tester, 'said'), 'picked');
      expect(boxesOf(tester, 'picture'), isNotEmpty);
    });

    testWidgets('picking nothing ends the chain: nothing is appended', (tester) async {
      await _show(tester, _attach, Services(filePicker: const FixedFilePicker([])));
      await tester.tapAt(centerOf(tester, 'attach'));
      await settle(tester);
      expect(textOf(tester, 'count'), '0');
      expect(textOf(tester, 'said'), '');
    });

    test('the record: a data: URL, or the text, or neither; the type by the name when the picker gives none', () async {
      final h = Harness(services: Services(filePicker: FixedFilePicker([_notes])), ui: NavigatorActionUi(context: () => null), variables: [
        const Variable(name: 'file', type: VariableType.map, value: <String, Object?>{}),
      ]);
      Json set() => {'type': 'setVariable', 'variable': 'file', 'value': r'${result}'};
      await h.click([{'type': 'pickFile'}, set()]);
      expect(h.errors, isEmpty);
      final record = (h['file'] as Map).cast<String, Object?>();
      expect(record.keys, ['name', 'size', 'type', 'data']);
      expect((record['name'], record['size'], record['type']), ('notes.txt', 14, 'text/plain'));
      expect(utf8.decode(UriData.parse(record['data']! as String).contentAsBytes()), 'Low tide 06:12');
      // What a cloudFiles action's source takes.
      expect(sourceFiles(record).single.name, 'notes.txt');

      await h.click([{'type': 'pickFile', 'content': 'text'}, set()]);
      expect(h['file'], {'name': 'notes.txt', 'size': 14, 'type': 'text/plain', 'text': 'Low tide 06:12'});
      await h.click([{'type': 'pickFile', 'content': 'none'}, set()]);
      expect(h['file'], {'name': 'notes.txt', 'size': 14, 'type': 'text/plain'});
    });

    test('several files are a list of records', () async {
      final h = Harness(services: Services(filePicker: FixedFilePicker([_png, _notes])), ui: NavigatorActionUi(context: () => null), variables: [
        const Variable(name: 'names', value: ''),
      ]);
      await h.click([
        {'type': 'pickFile', 'multiple': true, 'content': 'none'},
        {'type': 'setVariable', 'variable': 'names', 'value': r'${= join(map(result, f => f.name), ",")}'},
      ]);
      expect(h.errors, isEmpty);
      expect(h['names'], 'map.png,notes.txt');
      // One file when it is not multiple, whatever the picker gives.
      await h.click([
        {'type': 'pickFile', 'content': 'none'},
        {'type': 'setVariable', 'variable': 'names', 'value': r'${result.name}'},
      ]);
      expect(h['names'], 'map.png');
    });

    test('a file of a kind not accepted, or over the size, fails with a code and gives nothing', () async {
      Future<(Object?, List<Json>)> pick(Json action, PickedFile file) async {
        final scope = VariableScope(const [Variable(name: 'name', value: '')]);
        final events = <Json>[];
        final context = RuntimeActionContext(
          scope: scope,
          ui: NavigatorActionUi(context: () => null),
          services: Services(filePicker: FixedFilePicker([file]), analytics: const NoAnalytics()),
          onActionErrorEvent: events.add,
        );
        await const CodelesslyActions().trigger(
            Node.fromJson({
              'type': 'box',
              'actions': [
                {
                  'trigger': {'type': 'click'},
                  'actions': [action, {'type': 'setVariable', 'variable': 'name', 'value': r'${result.name}'}],
                },
              ],
            }, id: 'b')!,
            'click',
            context);
        final name = scope.read('name');
        scope.dispose();
        return (name, events);
      }

      final (kindName, kind) = await pick({'type': 'pickFile', 'accept': 'image/*,.pdf'}, _notes);
      expect((kind.single['error'] as Map)['code'], 'invalid-file-type');
      expect(kindName, '');
      final (sizeName, size) = await pick({'type': 'pickFile', 'maxSizeMB': 1}, _file('big.bin', List.filled(1024 * 1024 + 1, 0)));
      expect((size.single['error'] as Map)['code'], 'file-too-large');
      expect(sizeName, '');
      final (okName, ok) = await pick({'type': 'pickFile', 'accept': 'image/*,.txt'}, _notes);
      expect(ok, isEmpty);
      expect(okName, 'notes.txt');
    });

    test('the kinds accepted: MIME types, families and extensions', () {
      expect(acceptedKinds(' image/* , .PDF,,text/csv '), ['image/*', '.pdf', 'text/csv']);
      expect(fileAccepted(const [], 'a.bin', null), isTrue);
      expect(fileAccepted(const ['image/*'], 'a.png', null), isTrue, reason: 'by its name');
      expect(fileAccepted(const ['image/*'], 'a', 'image/webp'), isTrue);
      expect(fileAccepted(const ['.pdf'], 'Report.PDF', null), isTrue);
      expect(fileAccepted(const ['application/pdf'], 'a.pdf', ''), isTrue);
      expect(fileAccepted(const ['image/*', '.pdf'], 'a.txt', 'text/plain'), isFalse);
      final group = PlatformFilePicker.typeGroupOf(const ['image/*', '.pdf'])!;
      expect(group.extensions, containsAll(['png', 'jpg', 'pdf']));
      expect(group.mimeTypes, ['image/*']);
      expect(PlatformFilePicker.typeGroupOf(const ['application/x-thing']), isNull, reason: 'no known extension: any file, checked afterwards');
      expect(PlatformFilePicker.typeGroupOf(const []), isNull);
    });
  });

  group('sharing', () {
    const page = '''
state said=""
Column gap=12 pad=16
  Button#share "Share" onTap={share title="Tide tables" text="Low tide 06:12" url={screen.url}; said=result.shared ? "shared" : result.copied ? "copied" : "closed"}
  Text#said "{said}"
  Text#url "{screen.url}"
''';

    String? clipboard;
    setUp(() {
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      debugBrowserUrl = null;
    });

    testWidgets('the share panel takes the text, the title and the page\'s address', (tester) async {
      final sharer = RecordingSharer();
      await _show(tester, page, Services(sharer: sharer), routeName: '/trip/coast?day=2');
      expect(textOf(tester, 'url'), '/trip/coast?day=2', reason: 'in an app: the location a link opens the screen with');
      await tester.tapAt(centerOf(tester, 'share'));
      await settle(tester);
      expect(sharer.shared.single, (text: 'Low tide 06:12', url: '/trip/coast?day=2', title: 'Tide tables'));
      expect(textOf(tester, 'said'), 'shared');
      expect(clipboard, isNull);
    });

    testWidgets('in a browser screen.url is the address it shows', (tester) async {
      debugBrowserUrl = 'https://tides.example/trip/coast?day=2';
      final sharer = RecordingSharer();
      await _show(tester, page, Services(sharer: sharer), routeName: '/trip/coast?day=2');
      expect(textOf(tester, 'url'), 'https://tides.example/trip/coast?day=2');
      await tester.tapAt(centerOf(tester, 'share'));
      await settle(tester);
      expect(sharer.shared.single.url, 'https://tides.example/trip/coast?day=2');
    });

    testWidgets('where there is no share panel the link is copied, and the page is told', (tester) async {
      // The platform's own: none in a test, as on a desktop or a phone without a plugin.
      await _show(tester, page, Services(), routeName: '/trip/coast');
      await tester.tapAt(centerOf(tester, 'share'));
      await settle(tester);
      expect(clipboard, '/trip/coast');
      expect(textOf(tester, 'said'), 'copied');
    });

    testWidgets('a panel the person closes shares nothing and copies nothing', (tester) async {
      final sharer = RecordingSharer(outcome: ShareOutcome.dismissed);
      await _show(tester, page, Services(sharer: sharer), routeName: '/trip/coast');
      await tester.tapAt(centerOf(tester, 'share'));
      await settle(tester);
      expect(textOf(tester, 'said'), 'closed');
      expect(clipboard, isNull);
    });

    test('with no link the text is copied; with neither it fails', () async {
      final h = Harness(services: Services(), variables: [const Variable(name: 'copied', type: VariableType.boolean, value: false)]);
      await h.click([
        {'type': 'share', 'text': 'Low tide 06:12'},
        {'type': 'setVariable', 'variable': 'copied', 'value': r'${result.copied}'},
      ]);
      expect(h.errors, isEmpty);
      expect(clipboard, 'Low tide 06:12');
      expect(h['copied'], true);
      await h.click([{'type': 'share'}]);
      expect(h.errors.single, isA<CodedFailure>().having((e) => e.code, 'code', 'nothing-to-share'));
    });

    testWidgets('a screen with no location has an empty url', (tester) async {
      await _show(tester, 'Column\n  Text#url "[{screen.url}]"\n', Services());
      expect(textOf(tester, 'url'), '[]');
    });

    testWidgets('a dialog is at the address of the page it was opened from', (tester) async {
      Json label(String text) => {
            'type': 'text',
            'layout': {'width': {'hug': 80}, 'height': {'hug': 20}},
            'props': {'text': text, 'style': {'color': '#FF111111', 'fontSize': 14}},
          };
      final app = Codelessly.fromBundle(
        bundleOf([
          screen('home', children: ['at'], extraNodes: {'at': label(r'page ${screen.url}')}, onClick: [
            {'type': 'openModal', 'to': 'about'},
          ]),
          screen('about', children: ['where'], extraNodes: {'where': label(r'dialog ${screen.url}')}),
        ]),
        fonts: const NoFontFetcher(),
      );
      addTearDown(app.dispose);
      final controller = CodelesslyWidgetController(layoutId: 'home');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/trip/coast'),
          builder: (_) => CodelesslyWidget(codelessly: app, controller: controller),
        ),
      ));
      await settle(tester);
      expect(_texts(tester), contains('page /trip/coast'));
      // The chain waits for the dialog to close: not awaited.
      unawaited(controller.trigger('home-body', 'click'));
      await settle(tester);
      expect(_texts(tester), contains('dialog /trip/coast'));
    });
  });
}

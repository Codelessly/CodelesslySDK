import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const InputBorderModel _none = InputBorderModel(
  borderType: BorderTypeEnum.none,
);

/// Icons load as SVGs over the network; [_SvgHttp] serves one locally.
final MultiSourceIconModel _search = MultiSourceIconModel(
  show: true,
  size: 17,
  icon: CupertinoIcon(
    codepoint: CupertinoIcons.search.codePoint,
    name: 'search',
  ),
);

TextFieldNode _field({EdgeInsetsModel? iconPadding}) => TextFieldNode(
  id: 'field',
  name: 'Search',
  basicBoxLocal: NodeBox(0, 0, 300, 40),
  properties: TextFieldProperties(
    decoration: InputDecorationModel(
      hintText: 'Search name, variety, Latin',
      border: _none,
      enabledBorder: _none,
      focusedBorder: _none,
      disabledBorder: _none,
      errorBorder: _none,
      focusedErrorBorder: _none,
      contentPadding: EdgeInsetsModel.zero,
      prefixIcon: ReactiveIconModel(icon: _search),
      prefixIconPadding: iconPadding,
    ),
  ),
);

Future<void> _pump(WidgetTester tester, TextFieldNode node) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const String _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect width="24" height="24"/></svg>';

/// Serves [_svg] for every request, so the icon loads without the network.
class _SvgHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client();
}

class _Client implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _Request();
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _Response();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  final List<int> _bytes = utf8.encode(_svg);
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _bytes.length;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];
  @override
  HttpHeaders get headers => _Headers();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _settleIcon(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

double _left(WidgetTester tester, Finder f) => tester.getTopLeft(f).dx;

void main() {
  setUp(() => HttpOverrides.global = _SvgHttp());
  tearDown(() => HttpOverrides.global = null);

  testWidgets('an icon padding puts the prefix icon at that inset', (
    tester,
  ) async {
    await _pump(
      tester,
      _field(iconPadding: EdgeInsetsModel.only(left: 13, right: 8)),
    );
    await _settleIcon(tester);
    final double field = _left(tester, find.byType(TextField));
    // The text starts after the icon and its padding, plus Material's 4 px
    // gap after a prefix icon: 13 + 17 + 8 + 4.
    expect(_left(tester, find.byType(EditableText)) - field, 42);
  });

  testWidgets("without one, Material's 48 px slot (and its 4 px gap) stays", (
    tester,
  ) async {
    await _pump(tester, _field());
    await _settleIcon(tester);
    final double field = _left(tester, find.byType(TextField));
    expect(_left(tester, find.byType(EditableText)) - field, 52);
  });
}

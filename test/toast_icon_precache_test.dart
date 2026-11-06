import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Lamplight's "Desk lamp back in the tray" toast showed without its icon the
// first time in a session on the published site: the icon's SVG was fetched
// when the toast appeared and wasn't there yet. Layouts now load the SVGs of
// their toast icons when they load.

const String _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="M2 2h20v20H2z"/></svg>';

Map<String, dynamic> _toast(String name) => {
  'type': 'showToast',
  'message': 'Back in the tray',
  'icon': MultiSourceIconModel.icon(
    size: 19,
    icon: MaterialIcon(
      codepoint: 0,
      name: name,
      style: MaterialIconStyle.rounded,
    ),
  ).toJson(),
};

RowColumnNode _button() => RowColumnNode(
  id: 'button',
  name: 'Button',
  basicBoxLocal: NodeBox(0, 0, 100, 40),
  rowColumnType: RowColumnType.row,
  children: const [],
  reactions: [
    Reaction(
      trigger: TriggerModel(type: TriggerType.click),
      action: ActionModel.fromJson({
        'type': 'conditional',
        'expression': {
          'type': 'Expression',
          'leftPart': {'type': 'Variable', 'valueString': r'${= true}'},
          'operator': 'isTrue',
          'rightPart': {'type': 'RawValue', 'value': ''},
        },
        'actions': [_toast('inventory_2')],
        'elseActions': [_toast('delete')],
      }),
    ),
    Reaction(
      trigger: TriggerModel(type: TriggerType.click),
      action: ActionModel.fromJson(_toast('inventory_2')),
    ),
  ],
);

void main() {
  tearDown(() {
    SvgIcon.httpClient = null;
    SvgIcon.precacheEnabled = false;
    svg.cache.clear();
  });

  test('finds the toast icons in reactions, nested ones too', () {
    final List<MultiSourceIconModel> icons = AppToast.iconsIn([_button()]);
    expect(icons.map((icon) => (icon.icon! as MaterialIcon).name).toList(), [
      'inventory_2',
      'delete',
      'inventory_2',
    ]);
    expect(icons.first.size, 19);
  });

  testWidgets('a precached toast icon draws without fetching again', (
    tester,
  ) async {
    final List<Uri> requests = [];
    SvgIcon.httpClient = MockClient((request) async {
      requests.add(request.url);
      return http.Response(_svg, 200);
    });
    SvgIcon.precacheEnabled = true;

    await tester.runAsync(() => AppToast.precacheIcons([_button()]));
    // One fetch per icon, however often it appears.
    expect(requests.map((url) => url.pathSegments[3]).toList()..sort(), [
      'delete',
      'inventory_2',
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SvgIcon(
            icon: MaterialIcon(
              codepoint: 0,
              name: 'inventory_2',
              style: MaterialIconStyle.rounded,
            ),
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();
    // The toast's icon came from the cache and is drawn on its first frames.
    expect(requests, hasLength(2));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString().endsWith('VectorGraphicWidget'),
      ),
      findsOneWidget,
    );
  });

  test('off, it fetches nothing (widget tests answer 400)', () async {
    int calls = 0;
    SvgIcon.httpClient = MockClient((request) async {
      calls++;
      return http.Response(_svg, 200);
    });
    SvgIcon.precacheEnabled = false;
    await AppToast.precacheIcons([_button()]);
    expect(calls, 0);
  });
}

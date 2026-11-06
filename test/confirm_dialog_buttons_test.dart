import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const Color _surface = Color(0xFFFFFBF6);
const Color _ink = Color(0xFF2A211B);
const Color _line = Color(0xFFD2C0AC);
const Color _danger = Color(0xFFB04A3A);
const Color _offDot = Color(0xFFEDE6DC);

/// Lamplight's "Take Reading lamp down?" dialog: the lamp's dot over the
/// title, an outlined "Keep it" beside a red-outlined "Take down", centered
/// and sharing the row, its colours bound to the palette.
void main() {
  // Icons load as SVGs: answer with a square instead of the network.
  setUp(
    () => SvgIcon.httpClient = MockClient(
      (_) async => http.Response(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<rect width="24" height="24"/></svg>',
        200,
      ),
    ),
  );
  tearDown(() => SvgIcon.httpClient = null);

  Future<bool?> open(WidgetTester tester, ConfirmAction action) async {
    final CodelesslyContext ctx = CodelesslyContext.empty()
      ..variables['pal'] = Observable(
        VariableData(
          id: 'pal',
          name: 'pal',
          type: VariableType.map,
          value: <String, dynamic>{
            'surface': '#FFFBF6',
            'ink': '#2A211B',
            'lineStrong': '#D2C0AC',
            'danger': '#B04A3A',
            'offDot': '#EDE6DC',
          },
        ),
      )
      ..variables['lamp'] = Observable(
        VariableData(
          id: 'lamp',
          name: 'lamp',
          type: VariableType.map,
          value: <String, dynamic>{'name': 'Reading lamp', 'icon': 'light'},
        ),
      );
    bool? result;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: ctx,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await AppConfirmDialog.show(context, action),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  ConfirmAction takeDown({bool bindIcon = false}) =>
      ActionModel.fromJson({
            // A glyph drawn without a download, as in the card toast test.
            'icon': MultiSourceIconModel(
              show: true,
              size: 27,
              icon: CupertinoIcon(
                codepoint: CupertinoIcons.lightbulb.codePoint,
                name: 'light',
              ),
            ).toJson(),
            'type': 'confirm',
            'title': r'Take ${lamp.name} down?',
            'message': 'It goes back to the tray and switches off.',
            'confirmLabel': 'Take down',
            'cancelLabel': 'Keep it',
            'centered': true,
            'expandButtons': true,
            'confirmBorder': {'color': '#73B04A3A', 'width': 1},
            'cancelBorder': {'color': '#D2C0AC', 'width': 1},
            'iconDiscSize': 52,
            'iconDiscBorder': {'color': '#D2C0AC', 'width': 1},
            'iconSize': 27,
            'variables': {
              'backgroundColor': r'${pal.surface}',
              'confirmColor': r'${pal.surface}',
              'confirmTextColor': r'${pal.danger}',
              'cancelColor': r'${pal.surface}',
              'cancelTextColor': r'${pal.ink}',
              'confirmBorderColor': r'${= alpha(pal.danger, 0.45)}',
              'cancelBorderColor': r'${pal.lineStrong}',
              'iconDiscColor': r'${pal.offDot}',
              'iconColor': r'${pal.ink}',
              if (bindIcon) 'icon': r'${lamp.icon}',
            },
          })
          as ConfirmAction;

  test('the new fields survive JSON and are left out by default', () {
    final ConfirmAction action = takeDown();
    expect(ConfirmAction.fromJson(action.toJson()), action);
    final Map json = ConfirmAction(title: 'Sure?').toJson();
    for (final String key in [
      'confirmBorder',
      'cancelBorder',
      'icon',
      'iconSize',
      'iconDiscSize',
      'centered',
      'expandButtons',
    ]) {
      expect(json.containsKey(key), isFalse, reason: key);
    }
  });

  testWidgets('each button has its own outline, fill and label colour', (
    tester,
  ) async {
    await open(tester, takeDown());
    ButtonStyle style(String key) =>
        (tester.widget(find.byKey(ValueKey(key))) as ButtonStyleButton).style!;
    final ButtonStyle ok = style('codelessly-confirm-ok');
    final ButtonStyle cancel = style('codelessly-confirm-cancel');
    final BorderSide okSide = ok.side!.resolve({})!;
    final BorderSide cancelSide = cancel.side!.resolve({})!;
    expect(okSide.color.toARGB32() & 0xFFFFFF, _danger.toARGB32() & 0xFFFFFF);
    expect(okSide.color.a, closeTo(0.45, 0.01));
    expect(cancelSide.color, _line);
    expect(ok.backgroundColor!.resolve({}), _surface);
    expect(ok.foregroundColor!.resolve({}), _danger);
    expect(cancel.foregroundColor!.resolve({}), _ink);
  });

  testWidgets('a dot with the lamp icon sits over a centered title', (
    tester,
  ) async {
    await open(tester, takeDown());
    expect(find.text('Take Reading lamp down?'), findsOneWidget);
    final Finder disc = find.byKey(const ValueKey('codelessly-confirm-icon-disc'));
    expect(disc, findsOneWidget);
    expect(tester.getSize(disc), const Size(52, 52));
    final BoxDecoration decoration =
        tester.widget<Container>(disc).decoration! as BoxDecoration;
    expect(decoration.color, _offDot);
    expect((decoration.border! as Border).top.color, _line);
    // The bound icon name shows in the disc, above the title.
    final Finder icon = find.descendant(
      of: disc,
      matching: find.byType(SvgIcon),
    );
    expect(icon, findsOneWidget);
    expect(tester.widget<SvgIcon>(icon).color, _ink);
    expect(tester.widget<SvgIcon>(icon).size, 27);
    expect(
      tester.getCenter(disc).dy,
      lessThan(tester.getCenter(find.text('Take Reading lamp down?')).dy),
    );
    // Centered text, and the buttons share the row.
    final Text title = tester.widget(find.text('Take Reading lamp down?'));
    expect(title.textAlign, TextAlign.center);
    final double keep = tester
        .getSize(find.byKey(const ValueKey('codelessly-confirm-cancel')))
        .width;
    final double take = tester
        .getSize(find.byKey(const ValueKey('codelessly-confirm-ok')))
        .width;
    expect(keep, closeTo(take, 0.5));
    expect(keep, greaterThan(120));
    expect(
      tester.getCenter(disc).dx,
      closeTo(tester.getCenter(find.byType(Dialog)).dx, 0.5),
    );
  });

  test('an icon binding names a Material icon', () {
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'lamp': VariableData(
          id: 'lamp',
          name: 'lamp',
          type: VariableType.map,
          value: <String, dynamic>{'icon': 'table_lamp_rounded'},
        ),
      },
    );
    final MultiSourceIconModel? icon = AppConfirmDialog.iconOf(
      takeDown(bindIcon: true),
      scope,
    );
    expect(icon!.icon!.name, 'table_lamp');
    expect((icon.icon! as MaterialIcon).style, MaterialIconStyle.rounded);
    expect(AppConfirmDialog.iconOf(takeDown(), scope)!.icon!.name, 'light');
  });

  testWidgets('the outlined buttons still answer the dialog', (tester) async {
    final ConfirmAction action = takeDown();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await AppConfirmDialog.show(context, action),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take down'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

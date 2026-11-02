import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The Meridian "Booking code" field as the editor saved and published it.
final Map<String, dynamic> bookingCodeJson = {
  'variables': {
    'inputColor': r'${pal.ink}',
    'inputValue': r'${bkCode}',
    'cursorColor': r'${pal.gold}',
    'hintColor': r'${pal.muted}',
  },
  'id': 'bookingCode',
  'name': 'Booking code input',
  'horizontalFit': 'expanded',
  'verticalFit': 'shrinkWrap',
  'basicBoxLocal': [14, 3, 322, 44],
  'type': 'textField',
  'properties': {
    'cursorColor': '#9C7A45',
    'maxLength': 6,
    'inputStyle': {
      'fills': [
        {'id': 'f', 'type': 'solid', 'color': '#0F1B2D'},
      ],
      'fontSize': 15,
      'letterSpacing': {'value': 1},
      'fontName': {
        'family': 'JetBrains Mono',
        'style': 'Bold',
        'weight': 'w700',
      },
    },
    'decoration': {
      'isCollapsed': true,
      'prefixIcon': {'icon': {}},
      'suffixIcon': {'icon': {}},
      'focusedBorder': {'borderType': 'none'},
      'enabledBorder': {'borderType': 'none'},
      'border': {'borderType': 'none'},
      'showCounter': false,
    },
    'textCapitalization': 'characters',
  },
};

/// The field in a host app [app] wraps it in, with `bkCode` = K7Q2ZD.
Widget field({required bool scoped}) {
  final Widget input = PassiveTextFieldWidget(
    node: TextFieldNode.fromJson(bookingCodeJson),
    settings: const WidgetBuildSettings(debugLabel: 'test'),
    scopedValues: ScopedValues.preview(
      variables: {
        'bkCode': VariableData(id: 'bkCode', name: 'bkCode', value: 'K7Q2ZD'),
      },
    ),
  );
  return ChangeNotifierProvider<CodelesslyContext>(
    create: (_) => CodelesslyContext.empty(),
    child: Material(
      child: Row(
        children: [
          Expanded(
            child: scoped ? MaterialLocalizationsScope(child: input) : input,
          ),
        ],
      ),
    ),
  );
}

/// A host built without Flutter's MaterialApp, e.g. on `WidgetsApp` or on
/// `package:material_ui`'s MaterialApp (which registers material_ui's own
/// localizations): Flutter's MaterialLocalizations are missing.
Widget widgetsApp(Widget child) =>
    WidgetsApp(color: const Color(0xFFFFFFFF), builder: (context, _) => child);

void main() {
  testWidgets('a text field throws in a host without Material localizations', (
    tester,
  ) async {
    // The site rendered this as Flutter's grey release-mode error box.
    await tester.pumpWidget(widgetsApp(field(scoped: false)));
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('MaterialLocalizationsScope lets it build with its value', (
    tester,
  ) async {
    await tester.pumpWidget(widgetsApp(field(scoped: true)));
    expect(tester.takeException(), isNull);
    expect(find.text('K7Q2ZD'), findsOneWidget);
  });

  testWidgets('it works with no Localizations above at all', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: field(scoped: true),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('K7Q2ZD'), findsOneWidget);
  });

  testWidgets('it keeps the localizations a host gives', (tester) async {
    late BuildContext inner;
    await tester.pumpWidget(
      MaterialApp(
        home: MaterialLocalizationsScope(
          child: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(find.byType(Localizations), findsOneWidget);
    expect(MaterialLocalizations.of(inner), isNotNull);
  });

  testWidgets('CodelesslyWidget adds the scope', (tester) async {
    await tester.pumpWidget(
      widgetsApp(
        CodelesslyWidget(
          controller: CodelesslyWidgetController(
            layoutID: 'layout',
            codelessly: Codelessly(config: CodelesslyConfig(authToken: 'x')),
          ),
          loadingBuilder: (context) => Builder(
            builder: (context) =>
                Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ),
      ),
    );
    expect(find.text('OK'), findsOneWidget);
  });
}

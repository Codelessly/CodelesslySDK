import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_demand_blocks/main.dart' show loadCards, notationText;

void main() {
  testWidgets('render each live replacement at chat widths', (tester) async {
    final input =
        Platform.environment['ON_DEMAND_RESULTS'] ?? '/tmp/on-demand-results.json';
    final recorded =
        jsonDecode((await tester.runAsync(() => File(input).readAsString()))!)
            as List;
    final cards = (await tester.runAsync(loadCards))!;
    final report = <Map<String, Object?>>[];
    for (final item in recorded) {
      final row = (item as Map).cast<String, dynamic>();
      final session = UiSession(designSystem: cards);
      await session.applyNotation(
        Stream.value(notationText(row['firstNotation'] as String)),
      );
      session.addBlock(
        LayoutDocument.fromJson(row['blockJson'], catalog: standardCatalog),
      );
      final swap = await session.applyNotation(
        Stream.value(notationText(row['secondNotation'] as String)),
        replace: true,
      );
      final errors = <String>[];
      for (final width in [420.0, 320.0]) {
        // Keep the scenario and width beside any Flutter layout diagnostic.
        // ignore: avoid_print
        print('Rendering ${row['name']} at ${width.toInt()} px');
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: CodelesslyView(session: session),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final error = tester.takeException();
        if (error != null) errors.add('$width wide: $error');
      }
      report.add({'name': row['name'], 'swapOk': swap.ok, 'errors': errors});
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    final output =
        Platform.environment['ON_DEMAND_RENDER'] ?? '/tmp/on-demand-render.json';
    await tester.runAsync(
      () => File(
        output,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report)),
    );
    expect(report, hasLength(3));
    expect(report.every((row) => row['swapOk'] == true), isTrue);
  });
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Material 3 switch draws a smaller thumb when off (16 px of its 32 px
/// track, 24 on). `uniformThumb` keeps it 24 in both states, as a toggle
/// whose knob only slides (a white 22 px knob on a dark track, on or off).
void main() {
  SwitchNode toggle({required bool uniformThumb}) => SwitchNode(
    id: 's',
    name: 's',
    basicBoxLocal: NodeBox(0, 0, kSwitchDefaultWidth, kSwitchDefaultHeight),
    value: false,
    properties: SwitchProperties(
      activeTrackColor: ColorRGBA.black,
      inactiveTrackColor: ColorRGBA.black,
      activeThumbColor: ColorRGBA.white,
      inactiveThumbColor: ColorRGBA.white,
      uniformThumb: uniformThumb,
    ),
  );

  /// The width of the white thumb across the middle of the switch.
  Future<int> thumbWidth(
    WidgetTester tester, {
    required bool uniformThumb,
    required bool value,
  }) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Material(
          color: Colors.black,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: kSwitchDefaultWidth,
                height: kSwitchDefaultHeight,
                child: TransformerSwitch(
                  node: toggle(uniformThumb: uniformThumb),
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                  onChanged: (_, _) {},
                  value: value,
                  scopedValues: ScopedValues.empty(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    late ByteData data;
    late int width;
    late int height;
    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      width = image.width;
      height = image.height;
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    final int y = height ~/ 2;
    int longest = 0, run = 0;
    for (int x = 0; x < width; x++) {
      final int offset = (y * width + x) * 4;
      final bool white =
          data.getUint8(offset) > 200 &&
          data.getUint8(offset + 1) > 200 &&
          data.getUint8(offset + 2) > 200;
      run = white ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    return longest;
  }

  test('a uniform thumb has an empty icon in every state', () {
    final WidgetStateProperty<Icon?>? icon = TransformerSwitch.thumbIconOf(
      SwitchProperties(uniformThumb: true),
    );
    for (final Set<WidgetState> states in [
      <WidgetState>{},
      {WidgetState.selected},
      {WidgetState.disabled},
    ]) {
      expect(icon!.resolve(states), isA<Icon>());
      expect(icon.resolve(states)!.icon, isNull);
    }
    expect(TransformerSwitch.thumbIconOf(SwitchProperties()), isNull);
  });

  testWidgets('off, the default thumb is smaller than on', (tester) async {
    final int off = await thumbWidth(
      tester,
      uniformThumb: false,
      value: false,
    );
    final int on = await thumbWidth(tester, uniformThumb: false, value: true);
    expect(off, lessThan(on - 4));
  });

  testWidgets('a uniform thumb is as large off as on', (tester) async {
    final int off = await thumbWidth(tester, uniformThumb: true, value: false);
    final int on = await thumbWidth(tester, uniformThumb: true, value: true);
    expect((off - on).abs(), lessThanOrEqualTo(1));
    expect(
      off,
      greaterThan(await thumbWidth(tester, uniformThumb: false, value: false)),
    );
  });
}

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';

CanvasNode canvas({SizeFit verticalFit = SizeFit.fixed}) => CanvasNode(
  id: 'sheet',
  name: 'Sheet',
  basicBoxLocal: NodeBox(0, 0, 520, 600),
  verticalFit: verticalFit,
  scaleMode: ScaleMode.responsive,
  properties: CanvasProperties(bodyId: 'body'),
  children: const ['body'],
);

void main() {
  const BoxConstraints phone = BoxConstraints(maxWidth: 390, maxHeight: 760);

  test('a sheet spans the width and keeps its design height', () {
    final box = CanvasViewport.resolve(
      canvas(),
      phone,
      sizing: CanvasSizing.sheet,
    );
    expect(box.width, 390);
    expect(box.height, 600);
  });

  test('a shrink-wrapping sheet is as tall as its content', () {
    final box = CanvasViewport.resolve(
      canvas(verticalFit: SizeFit.shrinkWrap),
      phone,
      sizing: CanvasSizing.sheet,
    );
    expect(box.width, 390);
    expect(box.height, isNull);
  });

  test('a dialog keeps its design width; full screen fills', () {
    const BoxConstraints desktop = BoxConstraints(
      maxWidth: 1440,
      maxHeight: 900,
    );
    expect(
      CanvasViewport.resolve(
        canvas(),
        desktop,
        sizing: CanvasSizing.design,
      ).width,
      520,
    );
    final full = CanvasViewport.resolve(canvas(), desktop);
    expect((full.width, full.height), (1440, 900));
  });

  testWidgets('a sheet sits at the bottom, a dialog in the middle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<Offset> place(CanvasSizing sizing) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodelesslyDialogWidget(
            showCloseButton: false,
            sizing: sizing,
            builder: (_) =>
                const SizedBox(key: ValueKey('box'), width: 390, height: 200),
          ),
        ),
      );
      return tester.getTopLeft(find.byKey(const ValueKey('box')));
    }

    expect((await place(CanvasSizing.sheet)).dy, 844 - 200);
    expect((await place(CanvasSizing.design)).dy, (844 - 200) / 2);
  });
}

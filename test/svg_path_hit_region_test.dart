import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a path region takes taps on its line and lets the rest of its '
      'box through', (tester) async {
    final List<String> taps = [];
    // Two full-size boxes, each with one diagonal line, like two runs on a
    // trail map: the top one must not swallow taps meant for the other.
    Widget line(String name, String data) => SvgPathHitRegion(
      path: parseSvgPath(data)!,
      filled: false,
      stroked: true,
      strokeWidth: 4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => taps.add(name),
        child: const SizedBox.expand(),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              children: [
                line('under', 'M0 400 L400 0'),
                line('over', 'M0 0 L400 400'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 100)); // on "over"
    await tester.tapAt(const Offset(100, 300)); // on "under", inside "over"'s box
    await tester.tapAt(const Offset(105, 291)); // within the slop of "under"
    await tester.tapAt(const Offset(200, 100)); // on neither
    expect(taps, ['over', 'under', 'under']);
  });

  test('a filled region takes taps inside its shape only', () {
    final RenderSvgPathHitRegion region = RenderSvgPathHitRegion(
      path: parseSvgPath('M0 0 L100 0 L100 100 Z')!,
      filled: true,
      stroked: false,
      strokeWidth: 0,
      slop: kSvgPathHitSlop,
    );
    expect(region.hits(const Offset(80, 20)), isTrue);
    expect(region.hits(const Offset(20, 80)), isFalse);
  });
}

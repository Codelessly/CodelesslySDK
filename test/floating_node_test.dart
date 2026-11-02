import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A 40px field box that clips, with a menu hanging 100px below it.
  Widget field({required bool floating, required VoidCallback onTap}) => MaterialApp(
        home: Scaffold(
          body: Column(children: [
            SizedBox(
              width: 200,
              height: 40,
              child: ClipRect(
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0,
                    top: 44,
                    width: 200,
                    height: 100,
                    child: Builder(builder: (_) {
                      final Widget menu = GestureDetector(
                        key: const ValueKey('menu'),
                        onTap: onTap,
                        child: const ColoredBox(color: Color(0xFF00FF00)),
                      );
                      return floating ? FloatingNode(child: menu) : menu;
                    }),
                  ),
                ]),
              ),
            ),
            // The next field, which the menu should cover.
            Container(key: const ValueKey('below'), width: 200, height: 200, color: const Color(0xFFFF0000)),
          ]),
        ),
      );

  testWidgets('a floating menu is tappable outside its clipping parent and over later siblings', (tester) async {
    int taps = 0;
    await tester.pumpWidget(field(floating: true, onTap: () => taps++));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 100)); // inside "below", where the menu floats
    expect(taps, 1);
    // The layout is unchanged: the next box starts right after the field.
    expect(tester.getTopLeft(find.byKey(const ValueKey('below'))).dy, 40);
  });

  testWidgets('without floating the menu is clipped away and can\'t be tapped', (tester) async {
    int taps = 0;
    await tester.pumpWidget(field(floating: false, onTap: () => taps++));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 0);
  });

  test('floating survives JSON on any node', () {
    final node = TextNode(id: 't', name: 'T', basicBoxLocal: NodeBox(0, 0, 10, 10), textMixedProps: const [], data: 'x')..floating = true;
    final json = node.toJson();
    expect(json['floating'], isTrue);
    expect((NodeJsonConverter.instance.fromJson(json) as TextNode).floating, isTrue);
    expect(TextNode(id: 't', name: 'T', basicBoxLocal: NodeBox(0, 0, 10, 10), textMixedProps: const [], data: 'x').toJson().containsKey('floating'), isFalse);
  });
}

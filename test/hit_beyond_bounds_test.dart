import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A node laid out at one place and drawn elsewhere by its motion (a planet
/// on its orbit) is tapped where it is drawn.
void main() {
  Widget scene({required bool beyond, required VoidCallback onTap}) {
    Widget moved = Transform.translate(
      offset: const Offset(200, 0),
      child: GestureDetector(onTap: onTap, child: Container(width: 40, height: 40, color: Colors.red)),
    );
    // The boxes around a node's transform: margins, constraints.
    moved = Padding(padding: EdgeInsets.zero, child: SizedBox(width: 40, height: 40, child: moved));
    if (beyond) moved = HitBeyondBounds(child: moved);
    return MaterialApp(
      home: Stack(children: [Positioned(left: 0, top: 0, child: moved)]),
    );
  }

  testWidgets('without it the drawn node takes no taps', (tester) async {
    int taps = 0;
    await tester.pumpWidget(scene(beyond: false, onTap: () => taps++));
    await tester.tapAt(const Offset(220, 20), );
    expect(taps, 0);
  });

  testWidgets('with it the node is tapped where it is drawn', (tester) async {
    int taps = 0;
    await tester.pumpWidget(scene(beyond: true, onTap: () => taps++));
    await tester.tapAt(const Offset(220, 20));
    expect(taps, 1);
    // Not where it rests.
    await tester.tapAt(const Offset(20, 20));
    expect(taps, 1);
  });
}

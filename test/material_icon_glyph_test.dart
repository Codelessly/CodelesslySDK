import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("icons draw Flutter's glyph for their name, not Google's codepoint", () {
    // The editor stores Google's codepoint: add is e145 in that font.
    const add = MaterialIcon(codepoint: 0xe145, name: 'add', style: MaterialIconStyle.filled);
    expect(flutterGlyphOf(add), Icons.add.codePoint);
    const grid = MaterialIcon(codepoint: 0, name: 'grid_view', style: MaterialIconStyle.rounded);
    expect(flutterGlyphOf(grid), Icons.grid_view_rounded.codePoint);
    const fire = MaterialIcon(codepoint: 1, name: 'local_fire_department', style: MaterialIconStyle.rounded);
    expect(flutterGlyphOf(fire), Icons.local_fire_department_rounded.codePoint);
    const unknown = MaterialIcon(codepoint: 1, name: 'no_such_icon', style: MaterialIconStyle.filled);
    expect(flutterGlyphOf(unknown), isNull);
  });

  testWidgets('SvgIcon draws the glyph from the name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SvgIcon(icon: MaterialIcon(codepoint: 0xe145, name: 'add', style: MaterialIconStyle.filled)),
    ));
    expect(tester.widget<Icon>(find.byType(Icon)).icon!.codePoint, Icons.add.codePoint);
  });
}

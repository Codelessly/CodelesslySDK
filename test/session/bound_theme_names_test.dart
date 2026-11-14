// A recorded generation (tool/stream/streams/live/2026-11-14-ssui/
// reservation@claude-sonnet-5-5) showed its seven day buttons as empty
// boxes: each day's texts bound their style to a formula naming the design
// system's text style and colour,
//   "bind": {"props.style": "${= index == dayIdx ? {'from': 'caption', 'color': 'onPrimary'} : ...}"}
// and the selected day's fill to a colour name. Names written in a node are
// resolved against the theme before it renders; a bound value arrived after
// that, unresolved: the colour name drew as transparent. A bound value now
// names the theme as a written one does.
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide TextStyle, Color; // ignore: deprecated_member_use
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DesignSystem> _ssui() => DesignSystem.load((ref) async {
      final f = File('design_systems/ssui/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    });

List<Map<String, Object?>> _card(Map<String, Object?> node) => [
      {'op': 'roots', 'roots': ['c']},
      {'op': 'vars', 'scope': 'c', 'set': {'on': {'type': 'boolean', 'value': true}}},
      {'op': 'set', 'id': 'c', 'node': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 200, 'height': 100}}},
      {
        'op': 'set',
        'id': 'col',
        'node': {'type': 'column', 'children': ['n'], 'layout': {'width': {'fill': 200}, 'height': {'fill': 100}}},
      },
      {'op': 'set', 'id': 'n', 'node': node},
    ];

void main() {
  testWidgets('a text style bound to a formula that names a theme style and colour draws in that colour, not transparent', (tester) async {
    final ds = (await tester.runAsync(_ssui))!;
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    final r = session.apply(_card({
      'type': 'text',
      'props': {'text': 'Mon', 'style': {'from': 'caption', 'color': 'secondaryText'}},
      'bind': {'props.style': r"${= on ? {'from': 'caption', 'color': 'onPrimary'} : {'from': 'caption', 'color': 'secondaryText'}}"},
      'layout': {'width': {'hug': 40}, 'height': {'hug': 20}},
    }));
    expect(r.errors, isEmpty, reason: '${r.errors}');
    await tester.pumpWidget(MaterialApp(home: Material(child: CodelesslyView(session: session))));
    await tester.pump();
    final paragraphs = <RenderParagraph>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) paragraphs.add(o);
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(CodelesslyView)));
    final p = paragraphs.firstWhere((p) => p.text.toPlainText() == 'Mon');
    final expected = session.theme.forBrightness(dark: false).color('onPrimary')!;
    expect(p.text.style?.color?.toARGB32(), expected.value, reason: 'the bound style\'s colour name is the theme\'s onPrimary');
    expect(p.text.style?.fontSize, session.theme.textStyle('caption')!.fontSize, reason: 'its "from" names the caption style');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a fill bound to a theme colour name paints that colour', (tester) async {
    tester.view.physicalSize = const Size(200, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ds = (await tester.runAsync(_ssui))!;
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    session.apply(_card({
      'type': 'box',
      'layout': {'width': {'fill': 200}, 'height': {'fill': 100}},
      'decoration': {'fills': [{'color': 'primaryBackground'}]},
      'bind': {'decoration.fills[0].color': r"${= on ? 'primary' : 'primaryBackground'}"},
    }));
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: CodelesslyView(session: session)));
    await tester.pump();
    final pixel = await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      final bytes = (await image.toByteData())!;
      image.dispose();
      return bytes.getUint32(4 * (50 * 200 + 100)); // RGBA
    });
    final primary = session.theme.forBrightness(dark: false).color('primary')!.value; // ARGB
    final rgba = ((primary << 8) | (primary >> 24)) & 0xFFFFFFFF;
    expect(pixel!.toRadixString(16), rgba.toRadixString(16));
    await tester.pumpWidget(const SizedBox());
  });
}

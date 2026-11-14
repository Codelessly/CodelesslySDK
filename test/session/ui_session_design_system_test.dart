// A generated UI made with a design system (UiSession(designSystem:)):
// under the agent's trust profile its components are node types the agent
// may call, and they render as their definitions.
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart'; // ignore: deprecated_member_use
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DesignSystem> _ssui() => DesignSystem.load((ref) async {
      final f = File('design_systems/ssui/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    });

const _ops = [
  {'op': 'roots', 'roots': ['card']},
  {
    'op': 'set',
    'id': 'card',
    'node': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': {'hug': 200}}},
  },
  {
    'op': 'set',
    'id': 'col',
    'node': {
      'type': 'column',
      'children': ['save'],
      'layout': {'width': {'fill': 390}, 'height': {'hug': 200}, 'padding': 16},
      'decoration': {'fills': [{'color': 'primaryBackground'}]},
    },
  },
  {
    'op': 'set',
    'id': 'save',
    'node': {'type': 'Button', 'props': {'label': 'Save'}, 'layout': {'width': {'hug': 60}, 'height': {'hug': 28}}},
  },
];

void main() {
  testWidgets('an agent session with a design system may call its components, and they render as their definitions', (tester) async {
    final ds = (await tester.runAsync(_ssui))!;
    final session = UiSession(designSystem: ds);
    expect(session.profile.widgets, contains('Button'));
    final r = session.apply(_ops);
    expect(r.errors, isEmpty, reason: '${r.errors}');
    await tester.pumpWidget(MaterialApp(home: Material(child: CodelesslyView(session: session))));
    await tester.pump();
    final instances = <String>{};
    void visit(RenderObject o) {
      final ci = o is NodeBox ? componentInstanceOf(o.instance) : null;
      if (ci != null) instances.add('${ci.call} ${ci.component}');
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(CodelesslyView)));
    expect(instances, {'save Button'});
    session.dispose();
  });

  testWidgets('a call that streams in after its parent shows renders as its definition, not as an empty box', (tester) async {
    final ds = (await tester.runAsync(_ssui))!;
    final session = UiSession(designSystem: ds);
    await tester.pumpWidget(MaterialApp(home: Material(child: CodelesslyView(session: session))));
    final ops = [
      ..._ops.take(2),
      {
        'op': 'set',
        'id': 'col',
        'node': {'type': 'column', 'children': ['title', 'save'], 'layout': {'width': {'fill': 390}, 'height': {'hug': 200}}},
      },
      {'op': 'set', 'id': 'title', 'node': {'type': 'text', 'props': {'text': 'Hi'}, 'layout': {'width': 40, 'height': 20}}},
      _ops[3],
    ];
    // One op per frame, as a stream arrives: the column shows with its
    // title while the button is still pending.
    for (final op in ops) {
      expect(session.apply([op]).errors, isEmpty);
      await tester.pump();
    }
    final instances = <String>{};
    void visit(RenderObject o) {
      final ci = o is NodeBox ? componentInstanceOf(o.instance) : null;
      if (ci != null) instances.add('${ci.call} ${ci.component}');
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(CodelesslyView)));
    expect(instances, {'save Button'});
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('a session\'s theme names resolve in its own nodes in light mode, not only in dark', (tester) async {
    tester.view.physicalSize = const Size(200, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final dark in [false, true]) {
      final session = UiSession(
          theme: ThemeTokens.fromJson({
        'mode': dark ? 'dark' : 'light',
        'colors': {'brand': '#FFFF0000'},
        'dark': {
          'colors': {'brand': '#FF0000FF'},
        },
      }));
      session.apply([
        {'op': 'roots', 'roots': ['c']},
        {'op': 'set', 'id': 'c', 'node': {'type': 'canvas', 'slots': {'body': 'b'}, 'layout': {'width': 200, 'height': 100}}},
        {
          'op': 'set',
          'id': 'b',
          'node': {'type': 'box', 'layout': {'width': {'fill': 200}, 'height': {'fill': 100}}, 'decoration': {'fills': [{'color': 'brand'}]}},
        },
      ]);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: CodelesslyView(session: session)));
      await tester.pump();
      final pixel = await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        final bytes = (await image.toByteData())!;
        image.dispose();
        return bytes.getUint32(4 * (50 * 200 + 100)); // RGBA
      });
      expect(pixel!.toRadixString(16).padLeft(8, '0'), dark ? '0000ffff' : 'ff0000ff', reason: dark ? 'dark' : 'light');
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    }
  });

  test('a session without a design system keeps the agent profile', () {
    expect(identical(UiSession().profile, TrustProfile.agent), isTrue);
  });
}

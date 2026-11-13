// UiSession against what live generations showed: a retry that would start
// over is answered with start_over, the end of a stream reports what the UI
// gets wrong that no declaration catches (a button with no label, characters
// the font cannot draw), a laid-out node with content and no size is
// reported, the card's surface shows before its content, and ui_docs is
// answered for the session's profile. Scripts written with the scripts op
// run where the profile allows them (the replay harness runs them in
// QuickJS; see tool/stream/README.md).
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Catalog;
import 'package:flutter_test/flutter_test.dart';

const _card = {
  'ops': [
    {'op': 'roots', 'roots': ['card']},
    {
      'op': 'set',
      'id': 'card',
      'node': {
        'type': 'canvas',
        'slots': {'body': 'wrap'},
        'layout': {'width': 390, 'height': {'hug': 200}},
      },
    },
    {
      'op': 'set',
      'id': 'wrap',
      'node': {
        'type': 'column',
        'children': ['title', 'btn'],
        'layout': {'width': {'fill': 390}, 'height': {'hug': 200}, 'padding': 16},
        'decoration': {
          'fills': [{'color': '#FFFFFFFF'}],
        },
      },
    },
  ],
};

const _rest = {
  'ops': [
    {
      'op': 'set',
      'id': 'title',
      'node': {
        'type': 'text',
        'layout': {'width': {'hug': 200}, 'height': {'hug': 20}},
        'props': {'text': 'London → Lisbon', 'style': {'color': '#FF111827'}},
      },
    },
    {
      'op': 'set',
      'id': 'btn',
      'node': {
        'type': 'box',
        'layout': {'width': {'fill': 358}, 'height': 48},
        'decoration': {
          'fills': [{'color': '#FFFBBF24'}],
        },
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'componentEvent', 'event': 'alert'},
            ],
          },
        ],
      },
    },
  ],
};

Stream<String> _chunks(Object input) {
  final text = jsonEncode(input);
  return Stream.fromIterable([for (var i = 0; i < text.length; i += 7) text.substring(i, i + 7 > text.length ? text.length : i + 7)]);
}

void main() {
  testWidgets('the card surface shows before its content; lints and start_over in the result', (tester) async {
    final session = UiSession(catalog: Catalog.core, glyphCoverage: (family, cp) => cp < 0x2000);
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: CodelesslyView(session: session)));
    await session.applyStream(_chunks(_card));
    await tester.pump();
    // The canvas's body has a fill: it shows (the card), though no child has arrived.
    expect(identical(session.node('wrap'), session.document['wrap']), isTrue);
    final r = await session.applyStream(_chunks(_rest));
    await tester.pump();
    expect({for (final d in r.warnings) d.code}, containsAll(['empty_button', 'missing_glyph']));
    expect(r.warnings.firstWhere((d) => d.code == 'missing_glyph').message, contains('arrow_forward'));
    // A retry that rebuilds under a new root.
    final again = await session.applyStream(_chunks({
      'ops': [
        {'op': 'roots', 'roots': ['card2']},
        {'op': 'set', 'id': 'card2', 'node': {'type': 'canvas'}},
        {'op': 'patch', 'id': 'title', 'patch': {'props': {'text': 'London to Lisbon'}}},
      ],
    }));
    expect([for (final d in again.errors) d.code], ['start_over', 'start_over']);
    expect(again.applied, [2]);
    expect(session.document.roots, ['card']);
    expect(again.toModelJson()['next'], contains('Never start over'));
    expect(session.lastStreamEnd?.complete, isTrue);
    // Nothing laid out at zero size here.
    expect(session.layoutDiagnostics(), isEmpty);
    // ui_docs for the session's profile.
    expect(session.docs({'topic': 'runScript'}), contains('Not available here'));
  });

  testWidgets('a node with content laid out with no size: no_size', (tester) async {
    final session = UiSession(catalog: Catalog.core);
    session.apply({
      'ops': [
        ...(_card['ops']! as List),
        {
          'op': 'set',
          'id': 'title',
          'parent': 'wrap',
          'node': {
            'type': 'text',
            'layout': {'width': 0, 'height': 20},
            'props': {'text': 'Hidden by its width', 'style': {'color': '#FF111827'}},
          },
        },
      ],
    });
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: CodelesslyView(session: session)));
    await tester.pump();
    final d = session.layoutDiagnostics();
    expect(d.single.code, 'no_size');
    expect(d.single.nodeId, 'title');
  });

  test('the apps profile takes the scripts op; the default does not', () {
    const op = {
      'op': 'scripts',
      'set': {
        'inc': {
          'params': ['n'],
          'source': 'return n + 1;',
        },
      },
    };
    expect(UiSession(catalog: Catalog.core).apply(op).errors.single.code, 'capability_not_allowed');
    final apps = UiSession(catalog: Catalog.core, profile: TrustProfile.agentApps);
    expect(apps.apply(op).ok, isTrue);
    expect(apps.document.scripts.single.name, 'inc');
  });
}

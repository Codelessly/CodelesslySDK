// The chat over recorded streams: a reply's UI fills in as its stream
// plays (nothing first, then the card), a tap in it comes back as the
// user's turn, and a follow-up edits the same UI with a few ops.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart'; // ignore: deprecated_member_use
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/main.dart';

Map<String, NodeBox> _boxes(WidgetTester tester) {
  final out = <String, NodeBox>{};
  void visit(RenderObject o) {
    if (o is NodeBox && o.attached && o.hasSize && o.size != Size.zero) out[o.id] = o;
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return out;
}

void main() {
  testWidgets('a recorded reply renders as it streams; actions and edits flow back', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(StreamChatApp(source: RecordedStreamSource(speed: 4)));
    await tester.pump();
    final chat = tester.state<ChatScreenState>(find.byType(ChatScreen));
    final done = chat.send('Show me flights from London to Lisbon on Friday.');
    await tester.pump(const Duration(milliseconds: 100));
    final reply = chat.messages.whereType<ReplyMessage>().single;
    // Partway: some of the card, not all of it.
    var sawPartial = false;
    for (var i = 0; i < 80 && reply.session.document.nodes.length < 43; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final n = reply.session.document.nodes.length;
      if (n > 5 && n < 43 && _boxes(tester).containsKey('fcHead')) sawPartial = true;
    }
    await tester.pump(const Duration(seconds: 2));
    await done;
    await tester.pump();
    expect(sawPartial, isTrue);
    expect(reply.session.document.nodes.length, 43);
    expect(reply.result!.rejected, isEmpty);
    expect(_boxes(tester).keys, containsAll(['fcCard', 'opt1', 'opt3', 'fcCta']));
    expect(tester.takeException(), isNull);

    // Pick the third option, then confirm: the action is the user's turn.
    final opt3 = _boxes(tester)['opt3']!;
    await tester.tapAt(opt3.localToGlobal(opt3.size.center(Offset.zero)));
    await tester.pump(const Duration(milliseconds: 200));
    final cta = _boxes(tester)['fcCta']!;
    await tester.tapAt(cta.localToGlobal(cta.size.center(Offset.zero)));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    final action = chat.messages.whereType<UserMessage>().where((m) => m.action).single;
    expect(action.text, contains('confirmFlight'));
    expect(action.text, contains('EZY8611'));

    // A follow-up edits the same UI: one move op.
    final before = reply.session.document['fcOpts']!.children;
    final edit = chat.send('Sort them by price.');
    await tester.pump(const Duration(seconds: 2));
    await edit;
    await tester.pump();
    expect(before, ['opt1', 'opt2', 'opt3']);
    expect(reply.session.document['fcOpts']!.children, ['opt1', 'opt3', 'opt2']);
    expect(reply.note, contains('an edit'));
    await tester.pumpWidget(const SizedBox());
  });
}

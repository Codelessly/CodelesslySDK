// A reply whose UI validates but shows nothing: the result the model reads
// next (EditTurn's tool result) carries what the drawn UI shows wrong
// (UiSession.shownDiagnostics), and the session checks formulas as it goes.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/main.dart';

/// Answers every turn with [ops] (one delta).
class _Fixed implements StreamSource {
  _Fixed(this.ops);
  final String ops;

  @override
  String get label => 'fixed';

  @override
  SourceReply reply(ChatTurn turn) =>
      SourceReply(toolInput: Stream.value(ops), text: Future.value(''), usage: Future.value(const {}));
}

void main() {
  testWidgets('a card whose list reads a formula that does not parse: the reply\'s result says so, and that the list shows nothing',
      (tester) async {
    const ops = '{"ops": ['
        '{"op": "roots", "roots": ["c"]},'
        '{"op": "set", "id": "c", "node": {"type": "canvas", "slots": {"body": "col"}, "layout": {"width": 360, "height": {"hug": 200}}}},'
        '{"op": "vars", "scope": "c", "set": {"slots": {"type": "list", "formula": "map(times, function(t) { return t })"}, '
        '"times": {"type": "list", "value": ["18:00", "18:30"]}}},'
        '{"op": "set", "id": "col", "node": {"type": "column", "children": ["title", "grid"], "layout": {"width": {"fill": 360}, "height": {"hug": 200}}}},'
        '{"op": "set", "id": "title", "node": {"type": "text", "props": {"text": "Time", "style": {"color": "#FF111827"}}, "layout": {"width": {"hug": 60}, "height": {"hug": 20}}}},'
        '{"op": "set", "id": "grid", "node": {"type": "listView", "children": ["slot"], "bind": {"data": "\${slots}"}, "layout": {"width": {"fill": 360}, "height": {"hug": 80}}}},'
        '{"op": "set", "id": "slot", "node": {"type": "text", "props": {"text": "\${item}", "style": {"color": "#FF111827"}}, "layout": {"width": {"hug": 60}, "height": {"hug": 20}}}}'
        ']}';
    await tester.pumpWidget(StreamChatApp(source: _Fixed(ops)));
    await tester.pump();
    final chat = tester.state<ChatScreenState>(find.byType(ChatScreen));
    final done = chat.send('Show me the times.');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await done;
    final result = chat.messages.whereType<ReplyMessage>().single.result!;
    final json = result.toModelJson();
    final rejected = [for (final d in json['rejected']! as List) '${(d as Map)['code']} ${d['path']}'];
    expect(rejected, containsAll(['expression_syntax /variables/c/0/formula', 'list_empty /nodes/grid/bind~1data']));
    expect(json['next'], isNotNull, reason: 'the model is told to fix it');
  });
}

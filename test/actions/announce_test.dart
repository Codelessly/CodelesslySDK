import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';
import '../support/screen.dart' as harness;

void main() {
  testWidgets(
    'announce speaks the current value on pointer and keyboard without moving focus',
    (tester) async {
      final events = <Map>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            if (message is Map) events.add(message);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      final nodes = harness.counter(
        actions: [
          harness.reaction('click', [
            harness.add('count'),
            {'type': 'announce', 'message': r'${count} results'},
          ]),
        ],
      );
      final s = await harness.show(
        tester,
        nodes,
        variables: [harness.v('count', 0, VariableType.integer)],
      );
      await tester.tapAt(s.center('button'));
      await tester.pump();
      expect(events.last['type'], 'announce');
      expect((events.last['data'] as Map)['message'], '1 results');
      final keys = Keyboard(tester);
      await keys.tab();
      expect(keys.focusedId, 'button');
      await keys.enter();
      await tester.pump();
      expect((events.last['data'] as Map)['message'], '2 results');
      expect(keys.focusedId, 'button');
    },
  );

  testWidgets(
    'live text carries a live-region semantic flag while its value changes',
    (tester) async {
      final handle = tester.ensureSemantics();
      final nodes = harness.counter();
      nodes['label'] = {
        ...nodes['label']!,
        'props': {'text': r'${count} results', 'live': true},
      };
      final s = await harness.show(
        tester,
        nodes,
        variables: [harness.v('count', 0, VariableType.integer)],
      );
      bool hasLive(String label) {
        var found = false;
        void visit(SemanticsNode node) {
          final data = node.getSemanticsData();
          if (data.label == label && data.flagsCollection.isLiveRegion) {
            found = true;
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(
          tester
              .binding
              .renderViews
              .single
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        return found;
      }

      expect(hasLive('0 results'), isTrue);
      s.scope.set('count', 3);
      await tester.pump();
      expect(hasLive('3 results'), isTrue);
      handle.dispose();
    },
  );
  testWidgets('pointer announcement inherits document RTL direction', (tester) async {
    final events = <Map>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map) events.add(message);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, null));
    final nodes = harness.counter(actions: [harness.reaction('click', [{'type': 'announce', 'message': 'Ready'}])]);
    nodes['col'] = {...nodes['col']!, 'textDirection': 'rtl'};
    final s = await harness.show(tester, nodes);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect((events.last['data'] as Map)['textDirection'], TextDirection.rtl.index);
  });
}

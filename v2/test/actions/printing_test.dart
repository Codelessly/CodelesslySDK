import 'dart:typed_data';

import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Printer implements PrintService {
  final images = <Uint8List>[];
  @override
  Future<bool> printPng(Uint8List png) async {
    images.add(png);
    return true;
  }
}

void main() {
  testWidgets(
    'print scrolls a badge into view and sends only its PNG to the dialog service',
    (tester) async {
      final document = LayoutDocument.fromJson({
        'roots': ['root'],
        'nodes': {
          'root': {
            'type': 'column',
            'props': {'scrollable': true},
            'layout': {'width': 200, 'height': 200},
            'children': ['space', 'badge'],
          },
          'space': {
            'type': 'box',
            'layout': {'height': 250},
          },
          'badge': {
            'type': 'box',
            'layout': {'width': 120, 'height': 80},
            'decoration': {
              'fills': [
                {'color': '#E5FA52'},
              ],
            },
          },
        },
      });
      final tree = NodeTree(DocumentSource(document));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: NodeView(tree: tree, rootId: 'root', interactive: true),
          ),
        ),
      );
      final printer = Printer();
      final scope = VariableScope([
        const Variable(
          name: 'requested',
          type: VariableType.boolean,
          value: false,
        ),
      ]);
      final errors = <Object>[];
      final context = RuntimeActionContext(
        scope: scope,
        tree: tree,
        services: Services(printing: printer),
        onError: (e, _, _) => errors.add(e),
      );
      final trigger = Node.fromJson({
        'type': 'box',
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'print', 'node': 'badge'},
              {
                'type': 'setVariable',
                'variable': 'requested',
                'value': r'${result.requested}',
              },
            ],
          },
        ],
      }, id: 'button')!;
      await tester.runAsync(() async {
        final action = const CodelesslyActions().run(trigger, 'click', context);
        await tester.pump();
        await action;
      });
      expect(errors, isEmpty);
      expect(scope.read('requested'), true);
      expect(printer.images, hasLength(1));
      final png = printer.images.single;
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(png);
      expect(header.getUint32(16), 240);
      expect(header.getUint32(20), 160);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
      scope.dispose();
    },
  );

  test('unsupported platforms report no requested print dialog', () async {
    expect(await const PlatformPrintService().printPng(Uint8List(0)), false);
  });
}

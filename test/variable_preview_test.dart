import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => VariablePreview.scopeResolver = null);

  group('placeholders', () {
    test('name a path after its last segment', () {
      expect(VariablePreview.textFor(r'${auth.displayName}'), 'Display name');
      expect(VariablePreview.textFor(r'${item.photo_count}'), 'Photo count');
      expect(VariablePreview.textFor(r'${total}'), 'Total');
    });

    test('skip accessors and indices', () {
      expect(VariablePreview.textFor(r'${item.title.initial}'), 'Title');
      expect(VariablePreview.textFor(r'${members[0].length}'), 'Members');
    });

    test('name a formula after the first variable it reads', () {
      expect(VariablePreview.textFor(r'${= money(cart.total)}'), 'Total');
      expect(
        VariablePreview.textFor(r'${= plural(count, "photo", "photos")}'),
        'Count',
      );
      expect(VariablePreview.textFor(r'${= 1 + 2 > 0}'), '…');
    });
  });

  group('defaults', () {
    setUp(() {
      VariablePreview.scopeResolver = (node, {item}) => ScopedValues.preview(
        variables: {
          'userName': VariableData(
            id: 'v1',
            name: 'userName',
            value: 'Ray',
            type: VariableType.text,
          ),
          'price': VariableData(
            id: 'v2',
            name: 'price',
            value: '4.5',
            type: VariableType.decimal,
          ),
        },
      );
    });

    test('show a variable default value', () {
      expect(VariablePreview.textFor(r'${userName}'), 'Ray');
      expect(VariablePreview.textFor(r'${userName.length}'), '3');
    });

    test('evaluate formulas with defaults', () {
      expect(VariablePreview.textFor(r'${= price * 2}'), '9');
    });

    test('show nothing for a formula that yields empty text', () {
      expect(VariablePreview.textFor(r"${= if(price > 9, 'big', '')}"), '');
      expect(VariablePreview.textFor(r'${= missing.name}'), 'Name');
    });

    test('fall back to a placeholder when there is no value', () {
      expect(VariablePreview.textFor(r'${auth.email}'), 'Email');
    });
  });

  test('VariableSpan shows the preview text', () {
    expect(VariableSpan(variable: r'${auth.email}').text, 'Email');
  });

  test('fixed-width nodes show a compact marker only when needed', () {
    TextNode node(SizeFit fit, {double width = 40}) => TextNode(
      id: 'text',
      name: 'Text',
      basicBoxLocal: NodeBox(0, 0, width, 20),
      horizontalFit: fit,
      characters: r'${shots}',
    );
    expect(
      VariablePreview.textFor(r'${shots}', node: node(SizeFit.fixed)),
      '…',
    );
    expect(
      VariablePreview.textFor(r'${shots}', node: node(SizeFit.shrinkWrap)),
      'Shots',
    );
    expect(
      VariablePreview.textFor(
        r'${shots}',
        node: node(SizeFit.fixed, width: 350),
      ),
      'Shots',
    );
  });

  testWidgets('a list row shows its own item', (tester) async {
    VariablePreview.scopeResolver = (node, {item}) => ScopedValues.preview(
      variables: const {},
      indexedItem: item ?? IndexedItem(0, {'id': 'first'}),
    );
    final texts = <String>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            for (final id in ['a', 'b'])
              IndexedItemProvider(
                item: IndexedItem(0, {'id': id}),
                child: Builder(
                  builder: (context) {
                    texts.add(
                      VariablePreview.textFor(r'${item.id}', context: context),
                    );
                    return const SizedBox();
                  },
                ),
              ),
          ],
        ),
      ),
    );
    expect(texts, ['a', 'b']);
    expect(VariablePreview.textFor(r'${item.id}'), 'first');
  });
}

import 'package:codelessly_api/codelessly_api.dart';
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
      VariablePreview.scopeResolver = (node) => ScopedValues.preview(
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

    test('read the list item the text is built for', () {
      VariablePreview.scopeResolver = (node) => ScopedValues.preview(
        variables: const {},
        indexedItem: IndexedItem(0, {'name': 'Canyon Loop'}),
      );
      expect(VariablePreview.textFor(r'${item.name}'), 'Canyon Loop');
      expect(
        VariablePreview.textFor(
          r'${item.name}',
          item: IndexedItem(2, {'name': 'Spring Shakedown'}),
        ),
        'Spring Shakedown',
      );
    });

    test('evaluate formulas with defaults', () {
      expect(VariablePreview.textFor(r'${= price * 2}'), '9');
    });

    test('show a formula that gives empty text as empty', () {
      expect(VariablePreview.textFor(r"${= if(price > 9, 'x', '')}"), '');
      expect(VariablePreview.textFor(r"${= ''}"), '');
      VariablePreview.scopeResolver = (node) => ScopedValues.preview(
        variables: const {},
        indexedItem: IndexedItem(0, {'published': false}),
      );
      expect(
        VariablePreview.textFor(r"${= if(item.published, 'Published', '')}"),
        '',
      );
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

  group('list items', () {
    setUp(() {
      // As the editor resolves a node in a bound list: the first item.
      VariablePreview.scopeResolver = (node) => ScopedValues.preview(
        variables: {
          'region': VariableData(
            id: 'v1',
            name: 'region',
            value: 'All',
            type: VariableType.text,
          ),
        },
        indexedItem: IndexedItem(0, {'label': 'All'}),
      );
    });

    test('an item with data shows its own element', () {
      final IndexedItem third = IndexedItem(2, {'label': 'Orange County'});
      expect(
        VariablePreview.textFor(r'${item.label}', item: third),
        'Orange County',
      );
      expect(VariablePreview.textFor(r'${= index + 1}', item: third), '3');
      expect(
        VariableSpan(variable: r'${item.label}', item: third).text,
        'Orange County',
      );
      // Variables still read the canvas's defaults.
      expect(VariablePreview.textFor(r'${region}', item: third), 'All');
    });

    test('without item data the item from the resolver stands', () {
      expect(VariablePreview.textFor(r'${item.label}'), 'All');
      expect(
        VariablePreview.textFor(r'${item.label}', item: IndexedItem(3, null)),
        'All',
      );
    });
  });
}

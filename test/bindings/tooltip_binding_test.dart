// A tooltip whose own text holds `${...}` (the notation writes
// `tooltip="Play at {s}"` so) is filled in from the scope, as a text's own
// text is: in a list copy it reads the copy's item, not `${item}` raw.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/runtime/expressions/bindings.dart';
import 'package:codelessly_sdk/src/runtime/expressions/engine.dart';
import 'package:codelessly_sdk/src/runtime/expressions/scopes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a tooltip with a value in it is bound, and reads the item', () {
    final n = api.Node.fromJson({'id': 'chip', 'type': 'box', 'tooltip': r'Play at ${item.speed}×'})!;
    final b = NodeBindings.of(n);
    final p = b.properties.where((p) => p.path == 'tooltip').single;
    final scope = ItemScope(index: 0, item: {'speed': 2});
    final shown = p.applyTo(n, const Expressions(), scope);
    expect(shown.behaviors.tooltip, 'Play at 2×');
  });

  test('a fixed tooltip, or one the node binds itself, is not bound again', () {
    expect(NodeBindings.of(api.Node.fromJson({'id': 'a', 'type': 'box', 'tooltip': 'Fixed'})!).properties, isEmpty);
    final bound = api.Node.fromJson({
      'id': 'b',
      'type': 'box',
      'tooltip': r'${item.name}',
      'bind': {'tooltip': r'${item.name}'},
    })!;
    expect(NodeBindings.of(bound).properties.where((p) => p.path == 'tooltip'), hasLength(1));
  });
}

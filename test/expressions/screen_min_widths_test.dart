// A responsive layout's own breakpoint widths recompute the breakpoint
// values of `screen`, and keep the rest (how the screen is shown).
import 'package:codelessly_sdk/src/runtime/expressions/scopes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screenWithMinWidths keeps screen.modal and screen.sheet', () {
    final screen = {...screenValues(390, 844), 'modal': true, 'sheet': true};
    final local = screenWithMinWidths(screen, {'tablet': 500});
    expect(local['sheet'], isTrue);
    expect(local['modal'], isTrue);
    expect(local['width'], 390);
  });
}

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mixtape's deck: `livePos` moves with `nowMs()`, and `rRight` (a reel's
/// radius) is computed from `livePos`. Both must read a new value each time
/// the clock moves, however deep the chain.
void main() {
  test('computed variables over nowMs() are not cached', () async {
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'start': VariableData(
          id: 'start',
          name: 'start',
          type: VariableType.decimal,
          value: '${DateTime.now().millisecondsSinceEpoch}',
        ),
        'livePos': VariableData(
          id: 'livePos',
          name: 'livePos',
          type: VariableType.decimal,
          formula: '(nowMs() - start) / 1000',
        ),
        'rRight': VariableData(
          id: 'rRight',
          name: 'rRight',
          type: VariableType.decimal,
          formula: 'sqrt(1 + 5.76 * livePos / 1800)',
        ),
      },
    );
    double read(String n) =>
        (PropertyValueDelegate.getVariableValueFromPath<Object>(
          n,
          scopedValues: scope,
        ) as num).toDouble();
    final double a = read('livePos'), ra = read('rRight');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(read('livePos'), greaterThan(a));
    expect(read('rRight'), greaterThan(ra));
  });
}

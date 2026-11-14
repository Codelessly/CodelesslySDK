// A recorded generation (tool/stream/streams/live/2026-11-14-ssui/
// data_table@claude-sonnet-5-5) showed "No results" under a table whose
// twelve invoices were defined: its list read
//   filtered = sortBy(filter(invoices, (statusF == 'All' || status == statusF)
//              && contains(lower(cust), lower(search))), sortKey, sortDir)
// The condition is not a lambda: it is computed once, outside the list
// (status and cust are no variables), and as a field name it matches no
// item. The formula engine is right to give an empty list; the session now
// tells the model, when the stream ends, which name is an item's field and
// the lambda to write.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/stream/src/replay.dart' show RecordedStream, loadDesignSystem;

const _recording = 'tool/stream/streams/live/2026-11-14-ssui/data_table@claude-sonnet-5-5.compact.ssui.r1.jsonl';

ValidateOptions _options({api.DesignSystem? ds}) => ValidateOptions(
      formulas: (f) => (error: FormulaEvaluator.errorOf(f), paths: FormulaEvaluator.referencedPaths(f)),
      components: ds?.components,
      theme: ds?.tokens,
    );

final _invoices = [
  for (final (i, s) in ['Paid', 'Pending', 'Overdue', 'Paid'].indexed) {'num': 'INV-$i', 'cust': 'Customer $i', 'amt': 100 * (i + 1), 'status': s},
];

void main() {
  group('a list filtered by a condition without its item', () {
    Object? read(String name) => {'invoices': _invoices, 'statusF': 'All', 'search': ''}[name];

    test('filters to nothing: the condition is computed once, outside the list', () {
      expect(FormulaEvaluator.evaluate("filter(invoices, (statusF == 'All' || status == statusF) && contains(lower(cust), lower(search)))", read), isEmpty);
    });

    test('written with a lambda, keeps every record when the search is empty and the status is All', () {
      expect(
          FormulaEvaluator.evaluate(
              "filter(invoices, i => (statusF == 'All' || i.status == statusF) && contains(lower(i.cust), lower(search)))", read),
          hasLength(4));
    });

    test('sortBy takes its direction as "asc" or "desc", not as 1 or -1', () {
      Object? r(String n) => {'invoices': _invoices, 'desc': true}[n];
      expect(FormulaEvaluator.evaluate("map(sortBy(invoices, 'amt', desc ? 'desc' : 'asc'), 'amt')", r), [400, 300, 200, 100]);
    });
  });

  testWidgets('when the recorded stream ends, the session reports the item fields its filter read without the item', (tester) async {
    final stream = RecordedStream.read(_recording);
    final ds = (await tester.runAsync(() => loadDesignSystem('ssui')))!;
    final session = UiSession(designSystem: ds, check: strictEditCheck(_options(ds: ds)));
    addTearDown(session.dispose);
    final result = await session.applyStream(Stream.value(stream.text));

    final names = [for (final d in result.errors) if (d.code == 'unknown_name' && d.path.startsWith('/variables/')) d];
    expect([for (final d in names) d.message.split(':').first], containsAll(['Variable "filtered"']));
    final status = names.firstWhere((d) => d.message.contains('"status" is not a variable'));
    expect(status.message, contains('a field of the records of "invoices"'));
    expect(status.message, contains('filter(invoices, r => r.status == x)'));
    expect(status.op, -1, reason: 'reported at the end of the stream; the op stays applied');
    // The streamed warning it replaces is gone.
    expect(result.warnings.where((d) => d.code == 'unknown_name' && d.path == status.path), isEmpty);
    // The bulk bar's total read its fields the same way.
    expect(result.errors.where((d) => d.path.startsWith('/nodes/barTxt') && d.code == 'unknown_name').map((d) => d.message),
        everyElement(contains('a field of the records of "invoices"')));
  });

  testWidgets('a reference that arrives before the stream ends is not reported', (tester) async {
    final session = UiSession(check: strictEditCheck(_options()));
    addTearDown(session.dispose);
    const ops = '{"ops": [{"op": "roots", "roots": ["c"]}, '
        '{"op": "set", "id": "c", "node": {"type": "canvas", "layout": {"width": 300, "height": 200}}}, '
        '{"op": "vars", "scope": "c", "set": {"rows": {"type": "list", "formula": "slice(shown, 0, 5)"}}}, '
        '{"op": "vars", "scope": "c", "set": {"shown": {"type": "list", "value": []}}}]}';
    final result = await session.applyStream(Stream.value(ops));
    expect(result.errors, isEmpty);
  });
}

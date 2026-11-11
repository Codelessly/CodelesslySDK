import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'runner_test.dart' show Harness, v;

void main() {
  test('downloadFile evaluates filename and contents and reports completion', () async {
    final exports = RecordingFileExporter();
    final h = Harness(services: Services(exports: exports), variables: [
      v('week', '2026-11-09'), v('csv', 'Name,Hours\r\nAlma,32\r\nMaja,24'),
      v('saved', false, VariableType.boolean),
    ]);
    await h.click([
      {'type': 'downloadFile', 'fileName': r'rota-${week}.csv', 'text': r'${csv}', 'mimeType': 'text/csv'},
      {'type': 'setVariable', 'variable': 'saved', 'value': r'${result.saved}'},
    ]);
    expect(h.errors, isEmpty);
    expect(h['saved'], true);
    expect(exports.files.single.fileName, 'rota-2026-11-09.csv');
    expect(exports.files.single.text, 'Name,Hours\r\nAlma,32\r\nMaja,24');
    expect(exports.files.single.mimeType, 'text/csv');
  });
  test('cancelling a save is a normal result and does not create a file', () async {
    final exports = RecordingFileExporter()..cancelled = true;
    final h = Harness(services: Services(exports: exports), variables: [v('saved', true, VariableType.boolean)]);
    await h.click([
      {'type': 'downloadFile', 'fileName': 'draft.csv', 'text': 'hello'},
      {'type': 'setVariable', 'variable': 'saved', 'value': r'${result.saved}'},
    ]);
    expect(exports.files, isEmpty);
    expect(h['saved'], false);
    expect(h.errors, isEmpty);
  });
  test('suggested filenames cannot choose directories or contain control characters', () {
    expect(exportFileName('../rota\\week\u0000.csv'), '.._rota_week_.csv');
    expect(exportFileName('  '), 'export.txt');
    expect(exportFileName('..'), 'export.txt');
    expect(exportFileName('Røta.csv'), 'Røta.csv');
  });
}

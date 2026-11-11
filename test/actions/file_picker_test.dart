// A cloudFiles upload without a `source` asks the person for files. The app
// shell's screens give no picker of their own, so the services' FilePicker
// (the platform's file dialog by default) chooses them; before, the upload
// got no files and did nothing ("Change photo" never opened a dialog).
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Node _click(List<Json> actions) => Node.fromJson({
      'type': 'box',
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': actions,
        },
      ],
    }, id: 'photo')!;

const Json _upload = {
  'type': 'cloudFiles',
  'path': 'avatars/u1',
  'maxSizeMB': 5,
  'actions': [
    {'type': 'setVariable', 'variable': 'url', 'value': r'${result.url}'},
  ],
};

PickedFile _photo(int bytes, {String type = 'image/jpeg'}) =>
    PickedFile(name: 'photo.jpg', bytes: Uint8List(bytes), contentType: type);

void main() {
  Future<(VariableScope, List<Json>)> upload(FilePicker picker, {ActionUi? ui}) async {
    final scope = VariableScope(const [Variable(name: 'url', value: '')]);
    final events = <Json>[];
    final context = RuntimeActionContext(
      scope: scope,
      ui: ui ?? NavigatorActionUi(context: () => null),
      services: Services(filePicker: picker, analytics: const NoAnalytics()),
      onActionErrorEvent: events.add,
    );
    await const CodelesslyActions().trigger(_click([_upload]), 'click', context);
    return (scope, events);
  }

  test('a screen without its own picker uploads what the services\' picker chose', () async {
    final (scope, events) = await upload(FixedFilePicker([_photo(1024)]));
    expect(events, isEmpty);
    expect(scope.read('url'), isNotEmpty);
    scope.dispose();
  });

  test('a photo over the limit fails with file-too-large', () async {
    final (scope, events) = await upload(FixedFilePicker([_photo(7 * 1024 * 1024)]));
    expect((events.single['error'] as Map)['code'], 'file-too-large');
    expect(scope.read('url'), '');
    scope.dispose();
  });

  test('a file that is not an image fails with invalid-file-type', () async {
    final (scope, events) = await upload(FixedFilePicker([_photo(10, type: 'application/pdf')]));
    // An image upload (kind image is the default).
    expect((events.single['error'] as Map)['code'], 'invalid-file-type');
    scope.dispose();
  });

  test('a shell that gives its own picker wins', () async {
    final ui = NavigatorActionUi(context: () => null, files: ({bool images = true, bool multiple = true}) async => const []);
    final (scope, events) = await upload(FixedFilePicker([_photo(1024)]), ui: ui);
    expect(events, isEmpty);
    expect(scope.read('url'), '', reason: 'the shell\'s picker chose nothing');
    scope.dispose();
  });

  test('cancelling (no files) does nothing', () async {
    final (scope, events) = await upload(const FixedFilePicker([]));
    expect(events, isEmpty);
    expect(scope.read('url'), '');
    scope.dispose();
  });
}

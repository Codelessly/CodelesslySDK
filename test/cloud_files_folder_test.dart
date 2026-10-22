import 'package:codelessly_sdk/src/functions/cloud_files.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('private files go under the uploader\'s folder', () {
    expect(
      CloudFiles.folderFor(
        root: 'data/p1',
        folder: r'albums/a1',
        access: CloudFileAccess.private,
        uid: 'u1',
      ),
      'data/p1/users/u1/albums/a1',
    );
    expect(
      () => CloudFiles.folderFor(
        root: 'data/p1',
        folder: 'x',
        access: CloudFileAccess.private,
        uid: null,
      ),
      throwsStateError,
    );
  });

  test('public files go in the project folder, never above it', () {
    expect(
      CloudFiles.folderFor(
        root: 'preview_data/p1',
        folder: '../../other/ photos /',
        access: CloudFileAccess.public,
        uid: 'u1',
      ),
      'preview_data/p1/other/photos',
    );
  });
}
